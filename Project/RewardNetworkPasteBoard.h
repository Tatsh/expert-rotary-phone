//
//  RewardNetworkPasteBoard.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK persistent storage backed by named
//  UIPasteboards. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (NSObject superclass; ivars _serviceName / _dataType, both NSString*).
//
//  Each record lives in its own persistent UIPasteboard named
//  "<service>-<index>" (index 0..518). The stored payload is a keyed-archived
//  dictionary with keys Value / EntryDate / LastAccess / Version; the Value is
//  AES-encrypted with a key derived (SHA-1) from the pasteboard name.
//

#import <Foundation/Foundation.h>

/**
 * @brief Cross-app record storage backed by named pasteboards, one per storage slot.
 */
@interface RewardNetworkPasteBoard : NSObject

/**
 * @brief The designated initialiser; it copies the service name and pasteboard data type into
 * _serviceName and _dataType.
 * @param serviceName The pasteboard service name.
 * @param dataType The pasteboard data type (a UTI).
 * @return The initialised store.
 * @ghidraAddress 0xf5988
 */
- (instancetype)initWithServiceName:(NSString *)serviceName dataType:(NSString *)dataType;

/**
 * @brief The first decoded record found by scanning every storage slot.
 * @return The record, or nil when no slot holds one.
 * @ghidraAddress 0xf5a60
 */
- (NSDictionary *)storageData;

/**
 * @brief The decoded record at one slot.
 * @param storageIndex The slot index.
 * @param error Receives the failure reason; may be NULL.
 * @return The record, or nil on a miss or corruption.
 * @ghidraAddress 0xf5bb8
 */
- (NSDictionary *)storageDataWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

/**
 * @brief Write a value into the first free slot.
 * @param data The value to store.
 * @param error Receives the failure reason; may be NULL.
 * @return The decoded record, or nil on failure.
 * @ghidraAddress 0xf604c
 */
- (NSDictionary *)writeStorageData:(NSString *)data error:(NSError **)error;

/**
 * @brief Write a value into one slot.
 * @param data The value to store.
 * @param storageIndex The slot index.
 * @param error Receives the failure reason; may be NULL.
 * @return The decoded record, or nil on failure.
 * @ghidraAddress 0xf6214
 */
- (NSDictionary *)writeStorageData:(NSString *)data
                      storageIndex:(NSInteger)storageIndex
                             error:(NSError **)error;

/**
 * @brief Remove the record, and its pasteboard, at one slot.
 * @param storageIndex The slot index.
 * @param error Receives the failure reason; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0xf6560
 */
- (BOOL)deleteWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

/**
 * @brief Decode a stored record: add its StorageIndex and decrypt its Value to a string.
 * @param data The raw stored record.
 * @param storageIndex The slot the record came from.
 * @return The decoded record.
 * @ghidraAddress 0xf6b90
 */
- (NSDictionary *)convertToData:(NSDictionary *)data storageIndex:(NSInteger)storageIndex;

/**
 * @brief The effective service name, prefixed with the reward environment when one other than "0"
 * is configured.
 * @return The service name.
 * @ghidraAddress 0xf6d64
 */
- (NSString *)getServiceName;

/**
 * @brief Scan every slot, reading its decoded value; a debug helper.
 * @ghidraAddress 0xf6e48
 */
- (void)debugLog;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
