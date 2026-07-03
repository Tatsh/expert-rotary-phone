//
//  OverScoreLogViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The "friend over-score" log
//  screen. Objective-C++ (.mm) because it drives the C++ "ne" engine singletons via
//  neEngineBridge (scene manager, root view controller, system SEs) and, on close, the C++
//  MusicSelTask / PlayTask launch path.
//

#import "OverScoreLogViewController.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "OverScoreLogCell.h"
#import "C_TASK.h"
#import "TaskFactory.h"
#import "MusicData.h"
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

namespace {
// MusicSelTask fields touched when launching a play from the over-score log. MusicSelTask is not
// yet reconstructed (TODO(dep): MusicSelTask); its storage is the same work area MainTask.mm maps,
// so read raw at the exact byte offsets, mirroring SortSelectViewController.mm.
constexpr int kOffMusicList    = 0x30;   // NSArray<MusicData *> * (id) — the loaded song list
constexpr int kOffSelectIndex  = 0x8f8;  // int     chosen list index
constexpr int kOffSelectMusic  = 0x900;  // int     chosen music id
constexpr int kOffSelectSheet  = 0x904;  // int     chosen difficulty (sheet)
constexpr int kOffSelectSeInst = 0x8e4;  // int     confirm-SE playing instance
constexpr int kOffSpawnedTask  = 0xaa0;  // C_TASK* the launched PlayTask
constexpr int kOffState        = 0xaa4;  // int     task state field

template <typename T>
inline T &TaskField(MusicSelTask *task, int off) {
    return *reinterpret_cast<T *>(reinterpret_cast<char *>(task) + off);
}
inline id TaskMusicList(MusicSelTask *task) {
    return *reinterpret_cast<__unsafe_unretained id *>(reinterpret_cast<char *>(task) + kOffMusicList);
}
}  // namespace

@interface OverScoreLogViewController ()
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)backButtonFunc;
@end

@implementation OverScoreLogViewController {
    UIViewController *_dummyView;              // dimmed spinner overlay shown while downloading
    BOOL _isAnimationing;                      // an open/close animation is in flight
    NSMutableArray *_overScoreLogDataArray;    // boxed OverScoreLogData rows (from DownloadMain)
    int m_musicId;                             // song picked to play (-1 = none)
    int m_sheet;                               // difficulty picked to play (-1 = none)
}

@synthesize musicSelTask = _musicSelTask;

// @ 0x29928 — build the transparent, separator-less table: a clear 20-pt spacer header, the
// "friman" backdrop (phone) / clear (iPad), and a hidden dimmed loading overlay with a large
// spinner.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) {
        return nil;
    }
    CGRect viewFrame = self.view.frame;
    self.tableView.rowHeight = 54.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    // Clear 20-pt spacer header.
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, viewFrame.size.width, 20.0f)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // iPad: pull the list up under the nav bar (-20 pre-iOS7, -10 on iOS7+).
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset = UIEdgeInsetsMake(osVersion < 7.0f ? -20.0f : -10.0f, 0.0f, 0.0f, 0.0f);
    }

    // Backdrop: "friman_bg" image (phone) / clear (iPad).
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *frimanImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *frimanView = [[UIImageView alloc] initWithImage:frimanImg];
        frimanView.frame = CGRectMake(0.0f, 0.0f, frimanImg.size.width, frimanImg.size.height);
        self.tableView.backgroundView = frimanView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Dimmed "loading" overlay (transparent white, hidden until viewDidLoad) + large spinner.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = self.view.frame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.0f];
    _dummyView.view.hidden = YES;
    [self.tableView addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    CGRect frame = self.view.frame;
    spinner.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f - 50.0f);
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];
    return self;
}

// @ 0x29e24 — keep the C++ task pointer, (re)build the table via initWithStyle:, wrap self in a
// UINavigationController (with a back button on phone) and return that nav controller.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask {
    _musicSelTask = musicSelTask;
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return navigationController;
}

// dealloc @ 0x29fd8 — ARC omits the -release of _overScoreLogDataArray / _dummyView; kept only to
// detach self as DownloadMain's over-score-log delegate (a non-object side effect ARC can't do).
- (void)dealloc {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl delegateGetOverScoreLog] == self) {
        [dl setDelegateGetOverScoreLog:nil];
    }
}

// @ 0x2a08c — reveal the spinner overlay, reset the pending selection, register as DownloadMain's
// over-score-log delegate and kick off the download.
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        [self setContentSizeForViewInPopover:CGSizeMake(320.0f, 524.0f)];
    }
    m_musicId = -1;
    m_sheet = -1;
    _dummyView.view.hidden = NO;
    DownloadMain *dl = [DownloadMain getInstance];
    [dl setDelegateGetOverScoreLog:self];
    [dl startGetOverScoreLogHttp];
}

// didReceiveMemoryWarning @ 0x2a180 — super-only override, omitted.

#pragma mark - Open / close animation (shared modal-VC lifecycle)

// @ 0x2a1b0 — fade the view + nav view in (phone) or slide the nav view up into place (iPad).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        self.navigationController.view.alpha = 1.0f;
    } else {
        // iPad: pre-position the nav view below the root scene, then slide it up. The completion
        // runs a folded shared settle animation whose exact frame math is not recovered; modelled
        // here as the lifecycle end (endOpenAnimation). Best-effort.
        UIViewController *root = RootVC();
        CGRect navFrame = self.navigationController.view.frame;
        CGRect rootFrame = root.view.frame;
        self.navigationController.view.frame =
            CGRectMake(navFrame.origin.x, rootFrame.size.height, navFrame.size.width, navFrame.size.height);
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             CGRect f = self.navigationController.view.frame;
                             self.navigationController.view.frame =
                                 CGRectMake(f.origin.x, 420.0f, f.size.width, f.size.height);
                         }
                         completion:^(BOOL finished) {
                             [self endOpenAnimation];
                         }];
    }
    [UIView commitAnimations];
}

// @ 0x2a664
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x2a678 — fade (phone) / slide (iPad) the panel out; the completion (endCloseAnimation)
// launches the selected play.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
    } else {
        // iPad: slide out; the folded completion is modelled as endCloseAnimation. Best-effort.
        UIViewController *root = RootVC();
        (void)root;
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             CGRect f = self.navigationController.view.frame;
                             self.navigationController.view.frame =
                                 CGRectMake(f.origin.x, 420.0f, f.size.width, f.size.height);
                         }
                         completion:^(BOOL finished) {
                             [self endCloseAnimation];
                         }];
    }
    [UIView commitAnimations];
}

// @ 0x2aad4 — remove the nav view, notify the root host, and (if a row was picked) drive the
// owning MusicSelTask into a play of the chosen song: find it in the task's song list, stash the
// selection, pop the menu BGM, fire the decide SE, spawn a PlayTask and hand it to the app
// delegate (state -> 0xc). If the song is not installed, alert instead (state -> 2).
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(OverScoreLogEndCallBack)];
    _isAnimationing = NO;

    if (m_musicId == -1 || m_sheet == -1) {
        return;
    }
    MusicSelTask *task = _musicSelTask;
    id musicList = TaskMusicList(task);
    NSUInteger count = [musicList count];
    for (NSUInteger i = 0; i < count; i++) {
        MusicData *info = [musicList objectAtIndexedSubscript:i];
        if ([info MusicID] == m_musicId) {
            TaskField<int>(task, kOffSelectIndex) = (int)i;
            TaskField<int>(task, kOffSelectMusic) = m_musicId;
            TaskField<int>(task, kOffSelectSheet) = m_sheet;
            AudioManager *audio = [AudioManager sharedManager];
            [audio popBgm];
            TaskField<int>(task, kOffSelectSeInst) = (int)[audio playSe:nil resourceId:0];
            TaskField<C_TASK *>(task, kOffSpawnedTask) = PlayTaskCreate();
            [[AppDelegate appDelegate] setMainTask:TaskField<C_TASK *>(task, kOffSpawnedTask)];
            TaskField<int>(task, kOffState) = 0xc;
            return;
        }
    }
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:nil
                                       message:@"楽曲が見つかりませんでした。\nストアで楽曲をインストールしてください。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
    TaskField<int>(task, kOffState) = 2;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0x2ab80
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x2ab84 — row height is the "osl_friend_banner" image's height.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIImage *banner = [UIImage imageNamed:@"osl_friend_banner"];
    return banner ? banner.size.height : 0.0f;
}

// @ 0x2abe0 — one row per downloaded log entry.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_overScoreLogDataArray != nil) ? (NSInteger)_overScoreLogDataArray.count : 0;
}

// @ 0x2ac1c — one OverScoreLogCell per entry (reused by "Cell%ld_%ld"), bound to its boxed data.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    OverScoreLogCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[OverScoreLogCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    [cell setOverScoreLogData:[_overScoreLogDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0x2ad28 — a row was picked: remember its music id / sheet and fade the panel closed (the
// close completion launches the play).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OverScoreLogData data;
    [(NSValue *)[_overScoreLogDataArray objectAtIndex:indexPath.row] getValue:&data];
    m_musicId = data.musicId;
    m_sheet = data.sheet;
    [self startCloseAnimation];
}

#pragma mark - DownloadMainDelegate

// @ 0x2adac — the over-score-log download finished: hide the spinner, then either alert on
// failure or swap in the parsed list and reload.
- (void)downloadMainFinished:(NSNumber *)success {
    _dummyView.view.hidden = YES;
    DownloadMain *dl = [DownloadMain getInstance];
    if (![success boolValue]) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                           message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
    } else {
        _overScoreLogDataArray = [[dl overScoreLogArray] mutableCopy];
        [self.tableView reloadData];
    }
}

#pragma mark - Actions

// @ 0x2aefc — the back button: play the cancel SE and fade the panel closed.
- (void)backButtonFunc {
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
