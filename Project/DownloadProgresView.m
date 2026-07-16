//
//  DownloadProgresView.m
//  pop'n rhythmin
//
//  See DownloadProgresView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithFrame: @ 0xde1d0, dealloc @ 0xde630 [release-only,
//  omitted under ARC], layout: @ 0xde65c, indicatorView @ 0xde708,
//  labelMessage @ 0xde718, progressView @ 0xde728).
//
//  Written for ARC: strong ivar-backed readonly properties, no manual
//  retain/release/autorelease. The binary's -dealloc only chains to super and
//  is omitted. The compiler-artifact .cxx_construct @ 0xde738 is not
//  reconstructed.
//
//  Byte-decoded constants:
//    * dialog art CFString cf_cmn_window -> ASCII "cmn_window" @ 0x115304.
//    * UI font getFontNameDFSoGei() -> AppFontName() ==
//    @"DFSoGei-W5-WIN-RKSJ-H".
//    * float hex -> decimal: 0.5 (0x3f000000), -0.5 (0xbf000000), 1.0
//    (0x3f800000),
//      40.0 (0x42200000, indicator box), -30.0 (0xc1f00000, label inset x2),
//      24.0 (0x41c00000, label height), 18.0 (0x41900000, label font),
//      25.0 (0x41c80000, progress x), 11.0 (0x41300000, progress height),
//      -100.0 (DAT_000de624, dialog y offset), -50.0 (DAT_000de628, progress
//      inset x2), 35.0 (DAT_000de62c, progress y offset), 5.0 (0x40a00000)
//      / 10.0 (0x41200000, layout label offsets).
//      setActivityIndicatorViewStyle: 0 = WhiteLarge, setTextAlignment: 1 =
//      NSTextAlignmentCenter, initWithProgressViewStyle: 1 = Bar.
//
//  NEON note: initWithFrame: computes the dialog frame and every subview frame
//  / center with packed NEON float vectors that spill through the stack. All
//  constant lanes have been recovered by disassembly trace (see inline comments
//  for evidence addresses). No best-effort values remain.
//

#import "DownloadProgresView.h"

#import "AppFont.h" // AppFontName() -> label typeface (getFontNameDFSoGei)

@implementation DownloadProgresView {
    // CGRect ivar @ 0x40 — the "cmn_window" dialog rect, in this view's
    // coordinates.
    CGRect _dialogFrame;
}

// @ 0xde1d0 — build the dialog: center a "cmn_window" image, then add a
// spinner, a message label and a progress bar as subviews of that image view.
// @complete
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        UIImage *windowImage = [UIImage imageNamed:@"cmn_window"];
        CGSize windowSize = windowImage ? windowImage.size : CGSizeZero;

        // All exact: x = frame.w/2 - image.w/2, y = frame.h/2 - 100 (DAT_000de624 =
        // 0xc2c80000 = -100.0), size = image size.
        _dialogFrame = CGRectMake(frame.size.width * 0.5f - windowSize.width * 0.5f,
                                  frame.size.height * 0.5f - 100.0f,
                                  windowSize.width,
                                  windowSize.height);

        UIImageView *windowView = [[UIImageView alloc] initWithImage:windowImage];
        windowView.frame = _dialogFrame;
        [self addSubview:windowView];

        // Activity indicator: a 40x40 white-large spinner recolored black.
        // center-X = dialog.w * 0.5 (exact); center-Y = 40.0 (0x42200000, exact:
        // r5 set at 0xde38e, preserved callee-saved, mov r3,r5 at 0xde3ca).
        _indicatorView =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [_indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _indicatorView.center = CGPointMake(_dialogFrame.size.width * 0.5f,
                                            40.0f); // 0x42200000
        _indicatorView.color = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        [windowView addSubview:_indicatorView];

        // Message label: full dialog width minus 30pt inset on both sides, 24pt
        // tall. x = 0.0 (exact: movs r2,#0x0 at 0xde45e), y = 0.0, w = dialog.w -
        // 30 (exact), h = 24.0 (0x41c00000, exact). -layout: recenters it anyway.
        _labelMessage = [[UILabel alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, _dialogFrame.size.width - 30.0f, 24.0f)];
        _labelMessage.backgroundColor = [UIColor clearColor];
        _labelMessage.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        _labelMessage.textAlignment = NSTextAlignmentCenter;
        _labelMessage.numberOfLines = 1;
        _labelMessage.font = [UIFont fontWithName:AppFontName() size:18.0f];
        [windowView addSubview:_labelMessage];

        // Progress bar (Bar style). All exact: x = 25 (0x41c80000), y = dialog.h/2
        // + 35 (DAT_000de62c = 0x420c0000 = 35.0), w = dialog.w - 50 (DAT_000de628
        // = -50.0), h = 11 (0x41300000).
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        _progressView.frame = CGRectMake(
            25.0f, _dialogFrame.size.height * 0.5f + 35.0f, _dialogFrame.size.width - 50.0f, 11.0f);
        [_progressView setProgress:0.0f];
        [windowView addSubview:_progressView];
    }
    return self;
}

// @ 0xde65c — toggle the progress bar and recenter the message label. When the
// progress bar is shown the label sits 5pt below the dialog center; when
// hidden, 10pt below (taking the freed space).
// @complete
- (void)layout:(BOOL)hidden {
    CGFloat width = _dialogFrame.size.width;
    CGFloat height = _dialogFrame.size.height;

    CGFloat offsetY;
    if (!hidden) {
        [self.progressView setHidden:NO];
        offsetY = 5.0f; // 0x40a00000
    } else {
        [self.progressView setHidden:YES];
        offsetY = 10.0f; // 0x41200000
    }

    self.labelMessage.center = CGPointMake(width * 0.5f, height * 0.5f + offsetY);
}

// -dealloc @ 0xde630 in the binary is release-only (chains to [super dealloc]);
// omitted under ARC.

// Synthesized accessors -indicatorView @ 0xde708, -labelMessage @ 0xde718,
// -progressView @ 0xde728 are provided by the readonly property declarations.

@end
