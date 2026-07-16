//
//  RewardNetworkError.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkError.h"
#import "NSBundle+RewardNetwork.h" // +rewardBundle (RewardNetworkResources.bundle)

// Error domain constant (CFString cf_ApplilinkErrorDomain @ 0x115d6d).
static NSString *const RewardNetworkErrorDomain = @"ApplilinkErrorDomain";

// Process-wide cache of localized error messages, keyed by NSNumber(code).
// Mirrors the file-scope g_pRewardErrorMessageDict global the SDK lazily fills.
static NSMutableDictionary *g_pRewardErrorMessageDict = nil;

@implementation RewardNetworkError

// @ 0xf58e4
// @complete
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code {
    return [self localizedRewardNetworkErrorWithCode:code userInfo:nil];
}

// Convenience: forward to the userInfo: form with no extra info.
+ (NSError *)localizedRewardNetworkErrorWithCode:(NSInteger)code {
    return [self localizedRewardNetworkErrorWithCode:code userInfo:nil];
}

// @ 0xf3f00 — build a localized NSError. On first use, the message table is
// populated from the SDK bundle's "Error" strings table; each entry falls back
// to a hard-coded English default when the bundle/string is unavailable. The
// message for the requested code (or 1000, the "unexpected" bucket) is
// installed under NSLocalizedDescriptionKey.
// @complete
+ (NSError *)localizedRewardNetworkErrorWithCode:(NSInteger)code userInfo:(NSDictionary *)userInfo {
    // The localized "Error" strings come from RewardNetworkResources.bundle.
    NSBundle * (^rewardBundle)(void) = ^NSBundle * {
      return [NSBundle rewardBundle];
    };

    if (g_pRewardErrorMessageDict == nil) {
        g_pRewardErrorMessageDict = [[NSMutableDictionary alloc] init];

        // { code, localized-key, English fallback }
        struct {
            NSInteger code;
            NSString *key;
            NSString *fallback;
        } entries[] = {
            {1000, @"ApplilinkUnexpectedError", @"Unexpected error."},
            {0x3e9, @"ApplilinkParameterError", @"Parameter error."},
            {0x3ea, @"ApplilinkAuthLoginError", @"Failed to login."},
            {0x3eb, @"ApplilinkErrorResponseEmpty", @"Response empty."},
            {0x3ec, @"ApplilinkErrorLoginTokenGetFailed", @"Failed to get login token."},
            {0x3ed,
             @"ApplilinkErrorLoginTokenRequestError",
             @"Login token request unexpected error."},
            {0x3ee, @"ApplilinkErrorContentsServer", @"Contents server error occurred."},
            {0x3ef,
             @"ApplilinkInvalidContentsServerStatus",
             @"Invalid response status from contents server."},
            {0x3f0, @"ApplilinkErrorApplicationInstall", @"Failed to notify application install."},
            {0x3f1, @"ApplilinkErrorApplicationNotFound", @"Application not found."},
            {0x3f2, @"ApplilinkErrorNeedToInitialize", @"Need to initilize."},
            {0x3f3, @"ApplilinkPasteBoardErrorStorageFull", @"Storage is full."},
            {0x3f4, @"ApplilinkPasteBoardErrorEmptyValue", @"Not found key."},
            {0x3f5,
             @"ApplilinkPasteBoardErrorInvalidField",
             @"Failed to get pasteboard index pointer."},
            {0x3f6,
             @"ApplilinkPasteBoardErrorUnarchiveFailed",
             @"Failed to un-archive pasteboard data"},
            {0x3f7, @"ApplilinkPasteBoardErrorWriteFailed", @"Failed to write pasteboard data."},
            {0x3f8, @"ApplilinkPasteBoardErrorValidateError", @"Validate error."},
            {0x3f9, @"ApplilinkPasteBoardErrorInvalidKey", @"Invalid pasteboard key."},
            {0x3fa,
             @"ApplilinkPasteBoardErrorInvalidDataType",
             @"Failed to get directed pasteboard data type."},
            {0x3fb, @"ApplilinkPasteBoardErrorInvalidFormat", @"Invalid data format."},
            {0x3fc, @"ApplilinkPasteBoardErrorInvalidValue", @"Invalid value data."},
            {0x3fd, @"ApplilinkPasteBoardErrorInvalidEntryDate", @"Invalid entry_date data."},
            {0x3fe, @"ApplilinkPasteBoardErrorInvalidLastAccess", @"Invalid last_access data."},
            {0x3ff, @"ApplilinkPasteBoardErrorInvalidVersion", @"Invalid version data."},
            {0x400, @"ApplilinkPasteBoardErrorOldVersion", @"Old system version."},
            {0x401,
             @"ApplilinkErrorSdkVersionNotSupported",
             @"Reward SDK is supported in iOS 5.0 and later."},
            {0x402, @"ApplilinkErrorUdidNotFound", @"Udid not found. Please restart application."},
            {0x403, @"ApplilinkErrorHTTPRequestTimeout", @"HTTP Request timeout."},
            {0x404, @"ApplilinkErrorCannotGetAdvertisingId", @"Cannot get Advertising Identifier."},
        };
        for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); i++) {
            NSBundle *bundle = rewardBundle();
            NSString *message = entries[i].fallback;
            if (bundle != nil) {
                message = [bundle localizedStringForKey:entries[i].key
                                                  value:entries[i].fallback
                                                  table:@"Error"];
            }
            g_pRewardErrorMessageDict[@(entries[i].code)] = message;
        }
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    if (g_pRewardErrorMessageDict != nil) {
        NSString *message = g_pRewardErrorMessageDict[@((int)code)];
        if (message == nil) {
            message = g_pRewardErrorMessageDict[@(1000)];
        }
        if (message != nil) {
            info[NSLocalizedDescriptionKey] = message;
        }
    }

    return [NSError errorWithDomain:RewardNetworkErrorDomain code:code userInfo:info];
}

@end
