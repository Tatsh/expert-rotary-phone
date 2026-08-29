/**
 * @file
 * One row in the "free request" friend list.
 *
 * A background plate carrying a chara icon, the player's name, and that player's score. The
 * subview x-positions shift between iOS 6 and 7 and between phone and pad; the offsets are
 * computed in init, and the row content is rebuilt by -setFriendData:rank:. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xe49c4, dealloc @
 * 0xe4b34, setFriendData:rank: @ 0xe4b60).
 */

#import <UIKit/UIKit.h>

// One record, as wrapped in the NSValue passed to -setFriendData:rank:. Only
// these fields are read by the cell (name / charaId / score); the leading word
// is not touched here (best-effort "playerId", by analogy with the sibling
// FriendRequestDataStruct), and the producing controller
// (FreeRequestListViewController / FreeRequestDetail) is not part of the
// reconstructed set, so the exact struct tail is unknown.
/**
 * One record, as wrapped in the NSValue passed to -setFriendData:rank:.
 *
 * Only the name, character id and score are read by the cell; the leading word is not touched
 * here, so its name is best-effort by analogy with the sibling FriendRequestDataStruct. The
 * producing controller is not part of the reconstructed set, so the exact struct tail is unknown.
 */
typedef struct {
    /** +0x0 Not read by the cell; the name is best-effort. */
    NSString *__unsafe_unretained playerId;
    NSString *__unsafe_unretained name; /**< +0x4 The player name label's text. */
    short charaId; /**< +0x8 The character icon id; 30 or above resolves under Application
                        Support. */
    int score;     /**< +0xc The score value. */
} FreeRequestDataStruct;

/**
 * One row in the "free request" friend list: a plate carrying a character icon, the
 * player's name and their score.
 */
@interface FreeRequestListCell : UITableViewCell

/**
 * Rebuild the row from a record.
 * @param friendData An NSValue-wrapped FreeRequestDataStruct.
 * @param rank Accepted but unused by the decompiled body.
 * @ghidraAddress 0xe4b60
 */
- (void)setFriendData:(NSValue *)friendData rank:(int)rank;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
