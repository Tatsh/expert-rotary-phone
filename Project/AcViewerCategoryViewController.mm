//
//  AcViewerCategoryViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade
//  (AC) viewer's genre-category list. Objective-C++ (.mm) because it drives the
//  C++ "ne" engine singletons via neEngineBridge (scene-manager pad flag, the
//  AC-viewer event-center selection, the system-SE hooks and the root view
//  controller's AcViewerEndCallBack).
//

#import "AcViewerCategoryViewController.h"

#import "AcMusicData.h"                 // -category (bucket key)
#import "AcViewerCategoryCell.h"        // in-project row cell (setData:)
#import "AcViewerMusicViewController.h" // pushed on row select
#import "AppDelegate.h"                 // +appAppSupportDirectory (mode-select BGM)
#import "AudioManager.h"                // shared BGM player
#import "MusicManager.h"                // +getInstance / -getAcMusicDataArray
#import "UserSettingData.h"             // +bgmVolume
#import "neEngineBridge.h"

// The scene manager owns the app's root nav host; the close animation notifies
// it that the AC viewer finished (mirrors AcViewerSplitViewController's
// RootVC()).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@interface AcViewerCategoryViewController ()
- (NSArray *)getAcMusicData:(int)index;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)touchedBackButton:(id)sender;
@end

@implementation AcViewerCategoryViewController {
    // Per-category AcMusicData arrays, indexed by AcMusicData.category (0 = etc,
    // 1 = TV, 2..23 = p01..p22). Built once in initWithStyle:.
    NSArray *_acMusicDataArray[24];
    BOOL _isAnimationing;
}

@synthesize delegate = _delegate;

// @ 0x687f0 — the songs bucketed under category `index`.
- (NSArray *)getAcMusicData:(int)index {
    return _acMusicDataArray[index];
}

// @ 0x68804 — build the transparent, separator-less grouped table; bucket every
// MusicManager AC song by genre category; install the "all category" header
// banner and (phone only) the "friman" backdrop.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self == nil) {
        return nil;
    }

    neSceneManager::shared();
    self.tableView.rowHeight = neSceneManager::isPadDisplay() ? 56.0f : 46.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    // Bucket every arcade song into its genre category (0..23).
    NSMutableArray *buckets[24];
    for (int i = 0; i < 24; i++) {
        buckets[i] = [NSMutableArray array];
    }
    for (AcMusicData *data in [[MusicManager getInstance] getAcMusicDataArray]) {
        [buckets[[data category]] addObject:data];
    }
    for (int i = 0; i < 24; i++) {
        _acMusicDataArray[i] = [NSArray arrayWithArray:buckets[i]];
    }

    // Header: the "all category" banner, hosted in a container tall enough to pad
    // it below (banner height + 17 top gap + 12 bottom gap).
    UIImage *headerImg = [UIImage imageNamed:@"acv_top_category_bar"];
    UIImageView *headerImgView = [[UIImageView alloc] initWithImage:headerImg];
    [headerImgView setFrame:CGRectMake(0.0f, 17.0f, headerImg.size.width, headerImg.size.height)];
    UIView *headerView = [[UIView alloc] init];
    headerView.frame = CGRectMake(0.0f, 0.0f, headerImg.size.width, headerImg.size.height + 29.0f);
    [headerView addSubview:headerImgView];
    self.tableView.tableHeaderView = headerView;

    // Backdrop: the "friman" paper on phone; a clear background on iPad.
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [bgView setFrame:CGRectMake(0.0f, 0.0f, bg.size.width, bg.size.height)];
        self.tableView.backgroundView = bgView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }
    return self;
}

// @ 0x68d40 — initialize the receiver (grouped) and wrap it in a nav controller
// with a custom back button in the left slot.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
    [backButton setBackgroundImage:backImg forState:UIControlStateNormal];
    [backButton addTarget:self
                   action:@selector(touchedBackButton:)
         forControlEvents:UIControlEventTouchUpInside];
    [self.navigationItem
        setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:backButton]];
    return nav;
}

// @ 0x68ec8 — dealloc: ARC-omitted. The binary releases the 24 category arrays
// and calls [super dealloc]; the arrays are __strong C-array ivars freed
// automatically under ARC (no Downloader / C memory to clean up).

// @ 0x68f30 — on phone, start the mode-select BGM if nothing is already
// playing.
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        AudioManager *audio = [AudioManager sharedManager];
        if (![audio isPlayingBgm]) {
            NSString *path = [[AppDelegate appAppSupportDirectory]
                stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
            [audio loadBgm:path isLoop:YES];
            [audio setBgmVolume:[UserSettingData bgmVolume]];
            [audio playBgm:0.0f];
        }
    }
}

// @ 0x6903c — super only.
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Open / close animations

// @ 0x69068 — fade the view + nav view in over 0.3 s (didStop ->
// endOpenAnimation).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1;
    self.navigationController.view.alpha = 1;
    [UIView commitAnimations];
}

// @ 0x691a0 — animation finished.
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x691b8 — fade the view + nav view out over 0.3 s (didStop ->
// endCloseAnimation).
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x692c0 — remove the nav view and notify the root VC the viewer closed.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    neSceneManager::shared();
    [RootVC() performSelector:@selector(AcViewerEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0x6932c
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x69330 — row 0 is the "all" banner, plus one row per non-empty category.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = 1;
    for (int i = 0; i < 24; i++) {
        if (_acMusicDataArray[i].count != 0) {
            rows++;
        }
    }
    return rows;
}

// @ 0x69378 — row 0 -> the "all" banner (nil data); row N -> the N-th non-empty
// category, scanned high (23) to low.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld_%ld", (long)indexPath.section, (long)indexPath.row];
    AcViewerCategoryCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[AcViewerCategoryCell alloc] initWithStyle:UITableViewCellStyleDefault
                                           reuseIdentifier:identifier];
    }

    NSArray *data = nil;
    if (indexPath.row != 0) {
        int found = 0;
        int idx = 0;
        for (int i = 23; i >= 0; i--) {
            if (_acMusicDataArray[i].count != 0) {
                if (indexPath.row - 1 == found) {
                    idx = i;
                    break;
                }
                found++;
            }
        }
        data = _acMusicDataArray[idx];
    }
    [cell setData:data];
    return cell;
}

// @ 0x694c4
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0x694c8 — push the category's song list (row 0 -> the full list); on iPad
// forward this screen's delegate to the pushed list.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self || indexPath.section != 0) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE

    NSArray *data = nil;
    if (indexPath.row != 0) {
        int found = 0;
        int idx = 0;
        for (int i = 23; i >= 0; i--) {
            if (_acMusicDataArray[i].count != 0) {
                if (indexPath.row - 1 == found) {
                    idx = i;
                    break;
                }
                found++;
            }
        }
        data = _acMusicDataArray[idx];
    }

    AcViewerMusicViewController *music = [[AcViewerMusicViewController alloc] initWithData:data];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"acv_friman_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    neSceneManager::shared();
    BOOL animated = !neSceneManager::isPadDisplay();
    if (!animated) {
        music.delegate = self.delegate;
    }
    [self.navigationController pushViewController:music animated:animated];
}

#pragma mark - Actions

// @ 0x696c4 — BACK: only when this screen is the nav top VC; clear the
// AC-viewer's current music selection, play the cancel SE and (phone) fade the
// screen out.
- (void)touchedBackButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neAppEventCenter::shared();
    neAppEventCenter::clearAcViewerCurrentMusic(); // g_dwAcViewerMusicId = -1
    neSceneManager::shared();
    neEngine::playSystemSe(2); // cancel SE
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [self startCloseAnimation];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
