/**
 * @file
 * View sizing, flash, jump, and popup animation helpers.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. These are entries in the instance
 * method_list @ 0x14af3c (entsize 12, count 16) of a category named "neSystemAddFunc" on the
 * framework class UIView; the cls slot @ 0x14b008 points to the external _OBJC_CLASS_$_UIView, the
 * same ref as PTR__OBJC_CLASS___UIView_0015bde8. A framework-class category is legitimate here.
 *
 * The selector spellings ("Harf", "SetFlash…") are the original binary's. This header declares the
 * seven helpers from the task address list plus the two RemoveX helpers they call.
 */

#import <UIKit/UIKit.h>

/**
 * The engine's small geometry and layer-animation helpers on UIView. The "Harf" spellings
 * are the binary's.
 */
@interface UIView (neSystemAddFunc)

/**
 * Halve the receiver's bounds size, keeping its origin.
 * @ghidraAddress 0x7dc90
 */
- (void)setHarfSize;
/**
 * Halve the receiver's frame origin, keeping its size.
 * @ghidraAddress 0x7dd08
 */
- (void)setHarfOrigin;
/**
 * Halve every component of the receiver's frame.
 * @ghidraAddress 0x7dd88
 */
- (void)setHarfSizeAndOrigin;

/**
 * Add a repeating, auto-reversing "opacity" CABasicAnimation under the key "FLUSH_ANIM".
 * @param duration The half-cycle duration, in seconds.
 * @param startOpacity The opacity to flash from.
 * @param endOpacity The opacity to flash to.
 * @ghidraAddress 0x7de20
 */
- (void)SetFlashEffectDuration:(float)duration Start:(float)startOpacity End:(float)endOpacity;
/**
 * Start the flash effect with the default fast preset: one third of a second, 1.0 to 0.2.
 * @ghidraAddress 0x7dfd0
 */
- (void)SetFlashEffectFast;

/**
 * Add a repeating "position" CAKeyframeAnimation under the key "PopAnim", bouncing the view
 * up with decreasing amplitude.
 * @param baseX The resting x the bounce returns to.
 * @param baseY The resting y the bounce returns to.
 * @ghidraAddress 0x7e160
 */
- (void)SetJumpEffectBaseX:(float)baseX BaseY:(float)baseY;

/**
 * Add a "transform" scale-bounce CAKeyframeAnimation under the key "transAnimation" —
 * 0, 1.2, 0.9, 1.0 — for a pop-in appearance.
 * @ghidraAddress 0x7e3c4
 */
- (void)setPopupEffect;

/**
 * Remove the "FLUSH_ANIM" flash animation from the layer.
 * @ghidraAddress 0x7df9c
 */
- (void)RemoveFlashEffect;
/**
 * Remove the "transAnimation" popup animation from the layer.
 * @ghidraAddress 0x7eac0
 */
- (void)removePopupEffect;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
