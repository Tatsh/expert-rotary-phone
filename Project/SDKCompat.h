/**
 * @file
 * Compatibility shims for the modern Objective-C API names.
 *
 * @newCode
 *
 * They let the reconstruction use the modern names uniformly while remaining buildable against the
 * very old SDK the app originally targeted. Import this in any file that uses one of the aliased
 * constants.
 *
 * The aliases are guarded: the source always spells the modern constant name, and for an SDK too
 * old to declare it, the modern name is defined back to the original constant that old SDK ships.
 * On a new-enough SDK the macro is absent and the modern constant resolves directly.
 */

#pragma once

#import <Foundation/Foundation.h>

#import <Availability.h>

// --- Modern constant names aliased back to the originals on old SDKs ----------

#if !defined(__IPHONE_7_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
/** The pre-iOS 7 spelling of the text-attribute font key. */
#define NSFontAttributeName UITextAttributeFont
/** The pre-iOS 7 spelling of the text-attribute foreground colour key. */
#define NSForegroundColorAttributeName UITextAttributeTextColor
/** The pre-iOS 7 spelling of the text-attribute shadow key. */
#define NSShadowAttributeName UITextAttributeTextShadowColor
#endif

#if !defined(__IPHONE_8_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
/** The pre-iOS 8 spelling of the Gregorian calendar identifier. */
#define NSCalendarIdentifierGregorian NSGregorianCalendar
/** The pre-iOS 8 spelling of the always-authorised location status. */
#define kCLAuthorizationStatusAuthorizedAlways kCLAuthorizationStatusAuthorized
/** The pre-iOS 8 spelling of the year calendar unit. */
#define NSCalendarUnitYear NSYearCalendarUnit
/** The pre-iOS 8 spelling of the month calendar unit. */
#define NSCalendarUnitMonth NSMonthCalendarUnit
/** The pre-iOS 8 spelling of the day calendar unit. */
#define NSCalendarUnitDay NSDayCalendarUnit
#endif

#if !defined(__IPHONE_9_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0
/** The pre-iOS 9 spelling of the spatial-mixer audio-unit subtype. */
#define kAudioUnitSubType_SpatialMixer kAudioUnitSubType_AU3DMixerEmbedded
#endif

// kate: hl Objective-C;
// vim: set ft=objc :
// code: language=Objective-C
