//
//  AcViewerCategoryCell.h
//  pop'n rhythmin
//
//  An arcade-viewer category header row: a single full-bleed banner image whose
//  placement varies by device (iPad vs phone) and iOS version.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x1a804).
//

#import <UIKit/UIKit.h>

@interface AcViewerCategoryCell : UITableViewCell

// Bind the row to a category: the first element of `dataList` supplies the category
// index (0 = etc, 1 = TV, 2..23 = p01..p22) that picks the banner image; a nil list
// falls back to the "all" banner.
- (void)setData:(NSArray *)dataList;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
