/**
 * @file
 * The iPhone friend-management hub; the iPad uses FriendMngTopSplitViewController.
 *
 * MainViewController -GotoFriendManage: pushes it over the game view, wrapped in its own
 * navigation controller. It offers three sections: the friend list, "presenting" (requests you
 * sent), and replies (requests to you, with a "new" warning badge). Reconstructed from Ghidra
 * project rb420, program PopnRhythmin (initAtNavigationController @ 0xa59f0, startOpenAnimation @
 * 0xa6590).
 */

#import <UIKit/UIKit.h>

/**
 * The friend-management hub screen: the section buttons that open the list, request and
 * reply screens.
 */
@interface FriendMngTopViewController : UIViewController {
    /** The hosting view controller; self-set, a plain assign, not retained. */
    __unsafe_unretained id m_Delegate;
    UIImageView *_markView; /**< The "new reply" warning badge over the reply button. */
    BOOL _isAnimationing;   /**< An open or close animation is running; it guards re-entry. */
}

/** The hosting controller — MainViewController on iPhone, the split hub on iPad — that section
 * taps and close are forwarded to. It backs m_Delegate. Getter @ 0xa6c00, setter @ 0xa6c10. */
@property(nonatomic, assign) id delegate;

/**
 * Build the hub view and its navigation controller, with a custom back button and the
 * section buttons.
 * @return The navigation controller.
 * @ghidraAddress 0xa59f0
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the hub and its navigation view in over 0.5 s.
 * @ghidraAddress 0xa6590
 */
- (void)startOpenAnimation;
/**
 * Fade the hub and its navigation view out over 0.5 s.
 */
- (void)startCloseAnimation;

/**
 * Open the friend list.
 * @param sender The tapped button.
 */
- (void)onListButtonTouched:(id)sender;
/**
 * Open the sent friend requests.
 * @param sender The tapped button.
 */
- (void)onRequestButtonTouched:(id)sender;
/**
 * Open the received friend requests.
 * @param sender The tapped button.
 */
- (void)onReplyButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
