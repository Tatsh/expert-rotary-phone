//
//  TouchRangeView.h
//  pop'n rhythmin
//
//  The pop-kun preview inside the "touch range" settings screen (TouchRangeViewCtrl).
//  A plain UIView that draws one of two pop-kun images -- an "untouched" and a
//  "touched" variant -- via -drawRect:, switching on the -isTouched flag that the
//  owning controller toggles while the finger is inside the adjustable radius.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFilename:touched: @ 0x8b20c, dealloc @ 0x8b2c0, drawRect: @ 0x8b324,
//  getImageWidth @ 0x8b364, getImageHeight @ 0x8b3a4, isTouched @ 0x8b3e4,
//  setIsTouched: @ 0x8b3fc). Pure UIKit / Objective-C, so the build lives in
//  TouchRangeView.m.
//

#import <UIKit/UIKit.h>

@interface TouchRangeView : UIView

// Build with two bundled image names: the pop-kun shown when the range is not being
// touched and the one shown while it is. The view's background is cleared so only the
// pop-kun art is visible.
- (instancetype)initWithFilename:(NSString *)filename touched:(NSString *)touched;   // @ 0x8b20c

// Natural size of the (untouched) pop-kun art; 0 when the image is missing.
- (CGFloat)getImageWidth;    // @ 0x8b364
- (CGFloat)getImageHeight;   // @ 0x8b3a4

// Which pop-kun art -drawRect: paints. Backed by _isTouched @0x3c; the binary emits
// data-memory-barrier'd accessors (isTouched @ 0x8b3e4, setIsTouched: @ 0x8b3fc), so
// this is modelled as an atomic property whose synthesized accessors match them.
@property (atomic, assign) BOOL isTouched;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
