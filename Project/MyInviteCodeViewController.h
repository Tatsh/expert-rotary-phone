//
//  MyInviteCodeViewController.h
//  pop'n rhythmin
//
//  Shows the local player's own invite code (player id): a full-screen
//  background, a nav-bar back button, two title images ("invite" + "player")
//  and the player id rendered inside a patterned ID-area plate. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (init @ 0xe8c98, viewDidLoad
//  @ 0xe9194, didReceiveMemoryWarning @ 0xe91c0, touchedBackButton @ 0xe91ec).
//

#import <UIKit/UIKit.h>

@interface MyInviteCodeViewController : UIViewController

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
