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

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
