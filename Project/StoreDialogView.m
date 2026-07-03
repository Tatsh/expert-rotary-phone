//
//  StoreDialogView.m
//  pop'n rhythmin
//
//  See StoreDialogView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  Byte-decoded constants (all little-endian float hex verified against the binary):
//    * card layer: cornerRadius 8.0 (0x41000000), borderWidth 2.0 (0x40000000),
//      shadowRadius 8.0 (0x41000000), shadowOffset CGSizeZero, shadowOpacity 0.5 (0x3f000000),
//      shouldRasterize YES; backgroundColor colorWithWhite:0 alpha:0.7 (0x3f333333).
//    * spinner box 40x40 (0x42200000); style 0 = WhiteLarge; center = (w/2, trunc(h * 0.2)),
//      0.2 = DAT_00041c44 (0x3e4ccccd).
//    * label frame (0, 0, w-30, 24) — 30.0 = 0xc1f00000, 24.0 = 0x41c00000; clear bg, white text,
//      center aligned, 1 line, font DFSoGei @18.0 (0x41900000).
//    * progress (Bar, style 1) frame (30, trunc(h/2)+10, w-60, 11) — 30.0 = 0x41f00000,
//      -60.0 = DAT_00041db8 (0xc2700000), 11.0 = 0x41300000; initial progress 0.3 (0x3e99999a).
//    * abort button: image "store_btn_abort.png" stretchable(6,6); custom type; frame (0,0,140,imgH)
//      140.0 = 0x430c0000; white title, font DFSoGei @20.0 (0x41a00000), title shadow (0,-1.0)
//      (0xbf800000) color white/alpha 0.6 (0x3f19999a); title "中止" (UTF-16 0x4e2d 0x6b62);
//      center = (w/2, trunc(h * 0.83)), 0.83 = DAT_00041dbc (0x3f547ae1); event 0x40 = TouchUpInside.
//    * -layout: label offset ±10.0 (0x41200000 / 0xc1200000).
//
//  NEON note: every subview frame/center is computed with packed NEON float vectors that spill
//  through the stack; the size lanes and the constants above are byte-exact, the origin/center
//  geometry is reconstructed best-effort. Where the binary truncates a lane with vcvt.s32.f32
//  the (int) cast below reproduces it. getFontNameDFSoGei() == AppFontName().
//
//  The compiler-artifact .cxx_construct/.cxx_destruct (if any) are not reconstructed.
//

#import "StoreDialogView.h"

#import <QuartzCore/QuartzCore.h>   // CALayer corner/shadow/border styling

#import "AppFont.h"                 // AppFontName() -> DFSoGei typeface (getFontNameDFSoGei)

@implementation StoreDialogView

@synthesize delegate = delegate;
@synthesize indicatorView = m_IndicatorView;
@synthesize labelMessage = m_LabelMessage;
@synthesize progressView = m_ProgressView;
@synthesize buttonAbort = m_ButtonAbort;

// @ 0x416dc — forward to the designated initializer with abortable = YES.
- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame abortable:YES];
}

// @ 0x41708 — build the card and its subviews.
- (instancetype)initWithFrame:(CGRect)frame abortable:(BOOL)abortable {
    self = [super initWithFrame:frame];
    if (self != nil) {
        // Propagate the main screen scale to the layer (guarded for pre-scale OSes).
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
            [self respondsToSelector:@selector(contentScaleFactor)]) {
            self.contentScaleFactor = [UIScreen mainScreen].scale;
        }

        // Rounded, shadowed, translucent-black card.
        self.opaque = NO;
        CALayer *layer = self.layer;
        layer.cornerRadius = 8.0f;
        layer.borderColor = [UIColor grayColor].CGColor;
        layer.borderWidth = 2.0f;
        layer.shadowRadius = 8.0f;
        layer.shadowOffset = CGSizeZero;
        layer.shadowOpacity = 0.5f;
        layer.shouldRasterize = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.7f];

        // Binary factors this into a -[UIView setAutoresizingCenter] category: flexible margins on
        // all four sides keep the card centered in its superview.
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

        // Spinner: 40x40 white-large, centered horizontally, ~0.2 of the height down.
        m_IndicatorView = [[UIActivityIndicatorView alloc]
                              initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [m_IndicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        m_IndicatorView.center = CGPointMake(frame.size.width * 0.5f,
                                             (float)(int)(frame.size.height * 0.2f));
        [self addSubview:m_IndicatorView];

        // Message label: full width minus 30pt, 24pt tall; white, centered. -layout: recenters it.
        m_LabelMessage = [[UILabel alloc]
                             initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width - 30.0f, 24.0f)];
        m_LabelMessage.backgroundColor = [UIColor clearColor];
        m_LabelMessage.textColor = [UIColor whiteColor];
        m_LabelMessage.textAlignment = NSTextAlignmentCenter;
        m_LabelMessage.numberOfLines = 1;
        m_LabelMessage.font = [UIFont fontWithName:AppFontName() size:18.0f];
        [self addSubview:m_LabelMessage];

        // Progress bar: 30pt inset each side, just below the card's vertical center.
        m_ProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        m_ProgressView.frame = CGRectMake(30.0f,
                                          (float)((int)(frame.size.height * 0.5f) + 10),
                                          frame.size.width - 60.0f,
                                          11.0f);
        [m_ProgressView setProgress:0.3f];
        [self addSubview:m_ProgressView];

        if (abortable) {
            // "中止" (abort) button with a stretchable background image.
            UIImage *abortImage = [[UIImage imageNamed:@"store_btn_abort.png"]
                                      stretchableImageWithLeftCapWidth:6 topCapHeight:6];
            // buttonWithType: returns an autoreleased button that the binary retains; under ARC the
            // strong ivar store keeps it alive.
            m_ButtonAbort = [UIButton buttonWithType:UIButtonTypeCustom];
            CGSize abortSize = abortImage ? abortImage.size : CGSizeZero;
            m_ButtonAbort.frame = CGRectMake(0.0f, 0.0f, 140.0f, abortSize.height);
            m_ButtonAbort.titleLabel.textColor = [UIColor whiteColor];
            m_ButtonAbort.titleLabel.font = [UIFont fontWithName:AppFontName() size:20.0f];
            m_ButtonAbort.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
            [m_ButtonAbort setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.6f]
                                      forState:UIControlStateNormal];
            [m_ButtonAbort setBackgroundImage:abortImage forState:UIControlStateNormal];
            [m_ButtonAbort setTitle:@"中止" forState:UIControlStateNormal];
            [m_ButtonAbort addTarget:self
                              action:@selector(btnAbort:)
                    forControlEvents:UIControlEventTouchUpInside];
            m_ButtonAbort.center = CGPointMake(frame.size.width * 0.5f,
                                               (float)(int)(frame.size.height * 0.83f));
            [self addSubview:m_ButtonAbort];
        }
    }
    return self;
}

// dealloc @ 0x41dc0 — release-only (release-chains m_IndicatorView/m_LabelMessage/m_ProgressView/
// m_ButtonAbort then [super dealloc]); ARC-omitted.

// @ 0x41e4c — toggle the progress bar / abort button and recenter the message label.
- (void)layout:(BOOL)hideControls {
    CGRect frame = self.frame;
    CGFloat centerX = frame.size.width * 0.5f;
    CGFloat centerY = frame.size.height * 0.5f;

    CGFloat offsetY;
    if (!hideControls) {
        [m_ProgressView setHidden:NO];
        [m_ButtonAbort setHidden:NO];
        offsetY = -10.0f;   // 0xc1200000
    } else {
        [m_ProgressView setHidden:YES];
        [m_ButtonAbort setHidden:YES];
        offsetY = 10.0f;    // 0x41200000
    }

    m_LabelMessage.center = CGPointMake(centerX, centerY + offsetY);
}

// @ 0x41f38 — abort button action: notify the delegate if it implements -storeDialogCancel:.
- (void)btnAbort:(id)sender {
    if ([delegate respondsToSelector:@selector(storeDialogCancel:)]) {
        [delegate performSelector:@selector(storeDialogCancel:) withObject:self];
    }
}

// Synthesized accessors: -delegate @ 0x41f8c, -setDelegate: @ 0x41f9c, -indicatorView @ 0x41fac,
// -labelMessage @ 0x41fbc, -progressView @ 0x41fcc, -buttonAbort @ 0x41fdc (see @property / @synthesize).

@end
