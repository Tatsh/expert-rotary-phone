/**
 * @file
 * One outgoing friend-request row: a request you sent, with a Cancel button.
 *
 * Its subview x-positions shift between iOS 6 and 7; the layout offsets are computed in init, and
 * the row content is filled by -setFriendData:. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xb9740, setFriendData: @ 0xb987c,
 * onTouchedCancelButton @ 0xba048).
 */

#import <UIKit/UIKit.h>

// One request record, as wrapped in the NSValue passed to -setFriendData:. Only
// these fields are read by the cell (playerId / name / date / charaId); the
// producing controller is not part of the reconstructed set, so the exact tail
// of the struct (if any) is unknown. Best-effort Obj-C type-encoding
// "{FriendRequestDataStruct=@@@s}".
/**
 * One outbound request record, as wrapped in the NSValue passed to -setFriendData:.
 *
 * Only these fields are read by the cell. The producing controller is not part of the
 * reconstructed set, so the exact tail of the struct, if any, is unknown. The best-effort
 * Objective-C type-encoding is `{FriendRequestDataStruct=@@@s}`.
 */
typedef struct {
    /** +0x0 The requester's id, kept for the cancel request. */
    NSString *__unsafe_unretained playerId;
    NSString *__unsafe_unretained name; /**< +0x4 The requester name label's text. */
    NSString *__unsafe_unretained date; /**< +0x8 The request date label's text. */
    /** +0xc The character icon id; 30 or above is downloaded into the Application Support
     * directory. */
    short charaId;
} FriendRequestDataStruct;

/**
 * One row of the sent-friend-requests list.
 */
@interface FriendRequestCell : UITableViewCell

/**
 * Populate the row from a request record.
 * @param friendData An NSValue-wrapped FriendRequestDataStruct.
 */
- (void)setFriendData:(NSValue *)friendData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
