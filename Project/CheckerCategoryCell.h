//
//  CheckerCategoryCell.h
//  pop'n rhythmin
//
//  A music-checker category row; layout offsets vary by iPad + iOS version.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xcf49c).
//

#import <UIKit/UIKit.h>

@interface CheckerCategoryCell : UITableViewCell

// Bind the row to a music-checker category: `category` (0 = etc, 1 = TV, 2..23 = p01..p22,
// >=24 = "near") picks the base banner image, and `playedList`'s count drives the small
// "played" digit badge. Layout offsets come from the init-computed device/OS ivars.
- (void)setData:(NSArray *)playedList category:(short)category;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
