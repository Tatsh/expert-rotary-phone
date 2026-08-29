/**
 * @file
 * The random login-bonus "slot machine" reward popup.
 *
 * A full-screen dimming UIView overlay carrying a "login_board_02" panel and a four-digit number
 * display of num_logb_* reels. On show it credits the rolled bonus to the player's treasure
 * points; the reels spin until the board is tapped, at which point each digit locks with a bounce
 * and a gift-styled CustomAlertView reports the amount. It loads, plays, and releases its SE
 * through AudioManager.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * On the superclass: the binary builds `self` with -[UIView initWithFrame:], tears it down with
 * -[UIView dealloc], and gives itself a semi-transparent black backgroundColor as a modal dimmer.
 * The recovered superclass is UIView.
 */

#import <UIKit/UIKit.h>

#import "CustomAlertView.h" // CustomAlertView + CustomAlertViewDelegate (customAlertView:clickedButtonAtIndex:)

/**
 * The randomised login-bonus reveal.
 */
@interface RandomLoginBonusView : UIView <CustomAlertViewDelegate>

/**
 * Install into the root scene view, credit the bonus and start the open animation.
 * @ghidraAddress 0x19960
 */
- (void)show;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
