/**
 * @file
 * @brief The iPad variant of the invite-code top screen; the iPhone uses
 * InviteTopViewController.
 *
 * MainViewController -GotoInviteTop chooses it when neSceneManager::isPadDisplay() is true,
 * wrapped in its own navigation controller. Unlike the phone version this is a single combined
 * screen: it shows my own invite code, with a "tweet it" button, and below it either the
 * guest-code entry field and decide button or an "already redeemed" banner. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initAtNavigationController @ 0x5c638,
 * startOpenAnimation @ 0x5d350). Built in InviteTopViewControllerPad.mm, where the neEngine and
 * neSceneManager singletons drive the system SE and the root-VC end callback.
 */

#import <UIKit/UIKit.h>

@class Downloader;

/**
 * @brief The iPad invite screen, combining the code display and the guest code entry.
 */
@interface InviteTopViewControllerPad : UIViewController {
    BOOL isAnimationing;     /**< An open or close fade is running; it guards re-entry. */
    UITextField *_codeField; /**< The guest invite-code entry field. */
    /** The in-flight spinner; the binary never instantiates it. */
    UIActivityIndicatorView *_indicator;
    Downloader *_downloader;   /**< The invite POST; nil when idle. */
    UIScrollView *_scrollView; /**< Scrolls the panels up when the keyboard shows. */
}

/**
 * @brief Build the combined invite screen and wrap it in a navigation controller.
 * @return The navigation controller.
 * @ghidraAddress 0x5c638
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the view and its navigation view in over 0.3 s.
 * @ghidraAddress 0x5d350
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
