//
//  RewardNetworkMessage.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkMessage.h"

#import "NSBundle+RewardNetwork.h" // +rewardBundle (RewardNetworkResources.bundle)

@implementation RewardNetworkMessage

// @ 0xf5904
+ (NSString *)localizedMessage:(NSString *)key {
    NSBundle *bundle = [NSBundle rewardBundle];
    return [bundle localizedStringForKey:key value:@"" table:@"Message"];
}

@end
