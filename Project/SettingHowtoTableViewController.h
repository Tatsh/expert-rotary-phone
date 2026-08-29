/**
 * @file
 * @brief The "how to play" settings sub-screen.
 *
 * A two-row grouped table reached from the top Settings list (SettingTableViewController row 1).
 * Each row is a rounded, patterned tile with a coloured border and a centred label; tapping a row
 * spawns a HowToViewCtrlPad tutorial, a horizontally-paged strip of how-to images, and drops its
 * view onto the scene manager's root view controller. Row 0 ("ゲームプレー") shows howto_01
 * through howto_05 and adds a "howto_navbar" nav bar; row 1 ("トレジャーモード") shows howto_tre01
 * through howto_tre06.
 *
 * It follows the app-wide modal view-controller lifecycle (see SettingTableViewController.h):
 * initAtNavigationController wraps self in a UINavigationController; startOpenAnimation and
 * startCloseAnimation fade the view and nav view; endCloseAnimation notifies the host via
 * -[MainViewController SettingEndCallBack]. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (class @ 0x0014b500; initWithStyle: @ 0x802e0, initAtNavigationController @
 * 0x80488, the modal open and close animations from 0x806ec, cellForRow @ 0x809c4, didSelectRow @
 * 0x80f1c).
 */

#import <UIKit/UIKit.h>

/**
 * @brief The how-to settings list.
 */
@interface SettingHowtoTableViewController : UITableViewController

/**
 * @brief Wrap self in a fresh navigation controller and build the nav-bar back button, which
 * targets -settingClose; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0x80488
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen in.
 * @ghidraAddress 0x806ec
 */
- (void)startOpenAnimation;
/**
 * @brief Play the cancel SE and fade the screen out.
 * @ghidraAddress 0x80830
 */
- (void)startCloseAnimation;
/**
 * @brief The back-button action; it calls -startCloseAnimation.
 * @ghidraAddress 0x811b8
 */
- (void)settingClose;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
