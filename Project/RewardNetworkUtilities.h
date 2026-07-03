//
//  RewardNetworkUtilities.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK grab-bag of stateless helpers.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. No instance state
//  (instanceSize 4 == isa only, no ivars, no instance methods); the 11 helpers below
//  all live on the metaclass.
//

#import <UIKit/UIKit.h>

@interface RewardNetworkUtilities : NSObject

// @ 0xf9874 — merge two dictionaries (values in `b` win) into a new mutable one.
+ (NSMutableDictionary *)joinDictionary:(NSDictionary *)a withDictionary:(NSDictionary *)b;

// @ 0xf9910 — build the SDK User-Agent string.
+ (NSString *)userAgent;

// @ 0xf9af8 — build the User-Agent as a query-parameter dictionary (ua_* keys).
+ (NSMutableDictionary *)userAgentParameters;

// @ 0xf9e58 — hardware model identifier (e.g. "iPhone7,2"), cached per process.
+ (NSString *)deviceName;

// @ 0xfa100 — append a parameter dictionary to `url` as a URL query string.
+ (NSString *)appendParametersToURL:(NSString *)url parameters:(NSDictionary *)parameters;

// @ 0xfa464 — preferred language code (falls back to "ja").
+ (NSString *)localeString;

// @ 0xfa4dc — country code from the current locale (falls back to "JP").
+ (NSString *)countryCodeString;

// @ 0xfa560 — YES if `responder` sits under a window/app/view/view-controller.
+ (BOOL)hasParentViewController:(id)responder;

// @ 0xfa660 — YES on iOS 5.0 or later.
+ (BOOL)canUseRewardSdk;

// @ 0xfa6e4 — the SDK version string ("1.0.31").
+ (NSString *)getSdkVersion;

// @ 0xfa6fc — percent-escape a string for use in a URL query.
+ (NSString *)URLEncodedString:(NSString *)string;

@end

// Generic percent-encode / decode free helpers (a separate pair from +URLEncodedString:).
// Reached only via a data function-pointer table in the binary; see the .m / HANDOFF.md.
NSString *urlEncodeString(NSString *string);   // @ 0xfc1d0
NSString *urlDecodeString(NSString *string);   // @ 0xfc218

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
