/**
 * @file
 * The "friend recommend" list.
 *
 * A grouped-style, separator-less UITableViewController of RecommendListCells, one per recommended
 * music pack, taken from DownloadMain.recommendDataArray and sorted by update date, newest first.
 * Tapping a row opens the in-app StoreViewController on that recommended pack; the back button
 * re-sorts the owning C++ MainTask's song list, when a store was opened, and fades the panel
 * closed. It is wrapped in its own UINavigationController, with a back button on phone, and driven
 * by the shared fade and slide open and close lifecycle. MainViewController.GotoRecommend: pushes
 * it.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0xbbd68,
 * initAtNavigationController: @ 0xbc30c, the table data source and delegate, the open and close
 * animations, and the musicSelTask and isAnimationing accessors).
 */

#import <UIKit/UIKit.h>

@class StoreViewController;

// The C++ music-select task (System/src/Task/MainTask.h) whose song list this
// screen re-sorts. MainTask is the music-select task, so it is
// an alias here. Held as a real forward-declared pointer (never void*); this
// header is ObjC++ (every includer is .mm).
class MainTask;

/**
 * The recommendations list of purchasable music packs.
 */
@interface RecommendViewController : UITableViewController

/** The owning C++ music-select task. It is an atomic raw pointer: the binary brackets both
 * accessors with a DataMemoryBarrier and stores the pointer without retaining it. Getter @
 * 0xbd3d4, setter @ 0xbd3e8. */
@property(atomic, assign) MainTask *musicSelTask;

/** Whether an open or close animation is in flight. The getter is atomic, bracketed by a
 * DataMemoryBarrier. Getter @ 0xbd400. */
@property(atomic, assign, readonly, getter=isAnimationing) BOOL animationing;

/**
 * Build the transparent, separator-less recommend table — a clear spacer header, the
 * "friman" backdrop on phone, and a hidden dimmed spinner overlay — then load and date-sort the
 * recommend list.
 * @param style Forwarded to UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0xbbd68
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * Keep the C++ task pointer, rebuild the table, and wrap self in a UINavigationController
 * with a back button on phone.
 * @param musicSelTask The owning music-select task.
 * @return The navigation controller.
 * @ghidraAddress 0xbc30c
 */
- (UINavigationController *)initAtNavigationController:(MainTask *)musicSelTask
    __attribute__((objc_method_family(none)));

/**
 * Fade the panel in on phone, or slide it in on iPad.
 * @ghidraAddress 0xbc5e0
 */
- (void)startOpenAnimation;

/**
 * Re-sort the task's list when a store was opened, then fade the panel closed on phone, or
 * slide it closed on iPad.
 * @ghidraAddress 0xbcaa8
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
