//
//  DownloadMain.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Manual
//  retain/release is kept where the original manages the Downloader/list
//  lifetime.
//

#import "DownloadMain.h"

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif

#import "AppDelegate.h"
#import "OverScoreData+Store.h"
#import "OverScoreData.h"
#import "StoreUtil.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h" // neAppEventCenter::shared().setStartDate() / setEndDate()

// C++ bridge helpers the scenes expose (unmangled -> declared extern "C"). Each
// pokes its owning C++ scene when the matching download finishes. Ghidra:
// modeSelectRefreshNews
// @ 0x6d8cc, musicSelUpdateInfoPanel @ 0x37c88. Both scene classes are
// reconstructed: ModeSelTask == MenuMainTask (aliased
// in DownloadMain.h). modeSelectRefreshNews is defined in MenuMainTask.mm
// (forwards to MenuMainTask::refreshNews); musicSelUpdateInfoPanel is defined
// in MainTask.mm (forwards to MainTask::UpdateInfoPanel).
extern "C" void modeSelectRefreshNews(ModeSelTask *task, bool hasNews);
extern "C" void musicSelUpdateInfoPanel(MainTask *task, bool hasList);

// HTML-entity unescaping applied to news text / titles / bodies (mirrors the
// inline replaceOccurrencesOfString: chains in newsGetFinished).
static void unescapeNewsEntities(NSMutableString *s) {
    [s replaceOccurrencesOfString:@"&quot;"
                       withString:@"\""
                          options:NSLiteralSearch
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&lt;"
                       withString:@"<"
                          options:NSLiteralSearch
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&gt;"
                       withString:@">"
                          options:NSLiteralSearch
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&amp;"
                       withString:@"&"
                          options:NSLiteralSearch
                            range:NSMakeRange(0, s.length)];
}

// Whether push-notification registration has already been requested (Ghidra:
// the one-shot flag DAT_00187bec).
static BOOL sRegisteredForRemote = NO;

static DownloadMain *sInstance = nil; // Ghidra: DAT_00188310

@implementation DownloadMain {
    Downloader *_dlGetDlFileList;  // active file-list download (nil when idle)
    NSArray *_dlFileListDataArray; // parsed result
    Downloader *_dlGetFriendList;  // active friend-list download (nil when idle)
    NSArray *_friendListArray;     // parsed friends (NSValue-wrapped FriendListData)
    int _friendRequestedCnt;       // pending inbound friend requests
    __unsafe_unretained id<DownloadMainDelegate> _delegateGetFriendList;
    Downloader *_dlGetBlockList; // active block-list fetch
    Downloader *_dlAddBlockList; // active add-block action
    Downloader *_dlDelBlockList; // active remove-block action
    NSArray *_blPlayerIdArray;   // blocked player ids
    NSArray *_blNameArray;       // blocked player names (parallel to ids)
    Downloader *_dlCancelFriend; // active cancel-friend-request action
    __unsafe_unretained id<DownloadMainDelegate> _delegateCancelFriend;
    Downloader *_dlSaveTreasure; // active treasure-save action

    Downloader *_dlGetPlayer;        // active player-get (login/profile) request
    Downloader *_dlNews;             // active store-info (news) request
    Downloader *_dlSaveScore;        // active score-save upload
    Downloader *_dlGetRecommendList; // active recommend-list request
    Downloader *_dlGetVisitor;       // active sugoroku-visitor request
    Downloader *_dlGetPresentList;   // active present-list request
    Downloader *_dlGetPresent;       // active present-claim request
    Downloader *_dlGetOverScoreLog;  // active over-score-log request
    Downloader *_dlGetEventInfo;     // active event-info request

    int _saveMusic;             // music id being uploaded (for saveScoreFinished)
    short _saveSheet;           // sheet being uploaded (for saveScoreFinished)
    NSString *_storeUpdateTime; // store "UpdateTime" string (drives new-pack flag)
}

// @ 0x93dd4 — construct the singleton once, guarded by @synchronized.
// @complete
+ (instancetype)getInstance {
    @synchronized(self) {
        if (sInstance == nil) {
            sInstance = [[DownloadMain alloc] init];
        }
    }
    return sInstance;
}

// @ 0x93ec0 — real teardown: unbox the retained struct fields of the friend and
// recommend arrays before they drop (ARC calls [super dealloc]).
// @complete
- (void)dealloc {
    [self releaseFriendList];
    [self releaseRecommendData];
}

// @ 0x979d8 — a request is in flight while its Downloader exists.
// @complete
- (BOOL)isGetDlFileListDownLoading {
    return _dlGetDlFileList != nil;
}

// @ 0x999e8
// @complete
- (NSArray *)dlFileListDataArray {
    return _dlFileListDataArray;
}

// @ 0x978ac — POST "target=<store>&file_id=<id>&client_ver=<ver>" to the
// file-list URL through a Downloader (with self as delegate) and start it.
// No-op if already downloading.
// @complete
- (void)startGetDlFileListHttp:(int)fileId {
    if (_dlGetDlFileList != nil) {
        return;
    }
    int clientVer = AppDelegate.appDelegate.appVersionNum;
    NSString *body = [NSString stringWithFormat:@"target=%@&file_id=%d&client_ver=%d",
                                                [StoreUtil targetStore],
                                                fileId,
                                                clientVer];
    // The ContextType literal at 0x979a8 resolves to the "application/json"
    // CFString (data @ 0x102bd8), not a form-urlencoded type.
    _dlGetDlFileList = [[Downloader alloc] initWithURL:[StoreUtil getDlFileListURL]
                                              delegate:self
                                                  Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                           ContextType:@"application/json"];
    [_dlGetDlFileList startDownloading];
}

// @ 0x98f78 — DownloaderDelegate: route a finished download to the handler that
// owns the matching Downloader. (The treasure-save case just frees its
// downloader inline.)
// @complete
- (void)downloaderFinished:(Downloader *)downloader {
    if (downloader == _dlGetPlayer) {
        [self playerGetFinished];
    } else if (downloader == _dlNews) {
        [self newsGetFinished];
    } else if (downloader == _dlSaveScore) {
        [self saveScoreFinished];
    } else if (downloader == _dlCancelFriend) {
        [self cancelFriendFinished];
    } else if (downloader == _dlGetFriendList) {
        [self getFriendListFinished];
    } else if (downloader == _dlAddBlockList) {
        [self addBlockListFinished];
    } else if (downloader == _dlGetBlockList) {
        [self getBlockListFinished];
    } else if (downloader == _dlDelBlockList) {
        [self delBlockListFinished];
    } else if (downloader == _dlGetRecommendList) {
        [self getRecommendListFinished];
    } else if (downloader == _dlGetVisitor) {
        [self getVisitorFinished];
    } else if (downloader == _dlSaveTreasure) {
        _dlSaveTreasure = nil;
    } else if (downloader == _dlGetDlFileList) {
        [self getDlFileListFinished];
    } else if (downloader == _dlGetPresentList) {
        [self getPresentListFinished];
    } else if (downloader == _dlGetPresent) {
        [self getPresentFinished];
    } else if (downloader == _dlGetOverScoreLog) {
        [self getOverScoreLogFinished];
    } else if (downloader == _dlGetEventInfo) {
        [self getEventInfoFinished];
    }
}

// @ 0x9918c — proceed callbacks are ignored.
// @complete
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0x99190 — a download failed: free the matching Downloader and notify the
// owning delegate / C++ scene with a failure result, mirroring each *Finished's
// teardown.
// @complete
- (void)downloaderError:(Downloader *)downloader {
    if (downloader == _dlGetPlayer) {
        _errorGetPlayer = 99;
        _dlGetPlayer = nil;
    } else if (downloader == _dlNews) {
        _dlNews = nil;
        if (_cppDelegateNews != NULL) {
            modeSelectRefreshNews(_cppDelegateNews, false);
        }
    } else if (downloader == _dlSaveScore) {
        _dlSaveScore = nil;
    } else if (downloader == _dlCancelFriend) {
        _dlCancelFriend = nil;
        if ([_delegateCancelFriend respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateCancelFriend performSelector:@selector(downloadMainFinished:)
                                        withObject:[NSNumber numberWithBool:NO]];
        }
    } else if (downloader == _dlGetFriendList) {
        _dlGetFriendList = nil;
        if ([_delegateGetFriendList respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetFriendList performSelector:@selector(downloadMainFinished:)
                                         withObject:[NSNumber numberWithBool:NO]];
        }
    } else if (downloader == _dlAddBlockList) {
        _dlAddBlockList = nil;
    } else if (downloader == _dlGetBlockList) {
        _dlGetBlockList = nil;
    } else if (downloader == _dlDelBlockList) {
        _dlDelBlockList = nil;
    } else if (downloader == _dlGetRecommendList) {
        _dlGetRecommendList = nil;
        if (_cppDelegateRecommendList != NULL) {
            musicSelUpdateInfoPanel(_cppDelegateRecommendList, false);
        }
    } else if (downloader == _dlSaveTreasure) {
        _dlSaveTreasure = nil;
    } else if (downloader == _dlGetVisitor) {
        _dlGetVisitor = nil;
        if ([_delegateGetVisitor respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetVisitor performSelector:@selector(downloadMainFinished:)
                                      withObject:[NSNumber numberWithBool:NO]];
        }
    } else if (downloader == _dlGetDlFileList) {
        _dlGetDlFileList = nil;
    } else if (downloader == _dlGetPresentList) {
        _dlGetPresentList = nil;
        if ([_delegateGetPresentList respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetPresentList performSelector:@selector(downloadMainFinished:)
                                          withObject:[NSNumber numberWithInt:-1]];
        }
    } else if (downloader == _dlGetPresent) {
        _dlGetPresent = nil;
        if ([_delegateGetPresent respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetPresent performSelector:@selector(downloadMainFinished:)
                                      withObject:[NSNumber numberWithInt:-1]];
        }
    } else if (downloader == _dlGetOverScoreLog) {
        _dlGetOverScoreLog = nil;
        if ([_delegateGetOverScoreLog respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetOverScoreLog performSelector:@selector(downloadMainFinished:)
                                           withObject:[NSNumber numberWithBool:NO]];
        }
    } else if (downloader == _dlGetEventInfo) {
        _dlGetEventInfo = nil;
        _treasureEventIdArray = nil;
        _isTreasureEventInfoUpdated = YES;
        _isGameEventInfoUpdated = YES;
        if ([_delegateGetEventInfo respondsToSelector:@selector(downloadMainFinished:)]) {
            [_delegateGetEventInfo performSelector:@selector(downloadMainFinished:)
                                        withObject:[NSNumber numberWithBool:NO]];
        }
    }
}

// @ 0x979f0 — unbox each DlFileListData (its retained url field) before
// dropping the array.
// @complete
- (void)releaseFileListData {
    if (_dlFileListDataArray == nil) {
        return;
    }
    for (NSValue *value in _dlFileListDataArray) {
        DlFileListData data;
        [value getValue:&data];
    }
    _dlFileListDataArray = nil;
}

// @ 0x97af4 — the file-list download finished: parse the JSON. If there is no
// "ErrorCode" and a "List" array is present, turn each {Id, Url, Size} entry
// into a DlFileListData wrapped in an NSValue, and keep them as an immutable
// array.
// @complete
- (void)getDlFileListFinished {
    NSDictionary *json = [_dlGetDlFileList getDataInJSON];
    if (json[@"ErrorCode"] == nil) {
        NSArray *list = json[@"List"];
        if (list != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in list) {
                DlFileListData data;
                data.fileId = [entry[@"Id"] intValue];
                data.url = entry[@"Url"];
                data.size = [entry[@"Size"] intValue];
                [out addObject:[NSValue value:&data withObjCType:@encode(DlFileListData)]];
            }
            [self releaseFileListData];
            _dlFileListDataArray = [[NSArray alloc] initWithArray:out];
        }
    }
    _dlGetDlFileList = nil;
}

#pragma mark - Friend list

// @ 0x99914 / 0x99734 — atomic accessors.
// @complete
- (NSArray *)friendListArray {
    return _friendListArray;
}

// @complete
- (int)friendRequestedCnt {
    return _friendRequestedCnt;
}

// @ 0x99748 — updated by the reply screen after fetching/answering requests.
// @complete
- (void)setFriendRequestedCnt:(int)cnt {
    _friendRequestedCnt = cnt;
}

// @ 0x99604 / 0x99618 — atomic delegate accessors (assign).
// @complete
- (id<DownloadMainDelegate>)delegateGetFriendList {
    return _delegateGetFriendList;
}

// @complete
- (void)setDelegateGetFriendList:(id<DownloadMainDelegate>)delegate {
    _delegateGetFriendList = delegate;
}

// @ 0x958a8
// @complete
- (BOOL)isGetFriendListDownLoading {
    return _dlGetFriendList != nil;
}

// @ 0x95794 — POST "uuid=<uuId>" to the friend-list endpoint. No-op if in
// flight.
// @complete
- (void)startGetFriendListHttp {
    if (_dlGetFriendList != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    _dlGetFriendList = [[Downloader alloc] initWithURL:[StoreUtil getFriendListURL]
                                              delegate:self
                                                  Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                           ContextType:@"application/json"];
    [_dlGetFriendList startDownloading];
}

// @ 0x958c0 — unbox each friend struct and release its two retained NSString
// fields, then drop the array.
// @complete
- (void)releaseFriendList {
    if (_friendListArray == nil) {
        return;
    }
    for (NSValue *value in _friendListArray) {
        FriendListData data;
        [value getValue:&data];
    }
    _friendListArray = nil;
}

// @ 0x959d4 — parse the friend-list JSON into FriendListData structs, or fail
// on an "ErrorCode". Notifies the delegate with an NSNumber success flag.
// The compiler flattened the nested key-building loops into a set of parallel
// temp arrays; the ObjCType encode @ 0x108ec4 is
// "{FriendListData=@@siii[3[7i]][3i][3i]}" and the fullCombo/perfect derivation
// loop @ 0x96312 clamps (fullCombo - perfect) at 0.
// @complete
- (void)getFriendListFinished {
    // Rank key prefixes per difficulty (N / H / Ex).
    static NSString *const kDiff[3] = {@"N", @"H", @"Ex"};
    static NSString *const kRankSuffix[5] = {@"S", @"AAA", @"AA", @"A", @"B"};

    BOOL success = NO;
    NSDictionary *json = [_dlGetFriendList getDataInJSON];
    if (json[@"ErrorCode"] == nil) {
        NSArray *friends = json[@"Friend"];
        if (friends != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in friends) {
                FriendListData data;
                data.playerId = entry[@"PlayerId"];
                data.name = entry[@"Name"];
                data.charaId = (short)[entry[@"CharaId"] intValue];
                data.totalScore = [entry[@"TotalScore"] intValue];
                data.bestScore = [entry[@"BestScore"] intValue];
                data.friendShip = [entry[@"FriendShip"] intValue];
                if (data.friendShip > 100) {
                    data.friendShip = 100;
                }
                for (int d = 0; d < 3; d++) {
                    for (int r = 0; r < 5; r++) {
                        NSString *key =
                            [NSString stringWithFormat:@"Rank%@%@", kDiff[d], kRankSuffix[r]];
                        data.rank[d][r] = [entry[key] intValue];
                    }
                    int fullCombo =
                        [entry[[@"FullCombo" stringByAppendingString:kDiff[d]]] intValue];
                    int perfect = [entry[[@"Perfect" stringByAppendingString:kDiff[d]]] intValue];
                    // The binary derives fullComboOnly/perfect from these but does not
                    // store fullCombo/perfect back into rank[d][5]/rank[d][6].
                    data.fullComboOnly[d] = (fullCombo - perfect > 0) ? (fullCombo - perfect) : 0;
                    data.perfect[d] = perfect;
                }
                [out addObject:[NSValue value:&data withObjCType:@encode(FriendListData)]];
            }
            [self releaseFriendList];
            _friendListArray = [[NSArray alloc] initWithArray:out];
        }
        success = YES;
    }

    _dlGetFriendList = nil;

    if ([_delegateGetFriendList respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetFriendList performSelector:@selector(downloadMainFinished:)
                                     withObject:[NSNumber numberWithBool:success]];
    }
}

#pragma mark - Block list

// @ 0x9997c / 0x99990 — the parsed blocked-player id/name arrays (parallel).
// @complete
- (NSArray *)blPlayerIdArray {
    return _blPlayerIdArray;
}

// @ 0x99990
// @complete
- (NSArray *)blNameArray {
    return _blNameArray;
}

// @ 0x9658c / 0x96710
// @complete
- (BOOL)isAddBlockListDownLoading {
    return _dlAddBlockList != nil;
}

// @complete
- (BOOL)isGetBlockListDownLoading {
    return _dlGetBlockList != nil;
}

// @ 0x96ae4
// @complete
- (BOOL)isDelBlockListDownLoading {
    return _dlDelBlockList != nil;
}

// POST "uuid=<uuId>" to fetch the block list. Shared body builder for the two
// GETs.
- (Downloader *)blockDownloaderForURL:(NSURL *)url
                             uuidBody:(BOOL)uuidOnly
                             playerId:(NSString *)playerId {
    NSString *body;
    if (uuidOnly) {
        body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    } else {
        body = [NSString
            stringWithFormat:@"uuid=%@&player_id=%@", AppDelegate.appDelegate.uuId, playerId];
    }
    Downloader *downloader =
        [[Downloader alloc] initWithURL:url
                               delegate:self
                                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                            ContextType:@"application/json"];
    [downloader startDownloading];
    return downloader;
}

// @ 0x965fc
// @complete
- (void)startGetBlockListHttp {
    if (_dlGetBlockList != nil) {
        return;
    }
    _dlGetBlockList = [self blockDownloaderForURL:[StoreUtil getBlockListURL]
                                         uuidBody:YES
                                         playerId:nil];
}

// @ 0x96440 — block a player; refuses to block yourself. No-op if already
// running.
// @complete
- (void)startAddBlockListHttp:(NSString *)playerId {
    if ([playerId isEqualToString:[UserSettingData playerId]]) {
        return;
    }
    if (_dlAddBlockList != nil) {
        return;
    }
    _dlAddBlockList = [self blockDownloaderForURL:[StoreUtil addBlockListURL]
                                         uuidBody:NO
                                         playerId:playerId];
}

// @ 0x969cc — unblock a player. No-op if already running.
// @complete
- (void)startDelBlockListHttp:(NSString *)playerId {
    if (_dlDelBlockList != nil) {
        return;
    }
    _dlDelBlockList = [self blockDownloaderForURL:[StoreUtil delBlockListURL]
                                         uuidBody:NO
                                         playerId:playerId];
}

// @ 0x96728 — parse the block list into parallel id/name arrays.
// @complete
- (void)getBlockListFinished {
    NSDictionary *json = [_dlGetBlockList getDataInJSON];
    if (json[@"ErrorCode"] == nil) {
        NSArray *block = json[@"Block"];
        if (block.count != 0) {
            NSMutableArray *ids = [NSMutableArray array];
            NSMutableArray *names = [NSMutableArray array];
            for (NSDictionary *entry in block) {
                NSString *pid = entry[@"PlayerId"];
                NSString *name = entry[@"Name"];
                if (pid != nil && name != nil) {
                    [ids addObject:pid];
                    [names addObject:name];
                }
            }
            _blPlayerIdArray = [[NSArray alloc] initWithArray:ids];
            _blNameArray = [[NSArray alloc] initWithArray:names];
        }
    }
    _dlGetBlockList = nil;
}

// @ 0x965a4 / 0x96afc — the mutations read the response and, when there is a
// body, probe ErrorCode (without acting on it) before freeing the downloader.
// @complete
- (void)addBlockListFinished {
    NSDictionary *json = [_dlAddBlockList getDataInJSON];
    if (json != nil) {
        (void)json[@"ErrorCode"];
    }
    _dlAddBlockList = nil;
}

// @complete
- (void)delBlockListFinished {
    NSDictionary *json = [_dlDelBlockList getDataInJSON];
    if (json != nil) {
        (void)json[@"ErrorCode"];
    }
    _dlDelBlockList = nil;
}

#pragma mark - Cancel friend request

// @ 0x99630 / 0x99644 — atomic delegate accessors (assign).
// @complete
- (id<DownloadMainDelegate>)delegateCancelFriend {
    return _delegateCancelFriend;
}

// @complete
- (void)setDelegateCancelFriend:(id<DownloadMainDelegate>)delegate {
    _delegateCancelFriend = delegate;
}

// @ 0x9566c
// @complete
- (BOOL)isCancelFriendDownLoading {
    return _dlCancelFriend != nil;
}

// @ 0x95554 — cancel an outbound friend request to playerId. No-op if in
// flight.
// @complete
- (void)startCancelFriendHttp:(NSString *)playerId {
    if (_dlCancelFriend != nil) {
        return;
    }
    NSString *body =
        [NSString stringWithFormat:@"uuid=%@&player_id=%@", AppDelegate.appDelegate.uuId, playerId];
    _dlCancelFriend = [[Downloader alloc] initWithURL:[StoreUtil cancelFriendURL]
                                             delegate:self
                                                 Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                          ContextType:@"application/json"];
    [_dlCancelFriend startDownloading];
}

// @ 0x95684 — finish: notify the delegate. The reported flag is (json == nil),
// exactly as in the binary (it signals the no-response / error state).
// @complete
- (void)cancelFriendFinished {
    NSDictionary *json = [_dlCancelFriend getDataInJSON];
    // The original (when json is non-nil) reads ErrorCode and probes it with
    // isKindOfClass:NSNumber without acting on the result; only the presence of a
    // JSON body drives the delegate flag. The probe is an inert, side-effect-free
    // call, so it is elided here.
    (void)json[@"ErrorCode"];

    _dlCancelFriend = nil;

    if ([_delegateCancelFriend respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateCancelFriend performSelector:@selector(downloadMainFinished:)
                                    withObject:[NSNumber numberWithBool:(json == nil)]];
    }
}

#pragma mark - Save treasure (sugoroku reward)

// @ 0x97698 — POST the player's collected pieces for a map cell to the server.
// mapId encodes main/sub as (mapId / 10, mapId % 10).
// @complete
- (void)startSaveTreasureHttp:(short)mapId visitor:(NSString *)visitor friendship:(int)friendship {
    if (_dlSaveTreasure != nil) {
        return;
    }
    NSManagedObjectContext *context = AppDelegate.appDelegate.managedObjectContext;
    TreasureData *treasure = [TreasureData getTreasureData:mapId / 10
                                                  subMapId:mapId % 10
                                    inManagedObjectContext:context];
    short charaId = [UserSettingData charaId];
    int musicPiece = [treasure.musicPiece intValue];
    int wallPiece = [treasure.wallPaperPiece intValue];

    NSString *body =
        [NSString stringWithFormat:@"uuid=%@&chara_id=%d&map_id=%d&music_piece=%d&wall_piece=%d"
                                   @"&visitor=%@&friendship=%d",
                                   AppDelegate.appDelegate.uuId,
                                   charaId,
                                   mapId,
                                   musicPiece,
                                   wallPiece,
                                   visitor,
                                   friendship];
    _dlSaveTreasure = [[Downloader alloc] initWithURL:[StoreUtil saveTreasureURL]
                                             delegate:self
                                                 Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                          ContextType:@"application/json"];
    [_dlSaveTreasure startDownloading];
}

- (void)saveTreasureFinished {
    _dlSaveTreasure = nil;
}

// @ 0x97894
// @complete
- (BOOL)isSaveTreasureDownLoading {
    return _dlSaveTreasure != nil;
}

#pragma mark - Player-get (login / profile)

// @ 0x93f14 — POST "uuid=<url-encoded uuId>&client_ver=<ver>" to the player-get
// URL and mark errorGetPlayer as in-flight (-1). No-op if already running.
// @complete
- (void)startPlayerGetHttp {
    if (_dlGetPlayer != nil) {
        return;
    }
    int clientVer = AppDelegate.appDelegate.appVersionNum;
    NSString *body = [NSString stringWithFormat:@"uuid=%@&client_ver=%d",
                                                urlEncodeString(AppDelegate.appDelegate.uuId),
                                                clientVer];
    _dlGetPlayer = [[Downloader alloc] initWithURL:[StoreUtil playerGetURL]
                                          delegate:self
                                              Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                       ContextType:@"application/json"];
    _errorGetPlayer = -1;
    [_dlGetPlayer startDownloading];
}

// @ 0x94060
// @complete
- (BOOL)isPlayerGetDownLoading {
    return _dlGetPlayer != nil;
}

// @ 0x94078 — the active player-get Downloader's elapsed seconds (0 when idle).
// @complete
- (NSTimeInterval)getPlayerGetProgressSec {
    if ([self isPlayerGetDownLoading]) {
        return [_dlGetPlayer getProgressSec];
    }
    return 0.0;
}

// @ 0x940c4 — parse the player profile. When every expected field has the right
// type, persist it (invite count, arcade points, pending friend requests, login
// bonus/count) and request push registration once; otherwise record the error
// code (99 when absent). The registerForRemoteNotificationTypes:0x7 path @
// 0x9447a (Badge|Sound|Alert) is the shipped iOS 8 call; the UNUserNotification
// branch is a modern-SDK equivalent.
// @complete
- (void)playerGetFinished {
    NSDictionary *json = [_dlGetPlayer getDataInJSON];
    if (json != nil) {
        id playerId = json[@"PlayerId"];
        id playerName = json[@"PlayerName"];
        id inviteCnt = json[@"InviteCnt"];
        id arcadePt = json[@"ArcadePt"];
        id friendRequested = json[@"FriendRequested"];
        id updateDate = json[@"UpdateDate"];
        id loginBonusId = json[@"LoginBonusId"];
        id loginCount = json[@"LoginCount"];
        id login = json[@"Login"];
        if ([playerId isKindOfClass:[NSString class]] &&
            [inviteCnt isKindOfClass:[NSNumber class]] &&
            [arcadePt isKindOfClass:[NSNumber class]] &&
            [friendRequested isKindOfClass:[NSNumber class]] &&
            [updateDate isKindOfClass:[NSString class]] &&
            [loginBonusId isKindOfClass:[NSNumber class]] &&
            [loginCount isKindOfClass:[NSNumber class]] && [login isKindOfClass:[NSNumber class]]) {
            [UserSettingData saveInviteCnt:[inviteCnt intValue]];
            _arcadePt = [arcadePt intValue];
            _friendRequestedCnt = [friendRequested intValue];
            // Refresh the login bonus/count when the server flags a new login, or the
            // first time when the flag has not yet been set this session.
            if ([login boolValue]) {
                _isLoginCntUpdate = YES;
                _loginBonusId = [loginBonusId intValue];
                _loginCnt = [loginCount intValue];
            } else if (!_isLoginCntUpdate) {
                _loginBonusId = [loginBonusId intValue];
                _loginCnt = [loginCount intValue];
            }
            [UserSettingData savePlayerId:playerId];
            [UserSettingData savePlayerName:playerName];
            // @ 0x29274 — mark the session start time now the login (player-get)
            // response has parsed. Ghidra: NEAppEventCenter_shared();
            // setStartDate(&g_pNeAppEventCenter).
            neAppEventCenter::shared().setStartDate();
            _errorGetPlayer = -1;
            if (!sRegisteredForRemote) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                // The original UIRemoteNotificationTypeBadge/Sound/Alert flags map
                // to the corresponding UNAuthorizationOption flags.
                [[UNUserNotificationCenter currentNotificationCenter]
                    requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                                     UNAuthorizationOptionBadge |
                                                     UNAuthorizationOptionSound)
                                  completionHandler:^(BOOL granted, NSError *error){
                                  }];
                [[UIApplication sharedApplication] registerForRemoteNotifications];
#else
                [[UIApplication sharedApplication]
                    registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                        UIRemoteNotificationTypeSound |
                                                        UIRemoteNotificationTypeAlert)];
#endif
                sRegisteredForRemote = YES;
            }
            _dlGetPlayer = nil;
            return;
        }
    }
    // Error path: use the server ErrorCode, or 99 when there is no body / code.
    id errorCode = json[@"ErrorCode"];
    if (errorCode == nil) {
        _errorGetPlayer = 99;
    } else {
        _errorGetPlayer = [errorCode intValue];
    }
    _dlGetPlayer = nil;
}

#pragma mark - News / store information

// @ 0x94488 — POST "info_id=<lastInformationId>" to the store-info URL. No-op
// if running.
// @complete
- (void)startNewsHttp {
    if (_dlNews != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"info_id=%d", [UserSettingData lastInformationId]];
    _dlNews = [[Downloader alloc] initWithURL:[StoreUtil storeNewInfoURL]
                                     delegate:self
                                         Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                  ContextType:@"application/json"];
    [_dlNews startDownloading];
}

// @ 0x9458c
// @complete
- (BOOL)isNewsDownLoading {
    return _dlNews != nil;
}

// @ 0x945a4 — unbox each InformationData (its retained title/body) before
// dropping.
// @complete
- (void)releaseInformationData {
    if (_informationDataArray == nil) {
        return;
    }
    for (NSValue *value in _informationDataArray) {
        InformationData data;
        [value getValue:&data];
    }
    _informationDataArray = nil;
}

// @ 0x946b8 — parse the news response: the server clock, the store "new pack"
// flag, the scrolling ticker (text + tap URL), and the information posts. Pokes
// the C++ mode-select scene with whether ticker text was parsed.
// @complete
- (void)newsGetFinished {
    _lastGetNewsTime = [NSDate date];

    NSDictionary *json = [_dlNews getDataInJSON];
    id updateTime = json[@"UpdateTime"];
    id updateText = json[@"UpdateText"];
    id timeStr = json[@"Time"];
    id information = json[@"Information"];

    // Server clock, formatted "Y-M-D H:M:S": split on space; the date half is
    // split on '-' (separator @ 0x107202) and the time half on ':' (separator @
    // 0x107810).
    if (timeStr != nil && [timeStr isKindOfClass:[NSString class]]) {
        int y = 0, mo = 0, d = 0, h = 0, mi = 0, s = 0;
        NSArray *halves = [timeStr componentsSeparatedByString:@" "];
        if (halves.count != 0) {
            NSArray *date = [[halves objectAtIndex:0] componentsSeparatedByString:@"-"];
            if (date.count > 2) {
                y = [[date objectAtIndex:0] intValue];
                mo = [[date objectAtIndex:1] intValue];
                d = [[date objectAtIndex:2] intValue];
            }
        }
        if (halves.count >= 2) {
            NSArray *time = [[halves objectAtIndex:1] componentsSeparatedByString:@":"];
            if (time.count >= 3) {
                h = [[time objectAtIndex:0] intValue];
                mi = [[time objectAtIndex:1] intValue];
                s = [[time objectAtIndex:2] intValue];
            }
        }
        _serverYear = y;
        _serverMonth = mo;
        _serverDay = d;
        _serverHour = h;
        _serverMinute = mi;
        _serverSecond = s;
    }

    // Store "UpdateTime": remember it, and flag a new music pack when it
    // post-dates the last time the store was viewed (numeric comparison).
    if (updateTime != nil && [updateTime isKindOfClass:[NSString class]]) {
        _storeUpdateTime = [[NSString alloc] initWithString:updateTime];
        NSString *lastView = [UserSettingData lastStoreViewTimeString];
        if (lastView == nil || [lastView compare:_storeUpdateTime
                                         options:NSNumericSearch] == NSOrderedAscending) {
            _isNewMusicPackReleased = YES;
        }
    }

    // Ticker lines: unescape HTML, split each on "@NEWSLINK=" (separator @
    // 0x108d70) into text + tap URL.
    BOOL hasNews = NO;
    if (updateText != nil && [updateText isKindOfClass:[NSArray class]] &&
        [updateText count] != 0) {
        NSMutableArray *texts = [[NSMutableArray alloc] init];
        NSMutableArray *urls = [[NSMutableArray alloc] init];
        for (NSString *entry in updateText) {
            if ([entry length] != 0) {
                NSMutableString *line = [[NSMutableString alloc] initWithString:entry];
                unescapeNewsEntities(line);
                NSArray *parts = [line componentsSeparatedByString:@"@NEWSLINK="];
                [texts addObject:[parts objectAtIndex:0]];
                if (parts.count < 2) {
                    [urls addObject:@""];
                } else {
                    [urls addObject:[parts objectAtIndex:1]];
                }
            }
        }
        _newsTextArray = [[NSArray alloc] initWithArray:texts];
        _newsUrlArray = [[NSArray alloc] initWithArray:urls];
        hasNews = YES;
    }

    // Information posts -> informationDataArray.
    [self releaseInformationData];
    if (information != nil && [information isKindOfClass:[NSArray class]] &&
        [information count] != 0) {
        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *entry in information) {
            InformationData data;
            data.informationId = [entry[@"Id"] intValue];
            NSMutableString *title = [[NSMutableString alloc] initWithString:entry[@"Title"]];
            unescapeNewsEntities(title);
            NSMutableString *body = [[NSMutableString alloc] initWithString:entry[@"Body"]];
            unescapeNewsEntities(body);
            [body replaceOccurrencesOfString:@"<br>"
                                  withString:@"\n"
                                     options:NSLiteralSearch
                                       range:NSMakeRange(0, body.length)];
            [body replaceOccurrencesOfString:@"<BR>"
                                  withString:@"\n"
                                     options:NSLiteralSearch
                                       range:NSMakeRange(0, body.length)];
            data.title = title;
            data.body = body;
            [out addObject:[NSValue value:&data withObjCType:@encode(InformationData)]];
        }
        _informationDataArray = [[NSArray alloc] initWithArray:out];
    }

    if (_cppDelegateNews != NULL) {
        modeSelectRefreshNews(_cppDelegateNews, hasNews);
    }
    _dlNews = nil;
}

#pragma mark - Score upload

// @ 0x952d4 — POST the finished play's score. Remembers music/sheet so
// saveScoreFinished can clear the "unsent" mark on success. No-op if already
// uploading.
// @complete
- (void)startSaveScoreHttp:(int)music
                     sheet:(short)sheet
                     score:(int)score
                     medal:(int)medal
                   charaId:(int)charaId {
    if (_dlSaveScore != nil) {
        return;
    }
    _saveMusic = music;
    _saveSheet = sheet;
    NSString *body =
        [NSString stringWithFormat:@"uuid=%@&music=%09d&sheet=%d&score=%d&medal=%d&charaId=%d",
                                   AppDelegate.appDelegate.uuId,
                                   music,
                                   sheet,
                                   score,
                                   medal,
                                   charaId];
    _dlSaveScore = [[Downloader alloc] initWithURL:[StoreUtil saveScoreURL]
                                          delegate:self
                                              Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                       ContextType:@"application/json"];
    [_dlSaveScore startDownloading];
}

// @ 0x9541c
// @complete
- (BOOL)isSaveScoreDownLoading {
    return _dlSaveScore != nil;
}

// @ 0x95434 — on an "Update" number, clear the pending-upload mark for the
// saved music/sheet; otherwise the original just probes ErrorCode without
// acting on it.
// @complete
- (void)saveScoreFinished {
    NSDictionary *json = [_dlSaveScore getDataInJSON];
    if (json != nil) {
        if ([json[@"Update"] isKindOfClass:[NSNumber class]]) {
            [UserSettingData subUncompleteSaveMusic:_saveMusic sheet:_saveSheet];
        } else {
            (void)[json[@"ErrorCode"] isKindOfClass:[NSNumber class]];
        }
    }
    _dlSaveScore = nil;
}

#pragma mark - Recommend list

// @ 0x96b54 — POST "uuid=<uuId>" to the recommend-list URL. No-op if already
// running.
// @complete
- (void)startGetRecommendListHttp {
    if (_dlGetRecommendList != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    _dlGetRecommendList =
        [[Downloader alloc] initWithURL:[StoreUtil getRecommendListURL]
                               delegate:self
                                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                            ContextType:@"application/json"];
    [_dlGetRecommendList startDownloading];
}

// @ 0x96c68
// @complete
- (BOOL)isGetRecommendListDownLoading {
    return _dlGetRecommendList != nil;
}

// @ 0x96c80 — unbox each RecommendData (its four retained fields) before
// dropping.
// @complete
- (void)releaseRecommendData {
    if (_recommendDataArray == nil) {
        return;
    }
    for (NSValue *value in _recommendDataArray) {
        RecommendData data;
        [value getValue:&data];
    }
    _recommendDataArray = nil;
}

// @ 0x96db0 — comparator (used via sortedArrayUsingSelector:) that orders two
// NSValue-wrapped RecommendData elements by their updateDate string.
// @complete
- (NSComparisonResult)compareToUpdateDate:(id)other {
    RecommendData a, b;
    [(NSValue *)self getValue:&a];
    [(NSValue *)other getValue:&b];
    return [a.updateDate localizedCaseInsensitiveCompare:b.updateDate];
}

// @ 0x96df0 — parse the recommend "List" into recommendDataArray, and merge the
// "Over" (a friend beat your score) records into the CoreData over-score store.
// Pokes the C++ music-select scene with whether a list was parsed.
// @complete
- (void)getRecommendListFinished {
    NSDictionary *json = [_dlGetRecommendList getDataInJSON];
    BOOL hasList = NO;
    if (json[@"ErrorCode"] == nil) {
        NSArray *list = json[@"List"];
        if (list != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in list) {
                RecommendData data;
                data.packId = [entry[@"PackId"] intValue];
                data.url = entry[@"Url"];
                data.packName = entry[@"PackName"];
                data.updateDate = entry[@"UpdateDate"];
                data.name = entry[@"Name"];
                [out addObject:[NSValue value:&data withObjCType:@encode(RecommendData)]];
            }
            hasList = YES;
            [self releaseRecommendData];
            _recommendDataArray = [[NSArray alloc] initWithArray:out];
            // @ 0x292c0 — mark the session end time now the recommend-list fetch (the
            // last event of the download cycle) has parsed. Ghidra:
            // NEAppEventCenter_shared(); setEndDate(&g_pNeAppEventCenter).
            neAppEventCenter::shared().setEndDate();
        }
        NSArray *over = json[@"Over"];
        if (over != nil) {
            NSManagedObjectContext *context = AppDelegate.appDelegate.managedObjectContext;
            for (NSDictionary *entry in over) {
                id music = entry[@"Music"];
                id sheet = entry[@"Sheet"];
                NSString *playerId = entry[@"PlayerId"];
                NSString *updateDate = entry[@"UpdateDate"];
                OverScoreData *rec = [OverScoreData updateOverScoreDateWithMusic:[music intValue]
                                                                           sheet:[sheet shortValue]
                                                                        playerId:playerId
                                                                            date:updateDate
                                                          inManagedObjectContext:context];
                if (rec == nil) {
                    [OverScoreData addRecordWithMusic:[music intValue]
                                                sheet:[sheet shortValue]
                                             playerId:playerId
                                                 date:updateDate
                               inManagedObjectContext:context];
                }
            }
        }
    }
    _dlGetRecommendList = nil;
    if (_cppDelegateRecommendList != NULL) {
        musicSelUpdateInfoPanel(_cppDelegateRecommendList, hasList);
    }
}

#pragma mark - Sugoroku visitor

// @ 0x972e4 — POST "uuid=<uuId>&map_id=<mapId>&type=<type>" to the visitor URL.
// Clears the success flag first. No-op if already running.
// @complete
- (void)startGetVisitorHttp:(short)mapId type:(short)type {
    if (_dlGetVisitor != nil) {
        return;
    }
    _isGetVisitorSuccess = NO;
    NSString *body = [NSString stringWithFormat:@"uuid=%@&map_id=%d&type=%d",
                                                AppDelegate.appDelegate.uuId,
                                                (int)mapId,
                                                (int)type];
    _dlGetVisitor = [[Downloader alloc] initWithURL:[StoreUtil getVisitorURL]
                                           delegate:self
                                               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                        ContextType:@"application/json"];
    [_dlGetVisitor startDownloading];
}

// @ 0x97410
// @complete
- (BOOL)isGetVisitorDownLoading {
    return _dlGetVisitor != nil;
}

// @ 0x97428 — when a valid visitor (id/name/chara + both piece counts) is
// returned, stash it into the pending-treasure record and flag success; notify
// the delegate.
// @complete
- (void)getVisitorFinished {
    NSDictionary *json = [_dlGetVisitor getDataInJSON];
    _isGetVisitorSuccess = NO;
    if (json[@"ErrorCode"] == nil) {
        NSString *playerId = json[@"PlayerId"];
        NSString *name = json[@"Name"];
        id charaId = json[@"CharaId"];
        id musicPiece = json[@"MusicPiece"];
        id wallPiece = json[@"WallPiece"];
        id friendship = json[@"Friendship"];
        if (playerId != nil && name != nil && charaId != nil && musicPiece != nil &&
            wallPiece != nil) {
            TreasureTmpData tmp = [UserSettingData treasureTmp];
            strncpy(tmp.friendPlayerId, [playerId UTF8String], 8);
            strncpy(tmp.goalName, [name UTF8String], 13);
            tmp.friendPlayerId[7] = '\0';
            tmp.goalName[12] = '\0';
            tmp.goalCharaId = [charaId shortValue];
            tmp.musicPiece = [musicPiece intValue];
            tmp.wallPaperPiece = [wallPiece intValue];
            tmp.friendship = [friendship intValue];
            [UserSettingData saveTreasureTmp:tmp];
            _isGetVisitorSuccess = YES;
        }
    }
    _dlGetVisitor = nil;
    if ([_delegateGetVisitor respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetVisitor performSelector:@selector(downloadMainFinished:)
                                  withObject:[NSNumber numberWithBool:_isGetVisitorSuccess]];
    }
}

#pragma mark - Present box

// @ 0x97d60 — POST "uuid=<uuId>" to the present-list URL. No-op if already
// running.
// @complete
- (void)startGetPresentListHttp {
    if (_dlGetPresentList != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    _dlGetPresentList =
        [[Downloader alloc] initWithURL:[StoreUtil getPresentListURL]
                               delegate:self
                                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                            ContextType:@"application/json"];
    [_dlGetPresentList startDownloading];
}

// @ 0x97e74
// @complete
- (BOOL)isGetPresentListDownLoading {
    return _dlGetPresentList != nil;
}

// @ 0x97e8c — unbox each PresentData (its retained info field) before dropping.
// @complete
- (void)releasePresentList {
    if (_presentDataArray == nil) {
        return;
    }
    for (NSValue *value in _presentDataArray) {
        PresentData data;
        [value getValue:&data];
    }
    _presentDataArray = nil;
}

// @ 0x97f90 — parse the present list into presentDataArray; notify the delegate
// with 0 on success or -1 on error.
// @complete
- (void)getPresentListFinished {
    NSDictionary *json = [_dlGetPresentList getDataInJSON];
    int result = -1;
    if (json[@"ErrorCode"] == nil) {
        NSArray *list = json[@"PresentList"];
        if (list != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in list) {
                PresentData data;
                data.presentId = [entry[@"PresentId"] intValue];
                data.itemId = [entry[@"ItemId"] intValue];
                data.itemNum = [entry[@"ItemNum"] intValue];
                data.info = entry[@"Info"];
                [out addObject:[NSValue value:&data withObjCType:@encode(PresentData)]];
            }
            [self releasePresentList];
            _presentDataArray = [[NSArray alloc] initWithArray:out];
            result = 0;
        }
    }
    _dlGetPresentList = nil;
    if ([_delegateGetPresentList respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetPresentList performSelector:@selector(downloadMainFinished:)
                                      withObject:[NSNumber numberWithInt:result]];
    }
}

// @ 0x9829c — POST "uuid=<uuId>&present_id=<id>" to claim one present. No-op if
// running.
// @complete
- (void)startGetPresentHttp:(int)presentId {
    if (_dlGetPresent != nil) {
        return;
    }
    _getPresentId = presentId;
    NSString *body = [NSString
        stringWithFormat:@"uuid=%@&present_id=%d", AppDelegate.appDelegate.uuId, _getPresentId];
    _dlGetPresent = [[Downloader alloc] initWithURL:[StoreUtil getPresentURL]
                                           delegate:self
                                               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                        ContextType:@"application/json"];
    [_dlGetPresent startDownloading];
}

// @ 0x983c0
// @complete
- (BOOL)isGetPresentDownLoading {
    return _dlGetPresent != nil;
}

// @ 0x983d8 — notify the delegate. Faithful to the binary, the flag is 1 when
// there was no response body and -1 when there was (it only probes ErrorCode
// otherwise).
// @complete
- (void)getPresentFinished {
    NSDictionary *json = [_dlGetPresent getDataInJSON];
    int result;
    if (json == nil) {
        result = 1;
    } else {
        (void)json[@"ErrorCode"];
        result = -1;
    }
    _dlGetPresent = nil;
    if ([_delegateGetPresent respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetPresent performSelector:@selector(downloadMainFinished:)
                                  withObject:[NSNumber numberWithInt:result]];
    }
}

#pragma mark - Over-score log

// @ 0x984b4 — POST "uuid=<uuId>" to the over-score-log URL. No-op if already
// running.
// @complete
- (void)startGetOverScoreLogHttp {
    if (_dlGetOverScoreLog != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    _dlGetOverScoreLog =
        [[Downloader alloc] initWithURL:[StoreUtil getOverScoreLogURL]
                               delegate:self
                                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                            ContextType:@"application/json"];
    [_dlGetOverScoreLog startDownloading];
}

// @ 0x985c8
// @complete
- (BOOL)isGetOverScoreLogDownLoading {
    return _dlGetOverScoreLog != nil;
}

// @ 0x985e0 — unbox each OverScoreLogData (its three retained fields) before
// dropping.
// @complete
- (void)releaseOverScoreLogArray {
    if (_overScoreLogArray == nil) {
        return;
    }
    for (NSValue *value in _overScoreLogArray) {
        OverScoreLogData data;
        [value getValue:&data];
    }
    _overScoreLogArray = nil;
}

// @ 0x98700 — parse the "Over" list into overScoreLogArray; notify the delegate
// with a BOOL success flag.
// @complete
- (void)getOverScoreLogFinished {
    NSDictionary *json = [_dlGetOverScoreLog getDataInJSON];
    BOOL success = NO;
    if (json[@"ErrorCode"] == nil) {
        NSArray *over = json[@"Over"];
        if (over != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in over) {
                OverScoreLogData data;
                data.musicId = [entry[@"MusicId"] intValue];
                data.musicName = entry[@"MusicName"];
                data.sheet = [entry[@"Sheet"] intValue];
                data.friendName = entry[@"FriendName"];
                data.updateDate = entry[@"UpdateDate"];
                data.myScore = [entry[@"MyScore"] intValue];
                data.friendScore = [entry[@"FriendScore"] intValue];
                [out addObject:[NSValue value:&data withObjCType:@encode(OverScoreLogData)]];
            }
            [self releaseOverScoreLogArray];
            _overScoreLogArray = [[NSArray alloc] initWithArray:out];
            success = YES;
        }
    }
    _dlGetOverScoreLog = nil;
    if ([_delegateGetOverScoreLog respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetOverScoreLog performSelector:@selector(downloadMainFinished:)
                                       withObject:[NSNumber numberWithBool:success]];
    }
}

#pragma mark - Event info

// @ 0x98a6c — POST "client_ver=<ver>" to the event-info URL. No-op if already
// running.
// @complete
- (void)startGetEventInfoHttp {
    if (_dlGetEventInfo != nil) {
        return;
    }
    NSString *body =
        [NSString stringWithFormat:@"client_ver=%d", AppDelegate.appDelegate.appVersionNum];
    _dlGetEventInfo = [[Downloader alloc] initWithURL:[StoreUtil getEventInfoURL]
                                             delegate:self
                                                 Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                          ContextType:@"application/json"];
    [_dlGetEventInfo startDownloading];
}

// @ 0x98b7c
// @complete
- (BOOL)isGetEventInfoDownLoading {
    return _dlGetEventInfo != nil;
}

// @ 0x98b94 — parse the active treasure-event and game-event music ids into
// their NSNumber arrays and mark both refreshed; notify the delegate with a
// BOOL success flag.
// @complete
- (void)getEventInfoFinished {
    NSDictionary *json = [_dlGetEventInfo getDataInJSON];
    BOOL success = NO;
    if (json[@"ErrorCode"] == nil) {
        NSArray *treasure = json[@"Treasure"];
        _treasureEventIdArray = nil;
        if (treasure != nil) {
            NSMutableArray *ids = [NSMutableArray array];
            for (NSDictionary *entry in treasure) {
                [ids addObject:entry[@"EventId"]];
            }
            _treasureEventIdArray = [[NSArray alloc] initWithArray:ids];
        }
        NSArray *gamePlay = json[@"GamePlay"];
        _gameEventIdArray = nil;
        if (gamePlay != nil) {
            NSMutableArray *ids = [NSMutableArray array];
            for (NSDictionary *entry in gamePlay) {
                [ids addObject:entry[@"EventId"]];
            }
            _gameEventIdArray = [[NSArray alloc] initWithArray:ids];
        }
        success = YES;
        _isTreasureEventInfoUpdated = YES;
        _isGameEventInfoUpdated = YES;
    }
    _dlGetEventInfo = nil;
    if ([_delegateGetEventInfo respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetEventInfo performSelector:@selector(downloadMainFinished:)
                                    withObject:[NSNumber numberWithBool:success]];
    }
}

@end
