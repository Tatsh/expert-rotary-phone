//
//  StoreViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreViewController.h"
#import "StoreMainViewController.h"
#import "StoreManageViewController.h"
#import "StoreAcvManageViewController.h"
#import "AudioManager.h"
#import "AppFont.h"
#import "neEngineBridge.h"

@implementation StoreViewController

@synthesize recommendPackId = _recommendPackId;

// Wrap a tab's root controller in a navigation controller with the app's custom
// back button and navbar background image.
- (UINavigationController *)wrapController:(UIViewController *)root
                              navbarImage:(NSString *)navbarImageName {
    UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backButton =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImage.size.width,
                                                    backImage.size.height)];
    [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self
                   action:@selector(pushBarBtnBack:)
         forControlEvents:UIControlEventTouchUpInside];
    root.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backButton];

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:root];
    [nav.navigationBar setBackgroundImage:[UIImage imageNamed:navbarImageName]
                            forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// @ 0x53140 — build the three tabs; each is a nav controller with a custom navbar.
- (instancetype)initWithRecommendPackId:(int)recommendPackId {
    _recommendPackId = recommendPackId;
    if ((self = [super init])) {
        // 8pt tab-bar item titles in the app font (UITextAttributeFont — iOS 5/6 era).
        UIFont *tabFont = [UIFont fontWithName:AppFontName() size:8.0f];
        [[UITabBarItem appearance]
            setTitleTextAttributes:@{ UITextAttributeFont: tabFont }
                          forState:UIControlStateNormal];

        StoreMainViewController *mainVC =
            [[StoreMainViewController alloc] initWithParent:self];
        m_MainNavCtrl = [self wrapController:mainVC navbarImage:@"p_store_navbar"];

        StoreManageViewController *manageVC =
            [[StoreManageViewController alloc] initWithParent:self];
        m_ManageNavCtrl = [self wrapController:manageVC navbarImage:@"store_ryzumanage_navbar"];

        StoreAcvManageViewController *acvVC =
            [[StoreAcvManageViewController alloc] initWithParent:self];
        m_AcvManageNavCtrl = [self wrapController:acvVC navbarImage:@"store_viewmanage_navbar"];

        self.viewControllers = @[ m_MainNavCtrl, m_ManageNavCtrl, m_AcvManageNavCtrl ];
    }
    return self;
}

// @ 0x537d8 — build the dimming cover and the centred modal (please-wait / abort) dialog over the
// tab bar's view; on retina match the GL scene's native contentScaleFactor.
- (void)loadView {
    [super loadView];

    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
        [self.view respondsToSelector:@selector(contentScaleFactor)]) {
        self.view.contentScaleFactor = [UIScreen mainScreen].scale;
    }

    CGRect bounds = self.view.bounds;

    // 40%-black dimming backdrop, resized with the view and hidden until a dialog is shown.
    m_CoverView = [[UIView alloc] initWithFrame:bounds];
    m_CoverView.opaque = NO;
    m_CoverView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    m_CoverView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    m_CoverView.hidden = YES;
    [self.view addSubview:m_CoverView];

    // TODO(dep): StoreDialogView is a separate, not-yet-reconstructed unit; instantiated by name so
    // this compiles until its header lands. The dialog frame sizes are NEON-spilled (best-effort).
    Class dialogClass = NSClassFromString(@"StoreDialogView");
    UIFont *messageFont;
    if (neSceneManager::isPadDisplay()) {
        m_ModalDialog = [[dialogClass alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
        messageFont = [UIFont fontWithName:AppFontName() size:18.0f];
    } else {
        m_ModalDialog = [[dialogClass alloc] initWithFrame:CGRectMake(0, 0, 300, 270)];
        messageFont = [UIFont fontWithName:AppFontName() size:16.0f];
    }
    UILabel *messageLabel = [m_ModalDialog performSelector:@selector(labelMessage)];
    messageLabel.font = messageFont;
    [m_ModalDialog setCenter:CGPointMake(bounds.size.width * 0.5f, bounds.size.height * 0.5f)];
    [m_CoverView addSubview:m_ModalDialog];
}

// @ 0x54424 / 0x54438 — atomic accessors for the recommended-pack seed.
- (int)recommendPackId {
    return _recommendPackId;
}

- (void)setRecommendPackId:(int)recommendPackId {
    _recommendPackId = recommendPackId;
}

// @ 0x53e88 — fade the store in; pushes the menu BGM aside.
- (void)showAnimation {
    if (m_Animation) {
        return;
    }
    // Pre-iOS 5 does not auto-forward appearance callbacks under a tab bar.
    if ([UIDevice.currentDevice.systemVersion compare:@"5.0" options:NSNumericSearch]
            == NSOrderedAscending) {
        [self viewWillAppear:YES];
    }
    m_Animation = YES;
    self.view.alpha = 0.0f;
    [UIView beginAnimations:@"MusicViewAlpha" context:NULL];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(showAnimationEnd)];
    self.view.alpha = 1.0f;
    [UIView commitAnimations];

    AudioManager *audio = [AudioManager sharedManager];
    [audio stopBgm:0.5f];
    [audio pushBgm];
}

// @ 0x54030
- (void)showAnimationEnd {
    m_Animation = NO;
    if ([UIDevice.currentDevice.systemVersion compare:@"5.0" options:NSNumericSearch]
            == NSOrderedAscending) {
        [self viewDidAppear:YES];
    }
}

// @ 0x540b0 — fade the store out.
- (void)hideAnimation {
    m_Animation = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(hideAnimationEnd)];
    self.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x54178 — remove the view; hand back to the root VC unless opened for a pack.
- (void)hideAnimationEnd {
    [self.view removeFromSuperview];
    if (_recommendPackId > 0) {
        return;
    }
    neSceneManager::shared();
    UIViewController *rootVC = (__bridge UIViewController *)neSceneManager::rootViewController();
    // -[MainViewController StoreEndCallBack]
    [rootVC performSelector:@selector(StoreEndCallBack)];
}

// @ 0x541e0 — nav back button: close the front table, restore BGM, play the
// cancel SE and fade out.
- (void)pushBarBtnBack:(id)sender {
    if (m_Animation) {
        return;
    }
    UIViewController *top = m_MainNavCtrl.topViewController;
    if ([top isKindOfClass:StoreMainViewController.class]) {
        StoreMainViewController *mainVC = (StoreMainViewController *)top;
        if ([mainVC isAlertViewShowing]) {
            return;
        }
        [mainVC startStoreClose];
    }

    AudioManager *audio = [AudioManager sharedManager];
    if ([audio isPushBgm]) {
        [audio stopBgm:0.5f];
        [audio popBgm];
        [audio playBgm:0.5f];
    }

    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self hideAnimation];
}

// @ 0x53b10 — fade the dimming cover in and reveal the modal dialog (spinner running, abort button
// disabled) with the given animation delegate. No-op (returns NO) while a fade is already running.
- (BOOL)showModalDialog:(id)delegate {
    if (m_IsModalDialogAnimation) {
        return NO;
    }
    m_IsModalDialogAnimation = YES;
    m_CoverView.alpha = 0.0f;
    m_CoverView.hidden = NO;
    [[m_ModalDialog performSelector:@selector(indicatorView)] startAnimating];
    [[m_ModalDialog performSelector:@selector(buttonAbort)] setEnabled:NO];
    [m_ModalDialog setDelegate:delegate];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(openDialogAnimStop:finished:context:)];
    m_CoverView.alpha = 1.0f;
    [UIView commitAnimations];
    return YES;
}

// @ 0x53c88 — open animation finished: clear the busy flag and re-enable the abort button.
- (void)openDialogAnimStop:(NSString *)animationID
                   finished:(NSNumber *)finished
                    context:(void *)context {
    m_IsModalDialogAnimation = NO;
    [[m_ModalDialog performSelector:@selector(buttonAbort)] setEnabled:YES];
}

// @ 0x53cd8 — fade the dimming cover out; disables the abort button and drops the dialog delegate.
- (BOOL)hideModalDialog {
    m_IsModalDialogAnimation = YES;
    [[m_ModalDialog performSelector:@selector(buttonAbort)] setEnabled:NO];
    [m_ModalDialog setDelegate:nil];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(closeDialogAnimStop:finished:context:)];
    m_CoverView.alpha = 0.0f;
    [UIView commitAnimations];
    return YES;
}

// @ 0x53df0 — close animation finished: clear the busy flag, stop the spinner and hide the cover.
- (void)closeDialogAnimStop:(NSString *)animationID
                    finished:(NSNumber *)finished
                     context:(void *)context {
    m_IsModalDialogAnimation = NO;
    [[m_ModalDialog performSelector:@selector(indicatorView)] stopAnimating];
    m_CoverView.hidden = YES;
}

// @ 0x53e58 — iPad locks to portrait; iPhone allows every orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (neSceneManager::isPadDisplay()) {
        return interfaceOrientation == UIInterfaceOrientationPortrait ||
               interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
    }
    return YES;
}

// @ 0x54414 — the shared modal dialog built in -loadView.
- (id)modalDialog {
    return m_ModalDialog;
}

// didReceiveMemoryWarning @ 0x54338 — super-only override, omitted.
// viewWillAppear: @ 0x54364 — super-only override, omitted.
// viewDidAppear: @ 0x54390 — super-only override, omitted.
// viewWillDisappear: @ 0x543bc — super-only override, omitted.
// viewDidDisappear: @ 0x543e8 — super-only override, omitted.

// @ 0x53708 — reset the app-wide tab-bar item title appearance installed in -init; the
// nav-controller / dialog / cover ivars are released by ARC.
- (void)dealloc {
    [[UITabBarItem appearance] setTitleTextAttributes:nil forState:UIControlStateNormal];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
