/**
 * @file
 * The list of friend requests you have sent, the lower table embedded in
 * FriendRequestViewController.
 *
 * A grouped-style UITableViewController with a "fripre_table" background plate, a dimmed dummy
 * overlay carrying a spinner while the sent-request list downloads, and one FriendRequestCell per
 * outstanding request, each with its own Cancel button. When the list comes back empty it shows a
 * "fripre_empty" placeholder and disables scrolling. Reconstructed from Ghidra project rb420,
 * program PopnRhythmin (initWithStyle: @ 0xb7148 and 14 more methods). Built in
 * FriendRequestTable.mm, which drives the C++ neSceneManager and neEngine singletons.
 */

#import <UIKit/UIKit.h>

/**
 * The sent-friend-requests table.
 */
@interface FriendRequestTable : UITableViewController

/**
 * Build the grouped-style table: a "fripre_table" background plate, a dimmed dummy overlay
 * carrying a centred activity indicator, and a custom back button in the navigation item.
 * @param style The table style.
 * @return The initialised controller.
 * @ghidraAddress 0xb7148
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * Re-fetch the list of friend requests you have sent; a no-op while a fetch is in flight.
 *
 * The owning FriendRequestViewController calls it after a request is sent or cancelled.
 * @ghidraAddress 0xb7a54
 */
- (void)reDownloadGetFriendRequest;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
