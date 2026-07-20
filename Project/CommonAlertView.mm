//
//  CommonAlertView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): resolves the root scene view via the C++ scene manager.
//
//  The initializer (Ghidra @ 0x4a350) is a large view-builder that branches on
//  the iPad vs iPhone idiom (neSceneManager::isPadDisplay()). The hierarchy,
//  colours and idiom-dependent card sizes are reconstructed below; a few inner
//  sub-frames (content / message / button-row) are laid out by the binary from
//  constant tables (DAT_0004a7xx) and are sized to their superview here.
//

#import "CommonAlertView.h"

#import <QuartzCore/QuartzCore.h>

#import "AppFont.h"
#import "CustomTextView.h"
#import "neEngineBridge.h"

@implementation CommonAlertView {
    UILabel *_titleView;
    CustomTextView *_messageView;
    UIView *_dummyView;   // transparent backdrop that blocks touches
    BOOL _isAnimationing; // guards the open/close animation (Ghidra ivar
                          // _isAnimationing)
}
// title/message/delegate are @property-backed (accessors annotated in the
// header).

// @ 0x4a308 — designated UIView initializer: chain to super and clear the
// animation guard.
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _isAnimationing = NO;
    }
    return self;
}

// dealloc @ 0x4b474 — ARC-omitted: the binary only nils the copy'd
// title/message (via setTitle:/setMessage:) and releases object ivars before
// [super dealloc]; nothing to cancel.

// @ 0x4a350
//
// Verified against the disassembly's NEON geometry. Every frame is `uiScale *
// constant + idiom-offset`, where uiScale (d8/`uVar25`) is DAT_0004a7ac/a7b0 =
// 0.5 on phone, 1.0 on pad; the two additive idiom offsets are DAT_0004a7b4/a7b8
// = {50.0 phone, 0.0 pad} (call it offX) and DAT_0004b340/b344 = {20.0 phone,
// 0.0 pad} (offY). Constant table (all byte-read): 430.0 (card w, DAT_0004a794),
// 325.0 (card h, DAT_0004a798), 350.0 / 190.0 (content w/h, DAT_0004a79c/a7a0),
// 40.0 (content x=y, DAT_0004a7a4), 50.0 (message inset, DAT_0004a7a8), 6.0
// (border thickness, 0x40c00000), 3.0 (inset, 0x40400000), 5.0 / 2.5 corner
// radii (0x40a00000 / 0x40200000), message font 12/18 (DAT_0004b45c/b460), the
// button-label x offset 10/14 (DAT_0004b464/b468), and the button-row base
// 257.0 x 84.0 (DAT_0004b46c/b470). The message / title / button / button-row
// sub-frames the binary derives from runtime .frame/.size/.center calls are
// reproduced as such below.
- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                     delegate:(id<CommonAlertViewDelegate>)delegate
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles {
    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGFloat uiScale = isPad ? 1.0f : 0.5f; // DAT_0004a7ac / DAT_0004a7b0
    const CGFloat offX = isPad ? 0.0f : 50.0f;   // DAT_0004a7b8 / DAT_0004a7b4
    const CGFloat offY = isPad ? 0.0f : 20.0f;   // DAT_0004b344 / DAT_0004b340

    // Card size: scale*430 + offX + 6 (width), scale*325 + offY + 6 (height).
    const CGFloat cardW = uiScale * 430.0f + offX + 6.0f;
    const CGFloat cardH = uiScale * 325.0f + offY + 6.0f;
    self = [super initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    if (self == nil) {
        return nil;
    }
    self.message = message;
    self.title = title;
    _delegate = delegate;

    // Rounded container with a 3-stop vertical gradient border/background.
    UIView *container = [[UIView alloc] init];
    container.frame = self.bounds;
    container.clipsToBounds = YES;
    container.layer.cornerRadius = 5.0;
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.505f green:1.0f blue:0.925f alpha:1.0f].CGColor,
        (id)[UIColor colorWithRed:1.0f green:0.910f blue:0.408f alpha:1.0f].CGColor,
        (id)[UIColor colorWithRed:0.996f green:0.635f blue:0.683f alpha:1.0f].CGColor,
    ];
    [container.layer insertSublayer:gradient atIndex:0];

    // Inner panel: patterned "back_bg_st" background, rounded corners.
    UIView *panel = [[UIView alloc] init];
    panel.frame = CGRectInset(container.bounds, 3, 3);
    panel.clipsToBounds = YES;
    panel.layer.cornerRadius = 2.5;
    panel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    [container addSubview:panel];
    [self addSubview:container];

    // Content area (holds title + message), rounded, tinted. Frame from the
    // table: origin (scale*40, scale*40), size (scale*350 + offX, scale*190 +
    // offY).
    const CGFloat contentX = uiScale * 40.0f;
    const CGFloat contentW = uiScale * 350.0f + offX;
    const CGFloat contentH = uiScale * 190.0f + offY;
    UIView *content =
        [[UIView alloc] initWithFrame:CGRectMake(contentX, contentX, contentW, contentH)];
    content.backgroundColor = [UIColor colorWithRed:0.917f green:0.882f blue:0.882f alpha:1.0f];
    content.layer.cornerRadius = 5.0;

    // Message: a non-editable CustomTextView. Frame is the content frame shrunk
    // by scale*50 on width and height (Ghidra: content.frame - scale*50).
    const CGFloat msgInset = uiScale * 50.0f;
    _messageView =
        [[CustomTextView alloc] initWithFrame:CGRectMake(content.frame.origin.x,
                                                         content.frame.origin.y,
                                                         content.frame.size.width - msgInset,
                                                         content.frame.size.height - msgInset)];
    _messageView.backgroundColor = [UIColor clearColor];
    _messageView.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
    _messageView.font = [UIFont fontWithName:AppMaruFontName()
                                        size:(neSceneManager::isPadDisplay() ? 18.0 : 12.0)];
    _messageView.textAlignment = NSTextAlignmentCenter;
    _messageView.editable = NO;

    // With a title, keep the message as-is; otherwise the message is the body.
    if (title.length != 0) {
        _titleView = [[UILabel alloc] init];
        _titleView.backgroundColor = [UIColor clearColor];
        _titleView.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        _titleView.highlightedTextColor = [UIColor whiteColor];
        _titleView.textAlignment = NSTextAlignmentCenter;
        _titleView.adjustsFontSizeToFitWidth = YES;
        _titleView.minimumScaleFactor = 0.5;
        [content addSubview:_titleView];
    } else {
        _messageView.text = message;
    }
    [content addSubview:_messageView];
    [panel addSubview:content];

    // Buttons: "other" (index 1, onYesButton) uses btn_yes_frame; "cancel"
    // (index 0, onNoButton) uses btn_no_frame. Their labels are the passed
    // titles.
    UIButton *otherButton = [self makeButtonWithTitle:otherButtonTitles
                                           background:@"btn_yes_frame"
                                               action:@selector(onYesButton)];
    UIButton *cancelButton = [self makeButtonWithTitle:cancelButtonTitle
                                            background:@"btn_no_frame"
                                                action:@selector(onNoButton)];

    // Button row across the space below the content area, spanning the panel
    // width (panel = container inset by 3). The binary derives these frames from
    // runtime .frame/.size/.center calls; reproduced here so the buttons sit
    // bottom-centre instead of collapsing to the panel origin (an un-framed row).
    const CGFloat panelW = cardW - 6.0f;
    const CGFloat panelH = cardH - 6.0f;
    const CGFloat rowTop = contentX + contentH; // just below the content area
    UIView *buttonRow =
        [[UIView alloc] initWithFrame:CGRectMake(0, rowTop, panelW, panelH - rowTop)];
    buttonRow.backgroundColor = [UIColor clearColor];
    const CGFloat rowMidY = (panelH - rowTop) * 0.5f;
    if (cancelButtonTitle == nil) {
        otherButton.center = CGPointMake(panelW * 0.5f, rowMidY); // one centred button
        [buttonRow addSubview:otherButton];
    } else if (otherButtonTitles == nil) {
        cancelButton.center = CGPointMake(panelW * 0.5f, rowMidY);
        [buttonRow addSubview:cancelButton];
    } else {
        // Two buttons side by side about the centre: "other" (yes) left, cancel right.
        const CGFloat gap = panelW * 0.02f;
        otherButton.center =
            CGPointMake(panelW * 0.5f - otherButton.bounds.size.width * 0.5f - gap, rowMidY);
        cancelButton.center =
            CGPointMake(panelW * 0.5f + cancelButton.bounds.size.width * 0.5f + gap, rowMidY);
        [buttonRow addSubview:otherButton];
        [buttonRow addSubview:cancelButton];
    }
    [panel addSubview:buttonRow];

    return self;
}

// Build a background-image button with a centered label (shared by both
// buttons).
- (UIButton *)makeButtonWithTitle:(NSString *)title
                       background:(NSString *)imageName
                           action:(SEL)action {
    UIImage *bg = [UIImage imageNamed:imageName];
    UIButton *button =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, bg.size.width, bg.size.height)];
    button.exclusiveTouch = YES;
    [button setBackgroundImage:bg forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.text = title;
    // The binary tints the label (light blue) before positioning it; without a
    // colour it defaults to black on the dark button frame and reads as "no text".
    label.textColor = [UIColor colorWithRed:0.345f green:0.482f blue:1.0f alpha:1.0f];
    [label sizeToFit];
    label.center = CGPointMake(bg.size.width * 0.5f, neSceneManager::isPadDisplay() ? 24.0 : 12.0);
    [button addSubview:label];
    return button;
}

// @ 0x4b4cc
- (void)show {
    _titleView.text = self.title;
    _messageView.text = self.message;

    UIView *rootView = (neSceneManager::rootViewController()).view;
    self.center =
        CGPointMake(CGRectGetWidth(rootView.frame) * 0.5f, CGRectGetHeight(rootView.frame) * 0.5f);

    // Transparent backdrop that swallows touches behind the alert.
    _dummyView = [[UIView alloc] initWithFrame:rootView.frame];
    _dummyView.backgroundColor = [UIColor clearColor];
    [rootView addSubview:_dummyView];
    [rootView addSubview:self];
    [rootView bringSubviewToFront:_dummyView];
    [rootView bringSubviewToFront:self];

    [self startOpenAnimation];
}

// @ 0x4bb9c
- (BOOL)isVisible {
    return !self.isHidden;
}

#pragma mark - Buttons

// @ 0x4b970 — "other"/yes button: play the decide SE, then route through the
// click handler.
- (void)onYesButton {
    neEngine::playSystemSe(1); // Ghidra: NESceneManager_shared();
                               // SysSePlayIntoSlot(&g_pNeSceneManager, 1)
    [self commonAlertView:self clickedButtonAtIndex:1];
}

// @ 0x4b9a4 — "cancel"/no button: play the cancel SE, then route through the
// click handler.
- (void)onNoButton {
    neEngine::playSystemSe(2); // Ghidra: NESceneManager_shared();
                               // SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    [self commonAlertView:self clickedButtonAtIndex:0];
}

// @ 0x4b9d8 — the view is its own button target: run the fade-out close
// animation, then (once) notify the real delegate with the button index and
// tear the alert down. Guarded by _isAnimationing so a second tap during the
// close is ignored.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView animateWithDuration:0.3 // DAT_0004baa0 (0.3f)
        delay:0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{ // @ 0x4baa8 — animations block
          self.alpha = 0.0f;
        }
        completion:^(BOOL finished) { // @ 0x4bad0 — completion block
          self->_isAnimationing = NO;
          if ([self->_delegate
                  respondsToSelector:@selector(commonAlertView:clickedButtonAtIndex:)]) {
              [self->_delegate commonAlertView:alertView clickedButtonAtIndex:index];
          }
          [self dismiss]; // removes _dummyView backdrop + self
        }];
}

// @ 0x4b718 — the "pop open" bounce: snap to 75%, overshoot to 125% over 0.2s,
// then settle back to 100% over 0.2s. Guarded so it only runs once at a time.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
    [UIView animateWithDuration:0.2
        delay:0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{ // @ 0x4b800 — overshoot animation block
          self.transform = CGAffineTransformMakeScale(1.25f, 1.25f); // overshoot
        }
        completion:^(BOOL finished) { // @ 0x4b848 — completion: start the settle
          [UIView animateWithDuration:0.2
              delay:0
              options:UIViewAnimationOptionAllowUserInteraction
              animations:^{ // @ 0x4b8f0 — settle animation block
                self.transform = CGAffineTransformMakeScale(1.0f, 1.0f); // settle
              }
              completion:^(BOOL done) {
                self->_isAnimationing = NO;
              }];
        }];
}

- (void)dismiss {
    [_dummyView removeFromSuperview];
    [self removeFromSuperview];
}

@end
