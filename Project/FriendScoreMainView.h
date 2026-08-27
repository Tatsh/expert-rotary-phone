//
//  FriendScoreMainView.h
//  pop'n rhythmin
//
//  The friend-score ranking screen for one song: a UIViewController that hosts
//  three friend-score tables (Normal / Hyper / Ex). On phone the three tables
//  are the pages of a UITabBarController (custom tab art, iOS-7 rendering-mode
//  handling); on pad they are laid out side by side. This controller is the
//  shared data source / delegate of all three UITableViewControllers and
//  renders FriendScoreTableCell rows. It POSTs the friend-score request through
//  the Downloader HTTP helper and also listens for the DownloadMain friend-list
//  refresh so it can re-order the rows to match the local friend list.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initAtNavigationControllerWithMusicId: @ 0xa9df0 and 24 more methods).
//  Built in FriendScoreMainView.mm (Objective-C++: drives the C++
//  neSceneManager singleton).
//

#import <UIKit/UIKit.h>

#import "Downloader.h" // DownloaderDelegate

/**
 * @brief The friend-score screen: your friends' scores on one song.
 */
@interface FriendScoreMainView : UIViewController <UITabBarControllerDelegate, DownloaderDelegate>

/**
 * @brief Build the whole friend-score screen for a song and wrap self in a UINavigationController
 * with the custom back button and nav-bar art.
 * @param musicId The song to show scores for.
 * @return The navigation host the root MainViewController adds over the GL view.
 * @ghidraAddress 0xa9df0
 */
- (UINavigationController *)initAtNavigationControllerWithMusicId:(unsigned int)musicId
    __attribute__((objc_method_family(none)));

/** The song whose friend scores are shown. The accessors are atomic. Getter @ 0xae040, setter @
 * 0xae054. */
@property(atomic, assign) unsigned int musicId;

/** Whether the open or close cross-fade is running; it guards re-entry. Set internally, with no
 * public setter. Getter @ 0xae028. */
@property(atomic, assign, readonly) BOOL isAnimationing;

/**
 * @brief Cross-fade the navigation host in and pause the render loop. The root MainViewController
 * calls it right after adding the host.
 * @ghidraAddress 0xabfc8
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
