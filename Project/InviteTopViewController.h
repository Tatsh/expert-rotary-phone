/**
 * @file
 * The iPhone invite-code top screen; the iPad uses InviteTopViewControllerPad.
 *
 * MainViewController -GotoInviteTop pushes it over the game view, wrapped in its own navigation
 * controller. It is a scroll view with two panels: the "player" panel, which shows my own invite
 * code and leads to MyInviteCodeViewController, and the "guest" panel, which takes someone else's
 * code and leads to InputKidViewController. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initAtNavigationController @ 0xe6f88, startOpenAnimation @ 0xe7a38). Built in
 * InviteTopViewController.mm, where the SE and scene-root bridge drives the C++ neEngine
 * singletons.
 */

#import <UIKit/UIKit.h>

/**
 * The invite-code top screen.
 */
@interface InviteTopViewController : UIViewController {
    BOOL isAnimationing; /**< An open or close fade is running; it guards re-entry. */
}

/**
 * Build the top view and its navigation controller — the custom back button, nav-bar art
 * and the two panels.
 * @return The navigation controller.
 * @ghidraAddress 0xe6f88
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the view and its navigation view in over 0.3 s.
 * @ghidraAddress 0xe7a38
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
