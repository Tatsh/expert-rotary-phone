//
//  PopnLinkTopViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  pop'n-link top menu. Objective-C++ (drives the C++ scene manager / event
//  center for the pad flag, the link-enabled flag, SE playback and the root-VC
//  close callback).
//

#import "PopnLinkTopViewController.h"

#import "AppDelegate.h"
#import "CheckerCategoryViewController.h"
#import "HowToViewCtrl.h"
#import "InputKidViewController.h"
#import "MainViewController.h" // scene root -PopnLinkEndCallBack
#import "QuizMainViewController.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

// Root nav host (Ghidra: NESceneManager_rootViewController); the close callback
// is sent to whatever VC the scene manager stored, mirroring the sibling top
// screens.
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@interface PopnLinkTopViewController () {
    BOOL _isAnimationing;
    UIButton *_btnId;      // KID info
    UIButton *_btnChecker; // score checker (link-gated)
    UIButton *_btnQuiz;    // quiz (link-gated)
}
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)onInKidButtonTouched:(id)sender;
- (void)onScoreCheckerButtonTouched:(id)sender;
- (void)onQuizButtonTouched:(id)sender;
@end

@implementation PopnLinkTopViewController

@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;

// @ 0xccacc — lay out the backdrop, the three buttons (KID / checker / quiz)
// and their caption images, then seed the checker / quiz enabled state from the
// link flag.
// Verified against disassembly: yAdj -20 (mvn #0x13) / 0 for displayType 2;
// btnX 15.0f (0x41700000) / 0 pad; kidY 189 (0xbd) / 14 (0xe) + yAdj; checkerY
// 151 (0x97) + yAdj + (pad ? bh + 72.0f (DAT_000cd138 = 0x42900000) : 0); quizY
// 288 (0x120) + yAdj + same; caption pad offset +7.0f x (0x40e00000) / +92.0f y
// (DAT_000cd2dc = 0x42b80000); phone captions x = 22.0f (0x41b00000), y 106
// (0x6a) / 243 (0xf3) / 380 (0x17c) + yAdj; both link buttons seeded from
// neAppEventCenter::linkButtonsEnabled (ldrsb [center + 0x30]).
- (instancetype)init {
    if ((self = [super init])) {
        int displayType = [AppDelegate appDelegate].displayType;
        CGFloat yAdj = (displayType == DisplayTypePhoneRetinaTall) ?
                           0 :
                           -20; // 4-inch vs 3.5-inch vertical nudge
        BOOL isPad = neSceneManager::isPadDisplay();

        if (!isPad) {
            UIImageView *bg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friman_bg"]];
            [self.view addSubview:bg];
        } else {
            self.view.backgroundColor = [UIColor clearColor];
        }

        // All three buttons share the KID-info image size.
        UIImage *kidImg = [UIImage imageNamed:@"pl_btn_kidinfo"];
        CGFloat bw = kidImg.size.width, bh = kidImg.size.height;
        CGFloat btnX = isPad ? 0 : 15;

        // Button Y positions. Phone uses fixed offsets; on the pad the checker/quiz
        // buttons keep their phone base Y (151 / 288) but are pushed down by one
        // button height plus 72pt (engine DAT_000cd138). KID sits at a fixed 189
        // (pad) / 14 (phone) + yAdj.
        CGFloat kidY = (isPad ? 189 : 14) + yAdj;
        CGFloat checkerY = 151 + yAdj + (isPad ? (bh + 72) : 0);
        CGFloat quizY = 288 + yAdj + (isPad ? (bh + 72) : 0);

        _btnId = [[UIButton alloc] initWithFrame:CGRectMake(btnX, kidY, bw, bh)];
        [_btnId setBackgroundImage:kidImg forState:UIControlStateNormal];
        [_btnId addTarget:self
                      action:@selector(onInKidButtonTouched:)
            forControlEvents:UIControlEventTouchUpInside];
        _btnId.exclusiveTouch = YES;
        [self.view addSubview:_btnId];

        _btnChecker = [[UIButton alloc] initWithFrame:CGRectMake(btnX, checkerY, bw, bh)];
        [_btnChecker setBackgroundImage:[UIImage imageNamed:@"pl_btn_playinfo"]
                               forState:UIControlStateNormal];
        [_btnChecker addTarget:self
                        action:@selector(onScoreCheckerButtonTouched:)
              forControlEvents:UIControlEventTouchUpInside];
        _btnChecker.exclusiveTouch = YES;
        [self.view addSubview:_btnChecker];

        _btnQuiz = [[UIButton alloc] initWithFrame:CGRectMake(btnX, quizY, bw, bh)];
        [_btnQuiz setBackgroundImage:[UIImage imageNamed:@"pl_btn_quize"]
                            forState:UIControlStateNormal];
        [_btnQuiz addTarget:self
                      action:@selector(onQuizButtonTouched:)
            forControlEvents:UIControlEventTouchUpInside];
        _btnQuiz.exclusiveTouch = YES;
        [self.view addSubview:_btnQuiz];

        // Caption images near each button. Phone: fixed x=22 with per-caption Y;
        // pad: offset from the owning button's frame origin by (+7pt x, +92pt y =
        // engine DAT_000cd2dc).
        UIImage *psKid = [UIImage imageNamed:@"pl_ps_kidinfo"];
        UIImageView *ivKid = [[UIImageView alloc] initWithImage:psKid];
        ivKid.frame = isPad ? CGRectMake(_btnId.frame.origin.x + 7,
                                         _btnId.frame.origin.y + 92,
                                         psKid.size.width,
                                         psKid.size.height) :
                              CGRectMake(22, 106 + yAdj, psKid.size.width, psKid.size.height);
        [self.view addSubview:ivKid];

        UIImage *psPlay = [UIImage imageNamed:@"pl_ps_playinfo"];
        UIImageView *ivPlay = [[UIImageView alloc] initWithImage:psPlay];
        ivPlay.frame = isPad ? CGRectMake(_btnChecker.frame.origin.x + 7,
                                          _btnChecker.frame.origin.y + 92,
                                          psPlay.size.width,
                                          psPlay.size.height) :
                               CGRectMake(22, 243 + yAdj, psPlay.size.width, psPlay.size.height);
        [self.view addSubview:ivPlay];

        UIImage *psQuiz = [UIImage imageNamed:@"pl_ps_quize"];
        UIImageView *ivQuiz = [[UIImageView alloc] initWithImage:psQuiz];
        ivQuiz.frame = isPad ? CGRectMake(_btnQuiz.frame.origin.x + 7,
                                          _btnQuiz.frame.origin.y + 92,
                                          psQuiz.size.width,
                                          psQuiz.size.height) :
                               CGRectMake(22, 380 + yAdj, psQuiz.size.width, psQuiz.size.height);
        [self.view addSubview:ivQuiz];

        // Link-gated buttons follow the pop'n-link availability flag.
        _btnChecker.enabled = neAppEventCenter::linkButtonsEnabled();
        _btnQuiz.enabled = neAppEventCenter::linkButtonsEnabled();
    }
    return self;
}

// @ 0xcd2e0 — build self, wrap it in a navigation controller with a back button
// and the pop'n-link nav-bar art, and return that controller.
// Verified against disassembly: -init is invoked on the original self (r10) and
// its result is discarded (r10 kept), the nav controller is built from that same
// self, and the returned value is the nav controller ([sp,#0xc]).
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    // The binary calls -init only for its side effects and keeps the original
    // self; the result is intentionally discarded, so this is not
    // self = [self init].
    (void)[self init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *back =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [back setBackgroundImage:backImg forState:UIControlStateNormal];
    [back addTarget:self
                  action:@selector(startCloseAnimation)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:back];

    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                                  forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// viewDidLoad @ 0xcd4b8 — super-only override, omitted.

// @ 0xcd4e4 — re-apply the checker / quiz enabled state when the screen
// reappears.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_btnChecker) {
        _btnChecker.enabled = neAppEventCenter::linkButtonsEnabled();
    }
    if (_btnQuiz) {
        _btnQuiz.enabled = neAppEventCenter::linkButtonsEnabled();
    }
}

// didReceiveMemoryWarning @ 0xcd57c — super-only override, omitted.

// @ 0xcca48 — external nudge to re-sync the link-gated buttons.
// Verified against disassembly: both buttons re-seeded from linkButtonsEnabled,
// then a tail-call to reloadInputViews.
- (void)updateButtonEnable {
    if (_btnChecker) {
        _btnChecker.enabled = neAppEventCenter::linkButtonsEnabled();
    }
    if (_btnQuiz) {
        _btnQuiz.enabled = neAppEventCenter::linkButtonsEnabled();
    }
    [self reloadInputViews];
}

#pragma mark - Open/close animation (shared modal-VC lifecycle)

// @ 0xcd5a8 — on the very first, not-yet-linked entry, push the KID-input
// screen (and, the first time ever, the "firstplay_popnlink" how-to); then fade
// the view + nav view in.
// Verified against disassembly: the gate is if (!linkButtonsEnabled()); the
// first-time branch keys on !isPopnLinkSelected (tst; beq) and does pl_navbar +
// how-to + saveIsPopnLinkSelected:YES, the else does input_kid_navbar; the fade
// duration is the exact double 0.5 (vmov.f64 0x3fe0000000000000).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;

    if (!neAppEventCenter::linkButtonsEnabled()) {
        InputKidViewController *kid = [[InputKidViewController alloc] init];
        [self.navigationController pushViewController:kid animated:NO];

        UINavigationBar *bar = self.navigationController.navigationBar;
        if (![UserSettingData isPopnLinkSelected]) {
            [bar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                      forBarMetrics:UIBarMetricsDefault];

            HowToViewCtrl *howto = [[HowToViewCtrl alloc]
                initWithFileNameArray:[NSArray arrayWithObjects:@"firstplay_popnlink", nil]];
            howto.fromNaviBarImage = [UIImage imageNamed:@"input_kid_navbar"];
            howto.isCloseButtonEnable = YES;
            howto.backGroundImage = [UIImage imageNamed:@"friman_bg"];
            [self.navigationController pushViewController:howto animated:NO];

            [UserSettingData saveIsPopnLinkSelected:YES];
        } else {
            [bar setBackgroundImage:[UIImage imageNamed:@"input_kid_navbar"]
                      forBarMetrics:UIBarMetricsDefault];
        }
    }

    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1;
    self.navigationController.view.alpha = 1;
    [UIView commitAnimations];
}

// @ 0xcd8f4
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xcd908 — cancel SE, then fade out (phone, only when we are the top VC) or
// forward the close to the pad split delegate.
// Verified against disassembly: playSystemSe(2); the pad branch tail-forwards to
// [_delegate startCloseAnimation]; the phone fade duration is the single 0.3f
// promoted to double (vldr.64 0x3fd3333340000000 at DAT_000cda60), unlike the
// 0.5 open fade.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self || _isAnimationing) {
            return;
        }
        _isAnimationing = NO; // faithful to the binary (no re-entrancy latch here)
        [UIView beginAnimations:nil context:NULL];
        // 0.3f promoted to double, not 0.5 (DAT_000cda60 = 0x3fd3333340000000).
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    } else {
        [_delegate startCloseAnimation];
    }
}

// @ 0xcda68 — remove the nav view and notify the host that pop'n-link closed.
// Verified against disassembly: removeFromSuperview, then RootVC()
// PopnLinkEndCallBack, then _isAnimationing cleared to 0, in that order.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [(MainViewController *)RootVC() PopnLinkEndCallBack];
    _isAnimationing = NO;
}

#pragma mark - Button handlers

// @ 0xcdad4 — KID info: phone pushes the KID-input screen; pad forwards to the
// delegate.
// Verified against disassembly: pad branch forwards to the delegate; phone
// pushes InputKID animated:YES with input_kid_navbar; playSystemSe(1) runs on
// both paths as a tail-call.
- (void)onInKidButtonTouched:(id)sender {
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self || _isAnimationing) {
            return;
        }
        InputKidViewController *kid = [[InputKidViewController alloc] init];
        [self.navigationController pushViewController:kid animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"input_kid_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [_delegate onInKidButtonTouched:sender];
    }
    neEngine::playSystemSe(1);
}

// @ 0xcdc18 — score checker: phone pushes the checker category list; pad
// forwards.
// Verified against disassembly: phone pushes CheckerCategoryViewController
// initWithStyle:1 animated:YES with ppc_navbar; playSystemSe(1) tail-call.
- (void)onScoreCheckerButtonTouched:(id)sender {
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self || _isAnimationing) {
            return;
        }
        CheckerCategoryViewController *checker =
            [[CheckerCategoryViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:checker animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [_delegate onScoreCheckerButtonTouched:sender];
    }
    neEngine::playSystemSe(1);
}

// @ 0xcdd5c — quiz: phone pushes the quiz screen; pad forwards.
// Verified against disassembly: phone pushes QuizMainViewController
// initWithStyle:1 animated:YES with pq_navbar; playSystemSe(1) tail-call.
- (void)onQuizButtonTouched:(id)sender {
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self || _isAnimationing) {
            return;
        }
        QuizMainViewController *quiz =
            [[QuizMainViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:quiz animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"pq_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [_delegate onQuizButtonTouched:sender];
    }
    neEngine::playSystemSe(1);
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
