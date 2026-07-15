//
//  AcViewerOptionViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade
//  (AC) viewer's per-song option list. Objective-C++ (.mm) because it drives
//  the C++ "ne" engine singletons via neEngineBridge (scene manager,
//  event-center AC-viewer selection, and the AcMainTask exit / apply-settings
//  hooks).
//

#import "AcViewerOptionViewController.h"

#import "AcMusicData.h"
#import "AcViewerHiSpeedViewController.h" // option detail screens pushed from the option list
#import "AcViewerHidSudViewController.h"
#import "AcViewerOptionCell.h"
#import "AcViewerPopKunViewController.h"
#import "AcViewerRanMirViewController.h"
#import "AppDelegate.h"
#import "AppFont.h"
#import "MusicManager.h"
#import "StoreUtil.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

#import "SDKCompat.h"

// The C++ arcade note-play task the AC-main flow owns (the one AppDelegate
// holds in its acMainTask property); opaque on the ObjC side (a raw pointer,
// non-ARC), passed straight through to the engine hooks. Ghidra: struct
// AcViewerTask.
class AcViewerTask; // System/src/Task/AcViewerTask.h (: C_TASK)

// The app's root navigation host (bridged UIViewController on the C++ scene
// manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// One header caption label (song title / BPM); the binary builds both inline
// with an identical style (48/255 grey text, white when highlighted, DFSoGei
// font, auto-shrink).
static UILabel *AcvMakeHeaderLabel(CGFloat fontSize, NSTextAlignment alignment, CGRect frame) {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.textColor = [UIColor colorWithRed:48.0f / 255.0f
                                    green:48.0f / 255.0f
                                     blue:48.0f / 255.0f
                                    alpha:1.0f];
    lbl.highlightedTextColor = [UIColor whiteColor];
    lbl.font = [UIFont fontWithName:AppFontName() size:fontSize];
    lbl.textAlignment = alignment;
    lbl.adjustsFontSizeToFitWidth = YES;
    [lbl setMinimumScaleFactor:10.0f]; // raw 0x41200000 (legacy minimum-font-size
                                       // value)
    lbl.frame = frame;
    return lbl;
}

@implementation AcViewerOptionViewController {
    UINavigationController *_naviCtrl; // 0xa4 — own nav host (AC-main flow only)
    BOOL _forAcMain;                   // 0xa8 — hosted by the in-game AC-main task
    BOOL _isAnimationing;              // 0xa9 — a fade transition is in flight
    AcViewerTask *_pAcMain;            // 0xac — C++ arcade note-play task (non-ARC)
}

// @ 0xdeff0 — build the options table: a transparent, separator-less
// UITableView; the custom header (song banner, difficulty banner, title/genre
// and BPM labels); and, off the AC-main flow, a back button, the PLAY /
// CONTINUE buttons and the "friman" backdrop.
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) {
        return nil;
    }
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    neAppEventCenter::shared(); // force the event center to init before the AC
                                // globals
    int musicId = neAppEventCenter::acViewerMusicId();
    int difficulty = neAppEventCenter::acViewerDifficulty();
    AcMusicData *data = [[MusicManager getInstance] getAcMusicData:musicId];

    // Back button (skipped on the AC-main flow, which installs its own in
    // initForAcMain:).
    if (!_forAcMain) {
        NSString *backName =
            neSceneManager::isPadDisplay() ? @"pl_checker_return" : @"navi_btn_back";
        UIImage *backImg = [UIImage imageNamed:backName];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(touchedBackButton:)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        if (neSceneManager::isPadDisplay()) {
            self.navigationItem.hidesBackButton = YES;
        }
    }

    // --- Custom table header: song banner, difficulty banner, title and BPM ---
    UIImage *bannerImg = [UIImage imageNamed:@"acv_custom_banner"];
    UIImageView *bannerView = [[UIImageView alloc] initWithImage:bannerImg];
    bannerView.frame = CGRectMake(0.0f, 17.0f, bannerImg.size.width, bannerImg.size.height);

    // Difficulty banner (index 0..3). NB: the binary's asset name for "hyper" is
    // misspelled "heper".
    static NSString *const kDiffBanner[] = {
        @"acv_custom_easy", @"acv_custom_normal", @"acv_custom_heper", @"acv_custom_ex"};
    UIImage *diffImg = [UIImage imageNamed:kDiffBanner[difficulty]];
    UIImageView *diffView = [[UIImageView alloc] initWithImage:diffImg];
    diffView.frame = CGRectMake(22.0f, 46.0f, diffImg.size.width, diffImg.size.height);

    UILabel *titleLbl =
        AcvMakeHeaderLabel(15.0f, NSTextAlignmentCenter, CGRectMake(20.0f, 26.0f, 280.0f, 18.0f));
    titleLbl.text = [UserSettingData isAcvGenreName] ? [data genreName] : [data musicName];

    NSString *bpm = nil;
    switch (difficulty) {
    case 0:
        bpm = [data bpmEasy];
        break;
    case 1:
        bpm = [data bpmNormal];
        break;
    case 2:
        bpm = [data bpmHyper];
        break;
    case 3:
        bpm = [data bpmEx];
        break;
    default:
        break;
    }
    UILabel *bpmLbl =
        AcvMakeHeaderLabel(14.0f, NSTextAlignmentRight, CGRectMake(195.0f, 46.0f, 100.0f, 18.0f));
    if (bpm != nil) {
        bpmLbl.text = [NSString stringWithFormat:@"BPM:%@", bpm];
    }

    // Header container: the banner plus a 17 pt gap above and below it. (The
    // binary derives the height from the banner/difficulty image sizes via vector
    // adds; the banner-height + 34 form matches the recovered layout.)
    UIView *headerView = [[UIView alloc] init];
    headerView.frame = CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height + 34.0f);
    [headerView addSubview:bannerView];
    [headerView addSubview:titleLbl];
    [headerView addSubview:bpmLbl];
    [headerView addSubview:diffView];
    [self.tableView setTableHeaderView:headerView];

    // --- PLAY / CONTINUE buttons (off the AC-main flow) ---
    if (!_forAcMain) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        UIImage *playImg = [UIImage imageNamed:@"acv_bt_play"];
        CGFloat centerX = (320.0f - playImg.size.width) * 0.5f;
        CGFloat y = (osVersion < 7.0f) ? 290.0f : 280.0f;

        if (!neSceneManager::isPadDisplay() || musicId != neAppEventCenter::acViewerSelMusicId() ||
            difficulty != neAppEventCenter::acViewerSelDifficulty()) {
            // Fresh selection (or phone): a single PLAY button.
            UIButton *playBtn = [[UIButton alloc] init];
            [playBtn setBackgroundImage:playImg forState:UIControlStateNormal];
            playBtn.frame = CGRectMake(centerX, y, playImg.size.width, playImg.size.height);
            [playBtn addTarget:self
                          action:@selector(touchedPlayButton:)
                forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:playBtn];
        } else {
            // Same song/difficulty already in play (iPad): CONTINUE +
            // PLAY-FROM-START.
            UIButton *continueBtn = [[UIButton alloc] init];
            [continueBtn setBackgroundImage:[UIImage imageNamed:@"acv_bt_play_contin"]
                                   forState:UIControlStateNormal];
            continueBtn.frame = CGRectMake(30.0f, y, playImg.size.width, playImg.size.height);
            [continueBtn addTarget:self
                            action:@selector(touchedResumeButton:)
                  forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:continueBtn];

            UIButton *firstBtn = [[UIButton alloc] init];
            [firstBtn setBackgroundImage:[UIImage imageNamed:@"acv_bt_play_first"]
                                forState:UIControlStateNormal];
            firstBtn.frame = CGRectMake(170.0f, y, playImg.size.width, playImg.size.height);
            [firstBtn addTarget:self
                          action:@selector(touchedPlayButton:)
                forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:firstBtn];
        }
    }

    // "friman" backdrop behind the whole list (phone only).
    if (!neSceneManager::isPadDisplay()) {
        UIImage *frimanImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *frimanView = [[UIImageView alloc] initWithImage:frimanImg];
        frimanView.frame = CGRectMake(0.0f, 0.0f, frimanImg.size.width, frimanImg.size.height);
        self.tableView.backgroundView = frimanView;
    }

    return self;
}

// @ 0xdfc0c — options screen for the in-game AC-main flow: flag _forAcMain,
// keep the C++ task pointer, build the table (via init), wrap self in its own
// navigation controller and install the back button + the "pl_navbar" nav-bar
// background.
- (instancetype)initForAcMain:(AcViewerTask *)acMain {
    _forAcMain = YES;
    _pAcMain = acMain;
    if (!(self = [self init])) {
        return nil;
    }
    _naviCtrl = [[UINavigationController alloc] initWithRootViewController:self];

    NSString *backName = neSceneManager::isPadDisplay() ? @"pl_checker_return" : @"navi_btn_back";
    UIImage *backImg = [UIImage imageNamed:backName];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(touchedBackButton:)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                                  forBarMetrics:UIBarMetricsDefault];
    return self;
}

// @ 0xdfe30 — after loading, add a right-swipe pan recogniser (phone only) that
// acts as a back gesture.
- (void)viewDidLoad {
    [super viewDidLoad];
    if (!neSceneManager::isPadDisplay()) {
        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
        [self.view addGestureRecognizer:pan];
    }
}

// @ 0xdfee0 — super only.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

// @ 0xdff0c — treat a rightward pan (translation.x > 80) as a back-button
// press.
- (void)handleGesture:(UIPanGestureRecognizer *)recognizer {
    if (recognizer == nil) {
        return;
    }
    CGPoint t = [recognizer translationInView:self.view];
    if (t.x > 80.0f) {
        [self touchedBackButton:nil];
    }
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xdff78
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xdff7c — four option rows in section 0.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? 4 : 0;
}

// @ 0xdff88 — one AcViewerOptionCell per row (reused by "Cell%ld_%ld"), bound
// to the row's option kind.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld_%ld", (long)indexPath.section, (long)indexPath.row];
    AcViewerOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[AcViewerOptionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:identifier];
    }
    if (indexPath.section == 0) {
        switch (indexPath.row) {
        case 0:
            [cell setData:0];
            break;
        case 1:
            [cell setData:1];
            break;
        case 2:
            [cell setData:2];
            break;
        case 3:
            [cell setData:3];
            break;
        default:
            break;
        }
    }
    return cell;
}

// @ 0xe00c0 — no section headers.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xe00c4 — no accessory (private UITableView delegate hook).
- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView
         accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellAccessoryNone;
}

// @ 0xe00c8 — push the tapped option's detail screen and swap the nav-bar
// background to match; guarded so it does nothing mid-animation or when not the
// top view controller.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self || _isAnimationing ||
        indexPath.section != 0) {
        return;
    }
    // Push the option detail screen for the tapped row.
    UIViewController *vc = nil;
    NSString *navbarName = nil;
    switch (indexPath.row) {
    case 0:
        vc = [[AcViewerHiSpeedViewController alloc] init];
        navbarName = @"acv_hispeed_navbar";
        break;
    case 1:
        vc = [[AcViewerPopKunViewController alloc] init];
        navbarName = @"acv_popkun_navbar";
        break;
    case 2:
        vc = [[AcViewerHidSudViewController alloc] init];
        navbarName = @"acv_hidsud_navbar";
        break;
    case 3:
        vc = [[AcViewerRanMirViewController alloc] init];
        navbarName = @"acv_ranmir_navbar";
        break;
    default:
        return;
    }
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:navbarName]
                                                  forBarMetrics:UIBarMetricsDefault];
    [self.navigationController pushViewController:vc animated:!neSceneManager::isPadDisplay()];
    neEngine::playSystemSe(1);
}

#pragma mark - Actions

// @ 0xe0374 — PLAY: log the play, commit the pending selection and start the
// game. On iPad the play scene shows behind the panel (fade the black board,
// hide the panel, ask the AcMainTask to exit the *viewer*); on phone just close
// this screen.
- (void)touchedPlayButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (_isAnimationing) {
        return;
    }
    [self sendLog];
    neEngine::playSystemSe(0);
    if (neSceneManager::isPadDisplay()) {
        [RootVC() performSelector:@selector(FadeInBlackBoard)];
        neAppEventCenter::commitAcViewerSelection();
        [self.delegate startHiddenAnimation:NO];
        neEngine::acMainRequestGameExit(
            static_cast<AcMainTask *>(AppDelegate.appDelegate.acMainTask));
    } else {
        [self startCloseAnimation];
    }
}

// @ 0xe0490 — CONTINUE: apply the current options to the running AcMainTask and
// hide the panel (animated) so the in-progress play resumes.
- (void)touchedResumeButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (_isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    neEngine::acMainApplyGameplaySettings(
        static_cast<AcViewerTask *>(AppDelegate.appDelegate.acMainTask)); // acMainTask is void*
    [self.delegate startHiddenAnimation:YES];
}

// @ 0xe053c — BACK: off the AC-main flow, restore the "friman" nav-bar and pop
// this screen; on the AC-main flow, apply the options to the task and fade the
// panel closed.
- (void)touchedBackButton:(id)sender {
    if (self.navigationController.topViewController != self || _isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    if (!_forAcMain) {
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"acv_friman_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
        [self.navigationController popViewControllerAnimated:!neSceneManager::isPadDisplay()];
    } else {
        neEngine::acMainApplyGameplaySettings(_pAcMain);
        [self startCloseAnimation];
    }
}

// @ 0xe0664 — fire-and-forget analytics POST recording that an AC play started
// (uuid body, user-agent + store headers), sent to the arcade-viewer play-log
// endpoint.
- (void)sendLog {
    NSData *body = [[NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId]
        dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request =
        [[NSMutableURLRequest alloc] initWithURL:[StoreUtil logAcvPlayURL]
                                     cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                 timeoutInterval:15.0];
    [request setValue:AppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
    [request setHTTPBody:body];
    [request setHTTPMethod:@"POST"];
    RB_DEPRECATED_BEGIN
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:nil];
    RB_DEPRECATED_END(void) connection;
}

#pragma mark - Open / close animations

// @ 0xe0820 — AC-main flow: add the nav controller's view over the root scene
// and fade this screen (+ its nav view) 0 -> 1 over 0.3 s.
- (void)startOpenAnimationForAcMain {
    [RootVC().view addSubview:_naviCtrl.view];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:nil];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xe0960 — fade this screen (+ its nav view) 1 -> 0 over 0.3 s; didStop
// routes to endCloseAnimation (or endCloseAnimationForAcMain on the AC-main
// flow).
- (void)startCloseAnimation {
    _isAnimationing = YES;
    BOOL forAcMain = _forAcMain;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:(forAcMain ? @selector(endCloseAnimationForAcMain) :
                                                     @selector(endCloseAnimation))];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0xe0a78 — remove the nav view and notify the root that the AC viewer
// closed.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(AcViewerEndCallBack)];
}

// @ 0xe0ad4 — AC-main flow teardown: drop the owned nav controller.
- (void)endCloseAnimationForAcMain {
    [_naviCtrl.view removeFromSuperview];
    _naviCtrl = nil;
}

@end
