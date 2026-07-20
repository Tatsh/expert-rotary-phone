//
//  TouchRangeView.m
//  pop'n rhythmin
//
//  See TouchRangeView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. ARC; pure UIKit (no neEngine / neSceneManager bridge), so this
//  is a plain .m.
//
//  Honesty / recovery notes:
//   * -dealloc @ 0x8b2c0 in the binary is release-only ([super dealloc] plus
//     -release on the two UIImage ivars). Under ARC that is a no-op, so it is
//     omitted rather than reproduced.
//   * -isTouched @ 0x8b3e4 / -setIsTouched: @ 0x8b3fc are the
//   compiler-synthesized
//     atomic accessors (each wrapped in DataMemoryBarrier(0x1b)); they are
//     represented by the @property in the header and not hand-written here.
//   * -drawRect: paints at CGPointZero (origin (0,0) in the binary).
//   * The two image names are the ASCII CFString arguments passed by
//     TouchRangeViewCtrl -viewDidLoad: "ta_popkun_before" (untouched) and
//     "ta_popkun_after" (touched).
//

#import "TouchRangeView.h"

@implementation TouchRangeView {
    UIImage *_untouchedPopkun; // @0x34  pop-kun shown when not touched
                               // ("ta_popkun_before")
    UIImage *_touchedPopkun;   // @0x38  pop-kun shown while touched ("ta_popkun_after")
    // BOOL _isTouched;          // @0x3c  backing ivar for the atomic `isTouched`
    // property
}

// @ 0x8b20c — verified: [super init]; setBackgroundColor:clearColor;
// _untouchedPopkun = imageNamed:filename; _touchedPopkun = imageNamed:touched.
- (instancetype)initWithFilename:(NSString *)filename touched:(NSString *)touched {
    self = [super init];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        _untouchedPopkun = [UIImage imageNamed:filename];
        _touchedPopkun = [UIImage imageNamed:touched];
    }
    return self;
}

// dealloc @ 0x8b2c0 — ARC: release-only dealloc omitted (no added behavior).

// @ 0x8b324 — paint the touched or untouched pop-kun at the view origin.
// Verified: ldrb isTouched; select _touchedPopkun/_untouchedPopkun; tail-call
// drawAtPoint: with CGPointZero (r2=r3=0).
- (void)drawRect:(CGRect)rect {
    UIImage *img = self.isTouched ? _touchedPopkun : _untouchedPopkun;
    [img drawAtPoint:CGPointZero];
}

// @ 0x8b364 — verified: nil _untouchedPopkun returns 0; else returns size.width
// (vldr s0,[sp+0]).
- (CGFloat)getImageWidth {
    if (_untouchedPopkun == nil) {
        return 0.0f;
    }
    return _untouchedPopkun.size.width;
}

// @ 0x8b3a4 — verified: nil _untouchedPopkun returns 0; else returns
// size.height (vldr s0,[sp+4]).
- (CGFloat)getImageHeight {
    if (_untouchedPopkun == nil) {
        return 0.0f;
    }
    return _untouchedPopkun.size.height;
}

// isTouched @ 0x8b3e4, setIsTouched: @ 0x8b3fc — synthesized atomic accessors
// for the `isTouched` property (backing ivar _isTouched @0x3c); not
// hand-written.

@end
