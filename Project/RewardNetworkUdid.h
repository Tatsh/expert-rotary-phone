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

/**
 * @brief The reward SDK's device identifiers: the pasteboard-backed UDID, the advertising reward
 * UDID and the legacy keychain UDID.
 */
@interface RewardNetworkUdid : NSObject

/** The pasteboard-backed record store. Getter @ 0xf9828, setter @ 0xf9838. */
@property(nonatomic, strong) RewardNetworkPasteBoard *pasteBoard;

/**
 * @brief Run [super init] serialised on a dedicated queue.
 * @return The initialised instance.
 * @ghidraAddress 0xf70c0
 */
- (instancetype)init;

/**
 * @brief The app's keychain seed (Apple team) id, read from a generic-password item's access
 * group.
 * @return The seed id.
 * @ghidraAddress 0xf956c
 */
- (NSString *)bundleSeedID;

#pragma mark - Singleton (metaclass)

/**
 * @brief Allocate the process-wide shared instance exactly once.
 * @param zone The zone to allocate in.
 * @return The shared instance.
 * @ghidraAddress 0xf6ff0
 */
+ (instancetype)allocWithZone:(NSZone *)zone;

/**
 * @brief The process-wide shared instance.
 * @return The singleton.
 * @ghidraAddress 0xf7200
 */
+ (instancetype)sharedInstance;

#pragma mark - Pasteboard-backed UDID storage

/**
 * @brief Write, or reuse, a UDID in the first empty pasteboard slot.
 * @param error Receives the failure reason; may be NULL.
 * @return The decoded record, or nil on failure.
 * @ghidraAddress 0xf72d4
 */
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithError:(NSError **)error;

/**
 * @brief The decoded UDID record at one slot.
 * @param storageIndex The slot index.
 * @param error Receives the failure reason; may be NULL.
 * @return The record, or nil on failure.
 * @ghidraAddress 0xf742c
 */
+ (NSDictionary *)udidWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

/**
 * @brief The first decoded UDID record found across every slot.
 * @param error Receives the failure reason; may be NULL.
 * @return The record, or nil when none is stored.
 * @ghidraAddress 0xf74fc
 */
+ (NSDictionary *)udidForFirstInvalidDataWithError:(NSError **)error;

/**
 * @brief Delete the pasteboard UDID record at one slot.
 * @param storageIndex The slot index.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf75b0
 */
+ (BOOL)deleteUDIDWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

#pragma mark - Advertising reward UDID (keychain)

/**
 * @brief The current advertising-reward UDID, falling back to the advertising id.
 * @param error Receives the failure reason; may be NULL.
 * @return The UDID, or nil on failure.
 * @ghidraAddress 0xf76cc
 */
+ (NSString *)getAdvertisingRewardUdidWithError:(NSError **)error;

/**
 * @brief Create, or re-create, the advertising-reward UDID from the current advertising id.
 * @param error Receives the failure reason; may be NULL.
 * @return The new UDID, or nil on failure.
 * @ghidraAddress 0xf786c
 */
+ (NSString *)createAdvertisingRewardUdidWithError:(NSError **)error;

/**
 * @brief Delete one advertising-reward UDID keychain entry.
 * @param index The entry index.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf7b68
 */
+ (BOOL)deleteAdvertisingRewardUdidIndex:(NSInteger)index error:(NSError **)error;

#pragma mark - Old UDID (keychain)

/**
 * @brief Persist a UDID as the "old" UDID.
 * @param udid The UDID to store.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf7d14
 */
+ (BOOL)setOldUdid:(NSString *)udid error:(NSError **)error;

/**
 * @brief Read the "old" UDID.
 * @param error Receives the failure reason; may be NULL.
 * @return The UDID, or nil when none is stored.
 * @ghidraAddress 0xf7e64
 */
+ (NSString *)getOldUdidWithError:(NSError **)error;

/**
 * @brief Delete the "old" UDID keychain entry.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf7f78
 */
+ (BOOL)deleteOldUdidWithError:(NSError **)error;

/**
 * @brief Persist a UDID as the "new" (advertising) UDID and remember its index.
 * @param udid The UDID to store.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf80e0
 */
+ (BOOL)setNewUdid:(NSString *)udid error:(NSError **)error;

#pragma mark - Keychain primitives

/**
 * @brief Write a generic-password keychain item mapping a service to a UDID.
 * @param service The service name.
 * @param udid The UDID to store.
 * @return YES on success.
 * @ghidraAddress 0xf82ac
 */
+ (BOOL)setUdidWithService:(NSString *)service withUDID:(NSString *)udid;

/**
 * @brief Read, and touch, the UDID stored under a service and storage index.
 * @param service The service name.
 * @param storageIndex The storage index string.
 * @param rewardNetworkUDIDType The UDID kind.
 * @param error Receives the failure reason; may be NULL.
 * @return The UDID, or nil on failure.
 * @ghidraAddress 0xf846c
 */
+ (NSString *)getUdidWithService:(NSString *)service
                    storageIndex:(NSString *)storageIndex
           rewardNetworkUDIDType:(NSInteger)rewardNetworkUDIDType
                           error:(NSError **)error;

/**
 * @brief Look up the generic-password attributes for a service.
 * @param service The service name.
 * @return The attributes, or nil when the item is absent.
 * @ghidraAddress 0xf876c
 */
+ (NSDictionary *)searchWithService:(NSString *)service;

/**
 * @brief Delete the generic-password keychain item for a service.
 * @param service The service name.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf8860
 */
+ (BOOL)deleteKeyChainService:(NSString *)service error:(NSError **)error;

/**
 * @brief Validate the shape of a decoded keychain attributes dictionary.
 * @param data The attributes to validate.
 * @param error Receives the failure reason; may be NULL.
 * @return YES when the shape is valid.
 * @ghidraAddress 0xf89a0
 */
+ (BOOL)validate:(NSDictionary *)data error:(NSError **)error;

/**
 * @brief Read the stored storage-index string for a service.
 * @param service The service name.
 * @return The storage index string, or nil when absent.
 * @ghidraAddress 0xf8c30
 */
+ (NSString *)getServiceIndex:(NSString *)service;

/**
 * @brief Store a storage index under a service, as the keychain item's account.
 * @param service The service name.
 * @param storageIndex The storage index string.
 * @ghidraAddress 0xf8dc0
 */
+ (void)setService:(NSString *)service withStorageIndex:(NSString *)storageIndex;

#pragma mark - Advertising identifier

/**
 * @brief The MD5 of the current advertising identifier.
 * @return The digest, or nil when no identifier is available.
 * @ghidraAddress 0xf8ebc
 */
+ (NSString *)getAdvertisingUdid;

/**
 * @brief Whether ad tracking is enabled.
 * @return YES when enabled, and also on an OS too old to report it.
 * @ghidraAddress 0xf8fa4
 */
+ (BOOL)isAdvertisingTrackingEnabled;

/**
 * @brief Whether the OS is new enough — 6.1 or later — to use the advertising identifier.
 * @return YES on a supported OS.
 * @ghidraAddress 0xf9010
 */
+ (BOOL)isAdvertisingTrackingOSVersion;

#pragma mark - Helpers

/**
 * @brief The lowercase hexadecimal MD5 of a string.
 * @param string The string to hash.
 * @return The digest.
 * @ghidraAddress 0xf90a0
 */
+ (NSString *)md5WithString:(NSString *)string;

/**
 * @brief Populate a parameter dictionary with the udid and old_udid request fields.
 * @param parameters The dictionary to fill.
 * @param isUDIDPriorityType YES to prefer the pasteboard UDID over the advertising one.
 * @return YES when at least one field was written.
 * @ghidraAddress 0xf9168
 */
+ (BOOL)setUdidParameters:(NSMutableDictionary *)parameters
       isUDIDPriorityType:(BOOL)isUDIDPriorityType;

/**
 * @brief Whether the advertising, pasteboard and old UDIDs are three distinct values.
 * @return YES when all three differ.
 * @ghidraAddress 0xf93ac
 */
+ (BOOL)isUdidThreeKinds;

/**
 * @brief Seed the keychain "old" UDID from the persisted pasteboard index.
 * @ghidraAddress 0xf947c
 */
+ (void)setUdidKeychainFromPasteBoard;

/**
 * @brief Debug dump of the pasteboard, UDID and advertising-id state.
 * @ghidraAddress 0xf96e8
 */
+ (void)debugLog;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
