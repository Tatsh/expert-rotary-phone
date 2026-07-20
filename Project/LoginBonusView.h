//
//  LoginBonusView.h
//  pop'n rhythmin
//
//  Login-bonus "stamp board" reward popup. A full-screen, initially-hidden
//  UIImageView overlay carrying a "login_board" background image and a grid of
//  "login_popn%02d" stamp icons (one per consumed login day). Tapping the board
//  stamps the current day, grants any newly-unlocked reward (treasure points or
//  a music unlock) via -getReward, and walks the player through each reward
//  with a CustomAlertView (type gift). Installed into the root scene view on
//  init.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NOTE ON SUPERCLASS: the binary builds `self` with -[UIView initWithFrame:]
//  but tears it down with -[UIView dealloc], creates itself from a
//  "login_board" UIImage-backed hierarchy and lives as an image overlay;
//  init/dealloc dispatch through the UIView layer of UIImageView. Recovered
//  superclass: UIImageView.
//

#import <UIKit/UIKit.h>

#import "CustomAlertView.h" // CustomAlertView + CustomAlertViewDelegate (customAlertView:clickedButtonAtIndex:)

@interface LoginBonusView : UIImageView <CustomAlertViewDelegate>

// Reveal the board, grant rewards and start the open animation. Ghidra: @
// 0x7c728
- (void)show;

// Grant every login-bonus reward whose unlock threshold was crossed since the
// last time the board was shown (treasure points / music unlock). Ghidra: @
// 0x7c594
- (void)getReward;

// Number of reward rows defined for the active login-bonus id (table terminator
// scan). Used by this class and elsewhere. Ghidra: @ 0x7bf70
+ (int)getRewardMaxCnt;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
