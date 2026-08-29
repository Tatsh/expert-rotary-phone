/**
 * @file
 * @brief UIImage image-processing helpers.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. These three methods form the
 * instance method_list of a category on the framework class UIImage; the category name is
 * "neSystemAddFunc" in the binary, and the cls slot points to the external _OBJC_CLASS_$_UIImage.
 * A framework-class category is legitimate here.
 *
 * The method list @ 0x14ab40 (entsize 12, count 3) holds the selectors -createReverseImage: @
 * 0x7bba0, type `@12@0:4c8`; -createImageHarfBlightness @ 0x7bcc4, type `@8@0:4`; and
 * -createImagefromRect: @ 0x7be1c, type `@24@0:4{CGRect=...}8`. The selector spellings "Harf",
 * "Blightness", and "fromRect" are the original binary's.
 */

#import <UIKit/UIKit.h>

/**
 * @brief Small redraw effects on UIImage.
 */
@interface UIImage (Effects)

/**
 * @brief Redraw into a new same-size context, optionally reversing the image.
 * @param flip NO translates the CTM by (w, h) and scales it by (-1, -1) before drawing, reversing
 * the image; YES draws it as-is.
 * @return The redrawn image.
 * @ghidraAddress 0x7bba0
 */
- (UIImage *)createReverseImage:(BOOL)flip;

/**
 * @brief Draw into a matching bitmap context and halve each RGB channel, leaving alpha intact, to
 * produce a darkened copy. The selector's spelling is the binary's.
 * @return The darkened image.
 * @ghidraAddress 0x7bcc4
 */
- (UIImage *)createImageHarfBlightness;

/**
 * @brief Crop out a sub-rectangle by drawing the image, vertically flipped, into a
 * @p rect -sized context offset by its negated origin.
 * @param rect The sub-rectangle to crop.
 * @return The cropped image.
 * @ghidraAddress 0x7be1c
 */
- (UIImage *)createImagefromRect:(CGRect)rect;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
