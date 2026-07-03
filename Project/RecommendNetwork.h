//
//  RecommendNetwork.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — a tiny bookkeeping object that tracks whether the
//  Recommend network layer has been initialised. Its designated initialiser runs [super init]
//  on the shared "RewardNetwork" serial dispatch queue so that instance creation is serialised
//  against the rest of the SDK's networking.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass (NSObject) and the
//  int `_initializeFlg` ivar come from the Objective-C class_t metadata.
//    init @ 0xeba74   initializeFlg @ 0xec4b4   setInitializeFlg: @ 0xec4c4
//

#import <Foundation/Foundation.h>

@interface RecommendNetwork : NSObject

// Backed by the int `_initializeFlg` ivar; cleared to 0 when the shared instance is allocated.
@property (nonatomic, assign) int initializeFlg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
