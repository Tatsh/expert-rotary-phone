//
//  CheckerCategoryCell.h
//  pop'n rhythmin
//
//  A music-checker category row; layout offsets vary by iPad + iOS version.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xcf49c).
//

#import <UIKit/UIKit.h>

/**
 * @brief One music-checker category row.
 */
@interface CheckerCategoryCell : UITableViewCell

/**
 * @brief Bind the row to a music-checker category. The layout offsets come from the init-computed
 * device and OS ivars.
 * @param playedList The played songs in this category; its count drives the small "played" digit
 * badge.
 * @param category 0 for etc, 1 for TV, 2..23 for p01..p22, and 24 or above for "near". It picks
 * the base banner image.
 */
- (void)setData:(NSArray *)playedList category:(short)category;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
