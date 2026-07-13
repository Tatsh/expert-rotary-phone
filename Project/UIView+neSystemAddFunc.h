//
//  UIView+neSystemAddFunc.h
//  pop'n rhythmin
//
//  View sizing / flash / jump / popup animation helpers reconstructed from
//  Ghidra project rb420, program PopnRhythmin. These are entries in the
//  instance method_list @ 0x14af3c (entsize 12, count 16) of a category named
//  "neSystemAddFunc" on the framework class UIView (cls slot @ 0x14b008 ->
//  external _OBJC_CLASS_$_UIView, same ref as
//  PTR__OBJC_CLASS___UIView_0015bde8). A framework-class category is legitimate
//  here.
//
//  Selector spellings ("Harf", "SetFlash…") are the original binary's. This
//  header declares the seven helpers from the task address list plus the two
//  RemoveX helpers they call.
//

#import <UIKit/UIKit.h>

@interface UIView (neSystemAddFunc)

// @ 0x7dc90 — halve the receiver's bounds size (origin kept).
- (void)setHarfSize;
// @ 0x7dd08 — halve the receiver's frame origin (size kept).
- (void)setHarfOrigin;
// @ 0x7dd88 — halve every component of the receiver's frame.
- (void)setHarfSizeAndOrigin;

// @ 0x7de20 — add a repeating, auto-reversing "opacity" CABasicAnimation (key
// "FLUSH_ANIM") flashing from `startOpacity` to `endOpacity` over `duration`
// seconds.
- (void)SetFlashEffectDuration:(float)duration Start:(float)startOpacity End:(float)endOpacity;
// @ 0x7dfd0 — start the flash effect with the default fast preset (1/3 s, 1.0
// -> 0.2).
- (void)SetFlashEffectFast;

// @ 0x7e160 — add a repeating "position" CAKeyframeAnimation (key "PopAnim")
// bouncing the view up from (baseX, baseY) with decreasing amplitude.
- (void)SetJumpEffectBaseX:(float)baseX BaseY:(float)baseY;

// @ 0x7e3c4 — add a "transform" scale-bounce CAKeyframeAnimation (key
// "transAnimation": 0 -> 1.2 -> 0.9 -> 1.0) for a pop-in appearance.
- (void)setPopupEffect;

// @ 0x7df9c — remove the flash ("FLUSH_ANIM") animation from the layer.
- (void)RemoveFlashEffect;
// @ 0x7eac0 — remove the popup ("transAnimation") animation from the layer.
- (void)removePopupEffect;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
