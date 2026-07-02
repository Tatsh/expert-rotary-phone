//
//  DownloadMain.h
//  pop'n rhythmin
//
//  The app's download manager: a thread-safe singleton that fetches the server's
//  downloadable-file list and drives file downloads through the Downloader HTTP
//  helper. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (getInstance @ 0x93dd4, startGetDlFileListHttp: @ 0x978ac, getDlFileListFinished
//  @ 0x97af4, isGetDlFileListDownLoading @ 0x979d8, dlFileListDataArray @ 0x999e8).
//

#import <Foundation/Foundation.h>

#import "Downloader.h"

// One downloadable file's metadata. Obj-C type-encoding "{DlFileListData=i@i}"
// (verified in getDlFileListFinished's NSValue wrapping).
typedef struct {
    int fileId;         // JSON "Id"
    NSString *url;      // JSON "Url" (retained)
    int size;           // JSON "Size"
} DlFileListData;

// One friend's record. Obj-C type-encoding "{FriendListData=@@siii[3[7i]][3i][3i]}"
// (verified in getFriendListFinished's NSValue wrapping). The two NSString* fields
// are retained and must be released via releaseFriendList.
typedef struct {
    NSString *playerId;    // JSON "PlayerId" (retained)
    NSString *name;        // JSON "Name" (retained)
    short charaId;         // JSON "CharaId"
    int totalScore;        // JSON "TotalScore"
    int bestScore;         // JSON "BestScore"
    int friendShip;        // JSON "FriendShip" (clamped to <= 100)
    // Per-difficulty [N, H, Ex] x [S, AAA, AA, A, B, FullCombo, Perfect].
    int rank[3][7];
    // Per-difficulty FullCombo count minus Perfect count, floored at 0.
    int fullComboOnly[3];
    // Per-difficulty Perfect count.
    int perfect[3];
} FriendListData;

@protocol DownloadMainDelegate <NSObject>
@optional
// Sent (via performSelector:) when a friend-list request completes; the object is
// an NSNumber BOOL indicating success.
- (void)downloadMainFinished:(NSNumber *)success;
@end

@interface DownloadMain : NSObject <DownloaderDelegate>

// The shared instance (created under @synchronized on first use). Ghidra: 0x93dd4.
+ (instancetype)getInstance;

// Whether the file-list request is in flight (its Downloader is non-nil). @ 0x979d8.
- (BOOL)isGetDlFileListDownLoading;

// Whether the score-save upload is still in flight (the result screen waits on this
// before leaving). Ghidra: -[DownloadMain isSaveScoreDownLoading] @ 0x9541c.
- (BOOL)isSaveScoreDownLoading;

// The parsed file list — an NSArray of NSValue-wrapped DlFileListData. @ 0x999e8.
- (NSArray *)dlFileListDataArray;

// POST the file-list request for `fileId` (-1 = all) at the current client version.
// @ 0x978ac.
- (void)startGetDlFileListHttp:(int)fileId;

// --- Friend list ---

// The parsed friend list — an NSArray of NSValue-wrapped FriendListData. @ 0x99914.
- (NSArray *)friendListArray;
// Number of pending inbound friend requests. @ 0x99734.
- (int)friendRequestedCnt;
// Delegate notified when the friend-list request finishes. @ 0x99604 / 0x99618.
@property (nonatomic, assign) id<DownloadMainDelegate> delegateGetFriendList;
// Whether the friend-list request is in flight. @ 0x958a8.
- (BOOL)isGetFriendListDownLoading;
// POST "uuid=<uuId>" to the friend-list URL and start it. No-op if already running.
// @ 0x95794.
- (void)startGetFriendListHttp;

// --- Block list ---

// The blocked-player id / name arrays (parallel). @ 0x9997c / 0x99990.
- (NSArray *)blPlayerIdArray;
- (NSArray *)blNameArray;
// In-flight flags. @ 0x9658c / 0x96710.
- (BOOL)isAddBlockListDownLoading;
- (BOOL)isGetBlockListDownLoading;
// Fetch the block list. @ 0x965fc.
- (void)startGetBlockListHttp;
// Block / unblock a player id (add refuses to block yourself). @ 0x96440 / 0x969cc.
- (void)startAddBlockListHttp:(NSString *)playerId;
- (void)startDelBlockListHttp:(NSString *)playerId;

// --- Cancel friend request ---

// Delegate notified when a cancel completes. @ 0x99630 / 0x99644.
@property (nonatomic, assign) id<DownloadMainDelegate> delegateCancelFriend;
// In-flight flag. @ 0x9566c.
- (BOOL)isCancelFriendDownLoading;
// Cancel an outbound friend request to playerId. @ 0x95554.
- (void)startCancelFriendHttp:(NSString *)playerId;

// --- Save treasure (sugoroku reward) ---

// POST the collected pieces for map cell `mapId` (main = /10, sub = %10) with the
// visiting friend and friendship level. @ 0x97698.
- (void)startSaveTreasureHttp:(short)mapId visitor:(NSString *)visitor friendship:(int)friendship;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
