/** @file
 * An arcade-viewer category header row: a single full-bleed banner image whose placement varies by
 * device (iPad versus phone) and iOS version.
 */

#import <UIKit/UIKit.h>

/**
 * @brief An arcade-viewer category header row showing a single full-bleed banner image.
 */
@interface AcViewerCategoryCell : UITableViewCell

/**
 * @brief Bind the row to a category: the first element of `dataList` supplies the category index
 * (0 = etc, 1 = TV, 2..23 = p01..p22) that picks the banner image; a nil list falls back to the
 * "all" banner.
 * @param dataList The category data list (first element is the category index).
 * @ghidraAddress 0x1a878
 */
- (void)setData:(NSArray *)dataList;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
