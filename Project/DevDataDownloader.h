//
//  DevDataDownloader.h
//  pop'n rhythmin
//
//  Fetches a single "dev data" file from the development host
//  (http://dev.apr.konaminet.jp/apr/dev_data[_old]/<title>/<file>), writes it
//  into the app Caches directory (devdata / acvdevdata subtree), and reports
//  success or a formatted error string to its delegate. Thin wrapper around
//  Downloader.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    dealloc @ 0x8e8ec   startDownload:file: @ 0x8e984
//    downloaderFinished: @ 0x8eb1c   downloaderProceed: @ 0x8ed78
//    downloaderError: @ 0x8ed7c
//    delegate @ 0x8ee00  setDelegate: @ 0x8ee10  isOld @ 0x8ee20  setIsOld: @
//    0x8ee38
//

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class DevDataDownloader;

// Only the two selectors the binary actually sends to m_Delegate.
@protocol DevDataDownloaderDelegate <NSObject>
@optional
- (void)devDownloadSucceeded:(NSString *)fileName; // sent from downloaderFinished: on write success
- (void)devDownloadFailed:(NSString *)message; // sent from downloaderFinished: / downloaderError:
@end

@interface DevDataDownloader : NSObject <DownloaderDelegate> {
    Downloader *m_Downloader; // in-flight request (retained)
    NSString *m_Title;        // dev-data title (path component, retained)
    NSString *m_FileName;     // dev-data file name (retained)
    BOOL m_IsOld;             // pick the dev_data_old/ subtree
    __unsafe_unretained id<DevDataDownloaderDelegate> m_Delegate;
    BOOL isAcv; // title has the "acv_" prefix -> acvdevdata/ subtree
}

// getter @ 0x8ee00 / setter @ 0x8ee10 (plain pointer assign, nonatomic)
@property(nonatomic, assign) id<DevDataDownloaderDelegate> delegate;
// getter @ 0x8ee20 / setter @ 0x8ee38 (atomic, DataMemoryBarrier)
@property(assign) BOOL isOld;

// Shared instance (resets isOld to NO on every access). Ghidra: @ 0x8e894.
+ (instancetype)getInstance;

// Build the Downloader for <title>/<fileName> and start it. Returns NO if a
// request is already in flight. Ghidra: @ 0x8e984.
- (BOOL)startDownload:(NSString *)title file:(NSString *)fileName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
