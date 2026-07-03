//
//  RecommendAdId.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — cross-app advertising-id record for the recommend
//  feature. It stores/loads/deletes a small {AdIdFrom, CountryCode, CategoryId, AdType,
//  EntryDate} record keyed by the device's advertising id.
//
//  Two storage backends are chosen by OS version:
//    * iOS 7+  : the record is round-tripped through the Applilink server-side external
//                pasteboard (/ad/external/pasteboard/{get,set,delete}.php), keyed by a SHA-1
//                of the ASIdentifierManager advertising UUID. Requires ad tracking enabled.
//    * iOS < 7 : the record is AES-encrypted (key = SHA-1 of the service name) and kept in a
//                named UIPasteboard ("applilink.adid" type).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass (NSObject) and the
//  NSString *_serviceName ivar come from the Objective-C class_t metadata.
//    initWithCountryCode:categoryId: @ 0xe997c
//    getWithCountryCode:categoryId:error: @ 0xe9a34
//    setWithAdIdFrom:countryCode:categoryId:adType:error: @ 0xe9eb8
//    deleteWithCountryCode:categoryId:error: @ 0xea49c
//

#import <Foundation/Foundation.h>

@interface RecommendAdId : NSObject

// Build the named-pasteboard service key "ApplilinkRecommend.AdId_<country>_<category>".
- (instancetype)initWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId;

// Fetch the stored advertising-id record, or nil (with *error set) on failure.
- (id)getWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId
                   error:(NSError **)error;

// Store an advertising-id record and return the plaintext record, or nil (with *error) on failure.
- (id)setWithAdIdFrom:(NSString *)adIdFrom
          countryCode:(NSString *)countryCode
           categoryId:(NSString *)categoryId
               adType:(NSString *)adType
                error:(NSError **)error;

// Delete the stored advertising-id record. Returns NO (with *error set) on failure.
- (BOOL)deleteWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId
                        error:(NSError **)error;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
