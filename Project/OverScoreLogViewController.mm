//
//  OverScoreLogViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The "friend
//  over-score" log screen. Objective-C++ (.mm) because it drives the C++ "ne"
//  engine singletons via neEngineBridge (scene manager, root view controller,
//  system SEs) and, on close, the C++ MainTask / PlayTask launch path.
//

#import "OverScoreLogViewController.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "MainViewController.h"
#import "MusicData.h"
#import "OverScoreLogCell.h"
#import "PlayTask.h"
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene
// manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// ---------------------------------------------------------------------------
// Block invoke helpers emitted by the compiler after startOpenAnimation
// (0x2a1b0) and startCloseAnimation (0x2a678).  Placement: file-static.
// ---------------------------------------------------------------------------

// Ghidra: setNavViewFrameD @ 0x2a458
// Slides the navigation controller view to y = 420.0.
// Animations block, first phase of the iPad open animation.
// @complete
static void setNavViewFrameD(OverScoreLogViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameE @ 0x2a590
// Settles the navigation controller view to y = 470.0.
// Animations block of the settle phase (second step of open).
// @complete
static void setNavViewFrameE(OverScoreLogViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 470.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameF @ 0x2a838
// Slides the navigation controller view back to y = 420.0.
// Animations block, first phase of the iPad close animation.
// @complete
static void setNavViewFrameF(OverScoreLogViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameFromSubview2 @ 0x2a978
// Parks the navigation controller view off-screen below the root view.
// Animations block, second phase of the iPad close animation.  Captures self
// and a reference UIViewController; sets nav-view origin.y to refController's
// view height.
// @complete
static void setNavViewFrameFromSubview2(OverScoreLogViewController *self,
                                        UIViewController *refController) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    UIView *ref = refController.view;
    f.origin.y = ref ? ref.frame.size.height : 0.0f;
    self.navigationController.view.frame = f;
}

@interface OverScoreLogViewController ()
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)backButtonFunc;
@end

@implementation OverScoreLogViewController {
    UIViewController *_dummyView;           // dimmed spinner overlay shown while downloading
    BOOL _isAnimationing;                   // an open/close animation is in flight
    NSMutableArray *_overScoreLogDataArray; // boxed OverScoreLogData rows (from DownloadMain)
    int m_musicId;                          // song picked to play (-1 = none)
    int m_sheet;                            // difficulty picked to play (-1 = none)
}

@synthesize musicSelTask = _musicSelTask;

// @ 0x29928 — build the transparent, separator-less table: a clear 20-pt spacer
// header, the "friman" backdrop (phone) / clear (iPad), and a hidden dimmed
// loading overlay with a large spinner.
// @complete
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) {
        return nil;
    }
    CGRect viewFrame = self.view.frame;
    self.tableView.rowHeight = 54.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    // Clear 20-pt spacer header.
    UIView *header =
        [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, viewFrame.size.width, 20.0f)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // iPad: pull the list up under the nav bar (-20 pre-iOS7, -10 on iOS7+).
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset =
            UIEdgeInsetsMake(osVersion < 7.0f ? -20.0f : -10.0f, 0.0f, 0.0f, 0.0f);
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

    // Dimmed "loading" overlay (transparent white, hidden until viewDidLoad) +
    // large spinner.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = self.view.frame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.0f];
    _dummyView.view.hidden = YES;
    [self.tableView addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    CGRect frame = self.view.frame;
    // Ghidra: center.y truncates (height*0.5) to int, subtracts 10, then converts
    // back to float (vcvt.s32.f32 / subs #0xa / vcvt.f32.s32 @ 0x29d86..0x29d9c).
    // center.x stays a pure float.
    spinner.center =
        CGPointMake(frame.size.width * 0.5f, (float)((int)(frame.size.height * 0.5f) - 10));
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];
    return self;
}

// @ 0x29e24 — keep the C++ task pointer, (re)build the table via
// initWithStyle:, wrap self in a UINavigationController (with a back button on
// phone) and return that nav controller.
// @complete
- (UINavigationController *)initAtNavigationController:(MainTask *)musicSelTask
    __attribute__((objc_method_family(none))) {
    _musicSelTask = musicSelTask;
    UINavigationController *navigationController = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return navigationController;
}

// dealloc @ 0x29fd8 — ARC omits the -release of _overScoreLogDataArray /
// _dummyView; kept only to detach self as DownloadMain's over-score-log
// delegate (a non-object side effect ARC can't do).
// @complete
- (void)dealloc {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl delegateGetOverScoreLog] == self) {
        [dl setDelegateGetOverScoreLog:nil];
    }
}

// @ 0x2a08c — reveal the spinner overlay, reset the pending selection, register
// as DownloadMain's over-score-log delegate and kick off the download.
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        self.preferredContentSize = CGSizeMake(320.0f, 524.0f);
#else
        [self setContentSizeForViewInPopover:CGSizeMake(320.0f, 524.0f)];
#endif
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

// @ 0x2a1b0 — fade the view + nav view in (phone) or slide the nav view up into
// place (iPad).
// @complete
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
        [UIView setAnimationDuration:0.3f]; // DAT is (double)0.3f, not the double 0.3
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        self.navigationController.view.alpha = 1.0f;
    } else {
        // iPad: park the nav view below the root scene, then two-phase slide into
        // place. Phase 1 (~1/6 s): slide to y = 420 (setNavViewFrameD @ 0x2a458).
        // Phase 2 (~1/6 s): settle to y = 470 (setNavViewFrameE @ 0x2a590), then
        //   call -endOpenAnimation.
        UIViewController *root = RootVC();
        CGRect f = self.navigationController.view.frame;
        f.origin.y = root.view.frame.size.height; // park below screen
        self.navigationController.view.frame = f;
        [UIView animateWithDuration:(1.0f / 6.0f)
            delay:0.0
            options:UIViewAnimationOptionLayoutSubviews
            animations:^{
              setNavViewFrameD(self); // Ghidra: setNavViewFrameD @ 0x2a458
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:(1.0f / 6.0f)
                  delay:0.0
                  options:UIViewAnimationOptionLayoutSubviews
                  animations:^{
                    setNavViewFrameE(self); // Ghidra: setNavViewFrameE @ 0x2a590
                  }
                  completion:^(BOOL f2) {
                    [self endOpenAnimation];
                  }];
            }];
    }
    [UIView commitAnimations];
}

// @ 0x2a664
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x2a678 — fade (phone) / slide (iPad) the panel out; the completion
// (endCloseAnimation) launches the selected play.
// @complete
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f]; // DAT is (double)0.3f, not the double 0.3
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
    } else {
        // iPad: two-phase slide out.
        // Phase 1 (~1/6 s): slide from y = 470 back to y = 420 (setNavViewFrameF @
        // 0x2a838). Phase 2 (~1/6 s): park below the root view
        // (setNavViewFrameFromSubview2 @ 0x2a978),
        //   then call -endCloseAnimation.
        UIViewController *root = RootVC();
        [UIView animateWithDuration:(1.0f / 6.0f)
            delay:0.0
            options:UIViewAnimationOptionLayoutSubviews
            animations:^{
              setNavViewFrameF(self); // Ghidra: setNavViewFrameF @ 0x2a838
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:(1.0f / 6.0f)
                  delay:0.0
                  options:UIViewAnimationOptionLayoutSubviews
                  animations:^{
                    // Ghidra: setNavViewFrameFromSubview2 @ 0x2a978
                    setNavViewFrameFromSubview2(self, root);
                  }
                  completion:^(BOOL f2) {
                    [self endCloseAnimation];
                  }];
            }];
    }
    [UIView commitAnimations];
}

// @ 0x2aad4 — the close-animation completion. Remove the nav view, notify the
// root host, clear the animating flag, and — if a valid (m_musicId, m_sheet) was
// picked — hand the owning music-select task straight into a play of that song
// (or raise a "song not installed" alert).
//
// The Ghidra function region for this method is mis-bounded (its body spans a
// ~76 KB range starting at 0x2aad4), but the decompile of the real prologue at
// 0x2aad4 is coherent and complete; this reconstruction follows it. The
// play-launch writes the picked song into the task's save fields
// (m_chosenIndex @ +0x8f8, m_chosenMusicId @ +0x900, m_resultSheet @ +0x904),
// pops the BGM, fires the decide SE (m_seInst[3] @ +0x8e4 from m_seId[3] @
// +0x8d0), spawns a PlayTask (+0xaa0), installs it as the main task, and sets
// the task state to 0xc (the play-launch handoff) — mirroring the MainTask PLAY
// button path. A song no longer installed falls through to the alert and state
// 2.
// @complete
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [(MainViewController *)RootVC() OverScoreLogEndCallBack];
    _isAnimationing = NO;

    if ((unsigned)m_musicId == 0xffffffff || m_sheet == -1) {
        return;
    }

    MainTask *task = self.musicSelTask;
    NSArray<MusicData *> *songs = task->m_musicList;
    for (NSUInteger i = 0; i < songs.count; i++) {
        if ((int)[songs[i] MusicID] == m_musicId) {
            task->m_chosenIndex = (int)i;
            task->m_chosenMusicId = m_musicId;
            task->m_resultSheet = m_sheet;

            AudioManager *audio = [AudioManager sharedManager];
            [audio popBgm];
            task->m_seInst[3] = (int)[audio playSe:nil resourceId:task->m_seId[3]];

            task->m_spawnedTask = new PlayTask();
            [[AppDelegate appDelegate] setMainTask:(MainTask *)task->m_spawnedTask];
            task->m_state = 0xc; // -> play-launch handoff
            return;
        }
    }

    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:nil
                                       message:@"楽曲が見つかりませんでした。\n"
                                               @"ストアで楽曲をインストール"
                                               @"してください。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
    task->m_state = 2;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0x2ab80
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x2ab84 — row height is the "osl_friend_banner" image's height.
// @complete
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIImage *banner = [UIImage imageNamed:@"osl_friend_banner"];
    return banner ? banner.size.height : 0.0f;
}

// @ 0x2abe0 — one row per downloaded log entry.
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_overScoreLogDataArray != nil) ? (NSInteger)_overScoreLogDataArray.count : 0;
}

// @ 0x2ac1c — one OverScoreLogCell per entry (reused by "Cell%ld-%ld"), bound
// to its boxed data.
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Ghidra @ 0x2ac7e: the reuse-identifier format is "Cell%ld-%ld" (hyphen) —
    // string @ 0x134e38 (shared with the other table cells).
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    OverScoreLogCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[OverScoreLogCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identifier];
    }
    [cell setOverScoreLogData:[_overScoreLogDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0x2ad28 — a row was picked: remember its music id / sheet and fade the
// panel closed (the close completion launches the play).
// @complete
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OverScoreLogData data;
    [(NSValue *)[_overScoreLogDataArray objectAtIndex:indexPath.row] getValue:&data];
    m_musicId = data.musicId;
    m_sheet = data.sheet;
    [self startCloseAnimation];
}

#pragma mark - DownloadMainDelegate

// @ 0x2adac — the over-score-log download finished: hide the spinner, then
// either alert on failure or swap in the parsed list and reload.
// @complete
- (void)downloadMainFinished:(NSNumber *)success {
    _dummyView.view.hidden = YES;
    DownloadMain *dl = [DownloadMain getInstance];
    if (![success boolValue]) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                           message:@"通信に失敗しました。\n電波状態"
                                                   @"の良い場所でやり直して下さい。"
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
// @complete
- (void)backButtonFunc {
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
