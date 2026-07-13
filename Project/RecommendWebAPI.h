//
//  RecommendWebAPI.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the Recommend-specific web-API entry
//  point. A behaviourless subclass of RewardNetworkWebAPI: Ghidra shows an
//  empty class body and an empty metaclass, so it adds no methods or ivars of
//  its own. It exists only so the Recommend feature can issue the inherited
//    +requestSynchronousWithURL:method:parameters:cachePolicy:error:
//  under its own class object (see RecommendAdId's pasteboard calls).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass
//  determined from the Objective-C class_t metadata (superclass name
//  "RewardNetworkWebAPI").
//

#import <Foundation/Foundation.h>

// RewardNetworkWebAPI — the synchronous Applilink web-API superclass. It
// supplies +requestSynchronousWithURL:method:parameters:cachePolicy:error:.
#import "RewardNetworkWebAPI.h"

@interface RecommendWebAPI : RewardNetworkWebAPI

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
