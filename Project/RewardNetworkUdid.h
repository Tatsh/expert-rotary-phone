//
//  RewardNetworkUdid.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK per-device identifier helper.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (instanceSize
//  8: isa + the single `_pasteBoard` object ivar, NSObject superclass).
//
//  The metaclass carries the UDID generation/keychain API (allocWithZone:/
//  sharedInstance singleton, keychain storage via SecItem, advertising-id MD5,
//  and the RewardNetwork udid/ad_udid/old_udid plumbing); all of it is
//  reconstructed below as class (+) methods.
//

#import <Foundation/Foundation.h>

@class RewardNetworkPasteBoard;

@interface RewardNetworkUdid : NSObject

// _pasteBoard ivar / accessors @ 0xf9828 (getter) / 0xf9838 (setter).
@property(nonatomic, strong) RewardNetworkPasteBoard *pasteBoard;

// @ 0xf70c0 — runs [super init] serialized on a dedicated queue.
- (instancetype)init;

// @ 0xf956c — the app's keychain seed (Apple team) id, read from a
// generic-password item's access group.
- (NSString *)bundleSeedID;

#pragma mark - Singleton (metaclass)

// @ 0xf6ff0 — allocate the process-wide shared instance exactly once.
+ (instancetype)allocWithZone:(NSZone *)zone;

// @ 0xf7200 — the process-wide shared instance.
+ (instancetype)sharedInstance;

#pragma mark - Pasteboard-backed UDID storage

// @ 0xf72d4 — write (or reuse) a UDID into the first empty pasteboard slot.
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithError:(NSError **)error;

// @ 0xf742c — the decoded UDID record at `storageIndex`.
+ (NSDictionary *)udidWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

// @ 0xf74fc — the first decoded UDID record found across all slots.
+ (NSDictionary *)udidForFirstInvalidDataWithError:(NSError **)error;

// @ 0xf75b0 — delete the pasteboard UDID record at `storageIndex`.
+ (BOOL)deleteUDIDWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

#pragma mark - Advertising reward UDID (keychain)

// @ 0xf76cc — the current advertising-reward UDID, falling back to the ad id.
+ (NSString *)getAdvertisingRewardUdidWithError:(NSError **)error;

// @ 0xf786c — (re)create the advertising-reward UDID from the current ad id.
+ (NSString *)createAdvertisingRewardUdidWithError:(NSError **)error;

// @ 0xf7b68 — delete the advertising-reward UDID keychain entry at `index`.
+ (BOOL)deleteAdvertisingRewardUdidIndex:(NSInteger)index error:(NSError **)error;

#pragma mark - Old UDID (keychain)

// @ 0xf7d14 — persist `udid` as the "old" UDID.
+ (BOOL)setOldUdid:(NSString *)udid error:(NSError **)error;

// @ 0xf7e64 — read the "old" UDID.
+ (NSString *)getOldUdidWithError:(NSError **)error;

// @ 0xf7f78 — delete the "old" UDID keychain entry.
+ (BOOL)deleteOldUdidWithError:(NSError **)error;

// @ 0xf80e0 — persist `udid` as the "new" (advertising) UDID and remember its
// index.
+ (BOOL)setNewUdid:(NSString *)udid error:(NSError **)error;

#pragma mark - Keychain primitives

// @ 0xf82ac — write a generic-password keychain item {service -> udid}.
+ (BOOL)setUdidWithService:(NSString *)service withUDID:(NSString *)udid;

// @ 0xf846c — read (and touch) the UDID stored under `service`/`storageIndex`.
+ (NSString *)getUdidWithService:(NSString *)service
                    storageIndex:(NSString *)storageIndex
           rewardNetworkUDIDType:(NSInteger)rewardNetworkUDIDType
                           error:(NSError **)error;

// @ 0xf876c — look up the generic-password attributes for `service`.
+ (NSDictionary *)searchWithService:(NSString *)service;

// @ 0xf8860 — delete the generic-password keychain item for `service`.
+ (BOOL)deleteKeyChainService:(NSString *)service error:(NSError **)error;

// @ 0xf89a0 — validate the shape of a decoded keychain attributes dictionary.
+ (BOOL)validate:(NSDictionary *)data error:(NSError **)error;

// @ 0xf8c30 — read the stored storage-index string for `service`.
+ (NSString *)getServiceIndex:(NSString *)service;

// @ 0xf8dc0 — store `storageIndex` under `service` (account) in the keychain.
+ (void)setService:(NSString *)service withStorageIndex:(NSString *)storageIndex;

#pragma mark - Advertising identifier

// @ 0xf8ebc — the MD5 of the current advertising identifier, or nil.
+ (NSString *)getAdvertisingUdid;

// @ 0xf8fa4 — whether ad tracking is enabled (YES when unsupported OS).
+ (BOOL)isAdvertisingTrackingEnabled;

// @ 0xf9010 — whether the OS is new enough (>= 6.1) to use the ad identifier.
+ (BOOL)isAdvertisingTrackingOSVersion;

#pragma mark - Helpers

// @ 0xf90a0 — lowercase hex MD5 of `string`.
+ (NSString *)md5WithString:(NSString *)string;

// @ 0xf9168 — populate `parameters` with the udid/old_udid request fields.
+ (BOOL)setUdidParameters:(NSMutableDictionary *)parameters
       isUDIDPriorityType:(BOOL)isUDIDPriorityType;

// @ 0xf93ac — YES when ad/udid/old_udid are three distinct values.
+ (BOOL)isUdidThreeKinds;

// @ 0xf947c — seed the keychain "old" UDID from the persisted pasteboard index.
+ (void)setUdidKeychainFromPasteBoard;

// @ 0xf96e8 — debug dump of the pasteboard + udid/ad-id state.
+ (void)debugLog;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
