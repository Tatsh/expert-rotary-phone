//
//  RecommendAdId.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendAdId.h"

#import <AdSupport/AdSupport.h>       // ASIdentifierManager (iOS 7+ advertising id)
#import <CommonCrypto/CommonCrypto.h> // CC_SHA1, CCCrypt
#import <UIKit/UIKit.h>

#import "RecommendWebAPI.h"
// RewardNetworkError — the Applilink error factory. It supplies
// +localizedApplilinkErrorWithCode: and
// +localizedRewardNetworkErrorWithCode:userInfo:.
#import "RewardNetworkError.h"
// RecommendCore — the Recommend SDK core. It supplies the +baseUrlSsl endpoint
// base used by the external-pasteboard web calls.
#import "RecommendCore.h"

@interface RecommendAdId () {
    NSString *_serviceName;
}

// Applilink server-side external-pasteboard transport (iOS 7+ backend).
- (id)getPasteboardWithUdid:(NSString *)udid
                countryCode:(NSString *)countryCode
                 categoryId:(NSString *)categoryId
                      error:(NSError **)error;
- (void)setPasteboardWithUdid:(NSString *)udid
                  countryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                     adIdFrom:(NSString *)adIdFrom
                       adType:(NSString *)adType
                        error:(NSError **)error;
- (void)deletePasteboardWithUdid:(NSString *)udid
                     countryCode:(NSString *)countryCode
                      categoryId:(NSString *)categoryId
                           error:(NSError **)error;

// Decrypt an archived local-pasteboard record's fields back to plaintext
// strings.
- (NSDictionary *)convertToData:(NSDictionary *)dict;

// Crypto helpers (class methods on RecommendAdId).
+ (NSString *)sha1:(NSString *)string;                                             // @ 0xeac08
+ (NSData *)createHash:(NSData *)data;                                             // @ 0xea72c
+ (NSData *)cryptorToData:(uint)operation value:(NSData *)value key:(NSData *)key; // @ 0xea7d8

@end

@implementation RecommendAdId

// @ 0xe997c
- (instancetype)initWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId {
    if ((self = [super init])) {
        _serviceName = [NSString
            stringWithFormat:@"%@_%@_%@", @"ApplilinkRecommend.AdId", countryCode, categoryId];
    }
    return self;
}

// @ 0xe9a34
- (id)getWithCountryCode:(NSString *)countryCode
              categoryId:(NSString *)categoryId
                   error:(NSError **)error {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f) {
        ASIdentifierManager *manager = [ASIdentifierManager sharedManager];
        if (![manager isAdvertisingTrackingEnabled]) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x404];
            }
            return nil;
        }
        NSString *udid = [RecommendAdId sha1:[[manager advertisingIdentifier] UUIDString]];
        NSError *innerError = nil;
        id record = [self getPasteboardWithUdid:udid
                                    countryCode:countryCode
                                     categoryId:categoryId
                                          error:&innerError];
        if (innerError != nil) {
            if (error != NULL) {
                *error = innerError;
            }
            return nil;
        }
        return record;
    } else {
        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
        if (pasteboard == nil) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
            }
            return nil;
        }
        NSData *stored = [pasteboard valueForPasteboardType:@"applilink.adid"];
        if (stored == nil) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fa];
            }
            return nil;
        }
        NSDictionary *archived = [NSKeyedUnarchiver unarchiveObjectWithData:stored];
        return [self convertToData:archived];
    }
}

// @ 0xe9eb8
- (id)setWithAdIdFrom:(NSString *)adIdFrom
          countryCode:(NSString *)countryCode
           categoryId:(NSString *)categoryId
               adType:(NSString *)adType
                error:(NSError **)error {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f) {
        ASIdentifierManager *manager = [ASIdentifierManager sharedManager];
        if (![manager isAdvertisingTrackingEnabled]) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x404];
            }
            return nil;
        }
        NSString *udid = [RecommendAdId sha1:[[manager advertisingIdentifier] UUIDString]];
        NSError *innerError = nil;
        [self setPasteboardWithUdid:udid
                        countryCode:countryCode
                         categoryId:categoryId
                           adIdFrom:adIdFrom
                             adType:adType
                              error:&innerError];
        if (innerError != nil) {
            if (error != NULL) {
                *error = innerError;
            }
            return nil;
        }
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:3];
        [record setValue:countryCode forKey:@"CountryCode"];
        [record setValue:categoryId forKey:@"CategoryId"];
        [record setValue:adIdFrom forKey:@"AdIdFrom"];
        if (adType != nil) {
            [record setValue:adType forKey:@"AdType"];
        }
        return record;
    } else {
        // Encrypt each field (op 0 = encrypt) under a key derived from the service
        // name.
        NSData *key =
            [RecommendAdId createHash:[_serviceName dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *encAdIdFrom =
            [RecommendAdId cryptorToData:0
                                   value:[adIdFrom dataUsingEncoding:NSUTF8StringEncoding]
                                     key:key];
        NSData *encCountry =
            [RecommendAdId cryptorToData:0
                                   value:[countryCode dataUsingEncoding:NSUTF8StringEncoding]
                                     key:key];
        NSData *encCategory =
            [RecommendAdId cryptorToData:0
                                   value:[categoryId dataUsingEncoding:NSUTF8StringEncoding]
                                     key:key];
        NSData *encAdType = nil;
        if (adType != nil) {
            encAdType = [RecommendAdId cryptorToData:0
                                               value:[adType dataUsingEncoding:NSUTF8StringEncoding]
                                                 key:key];
        }
        NSDate *entryDate = [NSDate date];
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:4];
        [record setValue:encAdIdFrom forKey:@"AdIdFrom"];
        [record setValue:encCountry forKey:@"CountryCode"];
        [record setValue:encCategory forKey:@"CategoryId"];
        [record setValue:entryDate forKey:@"EntryDate"];
        if (adType != nil) {
            [record setValue:encAdType forKey:@"AdType"];
        }

        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:YES];
        if (pasteboard == nil) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
            }
            return nil;
        }
        [pasteboard setPersistent:YES];
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:record];
        [pasteboard setData:archived forPasteboardType:@"applilink.adid"];
        return [self convertToData:record];
    }
}

// @ 0xea49c
- (BOOL)deleteWithCountryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                        error:(NSError **)error {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f) {
        ASIdentifierManager *manager = [ASIdentifierManager sharedManager];
        if (![manager isAdvertisingTrackingEnabled]) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x404];
            }
            return NO;
        }
        NSString *udid = [RecommendAdId sha1:[[manager advertisingIdentifier] UUIDString]];
        NSError *innerError = nil;
        [self deletePasteboardWithUdid:udid
                           countryCode:countryCode
                            categoryId:categoryId
                                 error:&innerError];
        if (innerError != nil) {
            if (error != NULL) {
                *error = innerError;
            }
            return NO;
        }
        return YES;
    } else {
        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
        if (pasteboard == nil) {
            if (error != NULL) {
                *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
            }
            return NO;
        }
        [pasteboard setData:nil forPasteboardType:@"applilink.adid"];
        [UIPasteboard removePasteboardWithName:_serviceName];
        return YES;
    }
}

// @ 0xea914 — decrypt (op 1 = decrypt) the archived local-pasteboard record's
// data fields back into UTF-8 strings. AdType is optional and only present when
// it was supplied at store time.
- (NSDictionary *)convertToData:(NSDictionary *)dict {
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:dict];
    NSData *key = [RecommendAdId createHash:[_serviceName dataUsingEncoding:NSUTF8StringEncoding]];

    NSData *adIdFrom = [out objectForKey:@"AdIdFrom"];
    [out setObject:[[NSString alloc] initWithData:[RecommendAdId cryptorToData:1
                                                                         value:adIdFrom
                                                                           key:key]
                                         encoding:NSUTF8StringEncoding]
            forKey:@"AdIdFrom"];

    NSData *countryCode = [out objectForKey:@"CountryCode"];
    [out setObject:[[NSString alloc] initWithData:[RecommendAdId cryptorToData:1
                                                                         value:countryCode
                                                                           key:key]
                                         encoding:NSUTF8StringEncoding]
            forKey:@"CountryCode"];

    NSData *categoryId = [out objectForKey:@"CategoryId"];
    [out setObject:[[NSString alloc] initWithData:[RecommendAdId cryptorToData:1
                                                                         value:categoryId
                                                                           key:key]
                                         encoding:NSUTF8StringEncoding]
            forKey:@"CategoryId"];

    NSData *adType = [out objectForKey:@"AdType"];
    if (adType != nil) { // decompiler aliases this test onto AdIdFrom's register;
                         // it guards AdType
        [out setObject:[[NSString alloc] initWithData:[RecommendAdId cryptorToData:1
                                                                             value:adType
                                                                               key:key]
                                             encoding:NSUTF8StringEncoding]
                forKey:@"AdType"];
    }
    return out;
}

#pragma mark - Applilink external-pasteboard transport (iOS 7+)

// @ 0xead3c
- (id)getPasteboardWithUdid:(NSString *)udid
                countryCode:(NSString *)countryCode
                 categoryId:(NSString *)categoryId
                      error:(NSError **)error {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:3];
    [params setValue:udid forKey:@"udid"];
    [params setValue:countryCode forKey:@"country_code"];
    [params setValue:categoryId forKey:@"category_id"];

    NSString *url =
        [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/pasteboard/get.php"];
    NSError *requestError = nil;
    NSDictionary *response = [RecommendWebAPI requestSynchronousWithURL:url
                                                                 method:@"GET"
                                                             parameters:params
                                                            cachePolicy:0
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return nil;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3eb userInfo:nil];
        }
        return nil;
    }

    id statusObj = [response objectForKey:@"status"];
    if (![statusObj isKindOfClass:[NSString class]] &&
        ![statusObj isKindOfClass:[NSNumber class]]) {
        statusObj = nil;
    }
    BOOL status = [statusObj boolValue];

    id errorCodeObj = [response objectForKey:@"error_code"];
    int errorCode;
    if (([errorCodeObj isKindOfClass:[NSString class]] ||
         [errorCodeObj isKindOfClass:[NSNumber class]]) &&
        errorCodeObj != nil) {
        errorCode = [errorCodeObj intValue];
    } else {
        errorCode = 100000000; // sentinel: no usable error_code in the response
    }

    id kindObj = [response objectForKey:@"kind"];
    if (![kindObj isKindOfClass:[NSString class]]) {
        kindObj = nil;
    }

    if (!status || errorCode != 100000000) {
        int code;
        if (errorCode == 0xc106101) {
            code = 0x3f1;
        } else if ([kindObj isEqualToString:@"authorization"]) {
            code = 0x3ea;
        } else if ([kindObj isEqualToString:@"parameter_error"]) {
            code = 0x3e9;
        } else {
            code = 1000;
        }
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:code
                                                                    userInfo:response];
        }
        return nil;
    }

    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:3];
    [record setValue:[response objectForKey:@"country_code"] forKey:@"CountryCode"];
    [record setValue:[response objectForKey:@"category_id"] forKey:@"CategoryId"];
    [record setValue:[response objectForKey:@"ad_id_from"] forKey:@"AdIdFrom"];
    id adType = [response objectForKey:@"ad_type"];
    if (adType != nil) {
        [record setValue:adType forKey:@"AdType"];
    }
    return record;
}

// @ 0xeb23c
- (void)setPasteboardWithUdid:(NSString *)udid
                  countryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                     adIdFrom:(NSString *)adIdFrom
                       adType:(NSString *)adType
                        error:(NSError **)error {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
    [params setValue:udid forKey:@"udid"];
    [params setValue:countryCode forKey:@"country_code"];
    [params setValue:categoryId forKey:@"category_id"];
    [params setValue:adIdFrom forKey:@"ad_id_from"];
    if (adType != nil) {
        [params setValue:adType forKey:@"ad_type"];
    }

    NSString *url =
        [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/pasteboard/set.php"];
    NSError *requestError = nil;
    NSDictionary *response = [RecommendWebAPI requestSynchronousWithURL:url
                                                                 method:@"POST"
                                                             parameters:params
                                                            cachePolicy:0
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3eb userInfo:nil];
        }
        return;
    }

    id statusObj = [response objectForKey:@"status"];
    if (![statusObj isKindOfClass:[NSString class]] &&
        ![statusObj isKindOfClass:[NSNumber class]]) {
        statusObj = nil;
    }
    BOOL status = [statusObj boolValue];

    id errorCodeObj = [response objectForKey:@"error_code"];
    int errorCode;
    if (([errorCodeObj isKindOfClass:[NSString class]] ||
         [errorCodeObj isKindOfClass:[NSNumber class]]) &&
        errorCodeObj != nil) {
        errorCode = [errorCodeObj intValue];
    } else {
        errorCode = 100000000;
    }

    id kindObj = [response objectForKey:@"kind"];
    if (![kindObj isKindOfClass:[NSString class]]) {
        kindObj = nil;
    }

    if (!status || errorCode != 100000000) {
        int code;
        if (errorCode == 0xc106101) {
            code = 0x3f1;
        } else if ([kindObj isEqualToString:@"authorization"]) {
            code = 0x3ea;
        } else if ([kindObj isEqualToString:@"parameter_error"]) {
            code = 0x3e9;
        } else {
            code = 1000;
        }
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:code
                                                                    userInfo:response];
        }
    }
}

// @ 0xeb678
- (void)deletePasteboardWithUdid:(NSString *)udid
                     countryCode:(NSString *)countryCode
                      categoryId:(NSString *)categoryId
                           error:(NSError **)error {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:3];
    [params setValue:udid forKey:@"udid"];
    [params setValue:countryCode forKey:@"country_code"];
    [params setValue:categoryId forKey:@"category_id"];

    NSString *url =
        [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/pasteboard/delete.php"];
    NSError *requestError = nil;
    NSDictionary *response = [RecommendWebAPI requestSynchronousWithURL:url
                                                                 method:@"POST"
                                                             parameters:params
                                                            cachePolicy:0
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3eb userInfo:nil];
        }
        return;
    }

    id statusObj = [response objectForKey:@"status"];
    if (![statusObj isKindOfClass:[NSString class]] &&
        ![statusObj isKindOfClass:[NSNumber class]]) {
        statusObj = nil;
    }
    BOOL status = [statusObj boolValue];

    id errorCodeObj = [response objectForKey:@"error_code"];
    int errorCode;
    if (([errorCodeObj isKindOfClass:[NSString class]] ||
         [errorCodeObj isKindOfClass:[NSNumber class]]) &&
        errorCodeObj != nil) {
        errorCode = [errorCodeObj intValue];
    } else {
        errorCode = 100000000;
    }

    id kindObj = [response objectForKey:@"kind"];
    if (![kindObj isKindOfClass:[NSString class]]) {
        kindObj = nil;
    }

    if (!status || errorCode != 100000000) {
        int code;
        if (errorCode == 0xc106101) {
            code = 0x3f1;
        } else if ([kindObj isEqualToString:@"authorization"]) {
            code = 0x3ea;
        } else if ([kindObj isEqualToString:@"parameter_error"]) {
            code = 0x3e9;
        } else {
            code = 1000;
        }
        if (error != NULL) {
            *error = [RewardNetworkError localizedRewardNetworkErrorWithCode:code
                                                                    userInfo:response];
        }
    }
}

#pragma mark - Crypto helpers

// @ 0xeac08 — lowercase hex SHA-1 of the UTF-8 bytes of a string (40-char
// digest string).
+ (NSString *)sha1:(NSString *)string {
    NSData *data = [NSData dataWithBytes:[string cStringUsingEncoding:NSUTF8StringEncoding]
                                  length:[string length]];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([data bytes], (CC_LONG)[data length], digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

// @ 0xea72c — raw 20-byte SHA-1 digest of arbitrary data (used as the AES key
// material).
+ (NSData *)createHash:(NSData *)data {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([data bytes], (CC_LONG)[data length], digest);
    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

// @ 0xea7d8 — AES-128 (PKCS7-padded) transform. operation is kCCEncrypt (0) or
// kCCDecrypt (1); key is used as a 16-byte AES key with a zero IV. Returns the
// transformed data, or nil on error.
+ (NSData *)cryptorToData:(uint)operation value:(NSData *)value key:(NSData *)key {
    NSMutableData *output = [NSMutableData dataWithLength:[value length] + kCCBlockSizeAES128];
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(operation,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     [key bytes],
                                     kCCKeySizeAES128,
                                     NULL,
                                     [value bytes],
                                     [value length],
                                     [output mutableBytes],
                                     [output length],
                                     &moved);
    if (status == kCCSuccess) {
        return [NSData dataWithBytes:[output bytes] length:moved];
    }
    return nil;
}

// .cxx_destruct @ 0xeba60 — compiler-emitted ARC teardown; not hand-written.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
