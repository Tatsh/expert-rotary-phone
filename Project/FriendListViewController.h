//
//  FriendListViewController.h
//  pop'n rhythmin
//
//  The friend ranking list (pushed by the friend hub's "list" button). A
//  grouped table of FriendListCell rows sorted by total- or best-score, with
//  the local player inserted as a self row; tapping a row raises a
//  FriendListDetail overlay. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle: @ 0xb0774 and 11 more methods). Built in
//  FriendListViewController.mm.
//

#import <UIKit/UIKit.h>

#import "DownloadMain.h" // DownloadMainDelegate (friend-list completion)

@interface FriendListViewController : UITableViewController <DownloadMainDelegate>

// The friend-list request completed; the object is an NSNumber BOOL (success).
// Sent by DownloadMain via performSelector: (DownloadMainDelegate). @ 0xb15ec.
- (void)downloadMainFinished:(NSNumber *)result;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
