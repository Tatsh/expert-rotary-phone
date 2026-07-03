//
//  StorePackListController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackListController.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"

// Cached store country code, taken from the last resolved product's priceLocale
// (Ghidra global DAT_001882f0).
static NSString *s_storeCountry = nil;

// Server / version-mismatch copy (Ghidra CFStrings, byte-verified UTF-16).
// The store name substituted into the version message (@ 0x136dd8).
static NSString *const kStoreName = @"POP'N STORE";
// "%1$@ に接続するにはバージョン %2$@ 以上が必要です。\n\n最新バージョンにアップデートして下さい。"
// ("To connect to %1$@ you need version %2$@ or higher.\n\nPlease update to the
//  latest version.") — @ 0x136dc8.
static NSString *const kVersionMismatchFormat =
    @"%1$@ に接続するにはバージョン %2$@ 以上が必要です。\n\n最新バージョンにアップデートして下さい。";
// "サーバエラーが発生しました。\n後ほど再接続して下さい。"
// ("A server error occurred.\nPlease reconnect later.") — @ 0x136828.
static NSString *const kParseErrorMessage =
    @"サーバエラーが発生しました。\n後ほど再接続して下さい。";
// "サーバに接続できません。\nネットワーク接続をご確認下さい。"
// ("Cannot connect to the server.\nPlease check your network connection.") — @ 0x136808.
static NSString *const kDownloadErrorMessage =
    @"サーバに接続できません。\nネットワーク接続をご確認下さい。";

@implementation StorePackListController

@synthesize delegate = m_Delegate;   // delegate @ 0x58800 / setDelegate: @ 0x58810 (synthesized)

// @ 0x577dc — start "continued", with a 50-slot pack cache and id list.
- (instancetype)init {
    if ((self = [super init])) {
        m_PacklistContinued = YES;
        m_ArrayPackInfo = [[NSMutableArray alloc] initWithCapacity:50];
        m_ListPackID = [[NSMutableArray alloc] initWithCapacity:50];
    }
    return self;
}

#pragma mark - Fetch control

// @ 0x579f8
- (BOOL)isFetching {
    return m_PacklistDownloader != nil || m_ProductsRequest != nil;
}

// @ 0x5796c
- (void)cancelFetching {
    if (m_PacklistDownloader != nil) {
        [m_PacklistDownloader cancel];
        m_PacklistDownloader = nil;
    }
    if (m_ProductsRequest != nil) {
        [m_ProductsRequest cancel];
        m_ProductsRequest.delegate = nil;
        m_ProductsRequest = nil;
    }
}

// @ 0x57888 — GET the next page (8 packs from m_FetchedPackNum+1, optional seed id).
- (BOOL)startFetchingPack:(int)packId {
    if ([self isFetching]) {
        return NO;
    }
    NSURL *url = [StoreUtil packListURL:m_FetchedPackNum + 1 limit:8 packId:packId];
    if (m_PacklistDownloader != nil) {
        [m_PacklistDownloader cancel];
        m_PacklistDownloader = nil;
    }
    m_PacklistDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [m_PacklistDownloader startDownloading];
    return YES;
}

#pragma mark - Pack cache

// @ 0x57a54 — linear scan of the cache by pack id.
- (StorePackInfo *)getPackInfo:(int)packId {
    for (StorePackInfo *info in m_ArrayPackInfo) {
        if (info.packID == packId) {
            return info;
        }
    }
    return nil;
}

// @ 0x57b28 — lazy-create an empty StorePackInfo for a pack id.
- (StorePackInfo *)addPackInfoFromID:(int)packId {
    StorePackInfo *info = [self getPackInfo:packId];
    if (info == nil) {
        info = [[StorePackInfo alloc] initWithPackID:packId];
        [m_ArrayPackInfo addObject:info];
    }
    return info;
}

// @ 0x57a24
- (NSArray *)packInfos {
    return m_ArrayPackInfo;
}

// @ 0x57a34 / 0x57a44 / 0x58820
- (NSArray *)packIDList {
    return m_ListPackID;
}

- (NSArray *)promotionList {
    return m_PromotionList;
}

- (BOOL)packlistContinued {
    return m_PacklistContinued;
}

#pragma mark - Pack-list download

// Collect the product identifiers for pack entries this controller does not yet
// know about; returns YES if the list contained any usable entries.
- (BOOL)collectUnknownProductIDs:(NSArray *)packEntries into:(NSMutableSet *)productIDs {
    BOOL hasAny = NO;
    for (NSDictionary *entry in packEntries) {
        id idValue = entry[@"ID"];
        if (idValue != nil) {
            int packId = [idValue intValue];
            if ([self getPackInfo:packId] == nil) {
                [productIDs addObject:[StoreUtil productIDForPackID:packId]];
            }
            hasAny = YES;
        }
    }
    return hasAny;
}

// @ 0x57f48 — parse the pack-list JSON: version-gate, then either fire a StoreKit
// products request for the new packs or (nothing new) finish directly.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *version = json[@"Version"];
    NSString *appVersion = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"];

    BOOL tooOld = (appVersion == nil) ||
        (version != nil &&
         [appVersion compare:version options:NSNumericSearch] == NSOrderedAscending);

    if (tooOld) {
        NSString *message = [NSString stringWithFormat:kVersionMismatchFormat,
                             kStoreName, version ? version : @""];
        [m_Delegate packListDownloadError:self errorMessage:message];
    } else {
        NSArray *packList = json[@"PackList"];
        if (packList.count != 0) {
            NSMutableSet *productIDs = [NSMutableSet setWithCapacity:8];
            BOOL hasAny = [self collectUnknownProductIDs:packList into:productIDs];

            // Promotion banners are fetched once and add to the product lookup.
            if (m_PromotionList == nil && json[@"Promotion"] != nil) {
                m_PromotionList = [[NSArray alloc] initWithArray:json[@"Promotion"]];
                [self collectUnknownProductIDs:m_PromotionList into:productIDs];
            }

            if (productIDs.count == 0) {
                if (hasAny) {
                    // Everything is already resolved — apply the list directly.
                    [self updatePackInfo:json SKProductsResponse:nil];
                } else {
                    [m_Delegate packListDownloadError:self errorMessage:kParseErrorMessage];
                }
            } else {
                // Buffer the JSON and resolve the new products via StoreKit.
                m_TmpPackList = [[NSDictionary alloc] initWithDictionary:json];
                if (m_ProductsRequest != nil) {
                    [m_ProductsRequest cancel];
                    m_ProductsRequest.delegate = nil;
                    m_ProductsRequest = nil;
                }
                m_ProductsRequest =
                    [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
                m_ProductsRequest.delegate = self;
                [m_ProductsRequest start];
            }
        } else {
            NSString *serverError = json[@"Error"];
            [m_Delegate packListDownloadError:self
                                 errorMessage:serverError ? serverError : kDownloadErrorMessage];
        }
    }

    m_PacklistDownloader = nil;
}

// @ 0x584ec
- (void)downloaderError:(Downloader *)downloader {
    [m_Delegate packListDownloadError:self errorMessage:kDownloadErrorMessage];
    m_PacklistDownloader = nil;
}

// @ 0x58540 — progress callback; the pack-list controller ignores intermediate progress.
- (void)downloaderProceed:(Downloader *)downloader {
}

#pragma mark - SKProductsRequestDelegate

// @ 0x58544 — cache the store country, bind products, then finish.
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count != 0) {
        NSString *country =
            [response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];
        if (s_storeCountry == nil || ![s_storeCountry isEqualToString:country]) {
            s_storeCountry = [[NSString alloc] initWithString:country];
        }
    }
    [self updatePackInfo:m_TmpPackList SKProductsResponse:response];
    if (m_ProductsRequest != nil) {
        m_ProductsRequest = nil;
    }
    m_TmpPackList = nil;
}

// @ 0x58698 — StoreKit lookup failed: drop the in-flight request and buffered JSON, then
// report a network error to the delegate.
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    m_ProductsRequest = nil;
    m_TmpPackList = nil;
    [m_Delegate packListDownloadError:self errorMessage:kDownloadErrorMessage];
}

// @ 0x57bac — create StorePackInfo for each new product, apply the buffered pack
// dictionaries, advance the page, and notify success / nothing.
- (void)updatePackInfo:(NSDictionary *)packListJSON SKProductsResponse:(SKProductsResponse *)response {
    if (response != nil) {
        for (SKProduct *product in response.products) {
            int packId = [StoreUtil packIDForProductID:product.productIdentifier];
            if ([self getPackInfo:packId] == nil) {
                StorePackInfo *info = [[StorePackInfo alloc] initWithProduct:product];
                [m_ArrayPackInfo addObject:info];
            }
        }
    }

    NSMutableArray *addedIDs = [[NSMutableArray alloc] initWithCapacity:10];
    for (NSDictionary *entry in packListJSON[@"PackList"]) {
        int packId = [entry[@"ID"] intValue];
        StorePackInfo *info = [self getPackInfo:packId];
        if (info != nil) {
            [info setDictionary:entry];
            [addedIDs addObject:[NSNumber numberWithInt:packId]];
        }
    }

    m_FetchedPackNum += 8;
    m_PacklistContinued = [packListJSON[@"HasNext"] boolValue];

    if (addedIDs.count == 0) {
        [m_Delegate packListDownloadNothing:self];
    } else {
        [m_ListPackID addObjectsFromArray:addedIDs];
        [m_Delegate packListDownloadSuccess:self];
    }
}

// dealloc @ 0x58714 — real work kept: cancel any in-flight downloader / StoreKit request
// (and clear the request's delegate) before ARC releases the remaining object ivars.
- (void)dealloc {
    [self cancelFetching];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
