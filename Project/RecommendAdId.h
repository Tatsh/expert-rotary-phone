/**
 * @file
 * The Konami "Applilink" Recommend ad SDK's cross-app advertising-id record.
 *
 * It stores, loads, and deletes a small record of AdIdFrom, CountryCode, CategoryId, AdType, and
 * EntryDate, keyed by the device's advertising id.
 *
 * Two storage backends are chosen by OS version. On iOS 7 and later the record is round-tripped
 * through the Applilink server-side external pasteboard
 * (/ad/external/pasteboard/{get,set,delete}.php), keyed by a SHA-1 of the ASIdentifierManager
 * advertising UUID, and requires ad tracking to be enabled. Before iOS 7 the record is
 * AES-encrypted, with a key that is the SHA-1 of the service name, and kept in a named
 * UIPasteboard of type "applilink.adid".
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The superclass (NSObject) and the
 * NSString *_serviceName ivar come from the Objective-C class_t metadata:
 * initWithCountryCode:categoryId: @ 0xe997c, getWithCountryCode:categoryId:error: @ 0xe9a34,
 * setWithAdIdFrom:countryCode:categoryId:adType:error: @ 0xe9eb8, and
 * deleteWithCountryCode:categoryId:error: @ 0xea49c.
 */

#import <Foundation/Foundation.h>

/**
 * The advertising-id record stored on a named pasteboard, keyed by country and category.
 */
@interface RecommendAdId : NSObject

/**
 * Build the named-pasteboard service key "ApplilinkRecommend.AdId_<country>_<category>".
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @return The initialised record accessor.
 */
- (instancetype)initWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId;

/**
 * Fetch the stored advertising-id record.
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @param error Receives the failure reason; may be NULL.
 * @return The record, or nil on failure.
 */
- (id)getWithCountryCode:(NSString *)countryCode
              categoryId:(NSString *)categoryId
                   error:(NSError **)error;

/**
 * Store an advertising-id record.
 * @param adIdFrom The advertising id's origin.
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @param adType The advertisement type.
 * @param error Receives the failure reason; may be NULL.
 * @return The plaintext record, or nil on failure.
 */
- (id)setWithAdIdFrom:(NSString *)adIdFrom
          countryCode:(NSString *)countryCode
           categoryId:(NSString *)categoryId
               adType:(NSString *)adType
                error:(NSError **)error;

/**
 * Delete the stored advertising-id record.
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @param error Receives the failure reason; may be NULL.
 * @return NO on failure.
 */
- (BOOL)deleteWithCountryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                        error:(NSError **)error;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
