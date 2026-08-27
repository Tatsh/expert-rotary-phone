/** @file
 * The app's download manager: a thread-safe singleton that fetches the server's
 * downloadable-file list and drives file downloads through the Downloader HTTP helper.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (getInstance @ 0x93dd4,
 * startGetDlFileListHttp: @ 0x978ac, getDlFileListFinished @ 0x97af4, isGetDlFileListDownLoading @
 * 0x979d8, dlFileListDataArray @ 0x999e8).
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

/**
 * @brief Server result codes returned in the friend-request and free-request API's "ErrorCode"
 * field.
 *
 * Codes 3..6, 8 and 9 have distinct, screen-consistent meanings. Codes 0, 1, 2 and 7 are surfaced
 * to the user as a generic "communication failed" message and their individual server meanings are
 * not distinguished by the client — the friend-request and free-request screens even bucket code 1
 * differently — so they are named by code rather than given invented semantics.
 */
typedef NS_ENUM(NSInteger, FriendResultCode) {
    FriendResultCommError0 = 0, /**< Reported as "communication failed". */
    /** Reported as "communication failed" by the free-request screen, and as an invalid id by the
     * friend-request screen. */
    FriendResultCommError1 = 1,
    FriendResultCommError2 = 2,      /**< Reported as "communication failed". */
    FriendResultInvalidPlayerId = 3, /**< 無効なプレーヤーID: an invalid player id. */
    FriendResultSelfListFull = 4,    /**< This player cannot register any more friends. */
    FriendResultPeerListFull = 5,    /**< The other player cannot register any more friends. */
    FriendResultBlocked = 6,         /**< The other player is on the block list. */
    FriendResultCommError7 = 7,      /**< Reported as "communication failed". */
    /** Already applied, or a request has already been received from this player. */
    FriendResultAlreadyRequested = 8,
    FriendResultAlreadyRegistered = 9, /**< The two players are already friends. */
};

/**
 * @brief One downloadable file's metadata.
 *
 * Objective-C type-encoding "{DlFileListData=i@i}", verified in getDlFileListFinished's NSValue
 * wrapping.
 */
typedef struct {
    int fileId;                        /**< JSON "Id". */
    NSString *__unsafe_unretained url; /**< JSON "Url"; retained. */
    int size;                          /**< JSON "Size". */
} DlFileListData;

/**
 * @brief One friend's record.
 *
 * Objective-C type-encoding "{FriendListData=@@siii[3[7i]][3i][3i]}", verified in
 * getFriendListFinished's NSValue wrapping. The two NSString * fields are retained and must be
 * released via releaseFriendList.
 */
typedef struct {
    NSString *__unsafe_unretained playerId; /**< JSON "PlayerId"; retained. */
    NSString *__unsafe_unretained name;     /**< JSON "Name"; retained. */
    short charaId;                          /**< JSON "CharaId". */
    int totalScore;                         /**< JSON "TotalScore". */
    int bestScore;                          /**< JSON "BestScore". */
    int friendShip;                         /**< JSON "FriendShip", clamped to 100 or below. */
    /** Per-difficulty [N, H, Ex] by [S, AAA, AA, A, B, FullCombo, Perfect] counts. */
    int rank[3][7];
    /** Per-difficulty full-combo count minus perfect count, floored at 0. */
    int fullComboOnly[3];
    int perfect[3]; /**< Per-difficulty perfect count. */
} FriendListData;

/**
 * @brief One store "information" post.
 *
 * Objective-C type-encoding "{InformationData=i@@}", verified in newsGetFinished's NSValue
 * wrapping. The two NSString * fields are retained and freed via releaseInformationData.
 */
typedef struct {
    int informationId;                   /**< JSON "Id". */
    NSString *__unsafe_unretained title; /**< JSON "Title"; retained and HTML-unescaped. */
    /** JSON "Body"; retained, HTML-unescaped, with `<br>` turned into a newline. */
    NSString *__unsafe_unretained body;
} InformationData;

/**
 * @brief One recommended music pack.
 *
 * Objective-C type-encoding "{RecommendData=i@@@@}", verified in getRecommendListFinished's
 * NSValue wrapping. The four NSString * fields are retained and freed via releaseRecommendData.
 */
typedef struct {
    int packId;                               /**< JSON "PackId". */
    NSString *__unsafe_unretained url;        /**< JSON "Url"; retained. */
    NSString *__unsafe_unretained packName;   /**< JSON "PackName"; retained. */
    NSString *__unsafe_unretained updateDate; /**< JSON "UpdateDate"; retained. */
    NSString *__unsafe_unretained name;       /**< JSON "Name"; retained. */
} RecommendData;

/**
 * @brief One present-box entry.
 *
 * Objective-C type-encoding "{PresentData=iii@}", verified in getPresentListFinished's NSValue
 * wrapping. The NSString * field is retained and freed via releasePresentList.
 */
typedef struct {
    int presentId;                      /**< JSON "PresentId". */
    int itemId;                         /**< JSON "ItemId". */
    int itemNum;                        /**< JSON "ItemNum". */
    NSString *__unsafe_unretained info; /**< JSON "Info"; retained. */
} PresentData;

/**
 * @brief One over-score log entry: a friend beat your score.
 *
 * Objective-C type-encoding "{OverScoreLogData=i@i@@ii}", verified in getOverScoreLogFinished's
 * NSValue wrapping. The three NSString * fields are retained and freed via
 * releaseOverScoreLogArray.
 */
typedef struct {
    int musicId;                              /**< JSON "MusicId". */
    NSString *__unsafe_unretained musicName;  /**< JSON "MusicName"; retained. */
    int sheet;                                /**< JSON "Sheet". */
    NSString *__unsafe_unretained friendName; /**< JSON "FriendName"; retained. */
    NSString *__unsafe_unretained updateDate; /**< JSON "UpdateDate"; retained. */
    int myScore;                              /**< JSON "MyScore". */
    int friendScore;                          /**< JSON "FriendScore". */
} OverScoreLogData;

// C++ scene objects this singleton bridges back to (see the cppDelegate* properties and
// newsGetFinished / getRecommendListFinished). Only visible to C++ translation units so pure
// Objective-C importers never see the C++ types.
#ifdef __cplusplus
class MenuMainTask;               // System/src/Task/MenuMainTask.h (: ne::C_TASK); mode-select
                                  // scene
using ModeSelTask = MenuMainTask; // "ModeSelTask" is the binary's name for the mode-select hub
class MainTask;                   // System/src/Task/MainTask.h (: ne::C_TASK); music-select scene
#endif

/**
 * @brief Receives completion notices from DownloadMain's per-request delegates.
 */
@protocol DownloadMainDelegate <NSObject>
@optional
/**
 * @brief Sent via performSelector: when a request completes.
 * @param success An NSNumber wrapping a BOOL indicating success.
 */
- (void)downloadMainFinished:(NSNumber *)success;
@end

/**
 * @brief The app's download manager: a thread-safe singleton driving every backend request through
 * the Downloader HTTP helper.
 */
@interface DownloadMain : NSObject <DownloaderDelegate>

/**
 * @brief The shared instance, created under @@synchronized on first use.
 * @return The manager.
 * @ghidraAddress 0x93dd4
 */
+ (instancetype)getInstance;

/**
 * @brief Whether the file-list request is in flight, meaning its Downloader is non-nil.
 * @return YES while the request is running.
 * @ghidraAddress 0x979d8
 */
- (BOOL)isGetDlFileListDownLoading;

/**
 * @brief Whether the score-save upload is still in flight; the result screen waits on this before
 * leaving.
 * @return YES while the upload is running.
 * @ghidraAddress 0x9541c
 */
- (BOOL)isSaveScoreDownLoading;

/**
 * @brief The parsed downloadable-file list.
 * @return An NSArray of NSValue-wrapped DlFileListData.
 * @ghidraAddress 0x999e8
 */
- (NSArray *)dlFileListDataArray;

/**
 * @brief POST the file-list request at the current client version.
 * @param fileId The file to ask about, or -1 for all of them.
 * @ghidraAddress 0x978ac
 */
- (void)startGetDlFileListHttp:(int)fileId;

// --- Score upload ---

/**
 * @brief POST a finished play's score to the backend.
 *
 * The result screen (Ghidra FUN_0003dfe0 @ 0x3e282) fires this; -isSaveScoreDownLoading stays YES
 * until it completes.
 * @param music The music id.
 * @param sheet The sheet index.
 * @param score The final score.
 * @param medal The clear grade: 2 perfect full-combo, 1 cleared, 0 failed.
 * @param charaId The player's current character.
 */
- (void)startSaveScoreHttp:(int)music
                     sheet:(short)sheet
                     score:(int)score
                     medal:(int)medal
                   charaId:(int)charaId;

/**
 * The currently-active game-event music ids, as an NSArray of NSNumber. The result screen awards
 * the event bonus when the played song matches one. Getter @ 0x99a10.
 */
@property(nonatomic, strong, readonly) NSArray *gameEventIdArray;

// --- Friend list ---

/**
 * @brief The parsed friend list.
 * @return An NSArray of NSValue-wrapped FriendListData.
 * @ghidraAddress 0x99914
 */
- (NSArray *)friendListArray;
/**
 * @brief The number of pending inbound friend requests.
 * @return The request count.
 * @ghidraAddress 0x99734
 */
- (int)friendRequestedCnt;
/**
 * @brief Set the number of pending inbound friend requests.
 * @param cnt The request count.
 * @ghidraAddress 0x99748
 */
- (void)setFriendRequestedCnt:(int)cnt;
/** The delegate notified when the friend-list request finishes. Getter @ 0x99604, setter @
 * 0x99618. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetFriendList;
/**
 * @brief Whether the friend-list request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x958a8
 */
- (BOOL)isGetFriendListDownLoading;
/**
 * @brief POST "uuid=<uuId>" to the friend-list URL and start it. A no-op if already running.
 * @ghidraAddress 0x95794
 */
- (void)startGetFriendListHttp;

// --- Block list ---

/**
 * @brief The blocked players' ids, parallel to -blNameArray.
 * @return An NSArray of NSString.
 * @ghidraAddress 0x9997c
 */
- (NSArray *)blPlayerIdArray;
/**
 * @brief The blocked players' names, parallel to -blPlayerIdArray.
 * @return An NSArray of NSString.
 * @ghidraAddress 0x99990
 */
- (NSArray *)blNameArray;
/**
 * @brief Whether the add-to-block-list request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x9658c
 */
- (BOOL)isAddBlockListDownLoading;
/**
 * @brief Whether the block-list fetch is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x96710
 */
- (BOOL)isGetBlockListDownLoading;
/**
 * @brief Whether the remove-from-block-list request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x96ae4
 */
- (BOOL)isDelBlockListDownLoading;
/**
 * @brief Fetch the block list.
 * @ghidraAddress 0x965fc
 */
- (void)startGetBlockListHttp;
/**
 * @brief Block a player. The call refuses to block yourself.
 * @param playerId The player to block.
 * @ghidraAddress 0x96440
 */
- (void)startAddBlockListHttp:(NSString *)playerId;
/**
 * @brief Unblock a player.
 * @param playerId The player to unblock.
 * @ghidraAddress 0x969cc
 */
- (void)startDelBlockListHttp:(NSString *)playerId;

// --- Cancel friend request ---

/** The delegate notified when a cancel completes. Getter @ 0x99630, setter @ 0x99644. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateCancelFriend;
/**
 * @brief Whether the cancel-friend-request call is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x9566c
 */
- (BOOL)isCancelFriendDownLoading;
/**
 * @brief Cancel an outbound friend request.
 * @param playerId The player the request was sent to.
 * @ghidraAddress 0x95554
 */
- (void)startCancelFriendHttp:(NSString *)playerId;

// --- Save treasure (sugoroku reward) ---

/**
 * @brief POST the collected pieces for one map cell.
 * @param mapId The map cell: main map is `mapId / 10` and sub map `mapId % 10`.
 * @param visitor The visiting friend's player id.
 * @param friendship The friendship level.
 * @ghidraAddress 0x97698
 */
- (void)startSaveTreasureHttp:(short)mapId visitor:(NSString *)visitor friendship:(int)friendship;
/**
 * @brief Whether the treasure-save upload is still in flight.
 * @return YES while the upload is running.
 * @ghidraAddress 0x97894
 */
- (BOOL)isSaveTreasureDownLoading;

// --- Player-get (login / profile fetch) ---

/**
 * @brief POST "uuid=<uuId>&client_ver=<ver>" to the player-get URL, resetting errorGetPlayer to -1
 * while in flight.
 * @ghidraAddress 0x93f14
 */
- (void)startPlayerGetHttp;
/**
 * @brief Whether the player-get request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x94060
 */
- (BOOL)isPlayerGetDownLoading;
/**
 * @brief How long the active player-get request has been running.
 * @return The elapsed seconds, or 0 when idle.
 * @ghidraAddress 0x94078
 */
- (NSTimeInterval)getPlayerGetProgressSec;
/**
 * The backend error from the last player-get: -1 for none or in-flight, 99 for a network error,
 * otherwise the server code. Getter @ 0x99760.
 */
@property(nonatomic, assign, readonly) int errorGetPlayer;
/** The player's arcade-point balance, parsed by playerGetFinished. Getter @ 0x99720. */
@property(nonatomic, assign, readonly) int arcadePt;
/** The offered login-bonus id, parsed by playerGetFinished. Getter @ 0x99774. */
@property(nonatomic, assign, readonly) int loginBonusId;
/** The player's login count, parsed by playerGetFinished. Getter @ 0x99788. */
@property(nonatomic, assign, readonly) int loginCnt;
/** Whether the login count advanced on this fetch. Getter @ 0x9979c, setter @ 0x997b4. */
@property(nonatomic, assign) BOOL isLoginCntUpdate;

// --- News / store information ---

/**
 * @brief POST "info_id=<lastInformationId>" to the store-info URL.
 * @ghidraAddress 0x94488
 */
- (void)startNewsHttp;
/**
 * @brief Whether the news request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x9458c
 */
- (BOOL)isNewsDownLoading;
/** The scrolling-ticker text lines, parallel to newsUrlArray. Getter @ 0x997cc. */
@property(nonatomic, strong, readonly) NSArray *newsTextArray;
/** The ticker lines' tap URLs, parallel to newsTextArray. Getter @ 0x997e0. */
@property(nonatomic, strong, readonly) NSArray *newsUrlArray;
/** The parsed store-information posts, as NSValue-wrapped InformationData. Getter @ 0x9970c. */
@property(nonatomic, strong, readonly) NSArray *informationDataArray;
/** When the last news fetch completed; the ivar is _lastNewsGetTime. Getter @ 0x997f4. */
@property(nonatomic, strong, readonly) NSDate *lastGetNewsTime;
/** The server clock's year, parsed from the news "Time" field. Getter @ 0x99808. */
@property(nonatomic, assign, readonly) int serverYear;
/** The server clock's month. Getter @ 0x9981c. */
@property(nonatomic, assign, readonly) int serverMonth;
/** The server clock's day. Getter @ 0x99830. */
@property(nonatomic, assign, readonly) int serverDay;
/** The server clock's hour. Getter @ 0x99844. */
@property(nonatomic, assign, readonly) int serverHour;
/** The server clock's minute. Getter @ 0x99858. */
@property(nonatomic, assign, readonly) int serverMinute;
/** The server clock's second. Getter @ 0x9986c. */
@property(nonatomic, assign, readonly) int serverSecond;
/** Set when the store's UpdateTime is newer than the last viewed time. Getter @ 0x99880, setter @
 * 0x99898. */
@property(nonatomic, assign) BOOL isNewMusicPackReleased;
#ifdef __cplusplus
/** The C++ mode-select scene notified via modeSelectRefreshNews when news finishes. Getter @
 * 0x995ac, setter @ 0x995c0. */
@property(nonatomic, assign) ModeSelTask *cppDelegateNews;
#endif

// --- Recommend list ---

/**
 * @brief POST "uuid=<uuId>" to the recommend-list URL.
 * @ghidraAddress 0x96b54
 */
- (void)startGetRecommendListHttp;
/**
 * @brief Whether the recommend-list request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x96c68
 */
- (BOOL)isGetRecommendListDownLoading;
/** The parsed recommend list, as NSValue-wrapped RecommendData. Getter @ 0x999d4. */
@property(nonatomic, strong, readonly) NSArray *recommendDataArray;
#ifdef __cplusplus
/** The C++ music-select scene notified via musicSelUpdateInfoPanel when the fetch finishes.
 * Getter @ 0x995d8, setter @ 0x995ec. */
@property(nonatomic, assign) MainTask *cppDelegateRecommendList;
#endif

// --- Sugoroku visitor ---

/**
 * @brief POST "uuid=<uuId>&map_id=<mapId>&type=<type>" to the visitor URL.
 * @param mapId The map cell to fetch a visitor for.
 * @param type The visitor request type.
 * @ghidraAddress 0x972e4
 */
- (void)startGetVisitorHttp:(short)mapId type:(short)type;
/**
 * @brief Whether the visitor request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x97410
 */
- (BOOL)isGetVisitorDownLoading;
/** Whether the last visitor fetch stored a valid visitor. Getter @ 0x999a4, setter @ 0x999bc. */
@property(nonatomic, assign) BOOL isGetVisitorSuccess;
/** The delegate notified when the visitor request finishes. Getter @ 0x9965c, setter @
 * 0x99670. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetVisitor;

// --- Present box ---

/**
 * @brief POST "uuid=<uuId>" to the present-list URL.
 * @ghidraAddress 0x97d60
 */
- (void)startGetPresentListHttp;
/**
 * @brief Whether the present-list request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x97e74
 */
- (BOOL)isGetPresentListDownLoading;
/** The parsed present list, as NSValue-wrapped PresentData. Getter @ 0x99928. */
@property(nonatomic, strong, readonly) NSArray *presentDataArray;
/** The delegate notified when the present-list request finishes. Getter @ 0x99688, setter @
 * 0x9969c. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetPresentList;
/**
 * @brief POST "uuid=<uuId>&present_id=<id>" to claim one present.
 * @param presentId The present to claim.
 * @ghidraAddress 0x9829c
 */
- (void)startGetPresentHttp:(int)presentId;
/**
 * @brief Whether the present-claim request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x983c0
 */
- (BOOL)isGetPresentDownLoading;
/** The present id most recently claimed. Getter @ 0x9993c, setter @ 0x99950. */
@property(nonatomic, assign) int getPresentId;
/** The delegate notified when the present-claim request finishes. Getter @ 0x996b4, setter @
 * 0x996c8. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetPresent;

// --- Over-score log (friends who beat your score) ---

/**
 * @brief POST "uuid=<uuId>" to the over-score-log URL.
 * @ghidraAddress 0x984b4
 */
- (void)startGetOverScoreLogHttp;
/**
 * @brief Whether the over-score-log request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x985c8
 */
- (BOOL)isGetOverScoreLogDownLoading;
/** The parsed over-score log, as NSValue-wrapped OverScoreLogData. Getter @ 0x99968. */
@property(nonatomic, strong, readonly) NSArray *overScoreLogArray;
/** The delegate notified when the over-score-log request finishes. Getter @ 0x99a84, setter @
 * 0x99a98. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetOverScoreLog;

// --- Event info ---

/**
 * @brief POST "client_ver=<ver>" to the event-info URL.
 * @ghidraAddress 0x98a6c
 */
- (void)startGetEventInfoHttp;
/**
 * @brief Whether the event-info request is in flight.
 * @return YES while the request is running.
 * @ghidraAddress 0x98b7c
 */
- (BOOL)isGetEventInfoDownLoading;
/** The active treasure-event music ids, as an NSArray of NSNumber. Getter @ 0x999fc. */
@property(nonatomic, strong, readonly) NSArray *treasureEventIdArray;
/** Set once the treasure-event list refreshes so the scenes reload. Getter @ 0x99a24, setter @
 * 0x99a3c. */
@property(nonatomic, assign) BOOL isTreasureEventInfoUpdated;
/** Set once the game-event list refreshes so the scenes reload. Getter @ 0x99a54, setter @
 * 0x99a6c. */
@property(nonatomic, assign) BOOL isGameEventInfoUpdated;
/** The delegate notified when the event-info request finishes. Getter @ 0x996e0, setter @
 * 0x996f4. */
@property(nonatomic, assign) id<DownloadMainDelegate> delegateGetEventInfo;

// --- Sent / received friend-request lists (populated elsewhere) ---

/** Outbound friend-request player ids, parallel to frSendNameArray. Getter @ 0x998b0. */
@property(nonatomic, strong, readonly) NSArray *frSendPlayerIdArray;
/** Outbound friend-request names, parallel to frSendPlayerIdArray. Getter @ 0x998c4. */
@property(nonatomic, strong, readonly) NSArray *frSendNameArray;
/** Inbound friend-request player ids, parallel to frReceiveNameArray. Getter @ 0x998d8. */
@property(nonatomic, strong, readonly) NSArray *frReceivePlayerIdArray;
/** Inbound friend-request names, parallel to frReceivePlayerIdArray. Getter @ 0x998ec. */
@property(nonatomic, strong, readonly) NSArray *frReceiveNameArray;
/** Inbound friend-request messages, parallel to frReceivePlayerIdArray. Getter @ 0x99900. */
@property(nonatomic, strong, readonly) NSArray *frReceiveMessageArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
