//
//  InviteTopViewController.mm
//  pop'n rhythmin
//
//  See InviteTopViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neEngine / neSceneManager
//  singletons (system SE on decide/cancel, root-VC end callback). The
//  open/close fades are byte-verified; initAtNavigationController's
//  panel/button frames are structural, computed from runtime image .size plus
//  literal constants (player panel y=15.0; guest panel y=playerH+30.0; player
//  btn y=panelH-btnH-20.0; guest btn y=panelH-btnH-15.0; scroll content
//  +100.0), all centred by (frame.width - img.width)*0.5. Origins derive from
//  runtime .size, not lost constants.
//

#import "InviteTopViewController.h"

#import "InputKidViewController.h"     // "guest" panel  -> enter someone's code
#import "MyInviteCodeViewController.h" // "player" panel -> show my invite code
#import "neEngineBridge.h"             // neEngine::playSystemSe, neSceneManager::rootViewController

// Own privates (selectors wired up by initAtNavigationController).
@interface InviteTopViewController ()
- (void)touchedInviteButton:(id)sender;
- (void)touchedInputButton:(id)sender;
- (void)touchedBackButton;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
@end

@implementation InviteTopViewController

// @ 0xe6f88 — build the top view + wrap it in a navigation controller.
// @complete
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    // family(none) factory: returns the nav, not self, so it cannot assign self;
    // super init returns the receiver in place -> self stays valid (matches the
    // binary's super-init check).
    if (![super init]) {
        return nil;
    }

    const CGRect frame = self.view.frame;

    // Wrap self in its own navigation controller.
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];

    // Nav-bar custom back button + art.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(touchedBackButton)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"invite_navbar"]
             forBarMetrics:UIBarMetricsDefault];

    // Full-screen backdrop.
    UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
    [bg setImage:[UIImage imageNamed:@"friman_bg"]];
    [self.view addSubview:bg];

    // Scrolling container holding the two panels.
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.backgroundColor = [UIColor clearColor];
    [self.view addSubview:scroll];

    // "player" panel image (centred horizontally, y=15), interactive so its
    // button works.
    UIImage *inviteImg = [UIImage imageNamed:@"invite_view"];
    UIImageView *inviteView = [[UIImageView alloc] initWithImage:inviteImg];
    inviteView.frame = CGRectMake((frame.size.width - inviteImg.size.width) * 0.5f,
                                  15.0f,
                                  inviteImg.size.width,
                                  inviteImg.size.height);
    inviteView.userInteractionEnabled = YES;

    // "guest" panel image (centred horizontally, below the player panel: y =
    // playerH + 30).
    UIImage *guestImg = [UIImage imageNamed:@"invite_view_guest"];
    UIImageView *guestView = [[UIImageView alloc] initWithImage:guestImg];
    guestView.frame = CGRectMake((frame.size.width - guestImg.size.width) * 0.5f,
                                 inviteImg.size.height + 30.0f,
                                 guestImg.size.width,
                                 guestImg.size.height);
    guestView.userInteractionEnabled = YES;

    [scroll addSubview:inviteView];
    [scroll addSubview:guestView];
    scroll.contentSize =
        CGSizeMake(frame.size.width, inviteImg.size.height + guestImg.size.height + 100.0f);

    // "player" button on the player panel (bottom-anchored: y = panelH - btnH -
    // 20).
    UIButton *playerBtn = [[UIButton alloc] init];
    UIImage *playerBtnImg = [UIImage imageNamed:@"invite_btn_player"];
    [playerBtn setBackgroundImage:playerBtnImg forState:UIControlStateNormal];
    playerBtn.frame = CGRectMake((inviteImg.size.width - playerBtnImg.size.width) * 0.5f,
                                 inviteImg.size.height - playerBtnImg.size.height - 20.0f,
                                 playerBtnImg.size.width,
                                 playerBtnImg.size.height);
    playerBtn.exclusiveTouch = YES;
    [playerBtn addTarget:self
                  action:@selector(touchedInviteButton:)
        forControlEvents:UIControlEventTouchUpInside];
    [inviteView addSubview:playerBtn];

    // "guest" button on the guest panel (bottom-anchored: y = panelH - btnH -
    // 15).
    UIButton *guestBtn = [[UIButton alloc] init];
    UIImage *guestBtnImg = [UIImage imageNamed:@"invite_btn_guest"];
    [guestBtn setBackgroundImage:guestBtnImg forState:UIControlStateNormal];
    guestBtn.frame = CGRectMake((guestImg.size.width - guestBtnImg.size.width) * 0.5f,
                                guestImg.size.height - guestBtnImg.size.height - 15.0f,
                                guestBtnImg.size.width,
                                guestBtnImg.size.height);
    guestBtn.exclusiveTouch = YES;
    [guestBtn addTarget:self
                  action:@selector(touchedInputButton:)
        forControlEvents:UIControlEventTouchUpInside];
    [guestView addSubview:guestBtn];

    return nav;
}

// @ 0xe7860 — "player" button: push the my-invite-code screen (play the decide
// SE).
// @complete
- (void)touchedInviteButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (isAnimationing) {
        return;
    }
    MyInviteCodeViewController *vc = [[MyInviteCodeViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    neEngine::playSystemSe(1);
}

// @ 0xe7914 — "guest" button: push the invite-code input screen (play the
// decide SE).
// @complete
- (void)touchedInputButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (isAnimationing) {
        return;
    }
    InputKidViewController *vc = [[InputKidViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    neEngine::playSystemSe(1);
}

// @ 0xe79c8 — back button: play the cancel SE and run the close fade.
// @complete
- (void)touchedBackButton {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

// @ 0xe7a38 — fade the view + its nav view up to opaque over 0.3 s.
// @complete
- (void)startOpenAnimation {
    if (isAnimationing) {
        return;
    }
    isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xe7b70
// @complete
- (void)endOpenAnimation {
    isAnimationing = NO;
}

// @ 0xe7b88 — fade the view + its nav view out over 0.3 s.
// @complete
- (void)startCloseAnimation {
    if (isAnimationing) {
        return;
    }
    isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xe7c90 — pull the view, notify the root VC the invite flow closed, clear
// the guard. The binary calls -[root InviteCodeEndCallBack] directly; modelled
// as performSelector: (behaviourally identical for a no-argument selector).
// @complete
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(InviteCodeEndCallBack)];
    isAnimationing = NO;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
