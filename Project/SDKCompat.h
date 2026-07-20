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
//  Guarded constant aliases: the source always spells the MODERN constant name;
//  for an SDK too old to declare it, the modern name is defined back to the
//  original constant that old SDK ships. On a new-enough SDK the macro is absent
//  and the modern constant resolves directly.
//

#pragma once

#import <Foundation/Foundation.h>

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
#define NSCalendarUnitYear NSYearCalendarUnit
#define NSCalendarUnitMonth NSMonthCalendarUnit
#define NSCalendarUnitDay NSDayCalendarUnit
#endif

#if !defined(__IPHONE_9_0) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0
#define kAudioUnitSubType_SpatialMixer kAudioUnitSubType_AU3DMixerEmbedded
#endif

// kate: hl Objective-C;
// vim: set ft=objc :
// code: language=Objective-C
