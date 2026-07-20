//
//  PopnLinkTopSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad
//  pop'n-link split hub. Objective-C++ (drives the C++ "ne" engine singletons
//  for the link-enabled flag, SE and scene-root bridge).
//

#import "PopnLinkTopSplitViewController.h"

#import "CheckerCategoryViewController.h" // score-checker section
#import "HowToViewCtrlPad.h"              // first-play how-to overlay
#import "InputKIDViewCtrl.h"              // KONAMI-ID input controller (routed to while unlinked)
#import "MainViewController.h"            // scene root -PopnLinkEndCallBack
#import "PopnLinkTopViewController.h"     // left pane + PopnLinkTopViewControllerDelegate
#import "QuizMainViewController.h"        // quiz section
#import "UserSettingData.h"               // isPopnLinkSelected / saveIsPopnLinkSelected:
#import "neEngineBridge.h" // neAppEventCenter::linkButtonsEnabled, neEngine::playSystemSe,
                           //   neSceneManager::rootViewController

@interface PopnLinkTopSplitViewController () <PopnLinkTopViewControllerDelegate,
                                              PopnLinkTopSplitViewControllerDelegate>
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)handleTapCoverView;
@end

@implementation PopnLinkTopSplitViewController {
    BOOL _isAnimationing;                     // guards a transition against re-entry
    PopnLinkTopViewController *_leftViewCtrl; // left section-button column
    UINavigationController *_rightViewCtrl;   // right detail pane (swapped by the section buttons)
    UIImageView *_konamiIdArrowImageView;     // selection arrow
    int _selectedIndex;                       // -1 uninitialised, 0 KONAMI-ID, 1 checker, 2 quiz
    CGRect _konamiIdFrm;                      // right-pane frame per section
    CGRect _checkerFrm;
    CGRect _quizFrm;
    CGRect _konamiIdArrowFrm; // arrow frame per section row
    CGRect _checkerArrowFrm;
    CGRect _quizArrowFrm;
    HowToViewCtrlPad *_howToView; // first-play how-to overlay
}

// .cxx_construct @ 0xe2c38 — compiler-emitted C++ ivar constructor; not
// hand-written. (Verified: 0xe2c38 is a bare `bx lr`.)
// @complete

// @ 0xe0b40 — build the dimmed backdrop (tap to close), the artwork panel, the
// left section column (PopnLinkTopViewController), the right navigation pane,
// the selection arrow (positioned per link state), and a top cover strip; then
// populate the initial section (checker, which routes to the KONAMI-ID input
// while unlinked).
//
// Verified against the disassembly at 0xe0b40: the three right-pane frames
// (385,220,320,600 / 385,182,320,716 / 385,250,320,530), the three arrow frames
// (365,307 / 365,452 / 365,592), the left-column origin offsets (+65 / +100) and
// width 354, the cover alpha 0.5, the border colour (0,0.835,0.679,1) and width
// 3, the background colour (0.953,0.953,0.953,1), the corner radius 6, and the
// initial _selectedIndex = -1 followed by -onScoreCheckerButtonTouched:nil all
// match.
// @complete
- (instancetype)init {
    if ((self = [super init])) {
        _konamiIdFrm = CGRectMake(385, 220, 320, 600);
        _checkerFrm = CGRectMake(385, 182, 320, 716);
        _quizFrm = CGRectMake(385, 250, 320, 530);

        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _konamiIdArrowImageView = [[UIImageView alloc] initWithImage:arrow];
        _konamiIdArrowFrm = CGRectMake(365, 307, arrow.size.width, arrow.size.height);
        _checkerArrowFrm = CGRectMake(365, 452, arrow.size.width, arrow.size.height);
        _quizArrowFrm = CGRectMake(365, 592, arrow.size.width, arrow.size.height);

        // Arrow starts on the KONAMI-ID row until the player has linked pop'n-link.
        neAppEventCenter::shared();
        _konamiIdArrowImageView.frame =
            neAppEventCenter::linkButtonsEnabled() ? _checkerArrowFrm : _konamiIdArrowFrm;

        // Dimmed, tappable backdrop.
        UIView *cover = [[UIView alloc]
            initWithFrame:CGRectMake(
                              0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                        initWithTarget:self
                                                action:@selector(handleTapCoverView)]];

        // Artwork panel holding the split view, centred on screen.
        UIImage *bgImg = [UIImage imageNamed:@"pl_bg"];
        UIImageView *bg = [[UIImageView alloc] initWithImage:bgImg];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center =
            CGPointMake(self.view.frame.size.width * 0.5f, self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left section column (the pop'n-link top VC; its own view is embedded
        // here).
        _leftViewCtrl = [[PopnLinkTopViewController alloc] init];
        _leftViewCtrl.view.clipsToBounds = YES;
        _leftViewCtrl.view.frame = CGRectMake(_leftViewCtrl.view.frame.origin.x + 65,
                                              _leftViewCtrl.view.frame.origin.y + 100,
                                              354,
                                              bgImg.size.height);
        _leftViewCtrl.delegate = self;
        [bg addSubview:_leftViewCtrl.view];

        // Right navigation pane; initial frame depends on link state.
        _rightViewCtrl = [[UINavigationController alloc] init];
        _rightViewCtrl.view.clipsToBounds = YES;
        neAppEventCenter::shared();
        _rightViewCtrl.view.frame =
            neAppEventCenter::linkButtonsEnabled() ? _checkerFrm : _konamiIdFrm;
        _rightViewCtrl.view.layer.borderColor =
            [UIColor colorWithRed:0 green:0.835f blue:0.679f alpha:1].CGColor;
        _rightViewCtrl.view.layer.borderWidth = 3;
        _rightViewCtrl.view.backgroundColor = [UIColor colorWithRed:0.953f
                                                              green:0.953f
                                                               blue:0.953f
                                                              alpha:1];
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        // Top cover strip (swallows taps over the nav-bar band).
        UIView *topCover =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 140)];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                                   action:@selector(handleTapCoverView)]];

        // Populate the initial section (checker; falls back to KONAMI-ID input
        // while unlinked).
        _selectedIndex = -1;
        [self onScoreCheckerButtonTouched:nil];
        [bg addSubview:_konamiIdArrowImageView];
    }
    return self;
}

#pragma mark - Lifecycle

// @ 0xe1430 — detach the selection arrow on teardown (real work kept under ARC;
// the _leftViewCtrl / _rightViewCtrl / _howToView releases are ARC-automatic).
// Verified: the binary releases _leftViewCtrl, _rightViewCtrl,
// _konamiIdArrowImageView (via -removeFromSuperview) and _howToView before
// [super dealloc]; only the arrow detach is real work under ARC.
// @complete
- (void)dealloc {
    [_konamiIdArrowImageView removeFromSuperview];
}

// viewDidLoad @ 0xe14e0 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xe150c — super-only override, omitted.

#pragma mark - Open/close animation

// @ 0xe1538 — while unlinked, force the KONAMI-ID input onto the host nav stack
// (and show the first-play how-to once), then fade the view + nav view in over
// 0.5s.
//
// Verified against 0xe1538: guard set to YES, the unlinked branch pushes
// InputKIDViewCtrl animated:NO, the !isPopnLinkSelected branch builds the how-to
// overlay from @[@"firstplay_popnlink"] and saves the flag (else it swaps in the
// "input_kid_navbar" art), and the fade uses the 0.5 duration double at 0xe1958,
// setAnimationDidStopSelector:endOpenAnimation, and alpha 0 -> 1.
// @complete
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;

    neAppEventCenter::shared();
    if (!neAppEventCenter::linkButtonsEnabled()) {
        InputKIDViewCtrl *inKid = [[InputKIDViewCtrl alloc] init];
        [self.navigationController pushViewController:inKid animated:NO];
        if (![UserSettingData isPopnLinkSelected]) {
            _howToView =
                [[HowToViewCtrlPad alloc] initWithFileNameArray:@[ @"firstplay_popnlink" ]];
            [self.view addSubview:_howToView.view];
            [self.view bringSubviewToFront:_howToView.view];
            [_howToView startOpenAnimation];
            [UserSettingData saveIsPopnLinkSelected:YES];
        } else {
            [self.navigationController.navigationBar
                setBackgroundImage:[UIImage imageNamed:@"input_kid_navbar"]
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

// @ 0xe1840 — clear the guard. (Verified: 0xe1840 stores 0 into the guard ivar.)
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xe1858 — fade the view + nav view out over 0.3s. (The binary re-clears the
// guard here rather than setting it; reproduced faithfully.)
// Verified against 0xe1858: after the guard check it stores 0 (not 1) into the
// guard, the duration is the 0.3 double at 0xe1958,
// setAnimationDidStopSelector:endCloseAnimation, and alpha 0/0.
// @complete
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = NO;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xe1960 — remove the panel and notify the nav host it closed.
// Verified against 0xe1960: -removeFromSuperview, fetch the scene-root VC,
// -PopnLinkEndCallBack, then clear the guard.
// @complete
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root PopnLinkEndCallBack];
    _isAnimationing = NO;
}

#pragma mark - Section handlers

// @ 0xe19c0 — switch the right pane to the KONAMI-ID input section. Ghidra flip
// block helper showKonamiIdView @ 0xe1d18 (modeled as a single flip whose
// completion clears the guard).
//
// Verified against 0xe19c0 and its blocks: the bar-button items are cleared, an
// InputKIDViewCtrl is built with hidesBackButton = YES and delegate = self, the
// _selectedIndex < 0 branch pushes directly (navbar "pl_navbar"), and the flip
// path sets the guard, collapses the pane width to 0 (block 0xe1c88), swaps in
// the KID input and expands to _konamiIdFrm (blocks 0xe1d18/0xe1e68), and slides
// the arrow to _konamiIdArrowFrm (block 0xe1f48). Durations are the 0.3 doubles
// at 0xe1c78/0xe1d18 and the 0.6 double at 0xe1c80; options 0x10000.
// @complete
- (void)onInKidButtonTouched:(id)sender {
    if (_isAnimationing) {
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    InputKIDViewCtrl *vc = [[InputKIDViewCtrl alloc] init];
    vc.navigationItem.hidesBackButton = YES;
    vc.delegate = self;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        // Two-stage flip: collapse the pane's width to 0, swap its top controller,
        // then expand it back to the KONAMI-ID frame. The selection arrow slides
        // concurrently.
        [UIView transitionWithView:_rightViewCtrl.view
            duration:0.3                             // DAT_000e1c78 (0.3)
            options:UIViewAnimationOptionCurveEaseIn // 0x10000
            animations:^{ // @ 0xe1c88 — collapse rightViewCtrl.view width to 0
              CGRect f = _rightViewCtrl.view.frame;
              f.size.width = 0.0f;
              _rightViewCtrl.view.frame = f;
            }
            completion:^(BOOL finished) {
              // showKonamiIdView @ 0xe1d18 — set the navbar art, swap in the KID
              // input, then expand the pane to its section frame.
              [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                                 forBarMetrics:UIBarMetricsDefault];
              [_rightViewCtrl popToRootViewControllerAnimated:NO];
              [_rightViewCtrl pushViewController:vc animated:NO];
              [UIView transitionWithView:_rightViewCtrl.view
                  duration:0.3 // DAT_000e1e60 (0.3)
                  options:UIViewAnimationOptionCurveEaseIn
                  animations:^{ // @ 0xe1e68 — expand to _konamiIdFrm
                    _rightViewCtrl.view.frame = _konamiIdFrm;
                  }
                  completion:^(BOOL done) {
                    self->_isAnimationing = NO;
                  }];
            }];
        // @ 0xe1f48 — slide the selection arrow to the KONAMI-ID row (runs
        // concurrently).
        [UIView animateWithDuration:0.6 // DAT_000e1c80 (0.6)
                         animations:^{
                           _konamiIdArrowImageView.frame = _konamiIdArrowFrm;
                         }];
    }
    _selectedIndex = 0;
}

// @ 0xe1fa8 — switch the right pane to the score-checker section, or route to
// the KONAMI-ID input while unlinked. Ghidra flip block helper showCheckerView
// @ 0xe2320.
//
// Verified against 0xe1fa8 and its blocks: while unlinked it tail-calls
// -onInKidButtonTouched: and returns; otherwise it clears the bar-button items,
// builds a grouped CheckerCategoryViewController with hidesBackButton = YES, and
// on the _selectedIndex < 0 path pushes directly (navbar "ppc_navbar"). The flip
// collapses the pane width to 0 (block 0xe2290), swaps in the checker and expands
// to _checkerFrm (blocks 0xe2470), and slides the arrow to _checkerArrowFrm
// (block 0xe2550); navbar art is "ppc_navbar" and _selectedIndex ends at 1.
// @complete
- (void)onScoreCheckerButtonTouched:(id)sender {
    if (_isAnimationing) {
        return;
    }
    neAppEventCenter::shared();
    if (!neAppEventCenter::linkButtonsEnabled()) {
        [self onInKidButtonTouched:sender];
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    CheckerCategoryViewController *vc =
        [[CheckerCategoryViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.navigationItem.hidesBackButton = YES;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        [UIView transitionWithView:_rightViewCtrl.view
            duration:0.3
            options:UIViewAnimationOptionCurveEaseIn // 0x10000
            animations:^{ // @ 0xe2290 — collapse rightViewCtrl.view width to 0
              CGRect f = _rightViewCtrl.view.frame;
              f.size.width = 0.0f;
              _rightViewCtrl.view.frame = f;
            }
            completion:^(BOOL finished) {
              // showCheckerView @ 0xe2320 — set the navbar art, swap in the
              // checker, then expand.
              [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                                                 forBarMetrics:UIBarMetricsDefault];
              [_rightViewCtrl popToRootViewControllerAnimated:NO];
              [_rightViewCtrl pushViewController:vc animated:NO];
              [UIView transitionWithView:_rightViewCtrl.view
                  duration:0.3
                  options:UIViewAnimationOptionCurveEaseIn
                  animations:^{ // @ 0xe2470 — expand to _checkerFrm
                    _rightViewCtrl.view.frame = _checkerFrm;
                  }
                  completion:^(BOOL done) {
                    self->_isAnimationing = NO;
                  }];
            }];
        // @ 0xe2550 — slide the selection arrow to the checker row (runs
        // concurrently).
        [UIView animateWithDuration:0.6
                         animations:^{
                           _konamiIdArrowImageView.frame = _checkerArrowFrm;
                         }];
    }
    _selectedIndex = 1;
}

// @ 0xe25b0 — switch the right pane to the quiz section, or route to the
// KONAMI-ID input while unlinked. Ghidra flip block helper @ 0xe2928.
//
// Verified against 0xe25b0 and its blocks: while unlinked it tail-calls
// -onInKidButtonTouched: and returns; otherwise it builds a grouped
// QuizMainViewController with hidesBackButton = YES. The _selectedIndex < 0 path
// pushes directly with navbar "pl_konamiid_navbar" (CFString at 0xe2824). The
// flip collapses the pane width to 10 (0x41200000, block 0xe2898), swaps in the
// quiz and expands to _quizFrm (blocks 0xe2a78), and slides the arrow to
// _quizArrowFrm (block 0xe2b58). The animated showQuizView path uses "pq_navbar"
// (CFString at 0xe2928) — corrected here — and _selectedIndex ends at 2.
// @complete
- (void)onQuizButtonTouched:(id)sender {
    if (_isAnimationing) {
        return;
    }
    neAppEventCenter::shared();
    if (!neAppEventCenter::linkButtonsEnabled()) {
        [self onInKidButtonTouched:sender];
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    QuizMainViewController *vc =
        [[QuizMainViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.navigationItem.hidesBackButton = YES;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_konamiid_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        [UIView transitionWithView:_rightViewCtrl.view
            duration:0.3
            options:UIViewAnimationOptionCurveEaseIn // 0x10000
            animations:^{ // @ 0xe2898 — collapse rightViewCtrl.view width to 10
              CGRect f = _rightViewCtrl.view.frame;
              f.size.width = 10.0f; // 0x41200000
              _rightViewCtrl.view.frame = f;
            }
            completion:^(BOOL finished) {
              // showQuizView @ 0xe2928 — set the navbar art, swap in the quiz, then
              // expand. The animated-flip path uses "pq_navbar" (verified against
              // the imageNamed: CFString at 0xe2928), unlike the initial-populate
              // path above, which uses "pl_konamiid_navbar".
              [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pq_navbar"]
                                                 forBarMetrics:UIBarMetricsDefault];
              [_rightViewCtrl popToRootViewControllerAnimated:NO];
              [_rightViewCtrl pushViewController:vc animated:NO];
              [UIView transitionWithView:_rightViewCtrl.view
                  duration:0.3
                  options:UIViewAnimationOptionCurveEaseIn
                  animations:^{ // @ 0xe2a78 — expand to _quizFrm
                    _rightViewCtrl.view.frame = _quizFrm;
                  }
                  completion:^(BOOL done) {
                    self->_isAnimationing = NO;
                  }];
            }];
        // @ 0xe2b58 — slide the selection arrow to the quiz row (runs
        // concurrently).
        [UIView animateWithDuration:0.6
                         animations:^{
                           _konamiIdArrowImageView.frame = _quizArrowFrm;
                         }];
    }
    _selectedIndex = 2;
}

// @ 0xe2bb8 — rebuild the left column's inputs and re-evaluate its
// button-enabled state.
// Verified: 0xe2bb8 calls -reloadInputViews then tail-calls -updateButtonEnable
// on _leftViewCtrl.
// @complete
- (void)reloadLeftView {
    [_leftViewCtrl reloadInputViews];
    [_leftViewCtrl updateButtonEnable];
}

// @ 0xe2bf4 — a backdrop / top-cover tap: play the cancel SE and fade the panel
// out.
// Verified against 0xe2bf4: guard check, playSystemSe(2) (r1 = 2 into the SE
// call at 0xe2c1e), then tail-calls -startCloseAnimation.
// @complete
- (void)handleTapCoverView {
    if (_isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
