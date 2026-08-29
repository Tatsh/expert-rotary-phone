/**
 * @file
 * @brief The login-bonus "stamp board" reward popup.
 *
 * A full-screen, initially-hidden UIImageView overlay carrying a "login_board" background image
 * and a grid of "login_popn%02d" stamp icons, one per consumed login day. Tapping the board stamps
 * the current day, grants any newly-unlocked reward (treasure points or a music unlock) via
 * -getReward, and walks the player through each reward with a CustomAlertView of type gift. It is
 * installed into the root scene view on init.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * On the superclass: the binary builds `self` with -[UIView initWithFrame:] but tears it down with
 * -[UIView dealloc], creates itself from a "login_board" UIImage-backed hierarchy, and lives as an
 * image overlay; init and dealloc dispatch through the UIView layer of UIImageView. The recovered
 * superclass is UIImageView.
 */

#import <UIKit/UIKit.h>

#import "CustomAlertView.h" // CustomAlertView + CustomAlertViewDelegate (customAlertView:clickedButtonAtIndex:)

/**
 * @brief The login-bonus reward board.
 */
@interface LoginBonusView : UIImageView <CustomAlertViewDelegate>

/**
 * @brief Reveal the board, grant the rewards and start the open animation.
 * @ghidraAddress 0x7c728
 */
- (void)show;

/**
 * @brief Grant every login-bonus reward whose unlock threshold was crossed since the board was
 * last shown: treasure points and music unlocks.
 * @ghidraAddress 0x7c594
 */
- (void)getReward;

/**
 * @brief The number of reward rows defined for the active login-bonus id, found by scanning to the
 * table terminator.
 * @return The reward count.
 * @ghidraAddress 0x7bf70
 */
+ (int)getRewardMaxCnt;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
