//
//  StorePackListController.h
//  pop'n rhythmin
//
//  Fetches and caches the store's song-pack catalogue. It downloads the
//  pack-list JSON, resolves the StoreKit products for any packs it does not yet
//  know, then builds/updates StorePackInfo models and notifies its delegate.
//  Also holds the promotion banner list and paginates ("continued") through the
//  catalogue.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    init @ 0x577dc   isFetching @ 0x579f8   cancelFetching @ 0x5796c
//    startFetchingPack: @ 0x57888   getPackInfo: @ 0x57a54   addPackInfoFromID:
//    @ 0x57b28 packIDList @ 0x57a34   promotionList @ 0x57a44 packlistContinued
//    @ 0x58820 downloaderFinished: @ 0x57f48   downloaderError: @ 0x584ec
//    productsRequest:didReceiveResponse: @ 0x58544
//    updatePackInfo:SKProductsResponse: @ 0x57bac   packInfos @ 0x57a24
//    downloaderProceed: @ 0x58540   request:didFailWithError: @ 0x58698
//    dealloc @ 0x58714   delegate @ 0x58800 / setDelegate: @ 0x58810
//

#import "Downloader.h"
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class StorePackInfo;
@class StorePackListController;

@protocol StorePackListControllerDelegate <NSObject>
@optional
- (void)packListDownloadSuccess:(StorePackListController *)controller;
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(NSString *)message;
- (void)packListDownloadNothing:(StorePackListController *)controller;
@end

@interface StorePackListController : NSObject <DownloaderDelegate, SKProductsRequestDelegate> {
    NSMutableArray *m_ArrayPackInfo;      // cache of StorePackInfo (by pack id)
    NSMutableArray *m_ListPackID;         // NSNumber pack ids, in display order
    NSArray *m_PromotionList;             // promotion-banner dictionaries (fetched once)
    int m_FetchedPackNum;                 // how many packs have been paged in
    Downloader *m_PacklistDownloader;     // in-flight pack-list request
    SKProductsRequest *m_ProductsRequest; // in-flight StoreKit lookup
    BOOL m_PacklistContinued;             // server has more packs to page
    NSDictionary *m_TmpPackList;          // buffered pack-list JSON during the SK lookup
    __weak id<StorePackListControllerDelegate> m_Delegate;
}

@property(nonatomic, weak) id<StorePackListControllerDelegate> delegate;

// Store country code cached from the last resolved product's priceLocale (nil
// until known).
+ (NSString *)storeCountry; // @ 0x577a4

// A request (pack-list download or StoreKit lookup) is in flight.
- (BOOL)isFetching;
// Cancel any in-flight request.
- (void)cancelFetching;
// Fetch the next page of packs (8 per page), optionally seeded by a pack id.
- (BOOL)startFetchingPack:(int)packId;

// Lookup / lazy-create a StorePackInfo by pack id.
- (StorePackInfo *)getPackInfo:(int)packId;
- (StorePackInfo *)addPackInfoFromID:(int)packId;

- (NSArray *)packInfos;     // the StorePackInfo cache (m_ArrayPackInfo)
- (NSArray *)packIDList;    // ordered NSNumber pack ids
- (NSArray *)promotionList; // promotion-banner dictionaries
- (BOOL)packlistContinued;  // whether more packs remain

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
