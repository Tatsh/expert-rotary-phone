/**
 * @file
 * @brief The fetcher and cache for the store's song-pack catalogue.
 *
 * It downloads the pack-list JSON, resolves the StoreKit products for any packs it does not yet
 * know, then builds or updates StorePackInfo models and notifies its delegate. It also holds the
 * promotion banner list and paginates ("continued") through the catalogue.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: init @ 0x577dc, isFetching @
 * 0x579f8, cancelFetching @ 0x5796c, startFetchingPack: @ 0x57888, getPackInfo: @ 0x57a54,
 * addPackInfoFromID: @ 0x57b28, packIDList @ 0x57a34, promotionList @ 0x57a44, packlistContinued @
 * 0x58820, downloaderFinished: @ 0x57f48, downloaderError: @ 0x584ec,
 * productsRequest:didReceiveResponse: @ 0x58544, updatePackInfo:SKProductsResponse: @ 0x57bac,
 * packInfos @ 0x57a24, downloaderProceed: @ 0x58540, request:didFailWithError: @ 0x58698, dealloc
 * @ 0x58714, and delegate @ 0x58800 with setDelegate: @ 0x58810.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "Downloader.h"

@class StorePackInfo;
@class StorePackListController;

/**
 * @brief Receives the pack-list fetch outcome.
 */
@protocol StorePackListControllerDelegate <NSObject>
@optional
/**
 * @brief A pack-list page arrived.
 * @param controller The list controller that fetched it.
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller;
/**
 * @brief A pack-list fetch failed.
 * @param controller The list controller that failed.
 * @param message The error message to surface.
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(NSString *)message;
/**
 * @brief A pack-list fetch returned no packs.
 * @param controller The list controller that fetched it.
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;
@end

/**
 * @brief Pages the pack catalogue in and resolves each page's StoreKit products.
 */
@interface StorePackListController : NSObject <DownloaderDelegate, SKProductsRequestDelegate> {
    NSMutableArray *m_ArrayPackInfo;      /**< The StorePackInfo cache, keyed by pack id. */
    NSMutableArray *m_ListPackID;         /**< The NSNumber pack ids, in display order. */
    NSArray *m_PromotionList;             /**< The promotion-banner dictionaries, fetched once. */
    int m_FetchedPackNum;                 /**< How many packs have been paged in. */
    Downloader *m_PacklistDownloader;     /**< The in-flight pack-list request. */
    SKProductsRequest *m_ProductsRequest; /**< The in-flight StoreKit lookup. */
    BOOL m_PacklistContinued;             /**< The server has more packs to page. */
    NSDictionary *m_TmpPackList; /**< The pack-list JSON buffered during the StoreKit lookup. */
    __weak id<StorePackListControllerDelegate> m_Delegate; /**< The fetch-outcome delegate. */
}

/** The fetch-outcome delegate. */
@property(nonatomic, weak) id<StorePackListControllerDelegate> delegate;

/**
 * @brief The store country code, cached from the last resolved product's priceLocale.
 * @return The country code, or nil until one is known.
 * @ghidraAddress 0x577a4
 */
+ (NSString *)storeCountry;

/**
 * @brief Whether a pack-list download or StoreKit lookup is in flight.
 * @return YES while fetching.
 */
- (BOOL)isFetching;
/**
 * @brief Cancel any in-flight request.
 */
- (void)cancelFetching;
/**
 * @brief Fetch the next page of packs, eight per page.
 * @param packId A pack id to seed the page with, or a non-positive value for none.
 * @return YES when a fetch was started.
 */
- (BOOL)startFetchingPack:(int)packId;

/**
 * @brief Look up a cached pack by id.
 * @param packId The pack id.
 * @return The pack, or nil when it is not cached.
 */
- (StorePackInfo *)getPackInfo:(int)packId;
/**
 * @brief Look up a pack by id, creating and caching an empty one when absent.
 * @param packId The pack id.
 * @return The pack.
 */
- (StorePackInfo *)addPackInfoFromID:(int)packId;

/**
 * @brief The StorePackInfo cache.
 * @return An array of StorePackInfo.
 */
- (NSArray *)packInfos;
/**
 * @brief The pack ids in display order.
 * @return An array of NSNumber.
 */
- (NSArray *)packIDList;
/**
 * @brief The promotion-banner dictionaries.
 * @return An array of dictionaries.
 */
- (NSArray *)promotionList;
/**
 * @brief Whether the server has more packs to page.
 * @return YES when another page is available.
 */
- (BOOL)packlistContinued;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
