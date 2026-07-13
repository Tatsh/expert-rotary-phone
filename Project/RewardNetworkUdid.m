//
//  RewardNetworkUdid.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkUdid.h"
#import "RewardNetwork.h" // +ad_udid / +udid / +old_udid
#import "RewardNetworkError.h"
#import "RewardNetworkPasteBoard.h"

#import <AdSupport/AdSupport.h>       // ASIdentifierManager
#import <CommonCrypto/CommonDigest.h> // CC_MD5
#import <Security/Security.h>
#import <UIKit/UIKit.h> // UIDevice

// The process-wide singleton backing +allocWithZone: / +sharedInstance
// (g_pRewardNetworkUdidInstance in the binary).
static RewardNetworkUdid *g_sharedInstance = nil;

// The shared "ApplilinkUdid" serial queue (DAT_00188350), created in
// +allocWithZone:'s dispatch_once body and used by -init to serialize the SDK's
// UDID/keychain work.
static dispatch_queue_t g_pApplilinkUdidQueue = NULL;

@implementation RewardNetworkUdid

// @ 0xf70c0 — the recovered -init dispatches its super initialization
// synchronously onto the shared "ApplilinkUdid" serial queue created by
// +allocWithZone: (block body @ 0xf7188 does just `self = [super init]`).
- (instancetype)init {
    __block RewardNetworkUdid *result = nil;
    dispatch_sync(g_pApplilinkUdidQueue, ^{
      result = [super init];
    });
    return result;
}

// setPasteBoard: @ 0xf9838 / pasteBoard @ 0xf9828 — synthesized accessors for
// the
//   _pasteBoard ivar.
// .cxx_construct/.cxx_destruct @ 0xf9860 — compiler-emitted ARC ivar teardown
// for
//   _pasteBoard; not hand-written.

// @ 0xf956c — look up (creating if absent) a generic-password keychain item
// named "bundleSeedID" and read the leading component of its access group,
// which is the app's Apple seed (team) id.
- (NSString *)bundleSeedID {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"bundleSeedID",
        (__bridge id)kSecAttrService : @"",
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };

    CFTypeRef resultRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultRef);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, &resultRef);
    }
    if (status != errSecSuccess) {
        if (resultRef != NULL) {
            CFRelease(resultRef);
        }
        return nil;
    }

    NSDictionary *attributes = (__bridge_transfer NSDictionary *)resultRef;
    NSString *accessGroup = [attributes objectForKey:(__bridge id)kSecAttrAccessGroup];
    return [[[accessGroup componentsSeparatedByString:@"."] objectEnumerator] nextObject];
}

#pragma mark - Singleton (metaclass)

// @ 0xf6ff0 — allocate the shared instance once, then always hand back that
// instance.
+ (instancetype)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken;
    // @ 0xf705c — dispatch_once body: create the shared "ApplilinkUdid" serial
    // queue and, if absent, alloc the singleton via [super allocWithZone:].
    dispatch_once(&onceToken, ^{
      g_pApplilinkUdidQueue = dispatch_queue_create("ApplilinkUdid", NULL);
      if (g_sharedInstance == nil) {
          g_sharedInstance = [super allocWithZone:zone];
      }
    });
    return g_sharedInstance;
}

// @ 0xf7200 — the shared instance, created once (block @ 0x134508 does
// `[[RewardNetworkUdid alloc] init]`).
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      g_sharedInstance = [[RewardNetworkUdid alloc] init];
    });
    return g_sharedInstance;
}

#pragma mark - Pasteboard-backed UDID storage

// @ 0xf72d4 — reuse the existing pasteboard "Value", otherwise mint a fresh
// UUID, then write it into the first empty pasteboard slot.
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithError:(NSError **)error {
    RewardNetworkUdid *instance = [self sharedInstance];
    NSDictionary *storage = [[instance pasteBoard] storageData];
    NSString *udid = nil;
    if (storage != nil) {
        udid = [storage objectForKey:@"Value"];
    }
    if (udid == nil) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        udid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
    }

    NSError *writeError = nil;
    NSDictionary *result = [[instance pasteBoard] writeStorageData:udid error:&writeError];
    if (result == nil && error != NULL) {
        *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f7];
    }
    return result;
}

// @ 0xf742c — the decoded UDID record at `storageIndex`.
+ (NSDictionary *)udidWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error {
    RewardNetworkUdid *instance = [self sharedInstance];
    NSError *readError = nil;
    NSDictionary *result = [[instance pasteBoard] storageDataWithStorageIndex:storageIndex
                                                                        error:&readError];
    if (result == nil && error != NULL) {
        *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f4];
    }
    return result;
}

// @ 0xf74fc — the first decoded UDID record found across all slots.
+ (NSDictionary *)udidForFirstInvalidDataWithError:(NSError **)error {
    RewardNetworkUdid *instance = [self sharedInstance];
    NSDictionary *result = [[instance pasteBoard] storageData];
    if (result == nil && error != NULL) {
        *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f4];
    }
    return result;
}

// @ 0xf75b0 — delete the pasteboard record at `storageIndex`, but only when a
// non-"0" reward environment is configured.
+ (BOOL)deleteUDIDWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (env == nil) {
        return YES;
    }
    if ([env isEqualToString:@"0"]) {
        return YES;
    }

    NSError *deleteError = nil;
    [[[self sharedInstance] pasteBoard] deleteWithStorageIndex:storageIndex error:&deleteError];
    if (deleteError != nil) {
        *error = deleteError;
        return NO;
    }
    return YES;
}

#pragma mark - Advertising reward UDID (keychain)

// @ 0xf76cc — read the current advertising-reward UDID, falling back to the
// freshly hashed advertising id when the keychain read fails.
+ (NSString *)getAdvertisingRewardUdidWithError:(NSError **)error {
    if (![self isAdvertisingTrackingOSVersion]) {
        return nil;
    }

    NSString *serviceIndex = [RewardNetworkUdid getServiceIndex:@"adStorageIndex"];
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *service;
    if (![env isEqualToString:@"0"]) {
        service = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkAdUdid"];
    } else {
        service = @"ApplilinkAdUdid";
    }

    NSError *udidError = nil;
    NSString *udid = [RewardNetworkUdid getUdidWithService:service
                                              storageIndex:serviceIndex
                                     rewardNetworkUDIDType:1
                                                     error:&udidError];
    if (udidError == nil && udid != nil) {
        return udid;
    }

    *error = udidError;
    return [RewardNetworkUdid getAdvertisingUdid];
}

// @ 0xf786c — (re)create the advertising-reward UDID: store the current ad id
// as the new UDID (and rotate the previous one into the old UDID slot when it
// differs).
+ (NSString *)createAdvertisingRewardUdidWithError:(NSError **)error {
    if (![self isAdvertisingTrackingOSVersion]) {
        return nil;
    }

    NSString *serviceIndex = [RewardNetworkUdid getServiceIndex:@"adStorageIndex"];
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *service;
    if (![env isEqualToString:@"0"]) {
        service = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkAdUdid"];
    } else {
        service = @"ApplilinkAdUdid";
    }

    NSError *readError = nil;
    NSString *storedUdid = [RewardNetworkUdid getUdidWithService:service
                                                    storageIndex:serviceIndex
                                           rewardNetworkUDIDType:1
                                                           error:&readError];
    NSString *advertisingUdid = [RewardNetworkUdid getAdvertisingUdid];

    if (storedUdid == nil) {
        NSError *setError = readError;
        [RewardNetworkUdid setNewUdid:advertisingUdid error:&setError];
        if (setError != nil) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f7];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.campaignFlg"];
        return advertisingUdid;
    }

    if (![storedUdid isEqualToString:advertisingUdid]) {
        NSError *oldError = readError;
        [RewardNetworkUdid setOldUdid:storedUdid error:&oldError];
        NSError *newError = oldError;
        [RewardNetworkUdid setNewUdid:advertisingUdid error:&newError];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.campaignFlg"];
        *error = nil;
        return advertisingUdid;
    }

    return storedUdid;
}

// @ 0xf7b68 — delete the advertising-reward UDID keychain entry
// `<service>-<index>`.
+ (BOOL)deleteAdvertisingRewardUdidIndex:(NSInteger)index error:(NSError **)error {
    if (index >= 519) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f9];
        }
        return NO;
    }

    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *base;
    if (![env isEqualToString:@"0"]) {
        base = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkAdUdid"];
    } else {
        base = @"ApplilinkAdUdid";
    }
    NSString *service = [NSString stringWithFormat:@"%@-%d", base, (int)index];

    NSError *deleteError = nil;
    [RewardNetworkUdid deleteKeyChainService:service error:&deleteError];
    if (deleteError != nil && error != NULL) {
        *error = deleteError;
    }
    return deleteError == nil;
}

#pragma mark - Old UDID (keychain)

// @ 0xf7d14 — persist `udid` under the "old" UDID service.
+ (BOOL)setOldUdid:(NSString *)udid error:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *base;
    if (![env isEqualToString:@"0"]) {
        base = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkUdid"];
    } else {
        base = @"ApplilinkUdid";
    }
    NSString *service = [NSString stringWithFormat:@"%@_%@", base, @"0"];
    return [RewardNetworkUdid setUdidWithService:service withUDID:udid];
}

// @ 0xf7e64 — read the "old" UDID.
+ (NSString *)getOldUdidWithError:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *service;
    if (![env isEqualToString:@"0"]) {
        service = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkUdid"];
    } else {
        service = @"ApplilinkUdid";
    }
    return [RewardNetworkUdid getUdidWithService:service
                                    storageIndex:@"0"
                           rewardNetworkUDIDType:0
                                           error:error];
}

// @ 0xf7f78 — delete the "old" UDID keychain entry.
+ (BOOL)deleteOldUdidWithError:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *base;
    if (![env isEqualToString:@"0"]) {
        base = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkUdid"];
    } else {
        base = @"ApplilinkUdid";
    }
    NSString *service = [NSString stringWithFormat:@"%@_%@", base, @"0"];

    NSError *deleteError = nil;
    [RewardNetworkUdid deleteKeyChainService:service error:&deleteError];
    if (deleteError != nil && error != NULL) {
        *error = deleteError;
    }
    return deleteError == nil;
}

// @ 0xf80e0 — persist `udid` as the "new" advertising UDID, and remember the
// storage index used so it can be found again.
+ (BOOL)setNewUdid:(NSString *)udid error:(NSError **)error {
    NSString *serviceIndex = [RewardNetworkUdid getServiceIndex:@"adStorageIndex"];
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    NSString *base;
    if (![env isEqualToString:@"0"]) {
        base = [NSString stringWithFormat:@"%@_%@", env, @"ApplilinkAdUdid"];
    } else {
        base = @"ApplilinkAdUdid";
    }

    NSString *index = serviceIndex;
    if (serviceIndex == nil || [serviceIndex length] == 0) {
        index = @"0";
    }

    NSString *service = [NSString stringWithFormat:@"%@_%@", base, index];
    BOOL result = [RewardNetworkUdid setUdidWithService:service withUDID:udid];
    if (result) {
        [RewardNetworkUdid setService:@"adStorageIndex" withStorageIndex:index];
    }
    return result;
}

#pragma mark - Keychain primitives

// @ 0xf82ac — add a generic-password keychain item recording `udid` under
// `service`, replacing any previous item first.
+ (BOOL)setUdidWithService:(NSString *)service withUDID:(NSString *)udid {
    NSDate *now = [NSDate date];
    NSNumber *version = [NSNumber numberWithInteger:1];
    if (udid == nil) {
        return NO;
    }

    NSDictionary *existing = [RewardNetworkUdid searchWithService:service];
    if (existing != nil) {
        NSError *deleteError = nil;
        [RewardNetworkUdid deleteKeyChainService:service error:&deleteError];
    }

    NSDictionary *attributes = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : udid,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecAttrCreationDate : now,
        (__bridge id)kSecAttrModificationDate : now,
        (__bridge id)kSecAttrGeneric : version,
    };
    SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    return YES;
}

// @ 0xf846c — read the UDID (kSecAttrAccount) for `service`/`storageIndex`,
// validate the record, and touch its modification date. `rewardNetworkUDIDType`
// is unused.
+ (NSString *)getUdidWithService:(NSString *)service
                    storageIndex:(NSString *)storageIndex
           rewardNetworkUDIDType:(NSInteger)rewardNetworkUDIDType
                           error:(NSError **)error {
    NSDate *now = [NSDate date];

    NSString *index = storageIndex;
    if (storageIndex == nil || [storageIndex length] == 0) {
        index = @"0";
    }
    NSString *fullService = [NSString stringWithFormat:@"%@_%@", service, index];

    NSDictionary *found = [RewardNetworkUdid searchWithService:fullService];
    if (found == nil) {
        return nil;
    }

    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:found];
    NSError *validateError = nil;
    if (![RewardNetworkUdid validate:found error:&validateError]) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f8];
        }
        return nil;
    }

    NSString *udid = nil;
    id account = [record objectForKey:(__bridge id)kSecAttrAccount];
    if ([account isKindOfClass:[NSString class]]) {
        udid = account;
    }

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : fullService,
    };
    NSDictionary *update = @{
        (__bridge id)kSecAttrModificationDate : now,
    };
    CFTypeRef matchResult = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &matchResult);
    if (status == errSecSuccess) {
        SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
    }
    return udid;
}

// @ 0xf876c — copy the generic-password attributes stored for `service`.
//
// NOTE: reproduced 1:1 with the binary, which pairs the match-limit constants
// the "wrong" way round (kSecMatchLimitOne is used as the dictionary key and
// kSecMatchLimit as its value); this is an SDK quirk, not a transcription slip.
+ (NSDictionary *)searchWithService:(NSString *)service {
    if (service == nil) {
        return nil;
    }

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecMatchLimitOne : (__bridge id)kSecMatchLimit,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef resultRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultRef);
    if (status != errSecSuccess) {
        return nil;
    }
    return (__bridge_transfer NSDictionary *)resultRef;
}

// @ 0xf8860 — delete the generic-password keychain item for `service` (no-op
// when nothing is stored).
+ (BOOL)deleteKeyChainService:(NSString *)service error:(NSError **)error {
    NSDictionary *found = [RewardNetworkUdid searchWithService:service];
    if (found == nil) {
        return YES;
    }

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status == errSecSuccess) {
        return YES;
    }
    if (error != NULL) {
        *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x402];
    }
    return NO;
}

// @ 0xf89a0 — validate the shape of a decoded keychain attributes dictionary.
+ (BOOL)validate:(NSDictionary *)data error:(NSError **)error {
    if (![data isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fb];
        }
        return NO;
    }
    if ([data objectForKey:(__bridge id)kSecAttrAccount] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fc];
        }
        return NO;
    }
    if ([data objectForKey:(__bridge id)kSecAttrCreationDate] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fd];
        }
        return NO;
    }
    if ([data objectForKey:(__bridge id)kSecAttrModificationDate] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fe];
        }
        return NO;
    }
    id generic = [data objectForKey:(__bridge id)kSecAttrGeneric];
    if (generic == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3ff];
        }
        return NO;
    }
    if ([generic intValue] < 1) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x400];
        }
        return NO;
    }
    return YES;
}

// @ 0xf8c30 — read the stored storage-index string (account) for `service`, or
// "0".
+ (NSString *)getServiceIndex:(NSString *)service {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecMatchLimitOne : (__bridge id)kSecMatchLimit,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef resultRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultRef);
    if (status != errSecSuccess) {
        return @"0";
    }

    NSDictionary *attributes = (__bridge_transfer NSDictionary *)resultRef;
    id account = [attributes objectForKey:(__bridge id)kSecAttrAccount];
    if ([account isKindOfClass:[NSString class]]) {
        return account;
    }
    return @"0";
}

// @ 0xf8dc0 — record `storageIndex` (as the account) under `service` in the
// keychain.
+ (void)setService:(NSString *)service withStorageIndex:(NSString *)storageIndex {
    NSError *deleteError = nil;
    [RewardNetworkUdid deleteKeyChainService:service error:&deleteError];

    NSDictionary *attributes = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : storageIndex,
        (__bridge id)kSecAttrService : service,
    };
    SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
}

#pragma mark - Advertising identifier

// @ 0xf8ebc — MD5 of the current advertising identifier's UUID string, or nil
// when tracking is off / the id is the all-zero placeholder.
+ (NSString *)getAdvertisingUdid {
    if (![self isAdvertisingTrackingOSVersion]) {
        return nil;
    }

    ASIdentifierManager *manager = [ASIdentifierManager sharedManager];
    NSString *uuid = [[manager advertisingIdentifier] UUIDString];
    if ([uuid isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return nil;
    }
    return [RewardNetworkUdid md5WithString:uuid];
}

// @ 0xf8fa4 — whether ad tracking is enabled; on unsupported OS versions it
// reports YES.
+ (BOOL)isAdvertisingTrackingEnabled {
    if (![self isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    return [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
}

// @ 0xf9010 — whether the running OS is new enough (>= 6.1) to use the ad
// identifier.
+ (BOOL)isAdvertisingTrackingOSVersion {
    return [[[UIDevice currentDevice] systemVersion] doubleValue] >= 6.1;
}

#pragma mark - Helpers

// @ 0xf90a0 — lowercase hex MD5 of `string`.
+ (NSString *)md5WithString:(NSString *)string {
    const char *data = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), digest);

    NSMutableString *result = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
}

// @ 0xf9168 — populate `parameters` with the "udid"/"old_udid" request fields
// chosen from the ad id / udid / old udid, gated on the OS version and priority
// flag.
+ (BOOL)setUdidParameters:(NSMutableDictionary *)parameters
       isUDIDPriorityType:(BOOL)isUDIDPriorityType {
    NSString *adUdid = [RewardNetwork ad_udid];
    NSString *udid = [RewardNetwork udid];
    NSString *oldUdid = [RewardNetwork old_udid];

    if (adUdid == nil && udid == nil && oldUdid == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ApplilinkReward.campaignFlg"];
        return NO;
    }

    if ([RewardNetworkUdid isAdvertisingTrackingOSVersion]) {
        if (adUdid == nil) {
            [[NSUserDefaults standardUserDefaults]
                removeObjectForKey:@"ApplilinkReward.campaignFlg"];
            return NO;
        }
        [parameters setValue:adUdid forKey:@"udid"];

        NSString *chosen = oldUdid;
        if (!isUDIDPriorityType && ![adUdid isEqualToString:udid] && udid != nil) {
            chosen = udid;
        }
        if (![adUdid isEqualToString:chosen]) {
            [parameters setValue:chosen forKey:@"old_udid"];
        }
        return YES;
    }

    if (udid != nil) {
        [parameters setValue:udid forKey:@"udid"];
        if (oldUdid == nil || [oldUdid isEqualToString:udid]) {
            return YES;
        }
        [parameters setValue:oldUdid forKey:@"old_udid"];
        return YES;
    }

    if (oldUdid != nil) {
        [parameters setValue:oldUdid forKey:@"udid"];
        return YES;
    }

    return NO;
}

// @ 0xf93ac — YES when ad_udid, udid and old_udid are all present and pairwise
// distinct.
+ (BOOL)isUdidThreeKinds {
    NSString *adUdid = [RewardNetwork ad_udid];
    NSString *udid = [RewardNetwork udid];
    NSString *oldUdid = [RewardNetwork old_udid];

    if (adUdid == nil || udid == nil || oldUdid == nil) {
        return NO;
    }
    if ([adUdid isEqualToString:udid]) {
        return NO;
    }
    if ([oldUdid isEqualToString:udid]) {
        return NO;
    }
    if ([adUdid isEqualToString:oldUdid]) {
        return NO;
    }
    return YES;
}

// @ 0xf947c — seed the keychain "old" UDID from the pasteboard record
// identified by the persisted storage index.
+ (void)setUdidKeychainFromPasteBoard {
    NSString *storageIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:@"ApplilinkReward.storageIndex"];
    if (storageIndex == nil) {
        return;
    }

    NSDictionary *record = [RewardNetworkUdid udidWithStorageIndex:[storageIndex intValue]
                                                             error:NULL];
    if (record != nil) {
        NSString *value = [record objectForKey:@"Value"];
        [RewardNetworkUdid setOldUdid:value error:NULL];
    }
}

// @ 0xf96e8 — debug dump of the pasteboard plus the udid / ad-id state (the
// NSLog calls are compiled out in release, leaving only the accessor side
// effects).
+ (void)debugLog {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (env == nil) {
        return;
    }

    [[g_sharedInstance pasteBoard] debugLog];
    (void)[RewardNetwork ad_udid];
    (void)[RewardNetwork udid];
    (void)[RewardNetwork old_udid];
    (void)[[ASIdentifierManager sharedManager] advertisingIdentifier];
}

@end
