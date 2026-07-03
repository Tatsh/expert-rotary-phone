//
//  CustomAlertView.mm
//  pop'n rhythmin
//
//  See CustomAlertView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (dealloc @ 0x26880, setTitleColor: @ 0x268ac, setTextColor: @
//  0x268cc, setTitleFontSize: @ 0x268ec, setTextFontSize: @ 0x26940,
//  setOpenAnimeType: @ 0x26994, setCloseAnimeType: @ 0x269ac,
//  initWithType:... @ 0x269c4, initWithView:type:... @ 0x26a60,
//  initWithView:center:type:... @ 0x26abc, show @ 0x274fc, removeView @ 0x277b8,
//  endCloseAnimation @ 0x27ad0, clickedYesButton: @ 0x27ae0, clickedNoButton: @
//  0x27b34, customAlertView:clickedButtonAtIndex: @ 0x27b88).
//  Objective-C++ for the C++ engine bridge (neSceneManager:: / neEngine::).  ARC.
//
//  Byte-decoded constants (float hex -> decimal):
//    * gradient/scale transforms: 0.75 (0x3f400000), 1.25 (0x3fa00000), 1.0.
//    * open/close scale-bounce duration 0.25 (double 0x3fd0000000000000).
//    * open fade-in duration 0.75 (double 0x3fe8...), close fade-out 0.1
//      (double @ DAT_00027950 = 0x3fb99999a0000000).
//    * text colour gray 0.188 (0x3e40c0c1) rgba, title font 18.0 (0x41900000),
//      message font 14.0 (0x41600000), button font 13.0 (0x41500000),
//      minimumScaleFactor 0.5 (0x3f000000).
//    * background-art vertical nudge: info 0.0 (DAT_000274f4), gift 4.0
//      (DAT_000274f8 = 0x40800000).
//    * UIViewAnimationOptionAllowUserInteraction = 2, UIControlEventTouchUpInside
//      = 0x40, UITextAlignmentCenter = 1.
//  Title-label frames (x, y, w, 40): info (35, -2, 250), gift (40, 3, 187).
//  Button frames use the "info_icon" image's own size for w/h; button Y = 208
//  (info) / 121 (gift). X positions: single button centred (info 123 / gift 95);
//  with both buttons the "yes"/other sits right (info 205 / gift 160) and the
//  "no"/cancel shifts left (info 38 / gift 30).
//
//  NEON note: the background-art centre and the message CustomTextView frame are
//  produced by NEON vector math that spills through the stack (image .size halved,
//  added to the host-view half-extent, plus the type offset above). The scalar
//  constants are recovered exactly; the geometry is reconstructed best-effort and
//  flagged inline. The message text-view frame in particular arrives in spilled
//  float registers that the decompiler could not attribute — see the TODO below.
//

#import "CustomAlertView.h"

#import "CustomTextView.h"      // display-only message text view
#import "AppFont.h"             // AppMaruFontName (title/message), AppFontName (buttons)
#import "neEngineBridge.h"      // neSceneManager::rootViewController, neEngine::playSystemSe

@implementation CustomAlertView {
    UIImageView   *mBgImageView;    // +0x3c  background art; parents title/message/buttons
    UILabel       *_title;          // +0x40
    CustomTextView *_text;          // +0x44
    int            m_OpenAnimeType;  // +0x48
    int            m_CloseAnimeType; // +0x4c
}

@synthesize delegate = mDelegate;   // +0x38 (weak)

#pragma mark - Init

// @ 0x269c4 — install into the root scene view, centred on it.
- (instancetype)initWithType:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
             otherButtonTitle:(NSString *)otherButtonTitle {
    UIViewController *rootVC = neSceneManager::rootViewController();
    UIView *view = rootVC.view;
    CGPoint center = view ? view.center : CGPointZero;
    return [self initWithView:view
                       center:center
                         type:type
                        title:title
                      message:message
            cancelButtonTitle:cancelButtonTitle
              otherButtonTitle:otherButtonTitle];
}

// @ 0x26a60 — install into `view`, defaulting the centre (CGPointZero -> view centre).
- (instancetype)initWithView:(UIView *)view
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
             otherButtonTitle:(NSString *)otherButtonTitle {
    return [self initWithView:view
                       center:CGPointZero
                         type:type
                        title:title
                      message:message
            cancelButtonTitle:cancelButtonTitle
              otherButtonTitle:otherButtonTitle];
}

// @ 0x26abc — designated initializer.
- (instancetype)initWithView:(UIView *)view
                      center:(CGPoint)center
                        type:(CustomAlertViewType)type
                       title:(NSString *)title
                     message:(NSString *)message
           cancelButtonTitle:(NSString *)cancelButtonTitle
             otherButtonTitle:(NSString *)otherButtonTitle {
    // Full-host-view frame; this view is a transparent, interaction-enabled
    // overlay that hosts the background art. UIImageView disables interaction by
    // default, so it is re-enabled explicitly.
    CGRect hostFrame = view ? view.frame : CGRectZero;
    self = [super initWithFrame:hostFrame];
    self.userInteractionEnabled = YES;
    [view addSubview:self];

    self.delegate = nil;
    m_OpenAnimeType = CustomAlertViewAnimeTypeFade;
    m_CloseAnimeType = CustomAlertViewAnimeTypeFade;

    if (self == nil) {
        return self;
    }

    CGRect vframe = view ? view.frame : CGRectZero;

    // --- Background art ---
    NSString *bgName;
    if (type == CustomAlertViewTypeInfo) {
        bgName = @"info_bg";
    } else if (type == CustomAlertViewTypeGift) {
        bgName = @"gift_bg";
    } else {
        return self;   // unknown type: nothing to build.
    }
    UIImage *bgImage = [UIImage imageNamed:bgName];
    mBgImageView = [[UIImageView alloc] initWithImage:bgImage];

    // Size to the art; centre in the host view (gift art nudged down 4pt). When a
    // non-zero centre is supplied, position there instead.
    // NEON: origin = centre - size/2 with the type offset; recovered best-effort.
    CGSize bgSize = bgImage.size;
    CGFloat yOffset = (type == CustomAlertViewTypeGift) ? 4.0f : 0.0f;
    mBgImageView.frame = CGRectMake(0.0f, 0.0f, bgSize.width, bgSize.height);
    if (CGPointEqualToPoint(center, CGPointZero)) {
        mBgImageView.center = CGPointMake(CGRectGetWidth(vframe) * 0.5f,
                                          CGRectGetHeight(vframe) * 0.5f + yOffset);
    } else {
        mBgImageView.center = CGPointMake(center.x, center.y + yOffset);
    }
    mBgImageView.userInteractionEnabled = YES;
    [self addSubview:mBgImageView];
    mBgImageView.hidden = YES;

    // Type-dependent title-label frame.
    CGRect titleFrame = (type == CustomAlertViewTypeGift)
                            ? CGRectMake(40.0f, 3.0f, 187.0f, 40.0f)
                            : CGRectMake(35.0f, -2.0f, 250.0f, 40.0f);

    UIColor *textGray = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];

    // --- Title ---
    if (title != nil) {
        _title = [[UILabel alloc] init];
        _title.backgroundColor = [UIColor clearColor];
        _title.textColor = textGray;
        _title.highlightedTextColor = [UIColor whiteColor];
        _title.font = [UIFont fontWithName:AppMaruFontName() size:18.0f];
        _title.textAlignment = NSTextAlignmentCenter;
        _title.adjustsFontSizeToFitWidth = YES;
        _title.minimumScaleFactor = 0.5f;
        _title.frame = titleFrame;
        _title.text = title;
        [mBgImageView addSubview:_title];
    }

    // --- Message ---
    if (message != nil) {
        // TODO(NEON): the initWithFrame: rect arrives in spilled float registers
        // the decompiler could not recover; sized to the art content area
        // best-effort here.
        CGRect messageFrame = (type == CustomAlertViewTypeGift)
                                  ? CGRectMake(40.0f, 45.0f, 187.0f, 70.0f)
                                  : CGRectMake(35.0f, 40.0f, 250.0f, 160.0f);
        _text = [[CustomTextView alloc] initWithFrame:messageFrame];
        _text.backgroundColor = [UIColor clearColor];
        _text.textColor = textGray;
        _text.font = [UIFont fontWithName:AppMaruFontName() size:14.0f];
        _text.editable = NO;
        _text.text = message;
        [mBgImageView addSubview:_text];
    }

    // --- Buttons (both share the "info_icon" background art) ---
    UIImage *yesImage = [UIImage imageNamed:@"info_icon"];
    UIImage *noImage  = [UIImage imageNamed:@"info_icon"];
    CGSize yesSize = yesImage.size;
    CGSize noSize  = noImage.size;

    // Positions per type (see header comment for the decode).
    CGFloat buttonY  = (type == CustomAlertViewTypeGift) ? 121.0f : 208.0f;
    CGFloat yesX     = (type == CustomAlertViewTypeGift) ? 160.0f : 205.0f;   // both-buttons "yes"
    CGFloat centredX = (type == CustomAlertViewTypeGift) ?  95.0f : 123.0f;   // single-button centre
    CGFloat noLeftX  = (type == CustomAlertViewTypeGift) ?  30.0f :  38.0f;   // both-buttons "no"
    CGFloat noX      = centredX;

    if (otherButtonTitle != nil) {
        // With no cancel button, the "yes" button is centred instead.
        CGFloat x = (cancelButtonTitle == nil) ? centredX : yesX;
        UIButton *yesButton = [UIButton buttonWithType:UIButtonTypeCustom];
        yesButton.frame = CGRectMake(x, buttonY, yesSize.width, yesSize.height);
        yesButton.exclusiveTouch = YES;
        [yesButton setTitle:otherButtonTitle forState:UIControlStateNormal];
        yesButton.titleLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
        [yesButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [yesButton setBackgroundImage:yesImage forState:UIControlStateNormal];
        [mBgImageView addSubview:yesButton];
        [yesButton addTarget:self
                      action:@selector(clickedYesButton:)
            forControlEvents:UIControlEventTouchUpInside];
        // When a "yes" button exists the "no" button shifts to its left slot.
        noX = noLeftX;
    }

    if (cancelButtonTitle != nil) {
        UIButton *noButton = [UIButton buttonWithType:UIButtonTypeCustom];
        noButton.frame = CGRectMake(noX, buttonY, noSize.width, noSize.height);
        noButton.exclusiveTouch = YES;
        [noButton setTitle:cancelButtonTitle forState:UIControlStateNormal];
        noButton.titleLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
        [noButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [noButton setBackgroundImage:noImage forState:UIControlStateNormal];
        [mBgImageView addSubview:noButton];
        [noButton addTarget:self
                     action:@selector(clickedNoButton:)
           forControlEvents:UIControlEventTouchUpInside];
    }

    return self;
}

#pragma mark - Restyling

// @ 0x268ac
- (void)setTitleColor:(UIColor *)color {
    _title.textColor = color;
}

// @ 0x268cc
- (void)setTextColor:(UIColor *)color {
    _text.textColor = color;
}

// @ 0x268ec
- (void)setTitleFontSize:(CGFloat)size {
    _title.font = [UIFont fontWithName:AppMaruFontName() size:size];
}

// @ 0x26940
- (void)setTextFontSize:(CGFloat)size {
    _text.font = [UIFont fontWithName:AppMaruFontName() size:size];
}

// @ 0x26994 — clamp to a known animation kind (0..1).
- (void)setOpenAnimeType:(CustomAlertViewAnimeType)type {
    if (type > CustomAlertViewAnimeTypeScale) {
        return;
    }
    m_OpenAnimeType = (int)type;
}

// @ 0x269ac
- (void)setCloseAnimeType:(CustomAlertViewAnimeType)type {
    if (type > CustomAlertViewAnimeTypeScale) {
        return;
    }
    m_CloseAnimeType = (int)type;
}

#pragma mark - Show / dismiss

// @ 0x274fc
- (void)show {
    if (mBgImageView == nil) {
        return;
    }
    mBgImageView.hidden = NO;

    if (m_OpenAnimeType == CustomAlertViewAnimeTypeScale) {
        // Pop-open bounce: 0.75 -> 1.25 (0.25s) -> 1.0 (0.25s).
        mBgImageView.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self->mBgImageView.transform = CGAffineTransformMakeScale(1.25f, 1.25f);
        }
                         completion:^(BOOL finished) {
            [UIView animateWithDuration:0.25
                                  delay:0.0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self->mBgImageView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            }
                             completion:nil];
        }];
    } else {
        // Fade in over 0.75s.
        mBgImageView.alpha = 0.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.75];
        mBgImageView.alpha = 1.0f;
        [UIView commitAnimations];
    }
}

// @ 0x277b8
- (void)removeView {
    if (m_CloseAnimeType == CustomAlertViewAnimeTypeScale) {
        // Reverse bounce: 1.0 -> 1.25 (0.25s) -> settle, then remove.
        mBgImageView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self->mBgImageView.transform = CGAffineTransformMakeScale(1.25f, 1.25f);
        }
                         completion:^(BOOL finished) {
            [UIView animateWithDuration:0.25
                                  delay:0.0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self->mBgImageView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            }
                             completion:^(BOOL done) {
                [self endCloseAnimation];
            }];
        }];
    } else {
        // Fade out over 0.1s, then remove on stop.
        mBgImageView.alpha = 1.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.1];
        mBgImageView.alpha = 0.0f;
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        [UIView commitAnimations];
    }
}

// @ 0x27ad0 — animationDidStop / bounce-completion teardown.
- (void)endCloseAnimation {
    [self removeFromSuperview];
}

#pragma mark - Buttons

// @ 0x27ae0 — "yes" / other button (index 1).
- (void)clickedYesButton:(id)sender {
    neEngine::playSystemSe(1);
    [self removeView];
    [self.delegate customAlertView:self clickedButtonAtIndex:1];
}

// @ 0x27b34 — "no" / cancel button (index 0).
- (void)clickedNoButton:(id)sender {
    neEngine::playSystemSe(2);
    [self removeView];
    [self.delegate customAlertView:self clickedButtonAtIndex:0];
}

// @ 0x27b88 — empty default implementation of the delegate callback (no-op).
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
}

@end
