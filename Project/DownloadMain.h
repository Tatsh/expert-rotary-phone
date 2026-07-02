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

@interface DownloadMain : NSObject <DownloaderDelegate>

// The shared instance (created under @synchronized on first use). Ghidra: 0x93dd4.
+ (instancetype)getInstance;

// Whether the file-list request is in flight (its Downloader is non-nil). @ 0x979d8.
- (BOOL)isGetDlFileListDownLoading;

// The parsed file list — an NSArray of NSValue-wrapped DlFileListData. @ 0x999e8.
- (NSArray *)dlFileListDataArray;

// POST the file-list request for `fileId` (-1 = all) at the current client version.
// @ 0x978ac.
- (void)startGetDlFileListHttp:(int)fileId;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
