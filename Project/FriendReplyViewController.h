//
//  FriendReplyViewController.h
//  pop'n rhythmin
//
//  The incoming-friend-requests screen (pushed by the friend hub's "reply" button): a table of
//  FriendReplyCell rows, each an incoming request with accept (OK) / reject (NG) buttons that fire
//  a reply POST. Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle:
//  @ 0xa7854 and 16 more methods). Built in FriendReplyViewController.mm.
//

#import <UIKit/UIKit.h>

#import "Downloader.h"        // DownloaderDelegate (request fetch + reply POST)
#import "FriendReplyCell.h"   // FriendReplyCellDelegate (accept/reject callback)

@interface FriendReplyViewController : UITableViewController <DownloaderDelegate, FriendReplyCellDelegate>
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
