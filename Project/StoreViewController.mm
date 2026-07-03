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

// dealloc — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
