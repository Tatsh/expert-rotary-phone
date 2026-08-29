/**
 * @file
 * @brief The "send a friend request" screen, pushed from the friend hub.
 *
 * It shows the player's own id, a text field for the target player's id (at most 7 characters,
 * uppercased), a "request" button that POSTs the request, and a right-bar button that opens the
 * recommended-friend list (FreeRequestListViewController). Below the form it embeds a
 * FriendRequestTable listing the requests you have already sent. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin (init @ 0xb1c08 and 13 more methods). Built in
 * FriendRequestViewController.mm, which drives the C++ neSceneManager and neEngine singletons.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h" // DownloaderDelegate (friend-request POST)

/**
 * @brief The "send a friend request" screen.
 */
@interface FriendRequestViewController : UIViewController <UITextFieldDelegate, DownloaderDelegate>
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
