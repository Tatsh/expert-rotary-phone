//
//  RewardNetworkPasteBoard.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkPasteBoard.h"
#import "RewardNetworkError.h"

#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIKit.h>

// Slots are named "<service>-<index>" for index in 0..518 (< 0x207).
static const NSInteger kRewardStorageIndexLimit = 0x207;

@interface RewardNetworkPasteBoard () {
    NSString *_serviceName;
    NSString *_dataType;
}

// @ 0xf69a8 — SHA-1 of a data blob (used to derive the per-record AES key).
+ (NSData *)createHash:(NSData *)data;

// @ 0xf6a54 — AES-128/PKCS7 encrypt (kCCEncrypt) or decrypt (kCCDecrypt)
// `value`.
+ (NSData *)cryptorToData:(CCOperation)operation value:(NSData *)value key:(NSData *)key;

// @ 0xf6718 — ensure a decoded record dictionary carries the required keys.
+ (BOOL)validate:(NSDictionary *)data error:(NSError **)error;

@end

@implementation RewardNetworkPasteBoard

// @ 0xf5988
- (instancetype)initWithServiceName:(NSString *)serviceName dataType:(NSString *)dataType {
    self = [super init];
    if (self) {
        _serviceName = [[NSString alloc] initWithString:serviceName];
        _dataType = [[NSString alloc] initWithString:dataType];
    }
    return self;
}

// setData/.cxx_destruct @ 0xf6fbc — compiler-emitted ARC teardown for
// _serviceName /
//   _dataType; not hand-written.

// @ 0xf6d64
- (NSString *)getServiceName {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.env"];
    if (![env isEqualToString:@"0"] && env != nil) {
        return [NSString stringWithFormat:@"%@_%@", env, _serviceName];
    }
    return _serviceName;
}

// @ 0xf5a60
- (NSDictionary *)storageData {
    if (_serviceName == nil) {
        return nil;
    }
    NSString *service = [self getServiceName];
    NSDictionary *result = nil;
    for (NSInteger i = 0; i < kRewardStorageIndexLimit; i++) {
        NSString *name = [NSString stringWithFormat:@"%@-%d", service, (int)i];
        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
        if (pasteboard != nil) {
            NSError *error = nil;
            NSDictionary *data = [self storageDataWithStorageIndex:i error:&error];
            if (error == nil && data != nil) {
                result = data;
                break;
            }
        }
    }
    return result;
}

// @ 0xf5bb8
- (NSDictionary *)storageDataWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error {
    if (storageIndex >= kRewardStorageIndexLimit) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f9];
        }
        return nil;
    }

    NSString *name = [NSString stringWithFormat:@"%@-%d", [self getServiceName], (int)storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
        }
        return nil;
    }

    NSData *archived = [pasteboard valueForPasteboardType:_dataType];
    if (archived == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fa];
        }
        return nil;
    }

#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archived
                                                                                error:nil];
    unarchiver.requiresSecureCoding = NO;
    NSDictionary *record =
        [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    [unarchiver finishDecoding];
#else
    NSDictionary *record = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
#endif
    NSError *validateError = nil;
    if (![RewardNetworkPasteBoard validate:record error:&validateError]) {
        // The binary passes nil here (Ghidra: setData:0x0); UIPasteboard's data
        // parameter must be non-nil, so pass empty data to clear the type
        // without tripping the null-argument warning (behaviourally identical to nil).
        [pasteboard setData:[NSData data] forPasteboardType:_dataType];
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f8];
        }
        return nil;
    }

    NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:record];
    updated[@"LastAccess"] = [NSDate date];
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSData *updatedArchived = [NSKeyedArchiver archivedDataWithRootObject:updated
                                                   requiringSecureCoding:NO
                                                                   error:nil];
#else
    NSData *updatedArchived = [NSKeyedArchiver archivedDataWithRootObject:updated];
#endif
    [pasteboard setData:updatedArchived forPasteboardType:_dataType];

    return [self convertToData:record storageIndex:storageIndex];
}

// @ 0xf604c — scan for the first free slot (no existing pasteboard) and write
// there; on a failed write the slot is deleted and scanning continues.
- (NSDictionary *)writeStorageData:(NSString *)data error:(NSError **)error {
    NSString *service = [self getServiceName];
    NSError *deleteError = nil;
    NSError *writeError = nil;
    NSDictionary *result = nil;

    NSInteger i;
    for (i = 0; i < kRewardStorageIndexLimit; i++) {
        NSString *name = [NSString stringWithFormat:@"%@-%d", service, (int)i];
        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
        if (pasteboard == nil) {
            writeError = nil;
            NSDictionary *written = [self writeStorageData:data storageIndex:i error:&writeError];
            if (written != nil) {
                result = written;
                return result;
            }
            deleteError = nil;
            [self deleteWithStorageIndex:i error:&deleteError];
        }
    }

    if (deleteError == nil && writeError == nil) {
        result = nil;
    } else {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f7];
        }
        result = nil;
    }
    return result;
}

// @ 0xf6214
- (NSDictionary *)writeStorageData:(NSString *)data
                      storageIndex:(NSInteger)storageIndex
                             error:(NSError **)error {
    if (storageIndex >= kRewardStorageIndexLimit) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f9];
        }
        return nil;
    }

    NSString *name = [NSString stringWithFormat:@"%@-%d", [self getServiceName], (int)storageIndex];
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [RewardNetworkPasteBoard createHash:nameData];
    NSData *encrypted =
        [RewardNetworkPasteBoard cryptorToData:kCCEncrypt
                                         value:[data dataUsingEncoding:NSUTF8StringEncoding]
                                           key:key];
    NSDate *now = [NSDate date];
    NSDictionary *record = [NSDictionary dictionaryWithObjectsAndKeys:encrypted,
                                                                      @"Value",
                                                                      now,
                                                                      @"EntryDate",
                                                                      now,
                                                                      @"LastAccess",
                                                                      @(1),
                                                                      @"Version",
                                                                      nil];

    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:YES];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
        }
        return nil;
    }

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    // Persistence is set automatically on named pasteboards from iOS 10, so the
    // explicit assignment is omitted here.
#else
    pasteboard.persistent = YES;
#endif
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSData *recordArchived = [NSKeyedArchiver archivedDataWithRootObject:record
                                                  requiringSecureCoding:NO
                                                                  error:nil];
#else
    NSData *recordArchived = [NSKeyedArchiver archivedDataWithRootObject:record];
#endif
    [pasteboard setData:recordArchived forPasteboardType:_dataType];

    return [self convertToData:record storageIndex:storageIndex];
}

// @ 0xf6560
- (BOOL)deleteWithStorageIndex:(NSInteger)storageIndex error:(NSError **)error {
    if (storageIndex >= kRewardStorageIndexLimit) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f9];
        }
        return NO;
    }

    NSString *name = [NSString stringWithFormat:@"%@-%d", [self getServiceName], (int)storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3f5];
        }
        return NO;
    }

    id value = [pasteboard valueForPasteboardType:_dataType];
    if (value == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fa];
        }
        return NO;
    }

    // The binary passes nil here (Ghidra: setData:0x0); the pasteboard is
    // removed on the next line, so pass empty data to satisfy UIPasteboard's
    // non-nil data requirement without changing behaviour.
    [pasteboard setData:[NSData data] forPasteboardType:_dataType];
    [UIPasteboard removePasteboardWithName:name];
    return YES;
}

// @ 0xf6b90
- (NSDictionary *)convertToData:(NSDictionary *)data storageIndex:(NSInteger)storageIndex {
    NSMutableDictionary *converted = [NSMutableDictionary dictionaryWithDictionary:data];
    converted[@"StorageIndex"] = @(storageIndex);

    NSString *name = [NSString stringWithFormat:@"%@-%d", [self getServiceName], (int)storageIndex];
    NSData *key =
        [RewardNetworkPasteBoard createHash:[name dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *decrypted = [RewardNetworkPasteBoard cryptorToData:kCCDecrypt
                                                         value:[data objectForKey:@"Value"]
                                                           key:key];
    converted[@"Value"] = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    return converted;
}

// @ 0xf6e48
- (void)debugLog {
    if (_serviceName == nil) {
        return;
    }
    NSString *service = [self getServiceName];
    for (NSInteger i = 0; i < kRewardStorageIndexLimit; i++) {
        NSString *name = [NSString stringWithFormat:@"%@-%d", service, (int)i];
        UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
        if (pasteboard != nil) {
            NSError *error = nil;
            NSDictionary *data = [self storageDataWithStorageIndex:i error:&error];
            if (error == nil && data != nil) {
                (void)[data objectForKey:@"Value"];
            }
        }
    }
}

// @ 0xf69a8
+ (NSData *)createHash:(NSData *)data {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH] = {0};
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

// @ 0xf6a54
+ (NSData *)cryptorToData:(CCOperation)operation value:(NSData *)value key:(NSData *)key {
    NSMutableData *output = [NSMutableData dataWithLength:value.length + kCCBlockSizeAES128];
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(operation,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCCKeySizeAES128,
                                     NULL,
                                     value.bytes,
                                     value.length,
                                     output.mutableBytes,
                                     output.length,
                                     &moved);
    if (status == kCCSuccess) {
        return [NSData dataWithBytes:output.bytes length:moved];
    }
    return nil;
}

// @ 0xf6718
+ (BOOL)validate:(NSDictionary *)data error:(NSError **)error {
    if (![data isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fb];
        }
        return NO;
    }
    if ([data objectForKey:@"Value"] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fc];
        }
        return NO;
    }
    if ([data objectForKey:@"EntryDate"] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fd];
        }
        return NO;
    }
    if ([data objectForKey:@"LastAccess"] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3fe];
        }
        return NO;
    }
    if ([data objectForKey:@"Version"] == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3ff];
        }
        return NO;
    }
    if ([[data objectForKey:@"Version"] intValue] < 1) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x400];
        }
        return NO;
    }
    return YES;
}

@end
