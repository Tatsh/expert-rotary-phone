//
//  FriendReplyCell.h
//  pop'n rhythmin
//
//  One incoming friend-request row in FriendReplyViewController: chara icon,
//  requester name and date, and OK / NG (accept / reject) buttons that call
//  back to the controller. Its subview x-offsets shift between iOS 6 and 7.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xa9150, setReplyData: @ 0xa92ac,
//  onTouchedOkButton @ 0xa9cf0, onTouchedNgButton @ 0xa9d58).
//

#import <UIKit/UIKit.h>

// One request record, Obj-C type-encoding "{ReplyDataStruct=@@@@s[7i]}" (from
// getFriendRequestFinished's NSValue wrapping). The four NSString* fields are
// retained; the trailing int[7] is unused on this screen (left zero).
/**
 * @brief One inbound request record.
 *
 * Objective-C type-encoding "{ReplyDataStruct=@@@@s[7i]}", from getFriendRequestFinished's NSValue
 * wrapping. The four NSString * fields are retained; the trailing int[7] is unused on this screen
 * and left zeroed.
 */
typedef struct {
    NSString *__unsafe_unretained playerId; /**< +0x0 JSON "PlayerId"; retained. */
    NSString *__unsafe_unretained name;     /**< +0x4 JSON "Name"; retained. */
    NSString *__unsafe_unretained message;  /**< +0x8 JSON "Message"; retained. */
    NSString *__unsafe_unretained date;     /**< +0xc JSON "Date"; retained. */
    short charaId;                          /**< +0x10 JSON "CharaId". */
    int rank[7];                            /**< +0x14 Unused on the reply screen. */
} ReplyDataStruct;

/**
 * @brief Receives the row's accept and reject taps.
 */
@protocol FriendReplyCellDelegate <NSObject>
/**
 * @brief OK or NG was tapped for a requester.
 * @param playerId The requester's player id.
 * @param reply 1 to accept, 0 to reject.
 */
- (void)startReplyFriendHttp:(NSString *)playerId reply:(int)reply;
@end

/**
 * @brief One row of the received-friend-requests list, with accept and reject buttons.
 */
@interface FriendReplyCell : UITableViewCell

/** The accept and reject delegate; the store is DMB-guarded. Getter @ 0xa9dc0, setter @
 * 0xa9dd4. */
@property(nonatomic, weak) id<FriendReplyCellDelegate> delegate;

/**
 * @brief Populate the row from a request record.
 * @param replyData An NSValue-wrapped ReplyDataStruct.
 */
- (void)setReplyData:(NSValue *)replyData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
