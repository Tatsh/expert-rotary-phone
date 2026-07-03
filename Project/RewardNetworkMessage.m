//
//  RewardNetworkMessage.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkMessage.h"

@implementation RewardNetworkMessage

// @ 0xf5904
+ (NSString *)localizedMessage:(NSString *)key {
    // TODO(dep): +[NSBundle rewardBundle] is provided by the NSBundle+RewardNetwork
    // category (genuinely unreconstructed). Resolve it dynamically to avoid a
    // call-site extern / category seam.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSBundle *bundle = [NSBundle performSelector:@selector(rewardBundle)];
#pragma clang diagnostic pop
    return [bundle localizedStringForKey:key value:@"" table:@"Message"];
}

@end
