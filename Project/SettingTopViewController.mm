//
//  SettingTopViewController.mm
//  pop'n rhythmin
//
//  See SettingTopViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin:
//    init                       @ 0x13fe8
//    initAtNavigationController  @ 0x14464
//    viewDidLoad                @ 0x1463c
//    didReceiveMemoryWarning    @ 0x14668
//    startOpenAnimation         @ 0x14694
//    endOpenAnimation           @ 0x147c0
//    startCloseAnimation        @ 0x147d8
//    endCloseAnimation          @ 0x148f8
//    onGameButtonTouched:       @ 0x14964
//    onHowtoButtonTouched:      @ 0x14a90
//    onCustomerButtonTouched:   @ 0x14ae0
//    onOtherButtonTouched:      @ 0x14b30
//    settingTopDelegate         @ 0x14b80
//    setSettingTopDelegate:     @ 0x14b90
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - The four button y-positions are exact float-hex decodes (200 / 300 / 400 / 500), each
//     sized to its background art ("custom_bt_game"/"custom_bt_howto"/"custom_bt_inquiry"/
//     "custom_bt_other"); all use setExclusiveTouch:YES.
//   - -init's phone branch adds a "friman_bg" image view to the view; the binary computes that
//     image view's frame (from its own .frame and the image size) but never applies it, so the
//     image view keeps its intrinsic frame here too (faithful to the discarded computation).
//   - The open animation runs 0.5s (0x3fe00000); the close animation runs 0.3s
//     (DAT_000148f0 == 0x3fd3333340000000).
//   - -endCloseAnimation hands control back to the root VC via
//     -[MainViewController SettingEndCallBack] (neSceneManager::rootViewController()).
//

#import "SettingTopViewController.h"

#import "SettingGameTableViewController.h"  // phone: pushed by the ゲーム button
#import "neEngineBridge.h"                  // neSceneManager::isPadDisplay/rootViewController, neEngine::playSystemSe

static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@implementation SettingTopViewController {
    BOOL _isAnimationing;   // @0x… animation-in-flight guard (ivar type "c")
    // _settingTopDelegate is the @synthesize'd backing ivar (assign, id<...Dalegate>).
}

@synthesize settingTopDelegate = _settingTopDelegate;   // getter @ 0x14b80 / setter @ 0x14b90

// @ 0x13fe8 — backdrop + the four custom menu buttons.
- (instancetype)init {
    if ((self = [super init])) {
        if (!neSceneManager::isPadDisplay()) {
            // Phone: a "friman_bg" backdrop image view. (The binary computes a frame for it but
            // discards the result, so the intrinsic image size is kept.)
            UIImageView *bg =
                [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friman_bg"]];
            [self.view addSubview:bg];
        } else {
            self.view.backgroundColor = [UIColor clearColor];
        }

        NSString *const images[4] = {
            @"custom_bt_game", @"custom_bt_howto", @"custom_bt_inquiry", @"custom_bt_other"
        };
        const SEL actions[4] = {
            @selector(onGameButtonTouched:), @selector(onHowtoButtonTouched:),
            @selector(onCustomerButtonTouched:), @selector(onOtherButtonTouched:)
        };
        const CGFloat ys[4] = { 200.0f, 300.0f, 400.0f, 500.0f };  // 0x43480000/96/c8/fa0000
        for (int i = 0; i < 4; i++) {
            UIImage *img = [UIImage imageNamed:images[i]];
            UIButton *btn = [[UIButton alloc]
                initWithFrame:CGRectMake(0, ys[i], img.size.width, img.size.height)];
            btn.exclusiveTouch = YES;
            [btn setBackgroundImage:img forState:UIControlStateNormal];
            [btn addTarget:self action:actions[i]
              forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:btn];
        }
    }
    return self;
}

// @ 0x14464 — build self, wrap it in a nav controller, add a back button + settings nav-bar art.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    [self init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:self];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(startCloseAnimation)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// viewDidLoad @ 0x1463c — super-only override, ARC/omit.
// didReceiveMemoryWarning @ 0x14668 — super-only override, ARC/omit.

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0x14694 — fade the view + nav view in over 0.5s.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
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

// @ 0x147c0
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x147d8 — cancel SE, then fade out over 0.3s; also the back-button action.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);   // cancel/back SE
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // DAT_000148f0
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x148f8 — remove the nav view and hand control back to MainViewController.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Buttons

// @ 0x14964 — ゲーム: phone pushes SettingGameTableViewController; pad forwards to the delegate.
- (void)onGameButtonTouched:(id)sender {
    neEngine::playSystemSe(1);   // decide/confirm SE
    if (!neSceneManager::isPadDisplay()) {
        SettingGameTableViewController *vc = [[SettingGameTableViewController alloc]
            initWithStyle:UITableViewStyleGrouped];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [_settingTopDelegate onGameButtonTouched:sender];
    }
}

// @ 0x14a90 — 遊び方: phone is a no-op; pad forwards to the delegate.
- (void)onHowtoButtonTouched:(id)sender {
    neEngine::playSystemSe(1);   // decide/confirm SE
    if (!neSceneManager::isPadDisplay()) {
        return;
    }
    [_settingTopDelegate onHowtoButtonTouched:sender];
}

// @ 0x14ae0 — お問い合わせ: phone is a no-op; pad forwards to the delegate.
- (void)onCustomerButtonTouched:(id)sender {
    neEngine::playSystemSe(1);   // decide/confirm SE
    if (!neSceneManager::isPadDisplay()) {
        return;
    }
    [_settingTopDelegate onCustomerButtonTouched:sender];
}

// @ 0x14b30 — その他: phone is a no-op; pad forwards to the delegate.
- (void)onOtherButtonTouched:(id)sender {
    neEngine::playSystemSe(1);   // decide/confirm SE
    if (!neSceneManager::isPadDisplay()) {
        return;
    }
    [_settingTopDelegate onOtherButtonTouched:sender];
}

// settingTopDelegate @ 0x14b80 / setSettingTopDelegate: @ 0x14b90 — @synthesize'd assign accessors.

// dealloc — ARC-omitted (BOOL + assign delegate only; nothing owned to release).

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
