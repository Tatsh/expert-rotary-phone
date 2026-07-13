//
//  RewardNetwork.h  (STUB)
//  pop'n rhythmin
//
//  No-op replacement for the bundled **RewardNetwork** ad-reward SDK.
//  Per project policy nothing ad-related is linked or shipped; this header
//  keeps the original call sites compiling while contacting no ad network.
//
//  The real SDK exposed classes RewardNetwork, RewardNetworkError,
//  RewardNetworkIndicator, RewardNetworkMessage, RewardNetworkPasteBoard,
//  RewardNetworkURLConnection, RewardNetworkUdid, RewardNetworkUtilities,
//  RewardNetworkWebAPI, RewardNetworkWebViewController. Only the entry points
//  the app actually calls are stubbed here; add more no-ops if further call
//  sites surface during reconstruction.
//

#ifndef RewardNetwork_stub_h
#define RewardNetwork_stub_h

#import <Foundation/Foundation.h>

// Called at launch instead of the original
//   +[RewardNetwork startWithAppliId:env:callback:]  (Ghidra @ 0x8cf0 call
//   site).
// Intentionally does nothing.
static inline void RewardNetwork_startDisabled(void) { /* ad SDK removed */
}

@interface RewardNetwork : NSObject
+ (void)startWithAppliId:(NSString *)appId env:(NSInteger)env callback:(id)callback; // no-op
@end

#endif /* RewardNetwork_stub_h */

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
