//
//  AcceptPolicyViewController.mm
//  pop'n rhythmin
//
//  See AcceptPolicyViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neEngine / neSceneManager
//  singletons (system SE, pad-vs-phone card size, root-VC overlay + end
//  callback). All geometry constants are byte-verified from ARM32 Thumb2
//  disassembly / literal-pool reads: card 295×278 phone / 425×292 pad
//  (movw/movt pairs), nav-view 3pt inset (vmov.f32 d20,#3.0), textView x=10
//  (movt #0x4120) / y=60 pad / 55 phone (movt), detailBtn y=163.0 (0xb02b4:
//  0x43230000), rejectBtn x=15.0 (movt #0x4170) / y-gap=17.0 (vmov.f32
//  0x41880000), accept x-addend 84.0 iPad (0xb02b8: 0x42a80000) / 20.0 phone
//  (vmov.f32 0x41a00000). Gradient colours, corner radii, images, actions and
//  view hierarchy are exact.
//

#import "AcceptPolicyViewController.h"

#import <QuartzCore/QuartzCore.h> // CAGradientLayer / CALayer cornerRadius

#import "AppFont.h"         // AppFontName()  (getFontNameDFSoGei)
#import "CustomTextView.h"  // the read-only terms text view
#import "PolicyView.h"      // the full terms overlay (onDetailBtn:)
#import "UserSettingData.h" // +saveIsPolicyAccepted:
#import "neEngineBridge.h" // neEngine::playSystemSe, neSceneManager::rootViewController / isPadDisplay

// Own privates (selectors wired up by init).
@interface AcceptPolicyViewController ()
- (void)onYesBtn:(id)sender;
- (void)onNoBtn:(id)sender;
- (void)onDetailBtn:(id)sender;
- (void)onBackBtn:(id)sender;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
@end

@implementation AcceptPolicyViewController

// @ 0xaf848 — build the terms card (gradient card + embedded content nav +
// three buttons).
- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    const CGRect frame = self.view.frame;
    const bool isPad = neSceneManager::isPadDisplay();

    // Rounded, clipped card. Phone 295×278 / pad 425×292 (byte-verified:
    // movw/movt pairs), centred on screen.
    UIView *card = [[UIView alloc] init];
    card.frame = isPad ? CGRectMake(0, 0, 425.0f, 292.0f) : CGRectMake(0, 0, 295.0f, 278.0f);
    card.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f);
    card.clipsToBounds = YES;
    card.layer.cornerRadius = 5.0f;

    // Three-stop diagonal gradient behind the card content (colours byte-exact).
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, card.frame.size.width, card.frame.size.height);
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.50588959f green:1.0f blue:0.92548853f alpha:1.0f].CGColor,
        (id)[UIColor colorWithRed:1.0f green:0.90980393f blue:0.40784314f alpha:1.0f].CGColor,
        (id)[UIColor colorWithRed:0.99608099f green:0.63529414f blue:0.68235296f alpha:1.0f]
            .CGColor,
    ];
    [card.layer insertSublayer:gradient atIndex:0];
    [self.view addSubview:card];

    // Embedded content navigation controller, inset 3pt inside the card
    // (byte-verified: vmov.f32 d20,#3.0; dims = card − 6 via vadd with −6.0).
    _naviCtrl = [[UINavigationController alloc] init];
    _naviCtrl.view.frame =
        CGRectMake(3.0f, 3.0f, card.frame.size.width - 6.0f, card.frame.size.height - 6.0f);
    _naviCtrl.view.clipsToBounds = YES;
    _naviCtrl.view.layer.cornerRadius = 2.5f;
    _naviCtrl.view.backgroundColor =
        [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    [_naviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"btn_navbar_conditions"]
                                  forBarMetrics:UIBarMetricsDefault];
    [card addSubview:_naviCtrl.view];

    // Read-only terms summary text (seeded with the placeholder above). x=10.0
    // (movt #0x4120 = 0x41200000), y=60.0 pad / 55.0 phone (movt —
    // byte-verified).
    const CGRect navFrame = _naviCtrl.view.frame;
    CustomTextView *textView =
        [[CustomTextView alloc] initWithFrame:CGRectMake(10.0f,
                                                         isPad ? 60.0f : 55.0f,
                                                         navFrame.size.width - 20.0f,
                                                         navFrame.size.height - 20.0f)];
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    // UTF-16 CFString @ 0x13abc8 -> chars @ 0x12dc9e (9 units): 3010 6697 95C7
    // 3092 89E3 9664 3059 308B 3011.
    textView.text = @"【暗闇を解除する】";
    textView.font = [UIFont fontWithName:AppFontName() size:15.0f];
    textView.userInteractionEnabled = YES;
    textView.scrollEnabled = NO;
    [_naviCtrl.view addSubview:textView];

    // "詳細" (show full terms) button — horizontally centred in the content nav
    // view.
    UIImage *detailImg = [UIImage imageNamed:@"btn_conditions"];
    UIButton *detailBtn = [[UIButton alloc] init];
    [detailBtn setBackgroundImage:detailImg forState:UIControlStateNormal];
    detailBtn.frame = CGRectMake(0, 163.0f, detailImg.size.width, detailImg.size.height);
    detailBtn.exclusiveTouch = YES;
    detailBtn.center = CGPointMake(navFrame.size.width * 0.5f, detailBtn.center.y);
    [detailBtn addTarget:self
                  action:@selector(onDetailBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [_naviCtrl.view addSubview:detailBtn];

    // Reject button: x=15.0 (movt #0x4170 = 0x41700000), y-gap=17.0 (vmov.f32
    // 0x41880000 — byte-verified).
    UIImage *rejectImg = [UIImage imageNamed:@"btn_reject"];
    UIButton *rejectBtn = [[UIButton alloc] init];
    [rejectBtn setBackgroundImage:rejectImg forState:UIControlStateNormal];
    rejectBtn.frame = CGRectMake(15.0f,
                                 detailBtn.frame.origin.y + detailImg.size.height + 17.0f,
                                 rejectImg.size.width,
                                 rejectImg.size.height);
    rejectBtn.exclusiveTouch = YES;
    [rejectBtn addTarget:self
                  action:@selector(onNoBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [_naviCtrl.view addSubview:rejectBtn];

    // Accept button: x = rejectImg.size.width + 15.0 + (84.0 pad / 20.0 phone).
    // Byte-verified: 15.0 = vmov.f32 0x41700000; 84.0 = 0xb02b8: 0x42a80000
    // (pad); 20.0 = vmov.f32 0x41a00000 (phone). Binary does NOT include
    // rejectBtn.origin.x.
    UIImage *acceptImg = [UIImage imageNamed:@"btn_accept"];
    UIButton *acceptBtn = [[UIButton alloc] init];
    [acceptBtn setBackgroundImage:acceptImg forState:UIControlStateNormal];
    acceptBtn.frame = CGRectMake(rejectImg.size.width + 15.0f + (isPad ? 84.0f : 20.0f),
                                 rejectBtn.frame.origin.y,
                                 acceptImg.size.width,
                                 acceptImg.size.height);
    acceptBtn.exclusiveTouch = YES;
    [acceptBtn addTarget:self
                  action:@selector(onYesBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [_naviCtrl.view addSubview:acceptBtn];

    return self;
}

// dealloc @ 0xb02bc — object-only (releases _policyView + _naviCtrl);
// ARC-omitted.

// @ 0xb032c — accept: play the decide SE, record acceptance, run the close
// fade.
- (void)onYesBtn:(id)sender {
    neEngine::playSystemSe(1);
    [UserSettingData saveIsPolicyAccepted:YES];
    [self startCloseAnimation];
}

// @ 0xb037c — reject: play the cancel SE and run the close fade.
- (void)onNoBtn:(id)sender {
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

// @ 0xb03ac — "詳細": lazily build the full-terms overlay (PolicyView in its
// own nav controller) and add it over the root scene view.
- (void)onDetailBtn:(id)sender {
    neEngine::playSystemSe(1);
    if (_policyView == nil) {
        PolicyView *pv = [[PolicyView alloc] init];
        _policyView = [[UINavigationController alloc] initWithRootViewController:pv];
        [_policyView.navigationBar setBackgroundImage:[UIImage imageNamed:@"set_agreement_navbar"]
                                        forBarMetrics:UIBarMetricsDefault];
    }
    UIViewController *root = neSceneManager::rootViewController();
    [root.view addSubview:_policyView.view];
}

// @ 0xb04e4 — detail back: play the cancel SE, hide the detail overlay, re-show
// the card.
- (void)onBackBtn:(id)sender {
    neEngine::playSystemSe(2);
    _detailView.hidden = YES;
    _topView.hidden = NO;
}

// @ 0xb0540 — fade the card in over 0.3 s.
- (void)startOpenAnimation {
    if (isAnimationing) {
        return;
    }
    isAnimationing = YES;
    self.view.alpha = 0;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xb0630
- (void)endOpenAnimation {
    isAnimationing = NO;
}

// @ 0xb0648 — fade the card out over 0.3 s.
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
    [UIView commitAnimations];
}

// @ 0xb0718 — pull the view, notify the root VC the policy modal closed, clear
// the guard. The binary calls -[root AcceptPolicyEndCallBack] directly;
// modelled as performSelector: (behaviourally identical for a no-arg selector).
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(AcceptPolicyEndCallBack)];
    isAnimationing = NO;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
