/**
 * @file
 * A sort-option row.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @
 * 0xc5418).
 */

#import <UIKit/UIKit.h>

/**
 * One row of the sort-select list.
 */
@interface SortCell : UITableViewCell

/**
 * Bind the row to a sort option.
 * @param sortValue An NSValue wrapping `{ short sortType; char isChecked; }`. `sortType`, 0..5,
 * picks the title art — Title, Artist, level N, level H, level EX or no-data — and `isChecked`
 * picks the check-mark image.
 */
- (void)setSortData:(NSValue *)sortValue;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
