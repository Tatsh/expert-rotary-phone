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

// Error-only completion (session start, login, install report).
typedef void (^RewardNetworkErrorBlock)(NSError *error);

// Integer-flag + error completion (all-install flag / banner-enabled queries).
typedef void (^RewardNetworkFlgCallback)(NSInteger flg, NSError *error);

@interface RewardNetwork : NSObject {
    RewardNetworkWebViewController *_webViewController;   // the reward app-list panel
    int _initializeFlg;                                    // SDK initialization state
}

// --- read-only class "properties" (custom getters, not ivar-backed) ---

// Persisted appli id (NSUserDefaults "ApplilinkReward.appliId"). @ 0xee1d4
@property (class, readonly, nonatomic) NSString *appliId;
// SDK version string from +[RewardNetworkUtilities getSdkVersion]. @ 0xee230
@property (class, readonly, nonatomic) NSString *version;
// Reward UDID (Value of the first valid stored record), or nil. @ 0xee24c
@property (class, readonly, nonatomic) NSString *udid;
// Advertising reward UDID, or nil. @ 0xee2f0
@property (class, readonly, nonatomic) NSString *ad_udid;
// Legacy keychain UDID, or nil. @ 0xee350
@property (class, readonly, nonatomic) NSString *old_udid;

// Shared-instance singleton (dispatch_once). @ 0xee774
+ (instancetype)sharedInstance;

// Campaign flag from NSUserDefaults, gated on ad-tracking + initializeFlg==1; -2 otherwise. @ 0xee448
+ (int)campaignFlg;

// YES when the SDK can run on this iOS version (== +canUseRewardSdk). @ 0xee52c
+ (BOOL)isSupportediOSVersion;

// Persist the session appli URL / parameters / method into NSUserDefaults. @ 0xee804
+ (void)setSessionParameters:(id)parameters url:(NSString *)url method:(NSString *)method;

// Start a reward session: check login, then run `block` with any error. @ 0xeed2c
+ (void)startSessionWithBlock:(RewardNetworkErrorBlock)block;

// Create/register the device UDID, writing to the first empty storage slot. @ 0xef274
+ (BOOL)createUdidWithError:(NSError **)error;

// POST the application-install report. @ 0xef4c4
+ (void)postApplicationInstallWithPriority:(int)priority callback:(RewardNetworkErrorBlock)callback;

// GET the login status (/reward/auth/checkLoginStatus.php). @ 0xefc14
+ (void)checkLoginWithBlock:(RewardNetworkCallback)block;

// Request an auth token using the stored session parameters. @ 0xeff88
+ (void)requestTokenWithBlock:(RewardNetworkCallback)block;

// POST login (/reward/auth/login.php) with an optional token. @ 0xf04bc
+ (void)startLoginWithToken:(NSString *)token withPriority:(int)priority callback:(RewardNetworkErrorBlock)callback;

// Query the all-install flag (cached under "appInstallFlg"). @ 0xf16d4
+ (void)allInstallFlgWithInCompany:(NSString *)inCompany callback:(RewardNetworkFlgCallback)callback;

// Delete every stored reward UDID slot + reset session state. @ 0xf2e14
+ (void)clearUDID;
// Delete the legacy keychain UDID + reset session state if all UDIDs gone. @ 0xf2fb4
+ (void)clearKeyChainOldUDID;
// Delete every advertising reward UDID slot + reset session state. @ 0xf3110
+ (void)clearAdUDID;
// Delete all cookies + stored session URL/parameters/method. @ 0xf3240
+ (void)clearSession;

// GET the banner detail (/reward/banner/detail.php). @ 0xf33dc
+ (void)bannerInfoWithBlock:(RewardNetworkCallback)block;
// Report whether the banner is enabled (uses the banner cache when fresh). @ 0xf3714
+ (void)isEnabledBannerWithBlock:(RewardNetworkFlgCallback)block;
// YES if any UDID exists (else evicts the banner cache). @ 0xf3b28
+ (BOOL)canUseBannerCache;
// Evict the in-memory banner cache. @ 0xf3bd0
+ (void)clearBannerCache;

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
