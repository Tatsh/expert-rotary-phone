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

@interface FriendScoreTableCell : UITableViewCell

// Populate the row from an NSValue-wrapped ScoreDataStruct (see the .m).
// Rebuilt on every reuse; the local player's own row (nil name) gets the "you"
// marker. @ 0xae288.
- (void)setScoreData:(NSValue *)scoreData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
