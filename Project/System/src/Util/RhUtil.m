//
//  RhUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RhCrypto.h"
#import "RhUtil.h"

#import <CommonCrypto/CommonDigest.h>

// Ghidra: FUN_0005c258 — plist -> NSDictionary (nil unless the root is a dict).
NSDictionary *RhParsePlistDict(NSData *data) {
    if (data == nil) {
        return nil;
    }
    id root = [NSPropertyListSerialization propertyListWithData:data
                                                        options:NSPropertyListImmutable
                                                         format:nil
                                                          error:nil];
    return [root isKindOfClass:NSDictionary.class] ? root : nil;
}

// Ghidra: FUN_0005c330 — plist -> mutable NSArray copy (nil unless root is array).
NSMutableArray *RhParsePlistArray(NSData *data) {
    if (data == nil) {
        return nil;
    }
    id root = [NSPropertyListSerialization propertyListWithData:data
                                                        options:NSPropertyListImmutable
                                                         format:nil
                                                          error:nil];
    if (![root isKindOfClass:NSArray.class]) {
        return nil;
    }
    return [NSMutableArray arrayWithArray:root];
}

// Ghidra: FUN_0005c434 — file (not directory) existence.
BOOL RhFileExists(NSString *path) {
    BOOL isDir = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] && !isDir;
}

// Ghidra: FUN_0005b4b8 — MD5 of a C string as NSData.
NSData *RhMD5Data(const char *cString) {
    unsigned char digest[16];
    RhMD5(cString, (uint32_t)strlen(cString), digest);
    return [NSData dataWithBytes:digest length:16];
}

// Ghidra: FUN_0005b534 — MD5 of a C string as a 32-char lowercase hex string.
NSString *ComputeMD5HexString(const char *cString) {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cString, (CC_LONG)strlen(cString), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [NSString stringWithString:hex];
}

// Ghidra: FUN_0005bc04 — SHA-256 of a C string as a 64-char lowercase hex string.
NSString *ComputeSHA256HexString(const char *cString) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(cString, (CC_LONG)strlen(cString), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [NSString stringWithString:hex];
}
