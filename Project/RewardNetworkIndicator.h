/**
 * @file
 * @brief The Konami "RewardNetwork" (Applilink) ad-SDK modal busy indicator.
 *
 * A translucent black UIView hosting a centred UIActivityIndicatorView. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin, with a UIView superclass and a single `_indicator` object
 * ivar.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The reward SDK's busy-indicator overlay.
 */
@interface RewardNetworkIndicator : UIView

/** The hosted spinner, backed by the _indicator ivar. Getter @ 0xf3eb4, setter @ 0xf3ec4. */
@property(nonatomic, strong) UIActivityIndicatorView *indicator;

/**
 * @brief Unhide the overlay and start the spinner.
 * @ghidraAddress 0xf3e14
 */
- (void)show;

/**
 * @brief Hide the overlay and stop the spinner.
 * @ghidraAddress 0xf3e64
 */
- (void)close;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
