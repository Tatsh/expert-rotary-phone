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
//  retain/release/autorelease. The binary's -dealloc only chains to super and is
//  omitted. The compiler-artifact .cxx_construct @ 0xde738 is not reconstructed.
//
//  Byte-decoded constants:
//    * dialog art CFString cf_cmn_window -> ASCII "cmn_window" @ 0x115304.
//    * UI font getFontNameDFSoGei() -> AppFontName() == @"DFSoGei-W5-WIN-RKSJ-H".
//    * float hex -> decimal: 0.5 (0x3f000000), -0.5 (0xbf000000), 1.0 (0x3f800000),
//      40.0 (0x42200000, indicator box), -30.0 (0xc1f00000, label inset x2),
//      24.0 (0x41c00000, label height), 18.0 (0x41900000, label font),
//      25.0 (0x41c80000, progress x), 11.0 (0x41300000, progress height),
//      -100.0 (DAT_000de624, dialog y offset), -50.0 (DAT_000de628, progress inset x2),
//      35.0 (DAT_000de62c, progress y offset), 5.0 (0x40a00000) / 10.0 (0x41200000,
//      layout label offsets). setActivityIndicatorViewStyle: 0 = WhiteLarge,
//      setTextAlignment: 1 = NSTextAlignmentCenter, initWithProgressViewStyle: 1 = Bar.
//
//  NEON note: initWithFrame: computes the dialog frame and every subview frame /
//  center with packed NEON float vectors that spill through the stack, so the
//  decompiler cannot cleanly attribute the individual origin/size lanes. The
//  size lanes and the constant offsets above are byte-exact; the geometry below
//  is reconstructed best-effort and flagged inline where a lane is uncertain.
//  In particular the indicator's center-Y lane could not be recovered precisely.
//

#import "DownloadProgresView.h"

#import "AppFont.h"   // AppFontName() -> label typeface (getFontNameDFSoGei)

@implementation DownloadProgresView {
    // CGRect ivar @ 0x40 — the "cmn_window" dialog rect, in this view's coordinates.
    CGRect _dialogFrame;
}

// @ 0xde1d0 — build the dialog: center a "cmn_window" image, then add a spinner,
// a message label and a progress bar as subviews of that image view.
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        UIImage *windowImage = [UIImage imageNamed:@"cmn_window"];
        CGSize windowSize = windowImage ? windowImage.size : CGSizeZero;

        // NEON best-effort: horizontally centered against the view, pulled up 100pt.
        // x = frame.w/2 - image.w/2 (byte-exact), y = frame.h/2 - 100 (byte-exact),
        // size = image size.
        _dialogFrame = CGRectMake(frame.size.width * 0.5f - windowSize.width * 0.5f,
                                  frame.size.height * 0.5f - 100.0f,
                                  windowSize.width,
                                  windowSize.height);

        UIImageView *windowView = [[UIImageView alloc] initWithImage:windowImage];
        windowView.frame = _dialogFrame;
        [self addSubview:windowView];

        // Activity indicator: a 40x40 white-large spinner recolored black, centered
        // horizontally in the dialog. NEON best-effort: center-Y lane spilled and
        // could not be recovered precisely; using the dialog vertical center.
        _indicatorView = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [_indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _indicatorView.center = CGPointMake(_dialogFrame.size.width * 0.5f,
                                            _dialogFrame.size.height * 0.5f);
        _indicatorView.color = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        [windowView addSubview:_indicatorView];

        // Message label: full dialog width minus 30pt (15pt insets), 24pt tall.
        // NEON best-effort: width = dialog.w - 30 (byte-exact), height = 24 (byte-exact);
        // origin lanes spilled — using x = 15. -layout: recenters it anyway.
        _labelMessage = [[UILabel alloc]
            initWithFrame:CGRectMake(15.0f, 0.0f, _dialogFrame.size.width - 30.0f, 24.0f)];
        _labelMessage.backgroundColor = [UIColor clearColor];
        _labelMessage.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        _labelMessage.textAlignment = NSTextAlignmentCenter;
        _labelMessage.numberOfLines = 1;
        _labelMessage.font = [UIFont fontWithName:AppFontName() size:18.0f];
        [windowView addSubview:_labelMessage];

        // Progress bar (Bar style). NEON best-effort: x = 25 (byte-exact),
        // width = dialog.w - 50 (byte-exact), height = 11 (byte-exact),
        // y = dialog.h/2 + 35 (byte-exact).
        _progressView = [[UIProgressView alloc]
            initWithProgressViewStyle:UIProgressViewStyleBar];
        _progressView.frame = CGRectMake(25.0f,
                                         _dialogFrame.size.height * 0.5f + 35.0f,
                                         _dialogFrame.size.width - 50.0f,
                                         11.0f);
        [_progressView setProgress:0.0f];
        [windowView addSubview:_progressView];
    }
    return self;
}

// @ 0xde65c — toggle the progress bar and recenter the message label. When the
// progress bar is shown the label sits 5pt below the dialog center; when hidden,
// 10pt below (taking the freed space).
- (void)layout:(BOOL)hidden {
    CGFloat width = _dialogFrame.size.width;
    CGFloat height = _dialogFrame.size.height;

    CGFloat offsetY;
    if (!hidden) {
        [self.progressView setHidden:NO];
        offsetY = 5.0f;    // 0x40a00000
    } else {
        [self.progressView setHidden:YES];
        offsetY = 10.0f;   // 0x41200000
    }

    self.labelMessage.center = CGPointMake(width * 0.5f, height * 0.5f + offsetY);
}

// -dealloc @ 0xde630 in the binary is release-only (chains to [super dealloc]);
// omitted under ARC.

// Synthesized accessors -indicatorView @ 0xde708, -labelMessage @ 0xde718,
// -progressView @ 0xde728 are provided by the readonly property declarations.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
