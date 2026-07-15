//
//  SDKCompat.h
//  pop'n rhythmin
//
//  Compatibility shims that let the reconstruction keep the original 2014-era
//  Objective-C API names — so the source stays faithful to the binary and can
//  still target the very old SDK it was written against — while building
//  cleanly against a modern SDK.
//
//  Import this AFTER the system framework headers in any file that needs it (the
//  aliases below deliberately do not touch the SDK's own declarations, only the
//  reconstruction's later uses).
//
//  Two facilities:
//    * Guarded constant aliases: on a new-enough SDK a removed/renamed constant
//      is redirected to its modern equivalent; on the old SDK the macro is
//      absent and the original name resolves to the SDK constant directly.
//    * RB_DEPRECATED_BEGIN / RB_DEPRECATED_END: bracket a block that uses an API
//      Apple deprecated with no in-place replacement, silencing
//      -Wdeprecated-declarations for that block only.
//

#pragma once

#import <Availability.h>

// --- Simple constant/enum renames (keep the original name in the source) -----

#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
#define UITextAttributeFont NSFontAttributeName
#define UITextAttributeTextColor NSForegroundColorAttributeName
#define UITextAttributeTextShadowColor NSShadowAttributeName
#endif

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#define NSGregorianCalendar NSCalendarIdentifierGregorian
#define kCLAuthorizationStatusAuthorized kCLAuthorizationStatusAuthorizedAlways
#endif

// --- No-replacement deprecations: silence only the wrapped block --------------
// Use around calls into APIs Apple deprecated wholesale with no in-place
// modern equivalent (UIWebView, NSURLConnection, UILocalNotification, the
// pasteboard-persistence property, etc.) that the reconstruction keeps as-is.

#define RB_DEPRECATED_BEGIN                                                                        \
    _Pragma("clang diagnostic push")                                                               \
        _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#define RB_DEPRECATED_END _Pragma("clang diagnostic pop")

// kate: hl Objective-C;
// vim: set ft=objc :
// code: language=Objective-C
