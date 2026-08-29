/**
 * @file
 * The public facade of the bundled Konami RewardNetwork ("applilink") ad and reward SDK.
 *
 * It opens the reward app-list web panel, queries the reward app index, reports installs, and
 * keeps a small expiring key-value cache in NSUserDefaults. Requests go through
 * +[RewardNetworkWebAPI requestAsynchronousWithURL:...]; the panel is a
 * RewardNetworkWebViewController.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (RewardNetwork methods @
 * 0xee3f8..0xf3bf4, plus the helpers +baseUrlSsl @ 0xf1e88 and +startWithBlock: @ 0xef058 that the
 * listed methods call). The superclass is NSObject, with two instance variables:
 * _webViewController (RewardNetworkWebViewController *) and _initializeFlg (int).
 *
 * The project also ships a neutralised Stubs/RewardNetwork.h used by AppDelegate; this file is the
 * faithful reconstruction of the real class.
 */

#import <Foundation/Foundation.h>

#import "RewardNetworkWebViewController.h" // ivar type + RewardNetworkWebViewDelegate

@class RewardNetworkWebViewController;

/**
 * The single result-and-error callback used by the app-index and install-report requests.
 * @param result The response payload, or nil on failure.
 * @param error What went wrong, or nil on success.
 */
typedef void (^RewardNetworkCallback)(id result, NSError *error);

/**
 * The error-only completion used by session start, login and the install report.
 * @param error What went wrong, or nil on success.
 */
typedef void (^RewardNetworkErrorBlock)(NSError *error);

/**
 * The integer-flag completion used by the all-install-flag and banner-enabled queries.
 * @param flg The returned flag.
 * @param error What went wrong, or nil on success.
 */
typedef void (^RewardNetworkFlgCallback)(NSInteger flg, NSError *error);

/**
 * The Applilink reward SDK facade: session, UDID, install reporting and the app-list panel.
 */
@interface RewardNetwork : NSObject {
    RewardNetworkWebViewController *_webViewController; /**< The reward app-list panel. */
    int _initializeFlg;                                 /**< The SDK initialisation state. */
}

// Read-only class "properties": custom getters, not ivar-backed.

/** The persisted appli id, from the NSUserDefaults key "ApplilinkReward.appliId". Getter @
 * 0xee1d4. */
@property(class, readonly, nonatomic) NSString *appliId;
/** The SDK version string, from +[RewardNetworkUtilities getSdkVersion]. Getter @ 0xee230. */
@property(class, readonly, nonatomic) NSString *version;
/** The reward UDID: the value of the first valid stored record, or nil. Getter @ 0xee24c. */
@property(class, readonly, nonatomic) NSString *udid;
/** The advertising reward UDID, or nil. Getter @ 0xee2f0. */
@property(class, readonly, nonatomic) NSString *ad_udid;
/** The legacy keychain UDID, or nil. Getter @ 0xee350. */
@property(class, readonly, nonatomic) NSString *old_udid;

/**
 * The shared instance, created once via dispatch_once.
 * @return The singleton.
 * @ghidraAddress 0xee774
 */
+ (instancetype)sharedInstance;

/**
 * The campaign flag from NSUserDefaults, gated on ad-tracking and initializeFlg being 1.
 * @return The flag, or -2 when the gate fails.
 * @ghidraAddress 0xee448
 */
+ (int)campaignFlg;

/**
 * Whether the SDK can run on this iOS version; equivalent to +canUseRewardSdk.
 * @return YES when the SDK is usable.
 * @ghidraAddress 0xee52c
 */
+ (BOOL)isSupportediOSVersion;

/**
 * Persist the session appli URL, parameters and method into NSUserDefaults.
 * @param parameters The session parameters.
 * @param url The session URL.
 * @param method The HTTP method.
 * @ghidraAddress 0xee804
 */
+ (void)setSessionParameters:(id)parameters url:(NSString *)url method:(NSString *)method;

/**
 * Start a reward session: check login, then run the block with any error.
 * @param block Fired with the session error, or nil.
 * @ghidraAddress 0xeed2c
 */
+ (void)startSessionWithBlock:(RewardNetworkErrorBlock)block;

/**
 * Create and register the device UDID, writing to the first empty storage slot.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xef274
 */
+ (BOOL)createUdidWithError:(NSError **)error;

/**
 * POST the application-install report.
 * @param priority The report priority.
 * @param callback Fired with the report error, or nil.
 * @ghidraAddress 0xef4c4
 */
+ (void)postApplicationInstallWithPriority:(int)priority callback:(RewardNetworkErrorBlock)callback;

/**
 * GET the login status from /reward/auth/checkLoginStatus.php.
 * @param block Fired with the status payload or the error.
 * @ghidraAddress 0xefc14
 */
+ (void)checkLoginWithBlock:(RewardNetworkCallback)block;

/**
 * Request an auth token using the stored session parameters.
 * @param block Fired with the token or the error.
 * @ghidraAddress 0xeff88
 */
+ (void)requestTokenWithBlock:(RewardNetworkCallback)block;

/**
 * POST login to /reward/auth/login.php.
 * @param token The auth token, or nil.
 * @param priority The request priority.
 * @param callback Fired with the login error, or nil.
 * @ghidraAddress 0xf04bc
 */
+ (void)startLoginWithToken:(NSString *)token
               withPriority:(int)priority
                   callback:(RewardNetworkErrorBlock)callback;

/**
 * Query the all-install flag, cached under "appInstallFlg".
 * @param inCompany The company filter.
 * @param callback Fired with the flag or the error.
 * @ghidraAddress 0xf16d4
 */
+ (void)allInstallFlgWithInCompany:(NSString *)inCompany
                          callback:(RewardNetworkFlgCallback)callback;

/**
 * Delete every stored reward UDID slot and reset the session state.
 * @ghidraAddress 0xf2e14
 */
+ (void)clearUDID;
/**
 * Delete the legacy keychain UDID, and reset the session state once every UDID is gone.
 * @ghidraAddress 0xf2fb4
 */
+ (void)clearKeyChainOldUDID;
/**
 * Delete every advertising reward UDID slot and reset the session state.
 * @ghidraAddress 0xf3110
 */
+ (void)clearAdUDID;
/**
 * Delete all cookies and the stored session URL, parameters and method.
 * @ghidraAddress 0xf3240
 */
+ (void)clearSession;

/**
 * GET the banner detail from /reward/banner/detail.php.
 * @param block Fired with the banner payload or the error.
 * @ghidraAddress 0xf33dc
 */
+ (void)bannerInfoWithBlock:(RewardNetworkCallback)block;
/**
 * Report whether the banner is enabled, using the banner cache while it is fresh.
 * @param block Fired with the flag or the error.
 * @ghidraAddress 0xf3714
 */
+ (void)isEnabledBannerWithBlock:(RewardNetworkFlgCallback)block;
/**
 * Whether any UDID exists; when none does, the banner cache is evicted.
 * @return YES when the banner cache may be used.
 * @ghidraAddress 0xf3b28
 */
+ (BOOL)canUseBannerCache;
/**
 * Evict the in-memory banner cache.
 * @ghidraAddress 0xf3bd0
 */
+ (void)clearBannerCache;

/**
 * The SDK initialisation state; the getter also gates on ad-tracking being enabled.
 * @return The state, or 0 when ad-tracking is disabled.
 * @ghidraAddress 0xee3f8
 */
- (int)initializeFlg;
/**
 * Set the SDK initialisation state.
 * @param initializeFlg The new state.
 * @ghidraAddress 0xee438
 */
- (void)setInitializeFlg:(int)initializeFlg;

/**
 * The queue-guarded shared-instance initialiser.
 * @return The initialised instance.
 * @ghidraAddress 0xee634
 */
- (instancetype)init;

/**
 * Open the reward app-list web panel.
 *
 * It requires the SDK to be usable and ad-tracking to be enabled; otherwise it reports the failure
 * to @p delegate. The query-value parameters other than @p campaignId are typed `id` because they
 * are only stored as URL query values via setValue:forKey:, and their concrete types are not
 * recovered.
 * @param campaignId The campaign id; the menu passes an NSNumber wrapping 0.
 * @param inCompany The company filter.
 * @param type The listing type.
 * @param offset The paging offset.
 * @param limit The paging limit.
 * @param parentView The host view.
 * @param delegate The panel delegate.
 * @ghidraAddress 0xf0a80
 */
- (void)openAppListWebViewWithCampaignId:(NSNumber *)campaignId
                               inCompany:(id)inCompany
                                    type:(id)type
                                  offset:(id)offset
                                   limit:(id)limit
                              parentView:(UIView *)parentView
                                delegate:(id<RewardNetworkWebViewDelegate>)delegate;

/**
 * Fetch the reward app index via GET /reward/app/index.php.
 * @param campaignId The campaign id.
 * @param inCompany The company filter.
 * @param type The listing type.
 * @param offset The paging offset.
 * @param limit The paging limit.
 * @param callback Fired with the index payload or the error.
 * @ghidraAddress 0xf12d4
 */
- (void)appListWithCampaignId:(NSNumber *)campaignId
                    inCompany:(id)inCompany
                         type:(id)type
                       offset:(id)offset
                        limit:(id)limit
                     callback:(RewardNetworkCallback)callback;

/**
 * Forward a rotation to the open app-list panel.
 * @param orientation The new interface orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0xf1ff8
 */
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

/**
 * Store a value in the expiring key/value cache backed by NSUserDefaults, archived as
 * {Value, Expire}.
 * @param key The cache key.
 * @param value The value to store.
 * @param expiration The lifetime, in seconds.
 * @ghidraAddress 0xf2030
 */
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration;
/**
 * Read a value from the expiring cache.
 * @param key The cache key.
 * @return The value while unexpired; otherwise the entry is evicted and nil is returned.
 * @ghidraAddress 0xf2168
 */
- (id)getTemporaryCacheWithKey:(NSString *)key;

/**
 * Fetch the installed-appli id list via GET /reward/app/install/appliid/index.php.
 * @param type The listing type.
 * @param callback Fired with the id list or the error.
 * @ghidraAddress 0xf22e0
 */
- (void)appliIdListWithType:(int)type callback:(RewardNetworkCallback)callback;

/**
 * Report installed applis in batches of 10 via POST
 * /reward/app/install/report/regist.php, chaining the remainder.
 * @param appliList The applis to report.
 * @param callback Fired with the report error, or nil. The binary invokes it with a single NSError
 * argument.
 * @ghidraAddress 0xf25fc
 */
- (void)postAppliInstallReportWithAppliList:(NSArray *)appliList
                                   callback:(RewardNetworkErrorBlock)callback;

/**
 * Query already-installed applis (type 2) and report those actually installed.
 * @param callback Fired with the report error, or nil. The binary invokes it with a single NSError
 * argument.
 * @ghidraAddress 0xf2a48
 */
- (void)postAlreadyInstallAppWithCallback:(RewardNetworkErrorBlock)callback;

/**
 * A no-op in release builds.
 * @ghidraAddress 0xf3bf4
 */
- (void)debugLog;

// Class helpers the methods above call, owned by this class.

/**
 * The SSL base URL selected from the ApplilinkReward.env default.
 * @return The base URL.
 * @ghidraAddress 0xf1e88
 */
+ (NSString *)baseUrlSsl;

/**
 * Ensure the SDK is started, reading the persisted appli id, URL, method and environment,
 * then run the block.
 * @param block Fired with a parameter error when any default is missing, or nil.
 * @ghidraAddress 0xef058
 */
+ (void)startWithBlock:(void (^)(NSError *error))block;

/**
 * Start the Applilink SDK: persist the appli id and environment, ensure the reward UDID
 * exists, and post the install record.
 * @param appliId The appli id.
 * @param env The environment name.
 * @param callback Fired with a localised error, or nil.
 * @ghidraAddress 0xee8f0
 */
+ (void)startWithAppliId:(NSString *)appliId
                     env:(NSString *)env
                callback:(RewardNetworkErrorBlock)callback;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
