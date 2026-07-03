//
//  InviteTopViewController.h
//  pop'n rhythmin
//
//  The invite-code top screen (iPhone; the iPad uses InviteTopViewControllerPad).
//  Pushed by MainViewController -GotoInviteTop over the game view, wrapped in its
//  own navigation controller. A scroll view with two panels: the "player" panel
//  (shows my own invite code -> MyInviteCodeViewController) and the "guest" panel
//  (enter someone else's code -> InputKidViewController). Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (initAtNavigationController @ 0xe6f88,
//  startOpenAnimation @ 0xe7a38). Built in InviteTopViewController.mm
//  (Objective-C++: the SE / scene-root bridge drives the C++ neEngine singletons).
//

#import <UIKit/UIKit.h>

@interface InviteTopViewController : UIViewController {
    BOOL isAnimationing;   // an open/close fade is running (guards re-entry)
}

// Build the top view + its navigation controller (custom back button, nav-bar art,
// the two panels) and return the navigation controller. Ghidra: @ 0xe6f88.
- (UINavigationController *)initAtNavigationController;

// Fade the view (and its nav view) in over 0.3 s. Ghidra: startOpenAnimation @ 0xe7a38.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
