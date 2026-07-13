//
//  SortCell.h
//  pop'n rhythmin
//
//  A sort-option row. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xc5418).
//

#import <UIKit/UIKit.h>

@interface SortCell : UITableViewCell

// Bind the row to a sort option. `sortValue` is an NSValue wrapping the struct
// { short sortType; char isChecked; }: `sortType` (0..5) picks the title art
// (Title / Artist / Lv N / Lv H / Lv EX / no-data) and `isChecked` picks the
// check-mark image.
- (void)setSortData:(NSValue *)sortValue;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
