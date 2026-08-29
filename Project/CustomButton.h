/**
 * @file
 * @brief A UIButton whose hit-test area is grown, or shrunk, by `tappableInsets`.
 *
 * Negative insets enlarge the tappable region beyond the button's bounds, so a small on-screen
 * button can still be comfortably tapped. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (pointInside:withEvent: @ 0xdcfc0, tappableInsets and setTappableInsets: @ 0xdd0f8
 * and 0xdd11c).
 */

#import <UIKit/UIKit.h>

/**
 * @brief A UIButton whose hit-test area is grown or shrunk by tappableInsets, so a small on-screen
 * button can still be comfortably tapped.
 */
@interface CustomButton : UIButton

/** Applied to the bounds before hit-testing, via UIEdgeInsetsInsetRect; negative values expand the
 * tappable area. The recovered setter uses an atomic objc_copyStruct. Getter @ 0xdd0f8, setter @
 * 0xdd11c. */
@property(atomic) UIEdgeInsets tappableInsets;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
