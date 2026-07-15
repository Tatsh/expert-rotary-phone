//
//  SDKCompat.h
//  pop'n rhythmin
//
//  Compatibility shims that let the reconstruction use the modern Objective-C
//  API names uniformly while still being buildable against the very old SDK the
//  app originally targeted.
//
//  Import this in any file that uses one of the aliased constants.
//
//  Two facilities:
//    * Guarded constant aliases: the source always spells the MODERN constant
//      name; for an SDK too old to declare it, the modern name is defined back
//      to the original constant that old SDK ships. On a new-enough SDK the
//      macro is absent and the modern constant resolves directly.
//    * RB_DEPRECATED_BEGIN / RB_DEPRECATED_END: bracket a block that uses an API
//      Apple deprecated with no in-place replacement (only OpenGL ES is expected
//      to need this in practice), silencing -Wdeprecated-declarations there.
//

#pragma once

#import <Availability.h>

// --- Modern constant names aliased back to the originals on old SDKs ----------

#if !defined(__IPHONE_7_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
#define NSFontAttributeName UITextAttributeFont
#define NSForegroundColorAttributeName UITextAttributeTextColor
#define NSShadowAttributeName UITextAttributeTextShadowColor
#endif

#if !defined(__IPHONE_8_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
#define NSCalendarIdentifierGregorian NSGregorianCalendar
#define kCLAuthorizationStatusAuthorizedAlways kCLAuthorizationStatusAuthorized
#endif

// --- No-replacement deprecations: silence only the wrapped block --------------
// Use around calls into APIs Apple deprecated wholesale with no in-place modern
// equivalent (the OpenGL ES renderer) that the reconstruction keeps as-is.

#define RB_DEPRECATED_BEGIN                                                                        \
    _Pragma("clang diagnostic push")                                                               \
        _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#define RB_DEPRECATED_END _Pragma("clang diagnostic pop")

// kate: hl Objective-C;
// vim: set ft=objc :
// code: language=Objective-C
