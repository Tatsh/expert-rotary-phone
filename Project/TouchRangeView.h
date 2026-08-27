//
//  TouchRangeView.h
//  pop'n rhythmin
//
//  The pop-kun preview inside the "touch range" settings screen
//  (TouchRangeViewCtrl). A plain UIView that draws one of two pop-kun images --
//  an "untouched" and a "touched" variant -- via -drawRect:, switching on the
//  -isTouched flag that the owning controller toggles while the finger is
//  inside the adjustable radius.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFilename:touched: @ 0x8b20c, dealloc @ 0x8b2c0, drawRect: @
//  0x8b324, getImageWidth @ 0x8b364, getImageHeight @ 0x8b3a4, isTouched @
//  0x8b3e4, setIsTouched: @ 0x8b3fc). Pure UIKit / Objective-C, so the build
//  lives in TouchRangeView.m.
//

#import <UIKit/UIKit.h>

/**
 * @brief The touch-radius preview note: it paints one of two pop-kun images depending on whether
 * the range is being touched.
 */
@interface TouchRangeView : UIView

/**
 * @brief Build the view from two bundled image names. The background is cleared so only the
 * pop-kun art is visible.
 * @param filename The image shown when the range is not being touched.
 * @param touched The image shown while it is.
 * @return The initialised view.
 * @ghidraAddress 0x8b20c
 */
- (instancetype)initWithFilename:(NSString *)filename touched:(NSString *)touched;

/**
 * @brief The natural width of the untouched pop-kun art.
 * @return The width, or 0 when the image is missing.
 * @ghidraAddress 0x8b364
 */
- (CGFloat)getImageWidth;
/**
 * @brief The natural height of the untouched pop-kun art.
 * @return The height, or 0 when the image is missing.
 * @ghidraAddress 0x8b3a4
 */
- (CGFloat)getImageHeight;

/** Which pop-kun art -drawRect: paints, backed by _isTouched @ +0x3c. The binary emits
 * data-memory-barrier'd accessors, so this is modelled as an atomic property whose synthesised
 * accessors match them. Getter @ 0x8b3e4, setter @ 0x8b3fc. */
@property(atomic, assign) BOOL isTouched;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
