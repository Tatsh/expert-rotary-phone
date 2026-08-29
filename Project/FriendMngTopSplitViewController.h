/**
 * @file
 * @brief The iPad friend-management hub: a floating master-detail split panel over a dimmed
 * backdrop.
 *
 * The left pane is a FriendMngTopViewController (the section-button column); the right pane is a
 * UINavigationController whose top controller is swapped between the friend list, "presenting"
 * (requests you sent), and reply sections by the left column's buttons, forwarded here through
 * the left view controller's delegate. Section swaps are block-based flip transitions; a
 * selection arrow tracks the active row. The iPhone sibling is FriendMngTopViewController itself.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xc3358, the shared open
 * and close fade animations, and the section handlers onListButtonTouched:,
 * onRequestButtonTouched:, and onReplyButtonTouched:).
 *
 * All the app's modal view controllers share this animation lifecycle:
 *
 * - startOpenAnimation fades the view, and its nav controller view, 0 -> 1 over 0.5s; didStop
 *   reaches endOpenAnimation, which clears the guard and shows the first-play how-to once.
 * - startCloseAnimation fades 1 -> 0 over 0.3s; didStop reaches endCloseAnimation.
 * - endCloseAnimation removes the view from its superview and calls [rootVC
 *   FriendManageEndCallBack].
 */

#import <UIKit/UIKit.h>

/**
 * @brief The iPad friend-management hub: a split panel whose left column selects the right pane's
 * section.
 */
@interface FriendMngTopSplitViewController : UIViewController

/**
 * @brief Fade the panel and its navigation view in.
 * @ghidraAddress 0xc3d08
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the panel and its navigation view out.
 * @ghidraAddress 0xc3f68
 */
- (void)startCloseAnimation;

// Section buttons, driven by the left column (FriendMngTopViewController) through its delegate:
// they swap the right pane's top controller and slide the selection arrow.

/**
 * @brief Show the friend list in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xc40d0
 */
- (void)onListButtonTouched:(id)sender;
/**
 * @brief Show the sent friend requests in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xc4760
 */
- (void)onRequestButtonTouched:(id)sender;
/**
 * @brief Show the received friend requests in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xc4df0
 */
- (void)onReplyButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
