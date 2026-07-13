//
//  RewardNetworkMessage.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK localized-message lookup.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. No instance
//  state (instanceSize 4
//  == isa only, no ivars, no instance methods); the single factory lives on the
//  metaclass.
//

#import <Foundation/Foundation.h>

@interface RewardNetworkMessage : NSObject

// @ 0xf5904 — look up `key` in the SDK bundle's localized "Message" table.
+ (NSString *)localizedMessage:(NSString *)key;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
