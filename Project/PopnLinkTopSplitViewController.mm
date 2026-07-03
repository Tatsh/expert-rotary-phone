//
//  PopnLinkTopSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad pop'n-link
//  split hub. Objective-C++ (drives the C++ "ne" engine singletons for the link-enabled
//  flag, SE and scene-root bridge).
//

#import "PopnLinkTopSplitViewController.h"
#import "PopnLinkTopViewController.h"       // left pane + PopnLinkTopViewControllerDelegate
#import "CheckerCategoryViewController.h"   // score-checker section
#import "QuizMainViewController.h"          // quiz section
#import "HowToViewCtrlPad.h"                // first-play how-to overlay
#import "UserSettingData.h"                 // isPopnLinkSelected / saveIsPopnLinkSelected:
#import "neEngineBridge.h"                  // neAppEventCenter::linkButtonsEnabled, neEngine::playSystemSe,
                                            //   neSceneManager::rootViewController

// TODO(dep): the KONAMI-ID input controller InputKIDViewCtrl is not yet reconstructed
// (MISSING.md — missing). It is instantiated by name (NSClassFromString) and typed as a
// plain UIViewController here so this hub compiles and links until that unit lands.
static NSString *const kInputKIDViewCtrl = @"InputKIDViewCtrl";

@interface PopnLinkTopSplitViewController () <PopnLinkTopViewControllerDelegate>
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)handleTapCoverView;
@end

@implementation PopnLinkTopSplitViewController {
    BOOL _isAnimationing;                          // guards a transition against re-entry
    PopnLinkTopViewController *_leftViewCtrl;      // left section-button column
    UINavigationController *_rightViewCtrl;         // right detail pane (swapped by the section buttons)
    UIImageView *_konamiIdArrowImageView;          // selection arrow
    int _selectedIndex;                            // -1 uninitialised, 0 KONAMI-ID, 1 checker, 2 quiz
    CGRect _konamiIdFrm;                           // right-pane frame per section
    CGRect _checkerFrm;
    CGRect _quizFrm;
    CGRect _konamiIdArrowFrm;                      // arrow frame per section row
    CGRect _checkerArrowFrm;
    CGRect _quizArrowFrm;
    HowToViewCtrlPad *_howToView;                  // first-play how-to overlay
}

// @ 0xe0b40 — build the dimmed backdrop (tap to close), the artwork panel, the left
// section column (PopnLinkTopViewController), the right navigation pane, the selection
// arrow (positioned per link state), and a top cover strip; then populate the initial
// section (checker, which routes to the KONAMI-ID input while unlinked).
- (instancetype)init {
    if ((self = [super init])) {
        _konamiIdFrm = CGRectMake(385, 220, 320, 600);
        _checkerFrm  = CGRectMake(385, 182, 320, 716);
        _quizFrm     = CGRectMake(385, 250, 320, 530);

        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _konamiIdArrowImageView = [[UIImageView alloc] initWithImage:arrow];
        _konamiIdArrowFrm = CGRectMake(365, 307, arrow.size.width, arrow.size.height);
        _checkerArrowFrm  = CGRectMake(365, 452, arrow.size.width, arrow.size.height);
        _quizArrowFrm     = CGRectMake(365, 592, arrow.size.width, arrow.size.height);

        // Arrow starts on the KONAMI-ID row until the player has linked pop'n-link.
        neAppEventCenter::shared();
        _konamiIdArrowImageView.frame =
            neAppEventCenter::linkButtonsEnabled() ? _checkerArrowFrm : _konamiIdArrowFrm;

        // Dimmed, tappable backdrop.
        UIView *cover = [[UIView alloc] initWithFrame:
            CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView)]];

        // Artwork panel holding the split view, centred on screen.
        UIImage *bgImg = [UIImage imageNamed:@"pl_bg"];
        UIImageView *bg = [[UIImageView alloc] initWithImage:bgImg];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center = CGPointMake(self.view.frame.size.width * 0.5f,
                                self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left section column (the pop'n-link top VC; its own view is embedded here).
        _leftViewCtrl = [[PopnLinkTopViewController alloc] init];
        _leftViewCtrl.view.clipsToBounds = YES;
        _leftViewCtrl.view.frame = CGRectMake(_leftViewCtrl.view.frame.origin.x + 65,
                                              _leftViewCtrl.view.frame.origin.y + 100,
                                              354, bgImg.size.height);
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
        _rightViewCtrl.view.backgroundColor =
            [UIColor colorWithRed:0.953f green:0.953f blue:0.953f alpha:1];
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        // Top cover strip (swallows taps over the nav-bar band).
        UIView *topCover = [[UIView alloc] initWithFrame:
            CGRectMake(0, 0, self.view.frame.size.width, 140)];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView)]];

        // Populate the initial section (checker; falls back to KONAMI-ID input while unlinked).
        _selectedIndex = -1;
        [self onScoreCheckerButtonTouched:nil];
        [bg addSubview:_konamiIdArrowImageView];
    }
    return self;
}

#pragma mark - Lifecycle

// @ 0xe1430 — detach the selection arrow on teardown (real work kept under ARC; the
// _leftViewCtrl / _rightViewCtrl / _howToView releases are ARC-automatic).
- (void)dealloc {
    [_konamiIdArrowImageView removeFromSuperview];
}

// viewDidLoad @ 0xe14e0 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xe150c — super-only override, omitted.

#pragma mark - Open/close animation

// @ 0xe1538 — while unlinked, force the KONAMI-ID input onto the host nav stack (and show
// the first-play how-to once), then fade the view + nav view in over 0.5s.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;

    neAppEventCenter::shared();
    if (!neAppEventCenter::linkButtonsEnabled()) {
        UIViewController *inKid = [[NSClassFromString(kInputKIDViewCtrl) alloc] init]; // TODO(dep)
        [self.navigationController pushViewController:inKid animated:NO];
        if (![UserSettingData isPopnLinkSelected]) {
            _howToView = [[HowToViewCtrlPad alloc] initWithFileNameArray:@[@"firstplay_popnlink"]];
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

// @ 0xe1840 — clear the guard.
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xe1858 — fade the view + nav view out over 0.3s. (The binary re-clears the guard
// here rather than setting it; reproduced faithfully.)
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
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(PopnLinkEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Section handlers

// @ 0xe19c0 — switch the right pane to the KONAMI-ID input section. Ghidra flip block
// helper showKonamiIdView @ 0xe1d18 (modeled as a single flip whose completion clears the
// guard).
- (void)onInKidButtonTouched:(id)sender {
    if (_isAnimationing) {
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    UIViewController *vc = [[NSClassFromString(kInputKIDViewCtrl) alloc] init]; // TODO(dep)
    vc.navigationItem.hidesBackButton = YES;
    [vc performSelector:@selector(setDelegate:) withObject:self];

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        [UIView transitionWithView:_rightViewCtrl.view
                          duration:0.3
                           options:UIViewAnimationOptionCurveEaseIn
                        animations:^{
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
        } completion:^(BOOL finished) {
            _isAnimationing = NO;
        }];
    }
    _selectedIndex = 0;
}

// @ 0xe1fa8 — switch the right pane to the score-checker section, or route to the
// KONAMI-ID input while unlinked. Ghidra flip block helper showCheckerView @ 0xe2320.
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
                           options:UIViewAnimationOptionCurveLinear
                        animations:^{
            [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
        } completion:^(BOOL finished) {
            _isAnimationing = NO;
        }];
    }
    _selectedIndex = 1;
}

// @ 0xe25b0 — switch the right pane to the quiz section, or route to the KONAMI-ID input
// while unlinked. Ghidra flip block helper @ 0xe2928.
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
                           options:UIViewAnimationOptionCurveEaseIn
                        animations:^{
            [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_konamiid_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
        } completion:^(BOOL finished) {
            _isAnimationing = NO;
        }];
    }
    _selectedIndex = 2;
}

// @ 0xe2bb8 — rebuild the left column's inputs and re-evaluate its button-enabled state.
- (void)reloadLeftView {
    [_leftViewCtrl reloadInputViews];
    [_leftViewCtrl updateButtonEnable];
}

// @ 0xe2bf4 — a backdrop / top-cover tap: play the cancel SE and fade the panel out.
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
