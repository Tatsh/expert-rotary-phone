//
//  RewardNetworkUtilities.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkUtilities.h"

#import <sys/sysctl.h>
#import <errno.h>

// SDK version literal (CFString cf_1_0_31 @ 0x11659b).
static NSString *const kRewardSdkVersion = @"1.0.31";

@implementation RewardNetworkUtilities

// @ 0xf9874
+ (NSMutableDictionary *)joinDictionary:(NSDictionary *)a withDictionary:(NSDictionary *)b {
    NSMutableDictionary *merged =
        [NSMutableDictionary dictionaryWithCapacity:[a count] + [b count]];
    [merged addEntriesFromDictionary:a];
    [merged addEntriesFromDictionary:b];
    return merged;
}

// @ 0xf9910
+ (NSString *)userAgent {
    UIDevice *device = [UIDevice currentDevice];
    NSString *bundleVersion =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *appliId =
        [[NSUserDefaults standardUserDefaults] valueForKey:@"ApplilinkReward.appliId"];
    return [NSString stringWithFormat:
            @"applilink/%@ (%@; %@ %@; in-appli; %@; appli-version; %@; Language; %@; Region; %@; )",
            kRewardSdkVersion,
            [self deviceName],
            device.systemName,
            device.systemVersion,
            appliId,
            bundleVersion,
            [self localeString],
            [self countryCodeString]];
}

// @ 0xf9af8
+ (NSMutableDictionary *)userAgentParameters {
    UIDevice *device = [UIDevice currentDevice];
    NSString *bundleVersion =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:6];

    NSString *appliId =
        [[NSUserDefaults standardUserDefaults] valueForKey:@"ApplilinkReward.appliId"];
    if (appliId != nil) {
        params[@"ua_appli_id"] = appliId;
    }

    params[@"ua_device"] = [self URLEncodedString:[self deviceName]];
    params[@"ua_os"] = [self URLEncodedString:
        [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion]];
    params[@"ua_sdk"] = [self URLEncodedString:
        [NSString stringWithFormat:@"RewardNetwork/%@", kRewardSdkVersion]];

    if (bundleVersion != nil) {
        params[@"ua_appli_ver"] = [self URLEncodedString:bundleVersion];
    }

    NSString *lang = [self localeString];
    if (lang != nil) {
        params[@"ua_lang"] = lang;
    }
    NSString *region = [self countryCodeString];
    if (region != nil) {
        params[@"ua_region"] = region;
    }

    return params;
}

// @ 0xf9e58 — read "hw.machine" once via sysctl and cache it.
+ (NSString *)deviceName {
    static NSString *cached = nil;
    if (cached == nil) {
        size_t size = 0;
        if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0) {
            [NSException raise:@"Warn" format:@"Failed in sysctlbyname. errno=%d", errno];
        }
        char *machine = malloc(size);
        if (machine == NULL) {
            [NSException raise:@"Warn" format:@"Failed in malloc in deviceName."];
        }
        if (sysctlbyname("hw.machine", machine, &size, NULL, 0) != 0) {
            free(machine);
            [NSException raise:@"Warn" format:@"Failed in sysctlbyname. errno=%d", errno];
        }
        cached = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
        free(machine);
    }
    return cached;
}

// @ 0xfa100
+ (NSString *)appendParametersToURL:(NSString *)url parameters:(NSDictionary *)parameters {
    NSString *result = url;
    for (id key in parameters) {
        id value = [parameters valueForKey:key];
        NSMutableArray *pairs = [NSMutableArray array];
        if (![value isKindOfClass:[NSArray class]]) {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [parameters objectForKey:key]]];
        } else {
            for (NSUInteger i = 0; i < [value count]; i++) {
                [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [value objectAtIndex:i]]];
            }
        }
        NSString *joined = [pairs componentsJoinedByString:@"&"];
        NSString *separator = @"&";
        if (result != nil && [result rangeOfString:@"?"].location == NSNotFound) {
            separator = @"?";
        }
        result = [result stringByAppendingFormat:@"%@%@", separator, joined];
    }
    return result;
}

// @ 0xfa464
+ (NSString *)localeString {
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    if (language == nil) {
        language = @"ja";
    }
    return language;
}

// @ 0xfa4dc
+ (NSString *)countryCodeString {
    NSString *country = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if (country == nil) {
        country = @"JP";
    }
    return country;
}

// @ 0xfa560 — walk `responder` up: a window/application/view-controller counts as a
// parent; a view recurses on its nextResponder.
+ (BOOL)hasParentViewController:(id)responder {
    if ([responder isKindOfClass:[UIWindow class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIApplication class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIView class]]) {
        return [self hasParentViewController:[responder nextResponder]];
    }
    if ([responder isKindOfClass:[UIViewController class]]) {
        return YES;
    }
    return NO;
}

// @ 0xfa660
+ (BOOL)canUseRewardSdk {
    return [[UIDevice currentDevice].systemVersion doubleValue] >= 5.0;
}

// @ 0xfa6e4
+ (NSString *)getSdkVersion {
    return kRewardSdkVersion;
}

// @ 0xfa6fc — percent-escape for a URL query, escaping the reserved set
// "!*'();:@&=+$,/?%#[]" (CFString @ 0x102c29) as UTF-8.
+ (NSString *)URLEncodedString:(NSString *)string {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (__bridge CFStringRef)string,
        NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"),
        kCFStringEncodingUTF8));
}

@end

// ---- generic percent-encode / decode free helpers ----
// These are a SEPARATE pair from +[RewardNetworkUtilities URLEncodedString:] (@ 0xfa6fc):
// plain C-linkage-shaped free functions that sit in the RewardNetwork SDK's __text
// neighborhood (next to the dispatch_once accessor @ 0xfc0cc). No direct code caller was
// recoverable — they are reached only through a data function-pointer table (@ 0x1593bc /
// 0x193a28), so they are homed here in the SDK's utilities grab-bag (see HANDOFF.md).

// @ 0xfc1d0 — percent-escape `string` for a URL query (escapes "!*'();:@&=+$,/?%#[]"; UTF-8).
NSString *urlEncodeString(NSString *string) {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (__bridge CFStringRef)string,
        NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"),
        kCFStringEncodingUTF8));
}

// @ 0xfc218 — percent-decode `string` (UTF-8). The binary passes a shared "%d/%02d/15
// 12:00:00" CFString (@ 0x10869e) as charactersToLeaveEscaped — recovered verbatim; the
// reused date-format literal is unusual but faithful to the binary.
NSString *urlDecodeString(NSString *string) {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
        kCFAllocatorDefault,
        (__bridge CFStringRef)string,
        CFSTR("%d/%02d/15 12:00:00"),
        kCFStringEncodingUTF8));
}
