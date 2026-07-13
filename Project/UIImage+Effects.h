//
//  UIImage+Effects.h
//  pop'n rhythmin
//
//  UIImage image-processing helpers reconstructed from Ghidra project rb420,
//  program PopnRhythmin. These three methods form the instance method_list of a
//  category on the framework class UIImage (category name "neSystemAddFunc" in
//  the binary; cls slot points to the external _OBJC_CLASS_$_UIImage). A
//  framework-class category is legitimate here.
//
//  Method list @ 0x14ab40 (entsize 12, count 3), selectors:
//    -createReverseImage:       @ 0x7bba0  type "@12@0:4c8"
//    -createImageHarfBlightness @ 0x7bcc4  type "@8@0:4"
//    -createImagefromRect:      @ 0x7be1c  type "@24@0:4{CGRect=...}8"
//  (Selector spellings — "Harf"/"Blightness"/"fromRect" — are the original
//  binary's.)
//

#import <UIKit/UIKit.h>

@interface UIImage (Effects)

// @ 0x7bba0 — redraw into a new same-size context; when `flip` is NO the CTM is
// translated by (w,h) and scaled (-1,-1) to reverse the image, then drawn.
- (UIImage *)createReverseImage:(BOOL)flip;

// @ 0x7bcc4 — draw into a matching bitmap context and halve each RGB channel
// (>>1), leaving alpha intact, to produce a darkened copy.
- (UIImage *)createImageHarfBlightness;

// @ 0x7be1c — draw the image, vertically flipped, into a `rect`-sized context
// offset by -rect.origin, i.e. crop out the given sub-rectangle.
- (UIImage *)createImagefromRect:(CGRect)rect;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
