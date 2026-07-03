//
//  RewardNetwork.h
//  pop'n rhythmin
//
//  Public facade of the bundled Konami **RewardNetwork** ("applilink") ad/reward SDK:
//  opens the reward app-list web panel, queries the reward app index, reports installs,
//  and keeps a small expiring key/value cache in NSUserDefaults. Requests go through
//  +[RewardNetworkWebAPI requestAsynchronousWithURL:...]; the panel is a
//  RewardNetworkWebViewController.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (RewardNetwork methods @ 0xee3f8..0xf3bf4, plus the helpers +baseUrlSsl @ 0xf1e88 and
//  +startWithBlock: @ 0xef058 that the listed methods call). Superclass is NSObject.
//
//  Two instance variables: _webViewController (RewardNetworkWebViewController*),
//  _initializeFlg (int).
//
//  NOTE: the project also ships a neutralized Stubs/RewardNetwork.h used by AppDelegate;
//  this file is the faithful reconstruction of the real class.
//

#import <Foundation/Foundation.h>

#import "RewardNetworkWebViewController.h"   // ivar type + RewardNetworkWebViewDelegate

@class RewardNetworkWebViewController;

// Single result/error callback used by the app-index / install-report requests.
typedef void (^RewardNetworkCallback)(id result, NSError *error);

@interface RewardNetwork : NSObject {
    RewardNetworkWebViewController *_webViewController;   // the reward app-list panel
    int _initializeFlg;                                    // SDK initialization state
}

// initializeFlg getter also gates on ad-tracking being enabled (returns 0 if not). @ 0xee3f8
- (int)initializeFlg;
- (void)setInitializeFlg:(int)initializeFlg;   // @ 0xee438

// Queue-guarded shared-instance initializer. @ 0xee634
- (instancetype)init;

// Open the reward app-list web panel (requires the SDK be usable + ad-tracking enabled;
// otherwise reports the failure to `delegate`). @ 0xf0a80
- (void)openAppListWebViewWithCampaignId:(NSString *)campaignId
                               inCompany:(NSString *)inCompany
                                    type:(NSString *)type
                                  offset:(NSString *)offset
                                   limit:(NSString *)limit
                              parentView:(UIView *)parentView
                                delegate:(id<RewardNetworkWebViewDelegate>)delegate;

// Fetch the reward app index (GET /reward/app/index.php). @ 0xf12d4
- (void)appListWithCampaignId:(NSString *)campaignId
                    inCompany:(NSString *)inCompany
                         type:(NSString *)type
                       offset:(NSString *)offset
                        limit:(NSString *)limit
                     callback:(RewardNetworkCallback)callback;

// Forward a rotation to the open app-list panel. @ 0xf1ff8
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

// Expiring key/value cache backed by NSUserDefaults (archived {Value,Expire}). @ 0xf2030
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration;
// @ 0xf2168 — returns the value if unexpired, else evicts and returns nil.
- (id)getTemporaryCacheWithKey:(NSString *)key;

// Fetch the installed-appli id list (GET /reward/app/install/appliid/index.php). @ 0xf22e0
- (void)appliIdListWithType:(int)type callback:(RewardNetworkCallback)callback;

// Report installed applis in batches of 10 (POST /reward/app/install/report/regist.php),
// chaining the remainder. @ 0xf25fc
- (void)postAppliInstallReportWithAppliList:(NSArray *)appliList callback:(RewardNetworkCallback)callback;

// Query already-installed applis (type 2) and report those actually installed. @ 0xf2a48
- (void)postAlreadyInstallAppWithCallback:(RewardNetworkCallback)callback;

// No-op in release builds. @ 0xf3bf4
- (void)debugLog;

// --- class helpers the methods above call (owned by this class) ---

// SSL base URL selected from the ApplilinkReward.env default. @ 0xf1e88
+ (NSString *)baseUrlSsl;

// Ensure the SDK is started (reads the persisted appliId/URL/method/env), then run
// `block`; reports a parameter error if any default is missing. @ 0xef058
+ (void)startWithBlock:(void (^)(NSError *error))block;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
