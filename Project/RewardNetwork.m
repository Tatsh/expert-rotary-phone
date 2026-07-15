//
//  RewardNetwork.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See RewardNetwork.h for the class overview.
//

#import "RewardNetwork.h"
#import "RewardNetworkError.h"
#import "RewardNetworkUtilities.h"
#import <UIKit/UIKit.h>

#import "RewardNetworkUdid.h" // +isAdvertisingTrackingEnabled (reconstructed in parallel)
#import "RewardNetworkWebAPI.h"

// Serial queue guarding the shared-instance handoff in -init. Created in
// +allocWithZone:'s dispatch_once body (g_pRewardNetworkDispatchQueue).
static dispatch_queue_t g_pRewardNetworkDispatchQueue = NULL;

// The +allocWithZone:/+sharedInstance singleton (both guarded by
// dispatch_once).
static RewardNetwork *g_pRewardNetworkInstance = nil;

// In-memory banner cache (info dictionary + its expiry date).
static NSDictionary *g_pRewardBannerInfo = nil;
static NSDate *g_pRewardBannerExpireDate = nil;

@implementation RewardNetwork

// @ 0xee3f8   (sharedInstance forwarder twin @ 0xee3b0)
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
    // Queue-guarded shared-instance handoff (dispatch_sync on
    // g_pRewardNetworkDispatchQueue).
    dispatch_sync(g_pRewardNetworkDispatchQueue, ^{
      // @ 0xee6fc — the block body just performs [super init].
      result = [super init];
    });
    return result;
}

// @ 0xee550
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    // @ 0xee5bc — dispatch_once body: create the serial handoff queue, then alloc
    // the singleton via [super allocWithZone:] and clear its initializeFlg.
    dispatch_once(&onceToken, ^{
      g_pRewardNetworkDispatchQueue = dispatch_queue_create("RewardNetwork", NULL);
      if (g_pRewardNetworkInstance == nil) {
          g_pRewardNetworkInstance = [super allocWithZone:zone];
          [g_pRewardNetworkInstance setInitializeFlg:0];
      }
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
        NSString *flg =
            [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.campaignFlg"];
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
    [[NSUserDefaults standardUserDefaults] setObject:parameters
                                              forKey:@"ApplilinkReward.parameters"];
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
    // @ 0xeee40 (block literal @ 0x1341a0) — login-check completion.
    [RewardNetwork checkLoginWithBlock:^(id result, NSError *error) {
      if (error != nil) {
          [[RewardNetwork sharedInstance] debugLog];
          block(error);
          return;
      }
      if (result != nil) {
          // Already logged in — the session is ready.
          block(nil);
          return;
      }
      // @ 0xeeef0 — token-request completion.
      [RewardNetwork requestTokenWithBlock:^(id token, NSError *tokenError) {
        if (token == nil || tokenError != nil) {
            [[RewardNetwork sharedInstance] debugLog];
            block(tokenError);
            return;
        }
        // @ 0xeefb8 — login completion: seed the keychain UDID, then finish.
        [RewardNetwork startLoginWithToken:token
                              withPriority:1
                                  callback:^(NSError *loginError) {
                                    if (loginError != nil) {
                                        [[RewardNetwork sharedInstance] debugLog];
                                        block(loginError);
                                        return;
                                    }
                                    [RewardNetworkUdid setUdidKeychainFromPasteBoard];
                                    block(nil);
                                  }];
      }];
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
    NSString *storageIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.storageIndex"];
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
    [[NSUserDefaults standardUserDefaults] setValue:newIndex
                                             forKey:@"ApplilinkReward.storageIndex"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.campaignFlg"];
    return YES;
}

// @ 0xef4c4
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(RewardNetworkErrorBlock)callback {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    if ([[RewardNetwork sharedInstance] initializeFlg] == 1) {
        callback(nil);
        return;
    }
    id campaignFlg =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.campaignFlg"];
    if (campaignFlg != nil) {
        callback(nil);
        return;
    }
    NSString *appliId =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.appliId"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:2];
    [params setValue:appliId forKey:@"appli_id"];
    if (![RewardNetworkUdid setUdidParameters:params isUDIDPriorityType:priority]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x402]);
        return;
    }
    NSMutableDictionary *userAgent = [RewardNetworkUtilities userAgentParameters];
    NSMutableDictionary *joined = [RewardNetworkUtilities joinDictionary:params
                                                          withDictionary:userAgent];
    NSString *url =
        [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/install/regist.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"POST"
        parameters:joined
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xef838 — install response handler.
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          if ([[response objectForKey:@"status"] boolValue] &&
              [[response objectForKey:@"error_code"] intValue] == 100000000) {
              if (priority == 0 && [RewardNetworkUdid isUdidThreeKinds]) {
                  [RewardNetwork postApplicationInstallWithPriority:1 callback:callback];
              } else {
                  [[NSUserDefaults standardUserDefaults]
                      setObject:[response objectForKey:@"campaign_flg"]
                         forKey:@"ApplilinkReward.campaignFlg"];
                  [RewardNetworkUdid setUdidKeychainFromPasteBoard];
                  callback(nil);
              }
              return;
          }
          NSError *mapped;
          if ([[response objectForKey:@"error_code"] intValue] == 0xc106101) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3f1
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"error_code"] intValue] == 999999999) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3f0
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"kind"] isEqualToString:@"authorization"]) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ea
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"kind"] isEqualToString:@"parameter_error"]) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3e9
                                                                      userInfo:response];
          } else {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response];
          }
          callback(mapped);
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xefbf8 — tiny failure block, inlined/merged by the compiler
          // (no standalone function); forwards the network error.
          callback(error);
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
    NSString *url =
        [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/auth/checkLoginStatus.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"GET"
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xefe10 — login-status response handler.
          if (![response isKindOfClass:[NSDictionary class]]) {
              block(nil,
                    [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                   userInfo:response]);
              return;
          }
          if (![[response objectForKey:@"status"] boolValue]) {
              block(nil,
                    [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                   userInfo:response]);
              return;
          }
          BOOL loginStatus = [[response objectForKey:@"login_status"] boolValue];
          // Binary stuffs the raw BOOL (0/1) into the id `result`
          // slot; the caller reads it back as a boolean. Pass the bits
          // through void* so ARC doesn't treat it as a managed object.
          block((__bridge id)(void *)(intptr_t)loginStatus, nil);
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xeff6c — tiny failure block, inlined/merged by the compiler
          // (no standalone function); forwards the network error.
          block(nil, error);
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
          // @ 0xf0210 — token response handler.
          if (![response isKindOfClass:[NSDictionary class]]) {
              block(nil,
                    [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                   userInfo:response]);
              return;
          }
          id token = [response objectForKey:@"token"];
          if ([[response objectForKey:@"status"] boolValue] &&
              [[response objectForKey:@"error_code"] intValue] == 100000000 && token != nil) {
              block(token, nil);
              return;
          }
          NSError *mapped;
          if (token == nil) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ec
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"error_code"] intValue] == 999999999) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ed
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"kind"] isEqualToString:@"parameter_error"]) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3e9
                                                                      userInfo:response];
          } else {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response];
          }
          block(nil, mapped);
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xf04a0 — tiny failure block, inlined/merged by the compiler
          // (no standalone function); forwards the network error.
          block(nil, error);
        }];
}

// @ 0xf04bc
+ (void)startLoginWithToken:(NSString *)token
               withPriority:(int)priority
                   callback:(RewardNetworkErrorBlock)callback {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }
    NSString *method =
        [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.method"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    if (token != nil) {
        [params setValue:token forKey:@"token"];
    }
    if (![RewardNetworkUdid setUdidParameters:params isUDIDPriorityType:priority]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x402]);
        return;
    }
    NSMutableDictionary *userAgent = [RewardNetworkUtilities userAgentParameters];
    NSMutableDictionary *joined = [RewardNetworkUtilities joinDictionary:params
                                                          withDictionary:userAgent];
    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/auth/login.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:method
        parameters:joined
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xf07c4 — login response handler.
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          if ([[response objectForKey:@"status"] boolValue] &&
              [[response objectForKey:@"error_code"] intValue] == 100000000) {
              if (priority == 0 && [RewardNetworkUdid isUdidThreeKinds]) {
                  [RewardNetwork startLoginWithToken:token withPriority:1 callback:callback];
              } else {
                  callback(nil);
              }
              return;
          }
          NSError *mapped;
          if ([[response objectForKey:@"error_code"] intValue] == 0xc106cb9) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ea
                                                                      userInfo:response];
          } else if ([[response objectForKey:@"kind"] isEqualToString:@"parameter_error"]) {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3e9
                                                                      userInfo:response];
          } else {
              mapped = [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response];
          }
          callback(mapped);
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xf0a64 — tiny failure block, inlined/merged by the compiler
          // (no standalone function); forwards the network error.
          callback(error);
        }];
}

// @ 0xf16d4
+ (void)allInstallFlgWithInCompany:(NSString *)inCompany
                          callback:(RewardNetworkFlgCallback)callback {
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
    // @ 0xf1cd5 — start-completion: issue the checkAllInstall request.
    [RewardNetwork startWithBlock:^(NSError *error) {
      if (error != nil) {
          callback(-1, error);
          return;
      }
      NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
      if (inCompany) {
          [params setValue:inCompany forKey:@"in_company"];
      }
      [params setValue:@"json" forKey:@"format"];
      NSString *url =
          [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/checkAllInstall.php"];
      [RewardNetworkWebAPI requestAsynchronousWithURL:url
          method:@"GET"
          parameters:params
          userInfo:nil
          tag:0
          cachePolicy:nil
          finishedBlock:^(id response, id userInfo) {
            // @ 0xf1a50 — read all_install_flg, cache it under "appInstallFlg",
            // forward the flag.
            if (![response isKindOfClass:[NSDictionary class]]) {
                callback(0,
                         [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                        userInfo:response]);
                return;
            }
            BOOL ok = [[response objectForKey:@"status"] boolValue] &&
                      [[response objectForKey:@"error_code"] intValue] == 100000000;
            if (!ok) {
                callback(0,
                         [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                        userInfo:response]);
                return;
            }
            id flg = [response objectForKey:@"all_install_flg"];
            if (flg == nil) {
                callback(-1,
                         [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                        userInfo:response]);
                return;
            }
            [[RewardNetwork sharedInstance]
                setTemporaryCacheWithKey:@"appInstallFlg"
                                   value:[NSString stringWithFormat:@"%@", flg]
                              expiration:0];
            callback([flg intValue], nil);
          }
          failedBlock:^(NSURLRequest *request, NSError *failError) {
            callback(-1, failError);
          }];
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
        NSDictionary *entry = [RewardNetworkUdid udidWithStorageIndex:i error:&readError];
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
    NSString *url =
        [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/banner/detail.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"GET"
        parameters:userAgent
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xf358c — banner detail response handler: validate
          // dict/status/error_code, forward the raw response dict. (The
          // info/expiry caching happens in the isEnabledBanner completion @
          // 0xf397c, not here.)
          if (![response isKindOfClass:[NSDictionary class]]) {
              block(nil,
                    [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                   userInfo:response]);
              return;
          }
          BOOL ok = [[response objectForKey:@"status"] boolValue] &&
                    [[response objectForKey:@"error_code"] intValue] == 100000000;
          if (ok) {
              block(response, nil);
          } else {
              block(nil,
                    [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                   userInfo:response]);
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xf36f8 — tiny failure block, inlined/merged by the compiler
          // (no standalone function); forwards the network error.
          block(nil, error);
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
    NSString *appliId =
        [[NSUserDefaults standardUserDefaults] valueForKey:@"ApplilinkReward.appliId"];
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
      // @ 0xf397c — cache the freshly fetched banner info/expiry, then forward
      // its status.
      if (error == nil && [result isKindOfClass:[NSDictionary class]]) {
          g_pRewardBannerInfo = [result objectForKey:@"info"];
          NSTimeInterval expire =
              (NSTimeInterval)[[g_pRewardBannerInfo objectForKey:@"expire"] intValue];
          g_pRewardBannerExpireDate = [[NSDate date] dateByAddingTimeInterval:expire];
          block([[g_pRewardBannerInfo objectForKey:@"status"] intValue], nil);
      } else {
          block(0, error);
      }
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

// @ 0xf0a80   (sharedInstance forwarder twin @ 0xf11fc)
- (void)openAppListWebViewWithCampaignId:(NSNumber *)campaignId
                               inCompany:(id)inCompany
                                    type:(id)type
                                  offset:(id)offset
                                   limit:(id)limit
                              parentView:(UIView *)parentView
                                delegate:(id<RewardNetworkWebViewDelegate>)delegate {
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        if (delegate) {
            [delegate appListFailLoadWithError:[RewardNetworkError
                                                   localizedApplilinkErrorWithCode:0x401]];
        }
        return;
    }
    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        if (delegate) {
            [delegate appListFailLoadWithError:[RewardNetworkError
                                                   localizedApplilinkErrorWithCode:0x404]];
        }
        return;
    }

    __weak RewardNetwork *weakSelf = self;
    // @ 0xf0d2d — start-completion: report a start failure to the delegate,
    // otherwise clear the already-installed applis before opening the panel.
    [RewardNetwork startWithBlock:^(NSError *error) {
      if (error != nil) {
          if ([delegate respondsToSelector:@selector(appListFailLoadWithError:)]) {
              [delegate appListFailLoadWithError:error];
          }
          return;
      }
      // @ 0xf0eec — install-report completion: build the app-index request params
      // and load /reward/app/index.php into the (lazily created) web-view
      // controller.
      [weakSelf postAlreadyInstallAppWithCallback:^(NSError *reportError) {
        RewardNetwork *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if (reportError != nil) {
            if ([delegate respondsToSelector:@selector(appListFailLoadWithError:)]) {
                [delegate appListFailLoadWithError:reportError];
            }
            return;
        }
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        if (campaignId) {
            [params setValue:campaignId forKey:@"campaign_id"];
        }
        if (inCompany) {
            [params setValue:inCompany forKey:@"in_company"];
        }
        if (type) {
            [params setValue:type forKey:@"type"];
        }
        if (offset) {
            [params setValue:offset forKey:@"offset"];
        }
        if (limit) {
            [params setValue:limit forKey:@"limit"];
        }
        if (strongSelf->_webViewController == nil) {
            strongSelf->_webViewController = [[RewardNetworkWebViewController alloc] init];
        }
        if (parentView != nil) {
            [strongSelf->_webViewController setParentView:parentView];
        }
        NSString *url =
            [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/index.php"];
        [strongSelf->_webViewController loadRequestWithURL:[NSURL URLWithString:url]
                                                parameters:params
                                                  delegate:delegate];
      }];
    }];
}

// @ 0xf12d4
- (void)appListWithCampaignId:(NSNumber *)campaignId
                    inCompany:(id)inCompany
                         type:(id)type
                       offset:(id)offset
                        limit:(id)limit
                     callback:(RewardNetworkCallback)callback {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    if (campaignId) {
        [params setValue:campaignId forKey:@"campaign_id"];
    }
    if (inCompany) {
        [params setValue:inCompany forKey:@"in_company"];
    }
    if (type) {
        [params setValue:type forKey:@"type"];
    }
    if (offset) {
        [params setValue:offset forKey:@"offset"];
    }
    if (limit) {
        [params setValue:limit forKey:@"limit"];
    }
    [params setValue:@"json" forKey:@"format"];

    NSString *url = [[RewardNetwork baseUrlSsl] stringByAppendingString:@"/reward/app/index.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"GET"
        parameters:params
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xf154c — validate dict/status/error_code==1e8.
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback(nil,
                       [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          BOOL ok = [[response objectForKey:@"status"] boolValue] &&
                    [[response objectForKey:@"error_code"] intValue] == 100000000;
          if (ok) {
              callback(response, nil);
          } else {
              callback(nil,
                       [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          callback(nil, error);
        }];
}

// @ 0xf1ff8   (sharedInstance forwarder twin @ 0xf1fa4)
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration {
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    // -willAnimateRotationToInterfaceOrientation:duration: was deprecated in
    // iOS 8; it only forwarded to the controller's shared layout method using the
    // current status-bar orientation, so drive that method directly here.
    UIInterfaceOrientation currentOrientation =
        [[UIApplication sharedApplication] statusBarOrientation];
    [_webViewController rotateWebViewWithInterfaceOrientation:currentOrientation duration:duration];
#else
    [_webViewController willAnimateRotationToInterfaceOrientation:orientation duration:duration];
#endif
}

// @ 0xf2030
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expire = [[NSDate alloc]
        initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (NSTimeInterval)expiration)];
    NSDictionary *entry =
        [NSDictionary dictionaryWithObjectsAndKeys:value, @"Value", expire, @"Expire", nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:entry
                                             requiringSecureCoding:NO
                                                             error:nil];
#else
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:entry];
#endif
    [defaults setObject:archived forKey:key];
}

// @ 0xf2168
- (id)getTemporaryCacheWithKey:(NSString *)key {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (data == nil) {
        return nil;
    }
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data
                                                                                error:nil];
    unarchiver.requiresSecureCoding = NO;
    NSDictionary *entry = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey
                                                           error:nil];
    [unarchiver finishDecoding];
#else
    NSDictionary *entry = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#endif
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
    NSString *url = [[RewardNetwork baseUrlSsl]
        stringByAppendingString:@"/reward/app/install/appliid/index.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"GET"
        parameters:params
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xf2474 — validate dict/status/error_code==1e8 (variant).
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback(nil,
                       [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          BOOL ok = [[response objectForKey:@"status"] boolValue] &&
                    [[response objectForKey:@"error_code"] intValue] == 100000000;
          if (ok) {
              callback(response, nil);
          } else {
              callback(nil,
                       [RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          callback(nil, error);
        }];
}

// @ 0xf25fc
- (void)postAppliInstallReportWithAppliList:(NSArray *)appliList
                                   callback:(RewardNetworkErrorBlock)callback {
    NSArray *batch;
    NSArray *remainder = nil;
    if ([appliList count] < 11) {
        batch = [appliList copy];
    } else {
        // First 10 go now; the rest are chained from the completion block.
        NSIndexSet *first = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 10)];
        batch = [appliList objectsAtIndexes:first];
        NSIndexSet *rest =
            [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(10, [appliList count] - 10)];
        remainder = [appliList objectsAtIndexes:rest];
    }

    NSDictionary *params = [NSDictionary dictionaryWithObject:batch forKey:@"appli_id_list"];
    NSString *url = [[RewardNetwork baseUrlSsl]
        stringByAppendingString:@"/reward/app/install/report/regist.php"];
    [RewardNetworkWebAPI requestAsynchronousWithURL:url
        method:@"POST"
        parameters:params
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // @ 0xf2864 — on success chain `remainder`, else map the error.
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          BOOL ok = [[response objectForKey:@"status"] boolValue] &&
                    [[response objectForKey:@"error_code"] intValue] == 100000000;
          if (!ok) {
              callback([RewardNetworkError localizedRewardNetworkErrorWithCode:1000
                                                                      userInfo:response]);
              return;
          }
          if (remainder == nil || [remainder count] == 0) {
              callback(nil);
          } else {
              [self postAppliInstallReportWithAppliList:remainder callback:callback];
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          callback(error);
        }];
}

// @ 0xf2a48
- (void)postAlreadyInstallAppWithCallback:(RewardNetworkErrorBlock)callback {
    // @ 0xf2ab4 — filter the returned appli-id list down to apps that are
    // actually installed (canOpenURL: on each default_scheme) and report them.
    [self appliIdListWithType:2
                     callback:^(id result, NSError *error) {
                       if (error != nil) {
                           callback(error);
                           return;
                       }
                       if (![result isKindOfClass:[NSDictionary class]]) {
                           callback(nil);
                           return;
                       }
                       NSMutableArray *installed = [[NSMutableArray alloc] init];
                       for (NSDictionary *entry in [result objectForKey:@"list"]) {
                           NSDictionary *info = [entry objectForKey:@"appli_info"];
                           NSString *appliId = [info objectForKey:@"appli_id"];
                           NSString *scheme = [info objectForKey:@"default_scheme"];
                           if (scheme == nil || [scheme isKindOfClass:[NSNull class]]) {
                               continue;
                           }
                           NSString *urlString = scheme;
                           if ([scheme rangeOfString:@"://"].location == NSNotFound) {
                               urlString = [scheme stringByAppendingString:@"://"];
                           }
                           NSURL *url = [NSURL URLWithString:urlString];
                           if ([[UIApplication sharedApplication] canOpenURL:url]) {
                               [installed addObject:appliId];
                           }
                       }
                       if ([installed count] == 0) {
                           callback(nil);
                       } else {
                           [self postAppliInstallReportWithAppliList:installed callback:callback];
                       }
                     }];
}

// @ 0xf3bf4
- (void)debugLog {
    // No-op in release builds.
}

// @ 0xf1e88
+ (NSString *)baseUrlSsl {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if ([env isEqualToString:@"0"]) {
        return @"https://www.applilink.jp";
    }
    if ([env isEqualToString:@"1"]) {
        return @"https://st.es.i.revoinf.jp";
    }
    if ([env isEqualToString:@"2"]) {
        return @"https://dev.es.i.revoinf.jp";
    }
    if ([env isEqualToString:@"3"]) {
        return @"https://sandbox.applilink.jp";
    }
    if ([env isEqualToString:@"4"]) {
        return @"https://dev.es.i.revoinf.jp";
    }
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

    // @ 0xef239 — forward the start result to the caller's block.
    [RewardNetwork startWithAppliId:appliId
                                env:env
                           callback:^(NSError *error) {
                             if (block) {
                                 block(error);
                             }
                           }];
}

// @ 0xee8f0 — the applilink (reward SDK) network start. Validates the appli id
// + SDK availability, persists appliId/env, ensures the reward UDID exists, and
// (once) posts the install record. `callback` receives nil on success or a
// localized error.
+ (void)startWithAppliId:(NSString *)appliId
                     env:(NSString *)env
                callback:(RewardNetworkErrorBlock)callback {
    if (appliId == nil) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x3e9]);
        return;
    }
    if (![RewardNetworkUtilities canUseRewardSdk]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:appliId forKey:@"ApplilinkReward.appliId"];
    [defaults setObject:env forKey:@"ApplilinkReward.env"];

    if (![RewardNetworkUdid isAdvertisingTrackingEnabled]) {
        callback([RewardNetworkError localizedApplilinkErrorWithCode:0x404]);
        return;
    }

    // A fresh install (no udid on file) resets the initialize flag so we re-post
    // below.
    if ([RewardNetwork udid] == nil && [RewardNetwork ad_udid] == nil) {
        [[RewardNetwork sharedInstance] setInitializeFlg:0];
    }
    if ([[RewardNetwork sharedInstance] initializeFlg] == 1) {
        callback(nil); // already initialized
        return;
    }

    NSError *udidError = nil;
    BOOL created = [RewardNetwork createUdidWithError:&udidError];
    if (!created || udidError != nil) {
        [[RewardNetwork sharedInstance] setInitializeFlg:0];
        [g_pRewardNetworkInstance debugLog];
        callback(udidError);
        return;
    }

    NSError *adUdidError = nil;
    [RewardNetworkUdid createAdvertisingRewardUdidWithError:&adUdidError];
    if (adUdidError != nil) {
        [g_pRewardNetworkInstance debugLog];
        callback(adUdidError);
        return;
    }

    // Both UDIDs are in place — post the install record; the completion (@
    // 0xeec84) sets the initialize flag and forwards to `callback`.
    [RewardNetwork
        postApplicationInstallWithPriority:0
                                  callback:^(NSError *error) {
                                    if (error == nil) {
                                        [[RewardNetwork sharedInstance] setInitializeFlg:1];
                                        callback(nil);
                                    } else {
                                        [[RewardNetwork sharedInstance] setInitializeFlg:0];
                                        [g_pRewardNetworkInstance debugLog];
                                        callback(error);
                                    }
                                  }];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
