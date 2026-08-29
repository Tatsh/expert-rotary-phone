/**
 * @file
 * @brief The "friend over-score" log screen.
 *
 * A grouped-style UITableViewController that downloads, via DownloadMain, the list of songs on
 * which a friend has beaten your score, and shows one OverScoreLogCell per entry over a dimmed
 * spinner overlay. Picking a row closes the panel and, in the close-animation completion, drives
 * the owning C++ MainTask straight into a play of that song, or raises a "song not installed"
 * alert. It is wrapped in its own UINavigationController, with a back button on phone, and driven
 * by the shared fade and slide open and close lifecycle. MainViewController.GotoOverScoreLog:
 * pushes it.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0x29928,
 * initAtNavigationController: @ 0x29e24, the table data source and delegate, the DownloadMain
 * callback, the open and close animations, and the musicSelTask accessors).
 */

#import <UIKit/UIKit.h>

#import "DownloadMain.h" // DownloadMainDelegate (the over-score-log download callback)

// The C++ music-select task (System/src/Task/MainTask.h) whose song list this
// screen plays from. MainTask is the music-select task, so it is
// an alias here. Held as a real forward-declared pointer (never void*); this
// header is ObjC++ (every includer is .mm).
class MainTask;

/**
 * @brief The over-score log: the songs on which friends have beaten your score.
 */
@interface OverScoreLogViewController : UITableViewController <DownloadMainDelegate>

/** The owning C++ music-select task. It is an atomic raw pointer: the binary brackets both
 * accessors with a DataMemoryBarrier and stores the pointer without retaining it. Getter @
 * 0x2af2c, setter @ 0x2af40. */
@property(atomic, assign) MainTask *musicSelTask;

/**
 * @brief Build the transparent, separator-less table: a clear spacer header, the "friman" backdrop
 * on phone, and a hidden dimmed spinner overlay.
 * @param style Forwarded to UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0x29928
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Keep the C++ task pointer, rebuild the table, and wrap self in a UINavigationController
 * with a back button on phone.
 * @param musicSelTask The owning music-select task.
 * @return The navigation controller.
 * @ghidraAddress 0x29e24
 */
- (UINavigationController *)initAtNavigationController:(MainTask *)musicSelTask
    __attribute__((objc_method_family(none)));

/**
 * @brief Fade the panel in on phone, or slide it in on iPad.
 * @ghidraAddress 0x2a1b0
 */
- (void)startOpenAnimation;

/**
 * @brief Fade the panel closed on phone, or slide it closed on iPad; the completion launches the
 * selected play.
 * @ghidraAddress 0x2a678
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
