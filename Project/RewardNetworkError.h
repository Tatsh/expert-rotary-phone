//
//  RewardNetworkError.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK error factory. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin. The class holds no instance
//  state (instanceSize 4 == isa only, no ivars, no instance methods);
//  everything lives on the metaclass as the two class factories below.
//
//  +localizedRewardNetworkErrorWithCode:userInfo: (@ 0xf3f00) builds an NSError
//  in the "ApplilinkErrorDomain", filling NSLocalizedDescriptionKey from a
//  lazily built, process-wide message table whose strings come from the SDK's
//  localized "Error" table (via the NSBundle+RewardNetwork `rewardBundle`
//  category).
//

#import <Foundation/Foundation.h>

/**
 * @brief Builds localised NSErrors for the reward SDK.
 */
@interface RewardNetworkError : NSObject

/**
 * @brief Build a localised reward-network error.
 * @param code The error code.
 * @param userInfo Extra user info to attach; may be nil.
 * @return The error.
 * @ghidraAddress 0xf3f00
 */
+ (NSError *)localizedRewardNetworkErrorWithCode:(NSInteger)code userInfo:(NSDictionary *)userInfo;

/**
 * @brief Build a localised Applilink error, forwarding to
 * +localizedRewardNetworkErrorWithCode:userInfo: with a nil userInfo.
 * @param code The error code.
 * @return The error.
 * @ghidraAddress 0xf58e4
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code;

/**
 * @brief Build a localised reward-network error with a nil userInfo.
 * @param code The error code.
 * @return The error.
 */
+ (NSError *)localizedRewardNetworkErrorWithCode:(NSInteger)code;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
