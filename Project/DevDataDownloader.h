/**
 * @file
 * A fetcher for a single "dev data" file from the development host.
 *
 * It reads `http://dev.apr.konaminet.jp/apr/dev_data[_old]/<title>/<file>`, writes it into the app
 * Caches directory (the devdata or acvdevdata subtree), and reports success or a formatted error
 * string to its delegate. It is a thin wrapper around Downloader.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: dealloc @ 0x8e8ec,
 * startDownload:file: @ 0x8e984, downloaderFinished: @ 0x8eb1c, downloaderProceed: @ 0x8ed78,
 * downloaderError: @ 0x8ed7c, delegate @ 0x8ee00, setDelegate: @ 0x8ee10, isOld @ 0x8ee20, and
 * setIsOld: @ 0x8ee38.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class DevDataDownloader;

/**
 * Receives the dev-data fetch result. These are the only two selectors the binary sends to
 * m_Delegate.
 */
@protocol DevDataDownloaderDelegate <NSObject>
@optional
/**
 * The file was fetched and written, sent from downloaderFinished:.
 * @param fileName The file that was written.
 */
- (void)devDownloadSucceeded:(NSString *)fileName;
/**
 * The fetch failed, sent from downloaderFinished: or downloaderError:.
 * @param message The formatted error string.
 */
- (void)devDownloadFailed:(NSString *)message;
@end

/**
 * Fetches a single "dev data" file from the development host into the app Caches directory.
 */
@interface DevDataDownloader : NSObject <DownloaderDelegate> {
    Downloader *m_Downloader; /**< The in-flight request; retained. */
    NSString *m_Title;        /**< The dev-data title, a path component; retained. */
    NSString *m_FileName;     /**< The dev-data file name; retained. */
    BOOL m_IsOld;             /**< Pick the dev_data_old/ subtree. */
    /** The result delegate; not retained. */
    __unsafe_unretained id<DevDataDownloaderDelegate> m_Delegate;
    BOOL isAcv; /**< The title has the "acv_" prefix, so the acvdevdata/ subtree is used. */
}

/** The result delegate; a plain nonatomic pointer assign. Getter @ 0x8ee00, setter @ 0x8ee10. */
@property(nonatomic, assign) id<DevDataDownloaderDelegate> delegate;
/** Whether to pick the dev_data_old/ subtree. The accessors are atomic, using a
 * DataMemoryBarrier. Getter @ 0x8ee20, setter @ 0x8ee38. */
@property(assign) BOOL isOld;

/**
 * The shared instance. Every access resets isOld to NO.
 * @return The downloader.
 * @ghidraAddress 0x8e894
 */
+ (instancetype)getInstance;

/**
 * Build the Downloader for `<title>/<fileName>` and start it.
 * @param title The dev-data title.
 * @param fileName The dev-data file name.
 * @return NO if a request is already in flight.
 * @ghidraAddress 0x8e984
 */
- (BOOL)startDownload:(NSString *)title file:(NSString *)fileName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
