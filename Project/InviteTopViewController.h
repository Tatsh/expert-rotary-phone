//
//  InviteTopViewController.h
//  pop'n rhythmin
//
//  The invite-code top screen (iPhone; the iPad uses
//  InviteTopViewControllerPad). Pushed by MainViewController -GotoInviteTop
//  over the game view, wrapped in its own navigation controller. A scroll view
//  with two panels: the "player" panel (shows my own invite code ->
//  MyInviteCodeViewController) and the "guest" panel (enter someone else's code
//  -> InputKidViewController). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initAtNavigationController @ 0xe6f88, startOpenAnimation @
//  0xe7a38). Built in InviteTopViewController.mm (Objective-C++: the SE /
//  scene-root bridge drives the C++ neEngine singletons).
//

#import <UIKit/UIKit.h>

/**
 * @brief The invite-code top screen.
 */
@interface InviteTopViewController : UIViewController {
    BOOL isAnimationing; /**< An open or close fade is running; it guards re-entry. */
}

/**
 * @brief Build the top view and its navigation controller — the custom back button, nav-bar art
 * and the two panels.
 * @return The navigation controller.
 * @ghidraAddress 0xe6f88
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the view and its navigation view in over 0.3 s.
 * @ghidraAddress 0xe7a38
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
