//
//  FriendReplyCell.h
//  pop'n rhythmin
//
//  One incoming friend-request row in FriendReplyViewController: chara icon, requester name and
//  date, and OK / NG (accept / reject) buttons that call back to the controller. Its subview
//  x-offsets shift between iOS 6 and 7. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xa9150, setReplyData: @ 0xa92ac,
//  onTouchedOkButton @ 0xa9cf0, onTouchedNgButton @ 0xa9d58).
//

#import <UIKit/UIKit.h>

// One request record, Obj-C type-encoding "{ReplyDataStruct=@@@@s[7i]}" (from
// getFriendRequestFinished's NSValue wrapping). The four NSString* fields are retained; the
// trailing int[7] is unused on this screen (left zero).
typedef struct {
    NSString *__unsafe_unretained playerId;   // JSON "PlayerId"  (retained)  @0x0
    NSString *__unsafe_unretained name;       // JSON "Name"      (retained)  @0x4
    NSString *__unsafe_unretained message;    // JSON "Message"   (retained)  @0x8
    NSString *__unsafe_unretained date;       // JSON "Date"      (retained)  @0xc
    short charaId;        // JSON "CharaId"                @0x10
    int rank[7];          // unused on the reply screen    @0x14
} ReplyDataStruct;

@protocol FriendReplyCellDelegate <NSObject>
// Sent when OK (reply == 1, accept) or NG (reply == 0, reject) is tapped for `playerId`.
- (void)startReplyFriendHttp:(NSString *)playerId reply:(int)reply;
@end

@interface FriendReplyCell : UITableViewCell

// Synthesized accessors: delegate @ 0xa9dc0, setDelegate: @ 0xa9dd4 (DMB-guarded pointer store).
@property (nonatomic, weak) id<FriendReplyCellDelegate> delegate;

// Populate the row from an NSValue-wrapped ReplyDataStruct.
- (void)setReplyData:(NSValue *)replyData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
