/**
 * @file
 * The fetcher for a single store pack's detail JSON.
 *
 * It folds the result into the pack's StorePackInfo via -setDictionary:, then notifies its
 * delegate. The pack detail screens use it to lazily load full descriptions and song lists.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: initWithStorePackInfo: @ 0x57440,
 * downloadDetail: @ 0x574f4, downloaderFinished: @ 0x575fc, downloaderError: @ 0x576d8, packInfo @
 * 0x57734, setPackInfo: @ 0x57754, setDownloader: @ 0x577a0, and dealloc @ 0x57488.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StorePackInfo;
@class StorePackInfoDownloader;

/**
 * Receives a pack-detail fetch's progress and outcome.
 */
@protocol StorePackInfoDownloaderDelegate <NSObject>
@optional
/**
 * The fetch made progress.
 * @param downloader The fetch in progress.
 */
- (void)storePackInfoDownloaderProceed:(StorePackInfoDownloader *)downloader;
/**
 * The fetch completed and the pack's detail was filled in.
 * @param downloader The finished fetch.
 */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader;
/**
 * The fetch failed.
 * @param downloader The failed fetch.
 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;
@end

/**
 * Fetches one pack's detail — its description and song lists — into a StorePackInfo.
 */
@interface StorePackInfoDownloader : NSObject <DownloaderDelegate> {
    StorePackInfo *m_PackInfo; /**< The pack whose detail this fetches. */
    Downloader *m_Downloader;  /**< The in-flight request. */
    __weak id<StorePackInfoDownloaderDelegate> m_Delegate; /**< The outcome delegate. */
}

/** The pack whose detail this fetches. */
@property(nonatomic, retain) StorePackInfo *packInfo;
/** The in-flight request. */
@property(nonatomic, retain) Downloader *downloader;
/** The outcome delegate. */
@property(nonatomic, weak) id<StorePackInfoDownloaderDelegate> delegate;

/**
 * Wrap the pack whose detail will be fetched.
 * @param packInfo The pack to fill in.
 * @return The initialised downloader.
 */
- (instancetype)initWithStorePackInfo:(StorePackInfo *)packInfo;

/**
 * Start the detail request.
 * @param userOpen YES for an explicit tap, which sends the userInfo query fragment; NO for a
 * background refresh.
 */
- (void)downloadDetail:(BOOL)userOpen;

/**
 * Abort an in-flight detail fetch: cancel the wrapped Downloader and drop it.
 * @ghidraAddress 0x575b8
 */
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
