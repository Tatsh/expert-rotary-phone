//
//  DownloadMain.h
//  pop'n rhythmin
//
//  The app's download manager: a thread-safe singleton that fetches the
//  server's downloadable-file list and drives file downloads through the
//  Downloader HTTP helper. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (getInstance @ 0x93dd4, startGetDlFileListHttp: @ 0x978ac,
//  getDlFileListFinished
//  @ 0x97af4, isGetDlFileListDownLoading @ 0x979d8, dlFileListDataArray @
//  0x999e8).
//

#import <Foundation/Foundation.h>

#import "Downloader.h"

// One downloadable file's metadata. Obj-C type-encoding "{DlFileListData=i@i}"
// (verified in getDlFileListFinished's NSValue wrapping).
typedef struct {
    int fileId;                        // JSON "Id"
    NSString *__unsafe_unretained url; // JSON "Url" (retained)
    int size;                          // JSON "Size"
} DlFileListData;

// One friend's record. Obj-C type-encoding
// "{FriendListData=@@siii[3[7i]][3i][3i]}" (verified in getFriendListFinished's
// NSValue wrapping). The two NSString* fields are retained and must be released
// via releaseFriendList.
typedef struct {
    NSString *__unsafe_unretained playerId; // JSON "PlayerId" (retained)
    NSString *__unsafe_unretained name;     // JSON "Name" (retained)
    short charaId;                          // JSON "CharaId"
    int totalScore;                         // JSON "TotalScore"
    int bestScore;                          // JSON "BestScore"
    int friendShip;                         // JSON "FriendShip" (clamped to <= 100)
    // Per-difficulty [N, H, Ex] x [S, AAA, AA, A, B, FullCombo, Perfect].
    int rank[3][7];
    // Per-difficulty FullCombo count minus Perfect count, floored at 0.
    int fullComboOnly[3];
    // Per-difficulty Perfect count.
    int perfect[3];
} FriendListData;

// One store "information" post. Obj-C type-encoding "{InformationData=i@@}"
// (verified in newsGetFinished's NSValue wrapping). The two NSString* fields
// are retained; freed via releaseInformationData.
typedef struct {
    int informationId;                   // JSON "Id"
    NSString *__unsafe_unretained title; // JSON "Title" (retained), HTML-unescaped
    NSString *__unsafe_unretained body;  // JSON "Body" (retained), HTML-unescaped, <br> -> \n
} InformationData;

// One recommended music-pack. Obj-C type-encoding "{RecommendData=i@@@@}"
// (verified in getRecommendListFinished's NSValue wrapping). The four NSString*
// fields are retained; freed via releaseRecommendData.
typedef struct {
    int packId;                               // JSON "PackId"
    NSString *__unsafe_unretained url;        // JSON "Url" (retained)
    NSString *__unsafe_unretained packName;   // JSON "PackName" (retained)
    NSString *__unsafe_unretained updateDate; // JSON "UpdateDate" (retained)
    NSString *__unsafe_unretained name;       // JSON "Name" (retained)
} RecommendData;

// One present-box entry. Obj-C type-encoding "{PresentData=iii@}" (verified in
// getPresentListFinished's NSValue wrapping). The NSString* field is retained;
// freed via releasePresentList.
typedef struct {
    int presentId;                      // JSON "PresentId"
    int itemId;                         // JSON "ItemId"
    int itemNum;                        // JSON "ItemNum"
    NSString *__unsafe_unretained info; // JSON "Info" (retained)
} PresentData;

// One over-score log entry (a friend beat your score). Obj-C type-encoding
// "{OverScoreLogData=i@i@@ii}" (verified in getOverScoreLogFinished's NSValue
// wrapping). The three NSString* fields are retained; freed via
// releaseOverScoreLogArray.
typedef struct {
    int musicId;                              // JSON "MusicId"
    NSString *__unsafe_unretained musicName;  // JSON "MusicName" (retained)
    int sheet;                                // JSON "Sheet"
    NSString *__unsafe_unretained friendName; // JSON "FriendName" (retained)
    NSString *__unsafe_unretained updateDate; // JSON "UpdateDate" (retained)
    int myScore;                              // JSON "MyScore"
    int friendScore;                          // JSON "FriendScore"
} OverScoreLogData;

// C++ scene objects this singleton bridges back to (see the cppDelegate*
// properties and newsGetFinished / getRecommendListFinished). Only visible to
// C++ translation units so pure-Obj-C importers never see the C++ types.
#ifdef __cplusplus
class MenuMainTask;               // System/src/Task/MenuMainTask.h (: C_TASK); mode-select
                                  // scene
using ModeSelTask = MenuMainTask; // "ModeSelTask" is the binary's name for the mode-select hub
class MainTask;                   // System/src/Task/MainTask.h (: C_TASK); music-select scene
#endif

@protocol DownloadMainDelegate <NSObject>
@optional
// Sent (via performSelector:) when a friend-list request completes; the object
// is an NSNumber BOOL indicating success.
- (void)downloadMainFinished:(NSNumber *)success;
@end

@interface DownloadMain : NSObject <DownloaderDelegate>

// The shared instance (created under @synchronized on first use). Ghidra:
// 0x93dd4.
+ (instancetype)getInstance;

// Whether the file-list request is in flight (its Downloader is non-nil). @
// 0x979d8.
- (BOOL)isGetDlFileListDownLoading;

// Whether the score-save upload is still in flight (the result screen waits on
// this before leaving). Ghidra: -[DownloadMain isSaveScoreDownLoading] @
// 0x9541c.
- (BOOL)isSaveScoreDownLoading;

// The parsed file list — an NSArray of NSValue-wrapped DlFileListData. @
// 0x999e8.
- (NSArray *)dlFileListDataArray;

// POST the file-list request for `fileId` (-1 = all) at the current client
// version.
// @ 0x978ac.
- (void)startGetDlFileListHttp:(int)fileId;

// --- Score upload ---

// POST a finished play's score to the backend. `medal` is the clear grade
// (2 = perfect full-combo, 1 = cleared, 0 = failed) and `charaId` the player's
// current character. The result screen (Ghidra FUN_0003dfe0 @ 0x3e282) fires
// this; the isSaveScoreDownLoading flag above stays set until it completes.
- (void)startSaveScoreHttp:(int)music
                     sheet:(short)sheet
                     score:(int)score
                     medal:(int)medal
                   charaId:(int)charaId; // selector @ 0x15a8e4

// The currently-active game-event music ids (an NSArray of NSNumber). The
// result screen awards the event bonus when the played song matches one.
// @ 0x15a8f8 (getter @ 0x99a10).
@property(nonatomic, strong, readonly) NSArray *gameEventIdArray;

// --- Friend list ---

// The parsed friend list — an NSArray of NSValue-wrapped FriendListData. @
// 0x99914.
- (NSArray *)friendListArray;
// Number of pending inbound friend requests. @ 0x99734 (get) / 0x99748 (set).
- (int)friendRequestedCnt;
- (void)setFriendRequestedCnt:(int)cnt;
// Delegate notified when the friend-list request finishes. @ 0x99604 / 0x99618.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetFriendList;
// Whether the friend-list request is in flight. @ 0x958a8.
- (BOOL)isGetFriendListDownLoading;
// POST "uuid=<uuId>" to the friend-list URL and start it. No-op if already
// running.
// @ 0x95794.
- (void)startGetFriendListHttp;

// --- Block list ---

// The blocked-player id / name arrays (parallel). @ 0x9997c / 0x99990.
- (NSArray *)blPlayerIdArray;
- (NSArray *)blNameArray;
// In-flight flags. @ 0x9658c / 0x96710 / 0x96ae4.
- (BOOL)isAddBlockListDownLoading;
- (BOOL)isGetBlockListDownLoading;
- (BOOL)isDelBlockListDownLoading;
// Fetch the block list. @ 0x965fc.
- (void)startGetBlockListHttp;
// Block / unblock a player id (add refuses to block yourself). @ 0x96440 /
// 0x969cc.
- (void)startAddBlockListHttp:(NSString *)playerId;
- (void)startDelBlockListHttp:(NSString *)playerId;

// --- Cancel friend request ---

// Delegate notified when a cancel completes. @ 0x99630 / 0x99644.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateCancelFriend;
// In-flight flag. @ 0x9566c.
- (BOOL)isCancelFriendDownLoading;
// Cancel an outbound friend request to playerId. @ 0x95554.
- (void)startCancelFriendHttp:(NSString *)playerId;

// --- Save treasure (sugoroku reward) ---

// POST the collected pieces for map cell `mapId` (main = /10, sub = %10) with
// the visiting friend and friendship level. @ 0x97698.
- (void)startSaveTreasureHttp:(short)mapId visitor:(NSString *)visitor friendship:(int)friendship;
// Whether the treasure-save upload is still in flight. @ 0x97894.
- (BOOL)isSaveTreasureDownLoading;

// --- Player-get (login / profile fetch) ---

// POST "uuid=<uuId>&client_ver=<ver>" to the player-get URL. Resets
// errorGetPlayer to -1 while in flight. @ 0x93f14.
- (void)startPlayerGetHttp;
// Whether the player-get request is in flight. @ 0x94060.
- (BOOL)isPlayerGetDownLoading;
// The active player-get Downloader's elapsed seconds (0 when idle). @ 0x94078.
- (NSTimeInterval)getPlayerGetProgressSec;
// Backend error (-1 = none / in-flight, 99 = network error, else server code).
// @ 0x99760.
@property(nonatomic, assign, readonly) int errorGetPlayer;
// Player summary parsed by playerGetFinished. @ 0x99720 / 0x99774 / 0x99788.
@property(nonatomic, assign, readonly) int arcadePt;
@property(nonatomic, assign, readonly) int loginBonusId;
@property(nonatomic, assign, readonly) int loginCnt;
// Whether the login count advanced this fetch. @ 0x9979c / 0x997b4.
@property(nonatomic, assign) BOOL isLoginCntUpdate;

// --- News / store information ---

// POST "info_id=<lastInformationId>" to the store-info URL. @ 0x94488.
- (void)startNewsHttp;
// Whether the news request is in flight. @ 0x9458c.
- (BOOL)isNewsDownLoading;
// The scrolling-ticker text lines and their tap URLs (parallel). @ 0x997cc /
// 0x997e0.
@property(nonatomic, strong, readonly) NSArray *newsTextArray;
@property(nonatomic, strong, readonly) NSArray *newsUrlArray;
// The parsed store-information posts (NSValue-wrapped InformationData). @
// 0x9970c.
@property(nonatomic, strong, readonly) NSArray *informationDataArray;
// When the last news fetch completed. @ 0x997f4 (ivar _lastNewsGetTime).
@property(nonatomic, strong, readonly) NSDate *lastGetNewsTime;
// Server clock parsed from the news "Time" field.
@property(nonatomic, assign, readonly) int serverYear;   // @ 0x99808
@property(nonatomic, assign, readonly) int serverMonth;  // @ 0x9981c
@property(nonatomic, assign, readonly) int serverDay;    // @ 0x99830
@property(nonatomic, assign, readonly) int serverHour;   // @ 0x99844
@property(nonatomic, assign, readonly) int serverMinute; // @ 0x99858
@property(nonatomic, assign, readonly) int serverSecond; // @ 0x9986c
// Set when the store's UpdateTime is newer than the last viewed time. @ 0x99880
// / 0x99898.
@property(nonatomic, assign) BOOL isNewMusicPackReleased;
// C++ mode-select scene notified (via modeSelectRefreshNews) when news
// finishes.
// @ 0x995ac / 0x995c0.
#ifdef __cplusplus
@property(nonatomic, assign) ModeSelTask *cppDelegateNews;
#endif

// --- Recommend list ---

// POST "uuid=<uuId>" to the recommend-list URL. @ 0x96b54.
- (void)startGetRecommendListHttp;
// Whether the recommend-list request is in flight. @ 0x96c68.
- (BOOL)isGetRecommendListDownLoading;
// The parsed recommend list (NSValue-wrapped RecommendData). @ 0x999d4.
@property(nonatomic, strong, readonly) NSArray *recommendDataArray;
// C++ music-select scene notified (via musicSelUpdateInfoPanel) when it
// finishes.
// @ 0x995d8 / 0x995ec.
#ifdef __cplusplus
@property(nonatomic, assign) MainTask *cppDelegateRecommendList;
#endif

// --- Sugoroku visitor ---

// POST "uuid=<uuId>&map_id=<mapId>&type=<type>" to the visitor URL. @ 0x972e4.
- (void)startGetVisitorHttp:(short)mapId type:(short)type;
// Whether the visitor request is in flight. @ 0x97410.
- (BOOL)isGetVisitorDownLoading;
// Whether the last visitor fetch stored a valid visitor. @ 0x999a4 / 0x999bc.
@property(nonatomic, assign) BOOL isGetVisitorSuccess;
// Delegate notified when the visitor request finishes. @ 0x9965c / 0x99670.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetVisitor;

// --- Present box ---

// POST "uuid=<uuId>" to the present-list URL. @ 0x97d60.
- (void)startGetPresentListHttp;
// Whether the present-list request is in flight. @ 0x97e74.
- (BOOL)isGetPresentListDownLoading;
// The parsed present list (NSValue-wrapped PresentData). @ 0x99928.
@property(nonatomic, strong, readonly) NSArray *presentDataArray;
// Delegate notified when the present-list request finishes. @ 0x99688 /
// 0x9969c.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetPresentList;
// POST "uuid=<uuId>&present_id=<id>" to claim one present. @ 0x9829c.
- (void)startGetPresentHttp:(int)presentId;
// Whether the present-claim request is in flight. @ 0x983c0.
- (BOOL)isGetPresentDownLoading;
// The present id most recently claimed. @ 0x9993c / 0x99950.
@property(nonatomic, assign) int getPresentId;
// Delegate notified when the present-claim request finishes. @ 0x996b4 /
// 0x996c8.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetPresent;

// --- Over-score log (friends who beat your score) ---

// POST "uuid=<uuId>" to the over-score-log URL. @ 0x984b4.
- (void)startGetOverScoreLogHttp;
// Whether the over-score-log request is in flight. @ 0x985c8.
- (BOOL)isGetOverScoreLogDownLoading;
// The parsed over-score log (NSValue-wrapped OverScoreLogData). @ 0x99968.
@property(nonatomic, strong, readonly) NSArray *overScoreLogArray;
// Delegate notified when the over-score-log request finishes. @ 0x99a84 /
// 0x99a98.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetOverScoreLog;

// --- Event info ---

// POST "client_ver=<ver>" to the event-info URL. @ 0x98a6c.
- (void)startGetEventInfoHttp;
// Whether the event-info request is in flight. @ 0x98b7c.
- (BOOL)isGetEventInfoDownLoading;
// The active treasure-event / game-event music ids (NSArray of NSNumber). @
// 0x999fc.
@property(nonatomic, strong, readonly) NSArray *treasureEventIdArray;
// Set once each list refreshes so the scenes reload. @ 0x99a24 / 0x99a3c,
// 0x99a54 / 0x99a6c.
@property(nonatomic, assign) BOOL isTreasureEventInfoUpdated;
@property(nonatomic, assign) BOOL isGameEventInfoUpdated;
// Delegate notified when the event-info request finishes. @ 0x996e0 / 0x996f4.
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetEventInfo;

// --- Sent / received friend-request lists (populated elsewhere) ---

// Outbound friend-request player ids / names (parallel). @ 0x998b0 / 0x998c4.
@property(nonatomic, strong, readonly) NSArray *frSendPlayerIdArray;
@property(nonatomic, strong, readonly) NSArray *frSendNameArray;
// Inbound friend-request player ids / names / messages (parallel).
// @ 0x998d8 / 0x998ec / 0x99900.
@property(nonatomic, strong, readonly) NSArray *frReceivePlayerIdArray;
@property(nonatomic, strong, readonly) NSArray *frReceiveNameArray;
@property(nonatomic, strong, readonly) NSArray *frReceiveMessageArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
