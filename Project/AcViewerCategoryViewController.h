/** @file
 * The arcade (AC) viewer's genre-category list: a transparent, separator-less UITableView. Row 0 is
 * the "all songs" banner; the remaining rows are the non-empty genre categories (each an
 * AcViewerCategoryCell). Selecting a row pushes the AcViewerMusicViewController song list for that
 * category. On phone the whole screen fades in and out via the open/close animations; the iPad flow
 * forwards this screen's delegate to the pushed music list.
 */

#import <UIKit/UIKit.h>

// The AcViewerViewControllerDelegate protocol (the host that hides the split
// panel) is declared here; the iPad flow forwards this screen's delegate to the
// pushed music list.
#import "AcViewerOptionViewController.h"

/**
 * @brief The arcade viewer's genre-category list screen.
 */
@interface AcViewerCategoryViewController : UITableViewController

/**
 * @brief The host that hides the split panel; the iPad flow forwards it to the pushed music list.
 *
 * Stored raw with no retain, matching the binary's synthesised assign accessors.
 */
@property(nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

/**
 * @brief Build the transparent grouped table, bucketing every MusicManager AC song into one of
 * 24 genre categories.
 * @param style The table style (grouped).
 * @return The initialised AcViewerCategoryViewController.
 * @ghidraAddress 0x68804
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Initialize the receiver (grouped style) and return it wrapped in a fresh
 * UINavigationController with a custom back button in the left nav slot (the phone nav host).
 * @return The initialised AcViewerCategoryViewController wrapped in a UINavigationController.
 * @ghidraAddress 0x68d40
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen + its nav view in (phone entry animation).
 * @ghidraAddress 0x69068
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
