//
//  FriendListCell.h
//  pop'n rhythmin
//
//  A friend-list ranking row; subview x-offsets have three layouts (phone iOS
//  6, phone iOS 7, iPad). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xb3234,
//  setFriendData:rank:isBestScoreSort: @ 0xb34c0).
//

#import <UIKit/UIKit.h>

/**
 * @brief One friend-list ranking row.
 */
@interface FriendListCell : UITableViewCell

/**
 * @brief Populate the row from a friend record.
 * @param friendData An NSValue-wrapped FriendListData.
 * @param rank The 0-based row index; 0 is first place.
 * @param isBestScoreSort YES to show the best-score plaque and value, NO for the total-score one.
 * @ghidraAddress 0xb34c0
 */
- (void)setFriendData:(NSValue *)friendData rank:(int)rank isBestScoreSort:(BOOL)isBestScoreSort;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
