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
