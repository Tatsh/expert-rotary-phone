/**
 * @file
 * An over-score, or friend-score, log row.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @
 * 0x69760).
 */

#import <UIKit/UIKit.h>

/**
 * One row of the over-score log: a friend who beat your score on a song.
 */
@interface OverScoreLogCell : UITableViewCell

/**
 * Rebuild the row's labels and banner from one log entry.
 * @param overScoreLogData An NSValue boxing an OverScoreLogData; -getValue: unboxes it.
 * @ghidraAddress 0x69804
 */
- (void)setOverScoreLogData:(NSValue *)overScoreLogData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
