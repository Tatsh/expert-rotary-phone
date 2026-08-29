/**
 * @file
 * The NSBundle category the RewardNetwork ("applilink") SDK locates its resource bundle
 * with.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The bundle is
 * "RewardNetworkResources.bundle", holding the localised "Error" and "Message" string tables.
 * +rewardBundle caches the resolved bundle with dispatch_once.
 *
 * RewardNetworkError.m and RewardNetworkMessage.m reach this via -performSelector:, so they do not
 * pull in the category directly; this file is the faithful home of the real method.
 */

#import <Foundation/Foundation.h>

/**
 * Locates the reward-network resource bundle.
 */
@interface NSBundle (RewardNetwork)

/**
 * The cached RewardNetworkResources.bundle, resolved once via dispatch_once.
 * @return The resource bundle.
 * @ghidraAddress 0xfc0cc
 */
+ (NSBundle *)rewardBundle;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
