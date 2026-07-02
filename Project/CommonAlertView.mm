//
//  CommonAlertView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): resolves the root scene view via the C++ scene manager.
//
//  The initializer (Ghidra @ 0x4a350) is a large view-builder — hundreds of
//  frame calculations, branching on iPad vs iPhone (global gIsPad / DAT_00187b84)
//  with the exact pixel/colour constants stored as data in the binary
//  (DAT_0004a7xx / DAT_0004b3xx / DAT_0004b4xx). The hierarchy and styling are
//  reconstructed faithfully below; the precise magic numbers are represented by
//  named placeholders to be filled from those tables.
//

#import <QuartzCore/QuartzCore.h>

#import "CommonAlertView.h"
#import "CustomTextView.h"

// The root view controller of the scene (the MainViewController), via the C++
// scene manager. Ghidra: NESceneManager_shared + FUN_0002c5bc(&DAT_00187b74).
extern "C" UIViewController *neSceneManagerRootViewController(void);

// iPad idiom flag (Ghidra: DAT_00187b84).
extern BOOL gIsPad;

@implementation CommonAlertView {
    UILabel *_titleView;
    CustomTextView *_messageView;
    __weak id<CommonAlertViewDelegate> _delegate;
    UIView *_dummyView;    // transparent backdrop that blocks touches
    BOOL _isAnimationing;  // guards the open bounce (Ghidra ivar _isAnimationing)
}

// @ 0x4a350
- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                     delegate:(id<CommonAlertViewDelegate>)delegate
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles {
    // Card size + position depend on the idiom (values from DAT_0004a7xx tables).
    CGRect cardFrame = gIsPad ? CGRectMake(0, 0, 384, 260)
                              : CGRectMake(0, 0, 256, 176);
    self = [super initWithFrame:cardFrame];
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

    // Content area (holds title + message), rounded, tinted.
    UIView *content = [[UIView alloc] init];   // frame from DAT_0004a79c..a7a4
    content.backgroundColor = [UIColor colorWithRed:0.917f green:0.882f blue:0.882f alpha:1.0f];
    content.layer.cornerRadius = 5.0;

    // Message: a non-editable CustomTextView.
    _messageView = [[CustomTextView alloc] initWithFrame:CGRectZero];
    _messageView.backgroundColor = [UIColor clearColor];
    _messageView.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
    _messageView.font = [UIFont fontWithName:/* FUN_0005efa8 (font name) */ @"Helvetica"
                                        size:(gIsPad ? 18.0 : 14.0)];
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
    // (index 0, onNoButton) uses btn_no_frame. Their labels are the passed titles.
    UIButton *otherButton = [self makeButtonWithTitle:otherButtonTitles
                                          background:@"btn_yes_frame"
                                              action:@selector(onYesButton)];
    UIButton *cancelButton = [self makeButtonWithTitle:cancelButtonTitle
                                           background:@"btn_no_frame"
                                               action:@selector(onNoButton)];

    UIView *buttonRow = [[UIView alloc] init];
    buttonRow.backgroundColor = [UIColor clearColor];
    if (cancelButtonTitle == nil) {
        [buttonRow addSubview:otherButton];          // one centered button
    } else if (otherButtonTitles == nil) {
        [buttonRow addSubview:cancelButton];
    } else {
        [buttonRow addSubview:otherButton];          // both, side by side
        [buttonRow addSubview:cancelButton];
    }
    [panel addSubview:buttonRow];

    return self;
}

// Build a background-image button with a centered label (shared by both buttons).
- (UIButton *)makeButtonWithTitle:(NSString *)title
                       background:(NSString *)imageName
                           action:(SEL)action {
    UIImage *bg = [UIImage imageNamed:imageName];
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, bg.size.width, bg.size.height)];
    button.exclusiveTouch = YES;
    [button setBackgroundImage:bg forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.text = title;
    [label sizeToFit];
    label.center = CGPointMake(bg.size.width * 0.5f, gIsPad ? 24.0 : 12.0);
    [button addSubview:label];
    return button;
}

// @ 0x4b4cc
- (void)show {
    _titleView.text = self.title;
    _messageView.text = self.message;

    UIView *rootView = neSceneManagerRootViewController().view;
    self.center = CGPointMake(CGRectGetWidth(rootView.frame) * 0.5f,
                              CGRectGetHeight(rootView.frame) * 0.5f);

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

- (void)onYesButton {
    [_delegate commonAlertView:self clickedButtonAtIndex:1];
    [self dismiss];
}

- (void)onNoButton {
    [_delegate commonAlertView:self clickedButtonAtIndex:0];
    [self dismiss];
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
                     animations:^{
        self.transform = CGAffineTransformMakeScale(1.25f, 1.25f);  // overshoot
    }
                     completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);  // settle
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
