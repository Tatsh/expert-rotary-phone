/**
 * @file
 * @brief The screen showing the local player's own invite code, which is their player id.
 *
 * A full-screen background, a nav-bar back button, two title images ("invite" and "player"), and
 * the player id rendered inside a patterned ID-area plate. Reconstructed from Ghidra project
 * rb420, program PopnRhythmin (init @ 0xe8c98, viewDidLoad @ 0xe9194, didReceiveMemoryWarning @
 * 0xe91c0, touchedBackButton @ 0xe91ec).
 */

#import <UIKit/UIKit.h>

@interface MyInviteCodeViewController : UIViewController

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
