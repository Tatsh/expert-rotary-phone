//
//  FriendScoreTableCell.h
//  pop'n rhythmin
//
//  A friend-score ranking row (order / chara / name / score / rank /
//  full-combo); subview x-offsets shift on iOS 7. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @
//  0xae06c).
//

#import <UIKit/UIKit.h>

/**
 * @brief One row of the friend-score list.
 */
@interface FriendScoreTableCell : UITableViewCell

/**
 * @brief Populate the row from a score record; it is rebuilt on every reuse.
 * @param scoreData An NSValue-wrapped ScoreDataStruct (see the .m). A nil name marks the local
 * player's own row, which gets the "you" marker.
 * @ghidraAddress 0xae288
 */
- (void)setScoreData:(NSValue *)scoreData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
