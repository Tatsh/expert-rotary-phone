//
//  RewardNetwork.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See RewardNetwork.h for the class overview.
//

#import "RewardNetwork.h"
#import "RewardNetworkUtilities.h"
#import "RewardNetworkError.h"
#import <UIKit/UIKit.h>

#import "RewardNetworkWebAPI.h"
#import "RewardNetworkUdid.h"   // +isAdvertisingTrackingEnabled (reconstructed in parallel)

// ---------------------------------------------------------------------------
// Unreconstructed RewardNetwork ("applilink") SDK collaborators. Minimal forward
// interfaces only — reconstruct these classes separately.
// ---------------------------------------------------------------------------

// Private helpers owned by RewardNetwork.
@interface RewardNetwork ()
// TODO(dep): the real ad-SDK network entry point (@ startWithAppliId:env:callback:,
// deliberately not reconstructed — the project ships the ad path neutralized).
+ (void)startWithAppliId:(NSString *)appliId env:(NSString *)env callback:(void (^)(void))callback;
@end

// Serial queue guarding the shared-instance handoff in -init.
// TODO(dep): created by the unreconstructed SDK start path (g_pRewardNetworkDispatchQueue).
static dispatch_queue_t g_pRewardNetworkDispatchQueue = NULL;

// The +allocWithZone:/+sharedInstance singleton (both guarded by dispatch_once).
static RewardNetwork *g_pRewardNetworkInstance = nil;

// In-memory banner cache (info dictionary + its expiry date).
static NSDictionary *g_pRewardBannerInfo = nil;
static NSDate *g_pRewardBannerExpireDate = nil;

@implementation RewardNetwork

// @ 0xee3f8
- (int)initializeFlg {
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        return 0;
    }
    return _initializeFlg;
}

// @ 0xee438
- (void)setInitializeFlg:(int)initializeFlg {
    _initializeFlg = initializeFlg;
}

// @ 0xee634
- (instancetype)init {
    __block id result = nil;
    // Queue-guarded shared-instance handoff (Ghidra: dispatch_sync on
    // g_pRewardNetworkDispatchQueue running rewardNetworkInitBlock_1).
    dispatch_sync(g_pRewardNetworkDispatchQueue, ^{
        // TODO(dep): rewardNetworkInitBlock_1 — the queue-guarded singleton setup is
        // not part of this reconstruction pass; faithful wiring only.
        result = self;
    });
    return result;
}

// @ 0xee550
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_pRewardNetworkInstance = [super allocWithZone:zone];
    });
    return g_pRewardNetworkInstance;
}

// @ 0xee774
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_pRewardNetworkInstance = [[self alloc] init];
    });
    return g_pRewardNetworkInstance;
}

// @ 0xee1d4
+ (NSString *)appliId {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.appliId"];
}

// @ 0xee230
+ (NSString *)version {
    return [RewardNetworkUtilities getSdkVersion];
}

// @ 0xee24c
+ (NSString *)udid {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        return nil;
    }
    NSError *error = nil;
    NSDictionary *data = [RewardNetworkUdid udidForFirstInvalidDataWithError:&error];
    if (data == nil) {
        (void)[RewardNetworkUdid isAdvertisingTrackingOSVersion];
        return nil;
    }
    return [data objectForKey:@"Value"];
}

// @ 0xee2f0
+ (NSString *)ad_udid {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        return nil;
    }
    NSError *error = nil;
    return [RewardNetworkUdid getAdvertisingRewardUdidWithError:&error];
}

// @ 0xee350
+ (NSString *)old_udid {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        return nil;
    }
    NSError *error = nil;
    return [RewardNetworkUdid getOldUdidWithError:&error];
}

// @ 0xee448
+ (int)campaignFlg {
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        return -2;
    }
    if ([[RewardNetwork sharedInstance] initializeFlg] == 1) {
        NSString *flg = [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.campaignFlg"];
        if (flg != nil) {
            return [flg intValue];
        }
    }
    return -2;
}

// @ 0xee52c
+ (BOOL)isSupportediOSVersion {
    return [RewardNetworkUtilities canUseRewardSdk];
}

// @ 0xee804
+ (void)setSessionParameters:(id)parameters url:(NSString *)url method:(NSString *)method {
    [[NSUserDefaults standardUserDefaults] setObject:url forKey:@"ApplilinkReward.appliURL"];
    [[NSUserDefaults standardUserDefaults] setObject:parameters forKey:@"ApplilinkReward.parameters"];
    [[NSUserDefaults standardUserDefaults] setObject:method forKey:@"ApplilinkReward.method"];
}

// @ 0xeed2c
+ (void)startSessionWithBlock:(RewardNetworkErrorBlock)block {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        block([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        block([RewardNetworkError localizedApplilinkErrorWithCode:0x404]);
        return;
    }
    [RewardNetwork checkLoginWithBlock:^(id result, NSError *error) {
        // TODO(dep): rewardNetworkRequestTokenCallback_1 (block invoke @ 0x1341a0) — on a
        // successful login check forwards to `block`; body not reconstructed.
        (void)block;
    }];
}

// @ 0xef274
+ (BOOL)createUdidWithError:(NSError **)error {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        return NO;
    }
    NSString *udid = [RewardNetwork udid];
    NSString *oldUdid = [RewardNetwork old_udid];
    if (udid != nil && oldUdid == nil) {
        [RewardNetworkUdid setUdidKeychainFromPasteBoard];
    }
    if ([RewardNetworkUdid isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    NSString *storageIndex = [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.storageIndex"];
    if (storageIndex != nil) {
        id existing = [RewardNetworkUdid udidWithStorageIndex:[storageIndex intValue] error:NULL];
        if (existing != nil) {
            return YES;
        }
    }
    NSDictionary *written = [RewardNetworkUdid writeUDIDForFirstEmptyLocationWithError:error];
    if (written == nil) {
        return NO;
    }
    NSString *newIndex = [[written objectForKey:@"StorageIndex"] stringValue];
    [[NSUserDefaults standardUserDefaults] setValue:newIndex forKey:@"ApplilinkReward.storageIndex"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.campaignFlg"];
    return YES;
}

// @ 0xef4c4
+ (void)postApplicationInstallWithPriority:(int)priority callback:(RewardNetworkErrorBlock)callback {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    if ([[RewardNetwork sharedInstance] initializeFlg] == 1) {
        callback(nil);
        return;
    }
    id campaignFlg = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.campaignFlg"];
    if (campaignFlg != nil) {
        callback(nil);
        return;
    }
    NSString *appliId = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.appliId"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:2];
    [params setValue:appliId forKey:@"appli_id"];
    if (![RewardNetworkUdid setUdidParameters:params isUDIDPriorityType:priority]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x402]);
        return;
    }
    NSMutableDictionary *userAgent = [RewardNetworkUtilities userAgentParameters];
    NSMutableDictionary *joined = [RewardNetworkUtilities joinDictionary:params withDictionary:userAgent];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/install/regist.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"POST"
                                         parameters:joined
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): success block @ 0xef839 — forwards `callback`. Body not reconstructed.
                                          (void)callback;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): failure block @ 0xefbf8 — captures `priority`; forwards `callback`.
                                          (void)priority;
                                          (void)callback;
                                      }];
}

// @ 0xefc14
+ (void)checkLoginWithBlock:(RewardNetworkCallback)block {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        block(nil, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    NSString *udid = [RewardNetwork udid];
    NSString *oldUdid = [RewardNetwork old_udid];
    if (udid != nil && oldUdid == nil) {
        [RewardNetworkUdid setUdidKeychainFromPasteBoard];
    }
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/auth/checkLoginStatus.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"GET"
                                         parameters:nil
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): success block @ 0xefe11 — forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): failure block @ 0xeff6c — forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }];
}

// @ 0xeff88
+ (void)requestTokenWithBlock:(RewardNetworkCallback)block {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        block(nil, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *appliURL = [defaults objectForKey:@"ApplilinkReward.appliURL"];
    NSDictionary *parameters = [defaults objectForKey:@"ApplilinkReward.parameters"];
    NSString *method = [defaults stringForKey:@"ApplilinkReward.method"];
    if (appliURL == nil || method == nil || parameters == nil) {
        block(nil, [RewardNetworkError localizedApplilinkErrorWithCode:0x3f2]);
        return;
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [RewardNetworkWebAPI requestAsynchronousWithURL:appliURL
                                             method:method
                                         parameters:params
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): success block @ 0xf0211 — forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): failure block @ 0xf04a0 — forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }];
}

// @ 0xf04bc
+ (void)startLoginWithToken:(NSString *)token withPriority:(int)priority callback:(RewardNetworkErrorBlock)callback {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    NSString *method = [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.method"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    if (token != nil) {
        [params setValue:token forKey:@"token"];
    }
    if (![RewardNetworkUdid setUdidParameters:params isUDIDPriorityType:priority]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x402]);
        return;
    }
    NSMutableDictionary *userAgent = [RewardNetworkUtilities userAgentParameters];
    NSMutableDictionary *joined = [RewardNetworkUtilities joinDictionary:params withDictionary:userAgent];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/auth/login.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:method
                                         parameters:joined
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): success block @ 0xf07c5 — captures `priority`/`token`; forwards `callback`.
                                          (void)priority;
                                          (void)token;
                                          (void)callback;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): failure block @ 0xf0a64 — forwards `callback`. Body not reconstructed.
                                          (void)callback;
                                      }];
}

// @ 0xf16d4
+ (void)allInstallFlgWithInCompany:(NSString *)inCompany callback:(RewardNetworkFlgCallback)callback {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        callback(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x404]);
        return;
    }
    NSNumber *cached = [[RewardNetwork sharedInstance] getTemporaryCacheWithKey:@"appInstallFlg"];
    if (cached != nil) {
        callback([cached intValue], nil);
        return;
    }
    [RewardNetwork startWithBlock:^(NSError *error) {
        // TODO(dep): start-completion block @ 0xf1cd5 — requests the all-install flag using
        // `inCompany`, caches it under "appInstallFlg", and forwards to `callback`. Body not
        // reconstructed (uses __block accumulators from the enclosing frame).
        (void)inCompany;
        (void)callback;
    }];
}

// @ 0xf2e14
+ (void)clearUDID {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (env == nil || [env isEqualToString:@"0"]) {
        return;
    }
    for (int i = 0; i < 0x207; i++) {
        NSError *readError = nil;
        NSString *entry = [RewardNetworkUdid udidWithStorageIndex:i error:&readError];
        if (entry != nil && readError == nil) {
            NSError *deleteError = nil;
            [RewardNetworkUdid deleteUDIDWithStorageIndex:i error:&deleteError];
        }
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.storageIndex"];
    [[RewardNetwork sharedInstance] setInitializeFlg:0];
}

// @ 0xf2fb4
+ (void)clearKeyChainOldUDID {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (env != nil && ![env isEqualToString:@"0"]) {
        NSError *error = nil;
        [RewardNetworkUdid deleteOldUdidWithError:&error];
    }
    NSString *adUdid = [RewardNetwork ad_udid];
    NSString *udid = [RewardNetwork udid];
    NSString *oldUdid = [RewardNetwork old_udid];
    if (adUdid == nil && udid == nil && oldUdid == nil) {
        [[RewardNetwork sharedInstance] setInitializeFlg:0];
    }
}

// @ 0xf3110
+ (void)clearAdUDID {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (env == nil || [env isEqualToString:@"0"]) {
        return;
    }
    for (int i = 0; i < 0x207; i++) {
        NSError *error = nil;
        [RewardNetworkUdid deleteAdvertisingRewardUdidIndex:i error:&error];
    }
    [RewardNetworkUdid setService:@"adStorageIndex" withStorageIndex:@"0"];
    [[RewardNetwork sharedInstance] setInitializeFlg:0];
}

// @ 0xf3240
+ (void)clearSession {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.appliURL"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.parameters"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.method"];
}

// @ 0xf33dc
+ (void)bannerInfoWithBlock:(RewardNetworkCallback)block {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        block(nil, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    NSMutableDictionary *userAgent = [RewardNetworkUtilities userAgentParameters];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/banner/detail.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"GET"
                                         parameters:userAgent
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): success block @ 0xf358d — caches the banner info/expiry and
                                          // forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): failure block @ 0xf36f8 — forwards `block`. Body not reconstructed.
                                          (void)block;
                                      }];
}

// @ 0xf3714
+ (void)isEnabledBannerWithBlock:(RewardNetworkFlgCallback)block {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        block(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        block(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x404]);
        return;
    }
    NSString *appliId = [[NSUserDefaults standardUserDefaults] valueForKey:@"ApplilinkReward.appliId"];
    if (appliId == nil) {
        block(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x3f2]);
        return;
    }
    if (![RewardNetwork canUseBannerCache]) {
        block(0, [RewardNetworkError localizedApplilinkErrorWithCode:0x402]);
        return;
    }
    if (g_pRewardBannerInfo != nil && g_pRewardBannerExpireDate != nil &&
        [g_pRewardBannerExpireDate timeIntervalSinceNow] >= 0.0) {
        NSNumber *status = [g_pRewardBannerInfo objectForKey:@"status"];
        block([status intValue], nil);
        return;
    }
    [RewardNetwork bannerInfoWithBlock:^(id result, NSError *error) {
        // TODO(dep): block @ 0xf397d — re-reads the freshly fetched banner status and forwards
        // it to `block`. Body not reconstructed.
        (void)block;
    }];
}

// @ 0xf3b28
+ (BOOL)canUseBannerCache {
    NSString *udid = [RewardNetwork udid];
    NSString *adUdid = [RewardNetwork ad_udid];
    NSString *oldUdid = [RewardNetwork old_udid];
    if (udid == nil && oldUdid == nil && adUdid == nil) {
        g_pRewardBannerInfo = nil;
        g_pRewardBannerExpireDate = nil;
        return NO;
    }
    return YES;
}

// @ 0xf3bd0
+ (void)clearBannerCache {
    g_pRewardBannerInfo = nil;
    g_pRewardBannerExpireDate = nil;
}

// .cxx_destruct @ 0xf3bf8 — compiler-emitted; not hand-written.

// @ 0xf0a80
- (void)openAppListWebViewWithCampaignId:(NSString *)campaignId
                               inCompany:(NSString *)inCompany
                                    type:(NSString *)type
                                  offset:(NSString *)offset
                                   limit:(NSString *)limit
                              parentView:(UIView *)parentView
                                delegate:(id<RewardNetworkWebViewDelegate>)delegate {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        if (delegate) {
            [delegate appListFailLoadWithError:[RewardNetworkError localizedApplilinkErrorWithCode:0x401]];
        }
        return;
    }
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        if (delegate) {
            [delegate appListFailLoadWithError:[RewardNetworkError localizedApplilinkErrorWithCode:0x404]];
        }
        return;
    }

    __weak RewardNetwork *weakSelf = self;
    [RewardNetwork startWithBlock:^(NSError *error) {
        (void)weakSelf;
        // TODO(dep): the start-completion block (@ 0xf0d2d) opens the app-list panel via
        // weakSelf using campaignId/inCompany/type/offset/limit/parentView/delegate; its
        // exact body is not part of this reconstruction pass.
    }];
}

// @ 0xf12d4
- (void)appListWithCampaignId:(NSString *)campaignId
                    inCompany:(NSString *)inCompany
                         type:(NSString *)type
                       offset:(NSString *)offset
                        limit:(NSString *)limit
                     callback:(RewardNetworkCallback)callback {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    if (campaignId) { [params setValue:campaignId forKey:@"campaign_id"]; }
    if (inCompany)  { [params setValue:inCompany  forKey:@"in_company"]; }
    if (type)       { [params setValue:type       forKey:@"type"]; }
    if (offset)     { [params setValue:offset     forKey:@"offset"]; }
    if (limit)      { [params setValue:limit      forKey:@"limit"]; }
    [params setValue:@"json" forKey:@"format"];

    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/index.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"GET"
                                         parameters:params
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): wraps `callback` (success) — block body not reconstructed.
                                          (void)callback;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): wraps `callback` (failure) — block body not reconstructed.
                                          (void)callback;
                                      }];
}

// @ 0xf1ff8
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration {
    [_webViewController willAnimateRotationToInterfaceOrientation:orientation duration:duration];
}

// @ 0xf2030
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expire = [[NSDate alloc] initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (NSTimeInterval)expiration)];
    NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
                           value, @"Value",
                           expire, @"Expire",
                           nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:entry];
    [defaults setObject:archived forKey:key];
}

// @ 0xf2168
- (id)getTemporaryCacheWithKey:(NSString *)key {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (data == nil) {
        return nil;
    }
    NSDictionary *entry = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (entry == nil) {
        return nil;
    }
    NSDate *expire = [entry objectForKey:@"Expire"];
    if ([expire compare:[NSDate date]] == NSOrderedAscending) {
        // Expired — evict.
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        return nil;
    }
    return [entry objectForKey:@"Value"];
}

// @ 0xf22e0
- (void)appliIdListWithType:(int)type callback:(RewardNetworkCallback)callback {
    NSDictionary *params = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:type]
                                                       forKey:@"type"];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/install/appliid/index.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"GET"
                                         parameters:params
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): wraps `callback` (success) — block body not reconstructed.
                                          (void)callback;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): wraps `callback` (failure) — block body not reconstructed.
                                          (void)callback;
                                      }];
}

// @ 0xf25fc
- (void)postAppliInstallReportWithAppliList:(NSArray *)appliList callback:(RewardNetworkCallback)callback {
    NSArray *batch;
    NSArray *remainder = nil;
    if ([appliList count] < 11) {
        batch = [appliList copy];
    } else {
        // First 10 go now; the rest are chained from the completion block.
        NSIndexSet *first = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 10)];
        batch = [appliList objectsAtIndexes:first];
        NSIndexSet *rest = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(10, [appliList count] - 10)];
        remainder = [appliList objectsAtIndexes:rest];
    }

    NSDictionary *params = [NSDictionary dictionaryWithObject:batch forKey:@"appli_id_list"];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/install/report/regist.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
                                             method:@"POST"
                                         parameters:params
                                           userInfo:nil
                                                tag:0
                                        cachePolicy:nil
                                      finishedBlock:^(id response, id userInfo) {
                                          // TODO(dep): on success, chains `remainder` via
                                          // -postAppliInstallReportWithAppliList:callback: and forwards `callback`.
                                          (void)remainder;
                                          (void)callback;
                                      }
                                        failedBlock:^(NSURLRequest *request, NSError *error) {
                                          // TODO(dep): wraps `callback` (failure) — block body not reconstructed.
                                          (void)callback;
                                      }];
}

// @ 0xf2a48
- (void)postAlreadyInstallAppWithCallback:(RewardNetworkCallback)callback {
    [self appliIdListWithType:2 callback:^(id result, NSError *error) {
        // TODO(dep): rewardNetworkFilterInstalledAppsAndReport — filters the returned appli
        // id list down to apps actually installed (canOpenURL) and reports them via
        // -postAppliInstallReportWithAppliList:callback:. Block body not reconstructed.
        (void)callback;
    }];
}

// @ 0xf3bf4
- (void)debugLog {
    // No-op in release builds.
}

// @ 0xf1e88
+ (NSString *)baseUrlSsl {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if ([env isEqualToString:@"0"]) { return @"https://www.applilink.jp"; }
    if ([env isEqualToString:@"1"]) { return @"https://st.es.i.revoinf.jp"; }
    if ([env isEqualToString:@"2"]) { return @"https://dev.es.i.revoinf.jp"; }
    if ([env isEqualToString:@"3"]) { return @"https://sandbox.applilink.jp"; }
    if ([env isEqualToString:@"4"]) { return @"https://dev.es.i.revoinf.jp"; }
    return nil;
}

// @ 0xef058
+ (void)startWithBlock:(void (^)(NSError *error))block {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *appliId = [defaults objectForKey:@"ApplilinkReward.appliId"];
    NSString *appliURL = [defaults objectForKey:@"ApplilinkReward.appliURL"];
    NSString *method = [defaults stringForKey:@"ApplilinkReward.method"];
    NSString *env = [defaults stringForKey:@"ApplilinkReward.env"];

    if (appliId == nil || appliURL == nil || method == nil || env == nil) {
        if (block) {
            block([RewardNetworkError localizedApplilinkErrorWithCode:0x3f2]);
        }
        return;
    }

    [RewardNetwork startWithAppliId:appliId env:env callback:^{
        // TODO(dep): the start-completion block (@ 0xef239) forwards to `block`;
        // exact body not reconstructed.
        (void)block;
    }];
}

// TODO(dep): real ad-SDK network entry — deliberately a no-op (neutralized ad path).
+ (void)startWithAppliId:(NSString *)appliId env:(NSString *)env callback:(void (^)(void))callback {
    // Not reconstructed in this pass.
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
