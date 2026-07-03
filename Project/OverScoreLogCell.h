//
//  OverScoreLogCell.h
//  pop'n rhythmin
//
//  An over-score (friend score) log row. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x69760).
//

#import <UIKit/UIKit.h>

@interface OverScoreLogCell : UITableViewCell

// Rebuild the row's labels/banner from one element of the owning view controller's
// log-data array (the element exposes -getValue: which fills a plain C struct).
// Ghidra: -[OverScoreLogCell setOverScoreLogData:] @ 0x69804.
- (void)setOverScoreLogData:(id)overScoreLogData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
