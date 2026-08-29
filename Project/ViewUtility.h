/**
 * @file
 * @brief A stateless NSObject-derived helper.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The instance class_ro (@
 * 0x1477fc) has instanceStart 4, instanceSize 4 (just the isa, an NSObject subclass), NULL ivars,
 * and a NULL instance method_list, so there are zero instance methods.
 *
 * The metaclass class_ro (@ 0x1477d4), however, carries a baseMethods list (@ 0x1477c0, count 1),
 * so the class exposes one class method: +getCommonBannerBg: @ 0x64f2c, type
 * "@24@0:4{CGRect=...}8", taking a CGRect. No categories reference ViewUtility elsewhere in the
 * binary.
 */

#import <UIKit/UIKit.h>

/**
 * @brief Shared view-construction helpers.
 */
@interface ViewUtility : NSObject

/**
 * @brief Build the shared rounded gradient "banner" background view, with a 3 pt-inset inner
 * tiled-pattern panel added as a subview.
 * @param frame The banner frame.
 * @return The background view.
 * @ghidraAddress 0x64f2c
 */
+ (UIView *)getCommonBannerBg:(CGRect)frame;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
