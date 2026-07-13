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

@interface FriendListCell : UITableViewCell

// Populate the row from an NSValue-wrapped FriendListData. `rank` is the
// 0-based row index (0 == 1st place); `isBestScoreSort` picks the best-score
// vs. total-score plaque and value.
- (void)setFriendData:(NSValue *)friendData rank:(int)rank isBestScoreSort:(BOOL)isBestScoreSort;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
