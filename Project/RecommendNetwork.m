//
//  RecommendNetwork.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendNetwork.h"

// Module global owned by RecommendNetwork's shared-instance machinery. The serial
// "RewardNetwork" queue is created in the class's shared-instance allocWithZone: path
// (Ghidra recommendNetworkSharedAlloc @ 0xebcac, a dispatch_once body), which also zeroes
// the fresh instance's initializeFlg. That allocation path is outside this pass's method
// list; -init below faithfully dispatches onto the queue it produces.
static dispatch_queue_t g_pRewardNetworkQueue = NULL;   // @ g_pRewardNetworkQueue

@implementation RecommendNetwork {
    int _initializeFlg;
}

// @ 0xeba74 — perform [super init] on the shared RewardNetwork serial queue and return the
// resulting instance. The captured self is retained for the block and released afterwards
// (handled automatically under ARC); the block stores its [super init] result into the
// __block variable that is then handed back.
- (instancetype)init {
    __block RecommendNetwork *result = nil;
    dispatch_sync(g_pRewardNetworkQueue, ^{
        result = [super init];
    });
    return result;
}

// @ 0xec4b4
- (int)initializeFlg {
    return _initializeFlg;
}

// @ 0xec4c4
- (void)setInitializeFlg:(int)initializeFlg {
    _initializeFlg = initializeFlg;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
