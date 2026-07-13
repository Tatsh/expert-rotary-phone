//
//  FriendRequestViewController.h
//  pop'n rhythmin
//
//  The "send a friend request" screen (pushed from the friend hub). Shows the
//  player's own ID, a text field to type the target player's ID (max 7 chars,
//  uppercased), a "request" button that POSTs the request, and a right-bar
//  button that opens the recommended-friend list
//  (FreeRequestListViewController). Below the form it embeds a
//  FriendRequestTable listing the requests you have already sent. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (init @ 0xb1c08 and 13 more
//  methods). Built in FriendRequestViewController.mm (Objective-C++: drives the
//  C++ neSceneManager / neEngine singletons).
//

#import <UIKit/UIKit.h>

#import "Downloader.h" // DownloaderDelegate (friend-request POST)

@interface FriendRequestViewController : UIViewController <UITextFieldDelegate, DownloaderDelegate>
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
