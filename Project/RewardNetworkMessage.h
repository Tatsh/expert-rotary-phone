/**
 * @file
 * @brief The Konami "RewardNetwork" (Applilink) ad-SDK localised-message lookup.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. It holds no instance state
 * (instanceSize 4, isa only, no ivars, no instance methods); the single factory lives on the
 * metaclass.
 */

#import <Foundation/Foundation.h>

/**
 * @brief Looks up the reward SDK's localised strings.
 */
@interface RewardNetworkMessage : NSObject

/**
 * @brief Look up a key in the SDK bundle's localised "Message" table.
 * @param key The message key.
 * @return The localised message.
 * @ghidraAddress 0xf5904
 */
+ (NSString *)localizedMessage:(NSString *)key;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
