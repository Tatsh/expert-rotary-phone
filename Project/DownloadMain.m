//
//  DownloadMain.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Manual
//  retain/release is kept where the original manages the Downloader/list lifetime.
//

#import "DownloadMain.h"

#import "AppDelegate.h"
#import "StoreUtil.h"

static DownloadMain *sInstance = nil;   // Ghidra: DAT_00188310

@implementation DownloadMain {
    Downloader *_dlGetDlFileList;    // active file-list download (nil when idle)
    NSArray *_dlFileListDataArray;   // parsed result
    Downloader *_dlGetFriendList;    // active friend-list download (nil when idle)
    NSArray *_friendListArray;       // parsed friends (NSValue-wrapped FriendListData)
    int _friendRequestedCnt;         // pending inbound friend requests
    __unsafe_unretained id<DownloadMainDelegate> _delegateGetFriendList;
}

// @ 0x93dd4 — construct the singleton once, guarded by @synchronized.
+ (instancetype)getInstance {
    @synchronized (self) {
        if (sInstance == nil) {
            sInstance = [[DownloadMain alloc] init];
        }
    }
    return sInstance;
}

// @ 0x979d8 — a request is in flight while its Downloader exists.
- (BOOL)isGetDlFileListDownLoading {
    return _dlGetDlFileList != nil;
}

// @ 0x999e8
- (NSArray *)dlFileListDataArray {
    return _dlFileListDataArray;
}

// @ 0x978ac — POST "target=<store>&file_id=<id>&client_ver=<ver>" to the file-list
// URL through a Downloader (with self as delegate) and start it. No-op if already
// downloading.
- (void)startGetDlFileListHttp:(int)fileId {
    if (_dlGetDlFileList != nil) {
        return;
    }
    int clientVer = AppDelegate.appDelegate.appVersionNum;
    NSString *body = [NSString stringWithFormat:@"target=%@&file_id=%d&client_ver=%d",
                      [StoreUtil targetStore], fileId, clientVer];
    _dlGetDlFileList = [[Downloader alloc]
        initWithURL:[StoreUtil getDlFileListURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/x-www-form-urlencoded"];
    [_dlGetDlFileList startDownloading];
}

// DownloaderDelegate: route a finished download to the right handler. The file-list
// request is dispatched to getDlFileListFinished; the friend-list request to
// getFriendListFinished; other downloads (the per-file queue) have their own paths.
- (void)downloaderFinished:(Downloader *)downloader {
    if (downloader == _dlGetDlFileList) {
        [self getDlFileListFinished];
    } else if (downloader == _dlGetFriendList) {
        [self getFriendListFinished];
    }
}

// Free the previously-parsed list (Ghidra: releaseFileListData).
- (void)releaseFileListData {
    [_dlFileListDataArray release];
    _dlFileListDataArray = nil;
}

// @ 0x97af4 — the file-list download finished: parse the JSON. If there is no
// "ErrorCode" and a "List" array is present, turn each {Id, Url, Size} entry into a
// DlFileListData wrapped in an NSValue, and keep them as an immutable array.
- (void)getDlFileListFinished {
    NSDictionary *json = [_dlGetDlFileList getDataInJSON];
    if (json[@"ErrorCode"] == nil) {
        NSArray *list = json[@"List"];
        if (list != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in list) {
                DlFileListData data;
                data.fileId = [entry[@"Id"] intValue];
                data.url = [entry[@"Url"] retain];
                data.size = [entry[@"Size"] intValue];
                [out addObject:[NSValue value:&data withObjCType:@encode(DlFileListData)]];
            }
            [self releaseFileListData];
            _dlFileListDataArray = [[NSArray alloc] initWithArray:out];
        }
    }
    [_dlGetDlFileList release];
    _dlGetDlFileList = nil;
}

#pragma mark - Friend list

// @ 0x99914 / 0x99734 — atomic accessors.
- (NSArray *)friendListArray {
    return _friendListArray;
}

- (int)friendRequestedCnt {
    return _friendRequestedCnt;
}

// @ 0x99604 / 0x99618 — atomic delegate accessors (assign).
- (id<DownloadMainDelegate>)delegateGetFriendList {
    return _delegateGetFriendList;
}

- (void)setDelegateGetFriendList:(id<DownloadMainDelegate>)delegate {
    _delegateGetFriendList = delegate;
}

// @ 0x958a8
- (BOOL)isGetFriendListDownLoading {
    return _dlGetFriendList != nil;
}

// @ 0x95794 — POST "uuid=<uuId>" to the friend-list endpoint. No-op if in flight.
- (void)startGetFriendListHttp {
    if (_dlGetFriendList != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
    _dlGetFriendList = [[Downloader alloc]
        initWithURL:[StoreUtil getFriendListURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/json"];
    [_dlGetFriendList startDownloading];
}

// @ 0x958c0 — unbox each friend struct and release its two retained NSString fields,
// then drop the array.
- (void)releaseFriendList {
    if (_friendListArray == nil) {
        return;
    }
    for (NSValue *value in _friendListArray) {
        FriendListData data;
        [value getValue:&data];
        [data.playerId release];
        [data.name release];
    }
    [_friendListArray release];
    _friendListArray = nil;
}

// @ 0x959d4 — parse the friend-list JSON into FriendListData structs, or fail on an
// "ErrorCode". Notifies the delegate with an NSNumber success flag.
- (void)getFriendListFinished {
    // Rank key prefixes per difficulty (N / H / Ex).
    static NSString *const kDiff[3] = { @"N", @"H", @"Ex" };
    static NSString *const kRankSuffix[5] = { @"S", @"AAA", @"AA", @"A", @"B" };

    BOOL success = NO;
    NSDictionary *json = [_dlGetFriendList getDataInJSON];
    if (json[@"ErrorCode"] == nil) {
        NSArray *friends = json[@"Friend"];
        if (friends != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in friends) {
                FriendListData data;
                data.playerId = [entry[@"PlayerId"] retain];
                data.name = [entry[@"Name"] retain];
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
                    int fullCombo = [entry[[@"FullCombo" stringByAppendingString:kDiff[d]]] intValue];
                    int perfect = [entry[[@"Perfect" stringByAppendingString:kDiff[d]]] intValue];
                    data.rank[d][5] = fullCombo;
                    data.rank[d][6] = perfect;
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

    [_dlGetFriendList release];
    _dlGetFriendList = nil;

    if ([_delegateGetFriendList respondsToSelector:@selector(downloadMainFinished:)]) {
        [_delegateGetFriendList performSelector:@selector(downloadMainFinished:)
                                     withObject:[NSNumber numberWithBool:success]];
    }
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
