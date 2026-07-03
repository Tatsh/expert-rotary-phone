//
//  StorePackInfoDownloader.h
//  pop'n rhythmin
//
//  Fetches the detail JSON for a single store pack and folds it into the pack's
//  StorePackInfo (via -setDictionary:), then notifies its delegate. Used by the
//  pack detail screens to lazily load full descriptions / song lists.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStorePackInfo: @ 0x57440   downloadDetail: @ 0x574f4
//    downloaderFinished: @ 0x575fc   downloaderError: @ 0x576d8
//    packInfo @ 0x57734   setPackInfo: @ 0x57754   setDownloader: @ 0x577a0
//    dealloc @ 0x57488
//

#import <Foundation/Foundation.h>
#import "Downloader.h"

@class StorePackInfo;
@class StorePackInfoDownloader;

@protocol StorePackInfoDownloaderDelegate <NSObject>
@optional
- (void)storePackInfoDownloaderProceed:(StorePackInfoDownloader *)downloader;
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader;
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;
@end

@interface StorePackInfoDownloader : NSObject <DownloaderDelegate> {
    StorePackInfo *m_PackInfo;   // the pack whose detail this fetches (retained)
    Downloader *m_Downloader;    // in-flight request (retained)
    __weak id<StorePackInfoDownloaderDelegate> m_Delegate;
}

@property (nonatomic, retain) StorePackInfo *packInfo;
@property (nonatomic, retain) Downloader *downloader;
@property (nonatomic, weak) id<StorePackInfoDownloaderDelegate> delegate;

// Wrap the pack whose detail will be fetched.
- (instancetype)initWithStorePackInfo:(StorePackInfo *)packInfo;

// Start the detail request. userOpen distinguishes an explicit tap (sends the
// userInfo query fragment) from a background refresh.
- (void)downloadDetail:(BOOL)userOpen;

// Abort an in-flight detail fetch: cancel the wrapped Downloader and drop it.
// Ghidra: @ 0x575b8.
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
