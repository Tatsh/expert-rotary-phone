//
//  FreeRequestListCell.h
//  pop'n rhythmin
//
//  One row in the "free request" friend list: a background plate carrying a
//  chara icon, the player's name and that player's score. The subview
//  x-positions shift between iOS 6/7 and phone/pad (the offsets are computed in
//  init; the row content is rebuilt by -setFriendData:rank:). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xe49c4, dealloc @ 0xe4b34,
//  setFriendData:rank: @ 0xe4b60).
//

#import <UIKit/UIKit.h>

// One record, as wrapped in the NSValue passed to -setFriendData:rank:. Only
// these fields are read by the cell (name / charaId / score); the leading word
// is not touched here (best-effort "playerId", by analogy with the sibling
// FriendRequestDataStruct), and the producing controller
// (FreeRequestListViewController / FreeRequestDetail) is not part of the
// reconstructed set, so the exact struct tail is unknown.
typedef struct {
    NSString *__unsafe_unretained playerId; // @0x0  not read by the cell (best-effort name)
    NSString *__unsafe_unretained name;     // @0x4  player name label
    short charaId;                          // @0x8  chara icon id (>= 30 => app-support dir)
    int score;                              // @0xc  score value
} FreeRequestDataStruct;

@interface FreeRequestListCell : UITableViewCell

// Rebuild the row from an NSValue-wrapped FreeRequestDataStruct. `rank` is
// accepted but is not used by the decompiled body.
- (void)setFriendData:(NSValue *)friendData rank:(int)rank;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
