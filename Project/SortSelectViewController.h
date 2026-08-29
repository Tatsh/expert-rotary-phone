/**
 * @file
 * @brief The music-list sort-select screen.
 *
 * A transparent, separator-less UITableView of six SortCells (Title, Artist, Lv N, Lv H, Lv EX,
 * and best score), with the current sort marked by a check. Picking a new sort saves it, shows a
 * dimmed "loading" overlay, re-sorts the owning C++ MainTask's song list, and fades the panel
 * closed. It is wrapped in its own UINavigationController, with a back button on phone, and driven
 * by the shared fade and slide open and close lifecycle. MainViewController.GotoSortSelect: pushes
 * it.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0xc5988,
 * initAtNavigationController: @ 0xc6018, the table data source and delegate, the open and close
 * animations, and the musicSelTask accessors).
 */

#import <UIKit/UIKit.h>

// The C++ music-select task (System/src/Task/MainTask.h) whose song list this
// screen re-sorts. MainTask is the music-select task, so it is
// an alias here. Held as a real forward-declared pointer (never void*); this
// header is ObjC++ (every includer is .mm).
class MainTask;

/**
 * @brief The sort-select modal: the six song-list sort orders.
 */
@interface SortSelectViewController : UITableViewController

/** The owning C++ music-select task. It is an atomic raw pointer: the binary brackets both
 * accessors with a DataMemoryBarrier and stores the pointer without retaining it. Getter @
 * 0xc7028, setter @ 0xc703c. */
@property(atomic, assign) MainTask *musicSelTask;

/**
 * @brief Build the sort list — six rows, with the current sort checked — as a transparent table
 * with a "loading" overlay.
 * @param style Forwarded to UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0xc5988
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Keep the C++ task pointer, rebuild the table, and wrap self in a UINavigationController
 * with a back button on phone.
 *
 * The name carries an "init" prefix but the method returns a navigation controller rather than
 * self, so it opts out of the ARC init method family — the AVBus.h convention.
 * @param musicSelTask The owning music-select task.
 * @return The navigation controller.
 * @ghidraAddress 0xc6018
 */
- (UINavigationController *)initAtNavigationController:(MainTask *)musicSelTask
    __attribute__((objc_method_family(none)));

/**
 * @brief Fade the panel in on phone, or slide it in on iPad.
 * @ghidraAddress 0xc6288
 */
- (void)startOpenAnimation;

/**
 * @brief Re-sort the task's list when the sort changed, then fade the panel closed on phone, or
 * slide it closed on iPad.
 * @ghidraAddress 0xc6750
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
