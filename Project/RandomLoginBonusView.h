//
//  RandomLoginBonusView.h
//  pop'n rhythmin
//
//  Random login-bonus "slot machine" reward popup. A full-screen dimming UIView
//  overlay carrying a "login_board_02" panel and a four-digit number display
//  (num_logb_* reels). On show it credits the rolled bonus to the player's
//  treasure points; the reels spin until the board is tapped, at which point each
//  digit locks with a bounce and a gift-styled CustomAlertView reports the amount.
//  Loads/plays/releases its SE through AudioManager.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NOTE ON SUPERCLASS: the binary builds `self` with -[UIView initWithFrame:],
//  tears it down with -[UIView dealloc], and gives itself a semi-transparent black
//  backgroundColor as a modal dimmer. Recovered superclass: UIView.
//

#import <UIKit/UIKit.h>
#import "CustomAlertView.h"   // CustomAlertView + CustomAlertViewDelegate (customAlertView:clickedButtonAtIndex:)

@interface RandomLoginBonusView : UIView <CustomAlertViewDelegate>

// Install into the root scene view, credit the bonus and start the open animation.
// Ghidra: @ 0x19960
- (void)show;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
