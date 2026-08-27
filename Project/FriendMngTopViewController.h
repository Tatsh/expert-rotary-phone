//
//  FriendMngTopViewController.h
//  pop'n rhythmin
//
//  The friend-management hub (iPhone; the iPad uses
//  FriendMngTopSplitViewController). Pushed by MainViewController
//  -GotoFriendManage: over the game view, wrapped in its own navigation
//  controller. Offers three sections — friend list, "presenting" (requests you
//  sent), and replies (requests to you, with a "new" warning badge).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initAtNavigationController @ 0xa59f0, startOpenAnimation @ 0xa6590).
//

#import <UIKit/UIKit.h>

/**
 * @brief The friend-management hub screen: the section buttons that open the list, request and
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
 * @brief Build the hub view and its navigation controller, with a custom back button and the
 * section buttons.
 * @return The navigation controller.
 * @ghidraAddress 0xa59f0
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the hub and its navigation view in over 0.5 s.
 * @ghidraAddress 0xa6590
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the hub and its navigation view out over 0.5 s.
 */
- (void)startCloseAnimation;

/**
 * @brief Open the friend list.
 * @param sender The tapped button.
 */
- (void)onListButtonTouched:(id)sender;
/**
 * @brief Open the sent friend requests.
 * @param sender The tapped button.
 */
- (void)onRequestButtonTouched:(id)sender;
/**
 * @brief Open the received friend requests.
 * @param sender The tapped button.
 */
- (void)onReplyButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
