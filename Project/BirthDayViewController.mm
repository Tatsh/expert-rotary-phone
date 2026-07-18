//
//  BirthDayViewController.mm
//  pop'n rhythmin
//
//  See BirthDayViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. This file covers the cancel / close path; the
//  geometry-heavy -init and the open path (which depend on the custom
//  YearAndMonthPicker) are a separate piece. It is Objective-C++ so it can
//  reach the neEngine sound bridge.
//

#import "BirthDayViewController.h"

#import <QuartzCore/QuartzCore.h> // CAGradientLayer

#import "UserSettingData.h"
#import "YearAndMonthPicker.h"
#import "neEngineBridge.h" // neEngine::playSystemSe

// The modal open/close (fade) transition duration, shared by
// startOpenAnimation / startCloseAnimation.
static const NSTimeInterval kModalAnimationDuration = 0.5;

@implementation BirthDayViewController

// Plain assign accessors (the delegate is not retained). Ghidra: delegate
// getter @ 0x850c4 / setDelegate: @ 0x850d4 (synthesized).
// @complete
@synthesize delegate = _delegate;

// @ 0x8396c — build the whole age-gate: a full-screen touch blocker, a rounded
// gradient- bordered info panel (instruction text + OK button) centred on
// screen, and a second, initially-hidden gradient-bordered "picker" panel
// (title + YearAndMonthPicker + Cancel/ Decide). The two panels swap places
// when OK is tapped (see -onOkBtn:). All frames, the 3-stop border gradient and
// the OK-button placement are decoded from the NEON geometry.
// @complete
- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    const BOOL isPad = neSceneManager::isPadDisplay(); // DAT_00187b84
    UIViewController *root = neSceneManager::rootViewController();

    // Fully transparent backdrop; the open animation fades it up to 50% black.
    self.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];

    // Info-panel size: iPhone is fixed; the iPad layout grew between the iOS 6
    // and iOS 7 builds.
    CGFloat infoW, infoH;
    if (!isPad) {
        infoW = 286.0f; // 0x438f0000
        infoH = 342.0f; // 0x43ab0000
    } else if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f) {
        infoW = 371.8f; // 0x43b9e666
        infoH = 444.6f; // 0x43de4ccd
    } else {
        infoW = 429.0f; // 0x43d68000
        infoH = 513.0f; // 0x44004000
    }

    // Screen bounds come from the shell's root view (the panels are centred on
    // it).
    CGRect screen = root.view ? root.view.frame : CGRectZero;
    const CGFloat screenW = screen.size.width;
    const CGFloat screenH = screen.size.height;

    // The 3-stop border gradient (same for both panels), 0-255 colours from the
    // binary.
    UIColor *g0 = [UIColor colorWithRed:129 / 255.0f
                                  green:255 / 255.0f
                                   blue:236 / 255.0f
                                  alpha:1.0f];
    UIColor *g1 = [UIColor colorWithRed:255 / 255.0f
                                  green:232 / 255.0f
                                   blue:104 / 255.0f
                                  alpha:1.0f];
    UIColor *g2 = [UIColor colorWithRed:254 / 255.0f
                                  green:162 / 255.0f
                                   blue:174 / 255.0f
                                  alpha:1.0f];

    // --- full-screen transparent touch blocker (owned by the hierarchy) ---
    _dummyView = [[UIView alloc] initWithFrame:root.view.frame];
    _dummyView.backgroundColor = [UIColor clearColor];
    [root.view addSubview:_dummyView];

    // --- outer gradient border panel: a 3 px frame around the info panel,
    // rounded + clipped ---
    _borderView = [[UIView alloc] init];
    _borderView.frame = CGRectMake(0, 0, infoW + 6.0f, infoH + 6.0f);
    _borderView.clipsToBounds = YES;
    _borderView.layer.cornerRadius = 5.0f;
    _borderView.center = CGPointMake(screenW * 0.5f, screenH * 0.5f);
    {
        CAGradientLayer *grad = [CAGradientLayer layer];
        grad.frame = CGRectMake(0, 0, screenW, screenH); // over-sized, clipped to the border
        grad.colors = @[ (id)g0.CGColor, (id)g1.CGColor, (id)g2.CGColor ];
        [_borderView.layer insertSublayer:grad atIndex:0];
    }
    [root.view addSubview:_borderView];

    // --- info panel inside the border (3 px inset), rounded + patterned
    // background ---
    _infoView = [[UIView alloc] initWithFrame:CGRectMake(3.0f, 3.0f, infoW, infoH)];
    _infoView.userInteractionEnabled = YES;
    _infoView.clipsToBounds = YES;
    _infoView.layer.cornerRadius = 2.5f;
    _infoView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    [_borderView addSubview:_infoView];

    // --- non-editable instruction text (a scroll view; the OK button lives in
    // its content) ---
    UITextView *textView =
        [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 10.0f, infoW - 20.0f, infoH - 20.0f)];
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.text = @"◆年齢確認◆\n\n有料サービスのご利用にあたり、生年月の設定をお願いしてお"
                    @"ります。\n"
                     "ご入力頂いた情報は課金上限の設定にのみ使用いたします。\n\n"
                     "[15歳以下]\n 5000円/月制限\n[18歳未満]\n 10000円/月制限\n\n"
                     "[18歳以上]\n 無制限\n\n\n"
                     "※一度ご入力頂いた情報は変更できません。\n"
                     "また、キャンセルした場合は、15歳以下と同等の課金上限となります。";
    textView.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:15.0f];
    textView.userInteractionEnabled = YES;
    [_infoView addSubview:textView];
    [textView setContentSize:CGSizeMake(infoW - 20.0f, 500.0f)];

    // Modern layouts (iPad, or iPhone on iOS 7+) pad the text with trailing blank
    // lines and use a larger OK-button offset; the legacy iPhone (< iOS 7) layout
    // does neither.
    const BOOL legacyPhone =
        (!isPad && [[[UIDevice currentDevice] systemVersion] floatValue] < 7.0f);
    CGFloat okVOffset;
    if (legacyPhone) {
        okVOffset = 15.0f;
    } else {
        textView.text = [textView.text stringByAppendingString:@"\n\n\n\n\n"];
        okVOffset = 110.0f; // DAT_000842a0
    }

    // --- OK button, centred in the text width, sitting at the bottom of the
    // scroll content ---
    UIButton *okButton = [[UIButton alloc] init];
    UIImage *okImg = [UIImage imageNamed:@"birthday_ok"];
    CGSize okSize = okImg ? okImg.size : CGSizeZero;
    CGFloat okX = ((infoW - 20.0f) - okSize.width) * 0.5f;
    CGFloat okY = (textView.contentSize.height - okSize.height) - okVOffset;
    CGFloat okMinY = _infoView.frame.size.height - okSize.height;
    if (okY < okMinY) {
        okY = okMinY; // never let it ride above the first fold
    }
    if (isPad) {
        okY += -30.0f;
    }
    okButton.frame = CGRectMake(okX, okY, okSize.width, okSize.height);
    okButton.exclusiveTouch = YES;
    [okButton setBackgroundImage:okImg forState:UIControlStateNormal];
    [okButton addTarget:self
                  action:@selector(onOkBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [textView addSubview:okButton];

    // --- picker sub-panel: always iPhone-sized (286x341), hidden until OK is
    // tapped ---
    const CGRect subBase = CGRectMake(0, 0, 286.0f, 341.0f); // 0x438f0000 x 0x43aa8000

    _subBorderView = [[UIView alloc] init];
    _subBorderView.frame = CGRectMake(
        subBase.origin.x, subBase.origin.y, subBase.size.width + 6.0f, subBase.size.height + 6.0f);
    _subBorderView.clipsToBounds = YES;
    _subBorderView.layer.cornerRadius = 5.0f;
    _subBorderView.hidden = YES;
    _subBorderView.center = CGPointMake(screenW * 0.5f, screenH * 0.5f);
    {
        CAGradientLayer *grad = [CAGradientLayer layer];
        grad.frame = CGRectMake(0, 0, screenW, screenH);
        grad.colors = @[ (id)g0.CGColor, (id)g1.CGColor, (id)g2.CGColor ];
        [_subBorderView.layer insertSublayer:grad atIndex:0];
    }
    [root.view addSubview:_subBorderView];

    // Content host inside the sub-border (3 px inset). Created +1-owned (released
    // in -dealloc).
    _subView = [[UIView alloc] initWithFrame:CGRectMake(subBase.origin.x + 3.0f,
                                                        subBase.origin.y + 3.0f,
                                                        subBase.size.width,
                                                        subBase.size.height)];
    _subView.clipsToBounds = YES;
    _subView.layer.cornerRadius = 2.5f;
    _subView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    [_subBorderView addSubview:_subView];

    // The year/month wheel (also +1-owned; released in -dealloc).
    _selectDate = [[YearAndMonthPicker alloc] init];
    _selectDate.frame = CGRectMake(20.0f, 55.0f, 246.0f, 270.0f);
    [_subView addSubview:_selectDate];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 14.0f, 286.0f, 36.0f)];
    title.text = @"生年月を設定して下さい";
    title.textAlignment = NSTextAlignmentCenter; // 1
    title.backgroundColor = [UIColor clearColor];
    [_subView addSubview:title];

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect]; // raw type 1
    cancelBtn.frame = CGRectMake(14.0f, 280.0f, 121.0f, 47.0f);
    [cancelBtn setBackgroundImage:[UIImage imageNamed:@"birthday_cancel.png"]
                         forState:UIControlStateNormal];
    [cancelBtn addTarget:self
                  action:@selector(onCancelBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.exclusiveTouch = YES;
    [_subView addSubview:cancelBtn];

    UIButton *decideBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    decideBtn.frame = CGRectMake(151.0f, 280.0f, 121.0f, 47.0f);
    [decideBtn setBackgroundImage:[UIImage imageNamed:@"birthday_set.png"]
                         forState:UIControlStateNormal];
    [decideBtn addTarget:self
                  action:@selector(onDecideBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    decideBtn.exclusiveTouch = YES;
    [_subView addSubview:decideBtn];

    return self;
}

// @ 0x84c30 — cancel: play the cancel SE (slot 2), record that the gate was
// dismissed without a birthday, then slide the panel away.
// @complete
- (void)onCancelBtn:(id)sender {
    neEngine::playSystemSe(2);
    [UserSettingData saveIsBirthDayCanceled:YES];
    [self startCloseAnimation];
}

// @ 0x84af0 — decide: play the confirm SE (slot 1), turn the picked year/month
// into a concrete date (the 15th of that month at noon, parsed through a fixed
// formatter so the day/time are pinned), persist it as the birthday, clear the
// cancel flag, then close.
// @complete
- (void)onDecideBtn:(id)sender {
    neEngine::playSystemSe(1);

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    // Format string is "yyyy/MM/dd HH:mm:ss" per the __NSConstantString at the
    // setDateFormat: site (@ 0x84b62; string bytes @ 0x1065c5), not hyphen-dashed.
    fmt.dateFormat = @"yyyy/MM/dd HH:mm:ss";
    // Likewise the format literal is "%d/%02d/15 12:00:00" (@ 0x84bc4; string
    // bytes @ 0x10869e): slash separators, day pinned to 15, noon.
    NSString *str =
        [NSString stringWithFormat:@"%d/%02d/15 12:00:00", _selectDate.year, _selectDate.month];
    NSDate *date = [fmt dateFromString:str];

    [UserSettingData saveBirthDay:date];
    [UserSettingData saveIsBirthDayCanceled:NO];
    [self startCloseAnimation];
}

// @ 0x84c80 — reveal: start the panel off-screen (above) with a transparent
// backdrop, then animate it down to its rest frame while fading the dim
// backdrop up to 50%. Guarded against overlapping animations; -endOpenAnimation
// clears the guard. (The off-screen start frame is NEON-spilled in the binary;
// the panel begins one panel-height above its resting Y.)
// @complete
- (void)startOpenAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;

    CGRect f = (_borderView != nil) ? _borderView.frame : CGRectZero;
    _borderView.frame = CGRectMake(f.origin.x, -f.size.height, f.size.width, f.size.height);
    self.view.backgroundColor = [self.view.backgroundColor colorWithAlphaComponent:0.0f];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kModalAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    _borderView.frame = f;
    self.view.backgroundColor = [self.view.backgroundColor colorWithAlphaComponent:0.5f];
    [UIView commitAnimations];
}

// @ 0x848d4 — OK tapped: reveal the picker. Stage the picker sub-panel above the
// screen, unhide it, then animate the info panel down off the bottom while the
// sub-panel slides down into its resting place. Guarded.
// Verified against the disassembly: the axis is VERTICAL. The sub-panel is
// staged at (sub.x, -sub.height) (@ 0x84958-0x84984: y <- -sub.height (vneg),
// x/w/h kept), the info panel animates to (border.x, root.view.height)
// (@ 0x84a94: y <- root.view.frame.size.height, so it drops off the bottom), and
// the sub-panel animates back to its own captured resting frame (@ 0x84aac: y <-
// its original origin.y in s16). Duration 0.5 (0x3fe0000000000000).
// @complete
- (void)onOkBtn:(id)sender {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;

    CGRect subRest = (_subBorderView != nil) ? _subBorderView.frame : CGRectZero;
    CGRect borderRest = (_borderView != nil) ? _borderView.frame : CGRectZero;

    UIViewController *root = neSceneManager::rootViewController();
    const CGFloat screenH = root.view ? root.view.frame.size.height : 0.0f;

    // Stage the sub-panel one panel-height above the screen, then show it.
    _subBorderView.frame =
        CGRectMake(subRest.origin.x, -subRest.size.height, subRest.size.width, subRest.size.height);
    _subBorderView.hidden = NO;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kModalAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    // Info panel drops off the bottom; sub-panel slides down into place.
    _borderView.frame =
        CGRectMake(borderRest.origin.x, screenH, borderRest.size.width, borderRest.size.height);
    _subBorderView.frame = subRest;
    [UIView commitAnimations];
}

// @ 0x84e84 — slide the inner panel off-screen (0.5 s) and fade the dimmed
// backdrop to transparent, with -endCloseAnimation as the did-stop callback.
// Guarded so overlapping animations are ignored. (The exact off-screen frame is
// NEON-spilled in the binary; the panel is moved up by its own height, the
// reverse of the open slide.)
// @complete
- (void)startCloseAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;

    CGRect f = (_subBorderView != nil) ? _subBorderView.frame : CGRectZero;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kModalAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    _subBorderView.frame = CGRectMake(f.origin.x, -f.size.height, f.size.width, f.size.height);
    self.view.backgroundColor = [self.view.backgroundColor colorWithAlphaComponent:0.0f];
    [UIView commitAnimations];
}

// @ 0x84fec — close finished: pull the whole VC view out of the hierarchy and
// tell the delegate the gate is done (so the purchase flow can re-check the
// spending limit).
// @complete
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    if ([_delegate respondsToSelector:@selector(birthDayViewClose)]) {
        [_delegate performSelector:@selector(birthDayViewClose)];
    }
    m_IsAnimationing = NO;
}

// @ 0x84e70 — open finished: just clear the animating guard.
// @complete
- (void)endOpenAnimation {
    m_IsAnimationing = NO;
}

// viewDidLoad @ 0x8506c — super-only override, omitted.
// didReceiveMemoryWarning @ 0x85098 — super-only override, omitted.

// dealloc @ 0x847e8 — ARC-omitted (object ivars only: unhooks the panel
// subviews from the hierarchy and releases the picker; ARC handles this).

@end
