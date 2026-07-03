//
//  RewardNetworkPasteBoard.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK persistent storage backed by named
//  UIPasteboards. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (NSObject superclass; ivars _serviceName / _dataType, both NSString*).
//
//  Each record lives in its own persistent UIPasteboard named "<service>-<index>"
//  (index 0..518). The stored payload is a keyed-archived dictionary with keys
//  Value / EntryDate / LastAccess / Version; the Value is AES-encrypted with a key
//  derived (SHA-1) from the pasteboard name.
//

#import <Foundation/Foundation.h>

@interface RewardNetworkPasteBoard : NSObject

// @ 0xf5988 — designated initializer; copies the service name and pasteboard data
// type (UTI) into _serviceName / _dataType.
- (instancetype)initWithServiceName:(NSString *)serviceName dataType:(NSString *)dataType;

// @ 0xf5a60 — first decoded record found by scanning all storage slots.
- (NSDictionary *)storageData;

// @ 0xf5bb8 — decoded record at `storageIndex`, or nil (+ error) on miss/corruption.
- (NSDictionary *)storageDataWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

// @ 0xf604c — write `data` into the first free slot; returns the decoded record.
- (NSDictionary *)writeStorageData:(NSString *)data error:(NSError **)error;

// @ 0xf6214 — write `data` into slot `storageIndex`; returns the decoded record.
- (NSDictionary *)writeStorageData:(NSString *)data
                      storageIndex:(NSInteger)storageIndex
                             error:(NSError **)error;

// @ 0xf6560 — remove the record (and its pasteboard) at `storageIndex`.
- (BOOL)deleteWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error;

// @ 0xf6b90 — decode a stored record: add StorageIndex and decrypt Value to a string.
- (NSDictionary *)convertToData:(NSDictionary *)data storageIndex:(NSInteger)storageIndex;

// @ 0xf6d64 — the effective service name, prefixed with the reward environment when
// one other than "0" is configured.
- (NSString *)getServiceName;

// @ 0xf6e48 — scan every slot, reading its decoded Value (debug helper).
- (void)debugLog;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
