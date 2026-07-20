//
//  NSBundle+RewardNetwork.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See NSBundle+RewardNetwork.h for the overview.
//

#import "NSBundle+RewardNetwork.h"

// The cached resource bundle (DAT_00188360, once token DAT_00188364).
static NSBundle *g_pRewardBundle = nil;

@implementation NSBundle (RewardNetwork)

// @ 0xfc0cc — dispatch_once lazy accessor for the
// RewardNetworkResources.bundle.
+ (NSBundle *)rewardBundle {
    static dispatch_once_t onceToken;
    // @ 0xfc100 — dispatch_once body: resolve RewardNetworkResources.bundle from
    // the main bundle's resources and cache it (logging when it cannot be found).
    dispatch_once(&onceToken, ^{
      NSString *path = [[NSBundle mainBundle] pathForResource:@"RewardNetworkResources"
                                                       ofType:@"bundle"];
      g_pRewardBundle = [NSBundle bundleWithPath:path];
      if (g_pRewardBundle == nil) {
          NSLog(@"RewardNetworkResources could not be found.");
      }
    });
    return g_pRewardBundle;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
