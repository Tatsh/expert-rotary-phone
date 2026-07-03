//
//  FriendScoreMainView.h
//  pop'n rhythmin
//
//  The friend-score ranking screen for one song: a UIViewController that hosts three
//  friend-score tables (Normal / Hyper / Ex). On phone the three tables are the pages of
//  a UITabBarController (custom tab art, iOS-7 rendering-mode handling); on pad they are
//  laid out side by side. This controller is the shared data source / delegate of all
//  three UITableViewControllers and renders FriendScoreTableCell rows. It POSTs the
//  friend-score request through the Downloader HTTP helper and also listens for the
//  DownloadMain friend-list refresh so it can re-order the rows to match the local
//  friend list. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initAtNavigationControllerWithMusicId: @ 0xa9df0 and 24 more methods). Built in
//  FriendScoreMainView.mm (Objective-C++: drives the C++ neSceneManager singleton).
//

#import <UIKit/UIKit.h>

#import "Downloader.h"   // DownloaderDelegate

@interface FriendScoreMainView : UIViewController <UITabBarControllerDelegate, DownloaderDelegate>

// Build the whole friend-score screen for `musicId`, wrap self in a UINavigationController
// (with the custom back button + nav-bar art) and return that navigation controller — the
// phone nav host the root MainViewController adds over the GL view. Ghidra: @ 0xa9df0.
- (UINavigationController *)initAtNavigationControllerWithMusicId:(unsigned int)musicId;

// The song whose friend scores are shown. Synthesized atomic accessors
// (getter @ 0xae040 / setter @ 0xae054).
@property (atomic, assign) unsigned int musicId;

// YES while the open/close cross-fade is running (guards re-entry). Synthesized atomic
// getter @ 0xae028; set internally (no public setter).
@property (atomic, assign, readonly) BOOL isAnimationing;

// Cross-fade the nav host in (and pause the render loop). Called by the root
// MainViewController right after it adds the nav host. Ghidra: @ 0xabfc8.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
