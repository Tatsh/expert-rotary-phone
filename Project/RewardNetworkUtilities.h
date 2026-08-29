/**
 * @file
 * The Konami "RewardNetwork" (Applilink) ad-SDK grab-bag of stateless helpers.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. It holds no instance state
 * (instanceSize 4, isa only, no ivars, no instance methods); the 11 helpers below all live on the
 * metaclass.
 */

#import <UIKit/UIKit.h>

/**
 * The reward SDK's small helpers: user agent, device info, URL building and locale.
 */
@interface RewardNetworkUtilities : NSObject

/**
 * Merge two dictionaries into a new mutable one.
 * @param a The base dictionary.
 * @param b The overriding dictionary; its values win.
 * @return The merged dictionary.
 * @ghidraAddress 0xf9874
 */
+ (NSMutableDictionary *)joinDictionary:(NSDictionary *)a withDictionary:(NSDictionary *)b;

/**
 * Build the SDK User-Agent string.
 * @return The User-Agent.
 * @ghidraAddress 0xf9910
 */
+ (NSString *)userAgent;

/**
 * Build the User-Agent as a query-parameter dictionary, using ua_* keys.
 * @return The parameter dictionary.
 * @ghidraAddress 0xf9af8
 */
+ (NSMutableDictionary *)userAgentParameters;

/**
 * The hardware model identifier, such as "iPhone7,2"; cached per process.
 * @return The model identifier.
 * @ghidraAddress 0xf9e58
 */
+ (NSString *)deviceName;

/**
 * Append a parameter dictionary to a URL as a query string.
 * @param url The base URL.
 * @param parameters The query parameters.
 * @return The full URL.
 * @ghidraAddress 0xfa100
 */
+ (NSString *)appendParametersToURL:(NSString *)url parameters:(NSDictionary *)parameters;

/**
 * The preferred language code.
 * @return The language code, falling back to "ja".
 * @ghidraAddress 0xfa464
 */
+ (NSString *)localeString;

/**
 * The country code from the current locale.
 * @return The country code, falling back to "JP".
 * @ghidraAddress 0xfa4dc
 */
+ (NSString *)countryCodeString;

/**
 * Whether a responder sits under a window, application, view or view controller.
 * @param responder The responder to walk from.
 * @return YES when a host was found.
 * @ghidraAddress 0xfa560
 */
+ (BOOL)hasParentViewController:(id)responder;

/**
 * Whether the SDK can run on this OS.
 * @return YES on iOS 5.0 or later.
 * @ghidraAddress 0xfa660
 */
+ (BOOL)canUseRewardSdk;

/**
 * The SDK version string.
 * @return "1.0.31".
 * @ghidraAddress 0xfa6e4
 */
+ (NSString *)getSdkVersion;

/**
 * Percent-escape a string for use in a URL query.
 * @param string The string to escape.
 * @return The escaped string.
 * @ghidraAddress 0xfa6fc
 */
+ (NSString *)URLEncodedString:(NSString *)string;

@end

// Generic percent-encode / decode free helpers (a separate pair from
// +URLEncodedString:). Reached only via a data function-pointer table in the
// binary; see the .m / HANDOFF.md. NOTE: this reward-side urlEncodeString (@
// 0xfc1d0) is functionally identical to StoreUtil's
// (@ 0x5c5ec) and unused outside RewardNetworkUtilities.m, so it is file-static
// there (avoids a duplicate global with StoreUtil's canonical one). Callers
// include StoreUtil.h. (percent-decode is -[NSString URLDecodedString] @
// 0xfc218, in NSString+URLDecode.h)

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
