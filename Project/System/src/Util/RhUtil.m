//
//  RhUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RhUtil.h"
#import "RhCrypto.h"

#import <CommonCrypto/CommonDigest.h>
#import <sys/time.h>

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

// Ghidra: FUN_0005c330 — plist -> mutable NSArray copy (nil unless root is
// array).
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

// Ghidra: FUN_0005c48c — file byte size (int), or -1 when the file is absent.
int getFileSize(NSString *path) {
    if (!RhFileExists(path)) {
        return -1;
    }
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
    return [[attrs objectForKey:NSFileSize] intValue];
}

// Ghidra: FUN_00028aa4 — treat an NSArray of NSNumber as a packed
// 32-bit-per-element bitfield and return whether bit `bit` is set: element (bit
// >> 5)'s intValue masked by 1 << (bit & 31). An out-of-range element index
// reads as 0 (NO).
BOOL RhTestBitInNumberArray(NSArray *numberArray, unsigned bit) {
    unsigned idx = bit >> 5;
    if (idx >= [numberArray count]) {
        return NO;
    }
    int word = [[numberArray objectAtIndex:idx] intValue];
    return (word & (1 << (bit & 0x1f))) != 0;
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

// Ghidra: FUN_0005bc04 — SHA-256 of a C string as a 64-char lowercase hex
// string.
NSString *ComputeSHA256HexString(const char *cString) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(cString, (CC_LONG)strlen(cString), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [NSString stringWithString:hex];
}

// Ghidra: getTimeMillis @ 0x2dae0 — gettimeofday reduced to milliseconds.
long getTimeMillis(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

// Ghidra: utf8CharLen @ 0x17a84 — decode the byte-length of a UTF-8 sequence
// from its lead byte. Only s[0] is examined:
//   0xxxxxxx -> 1        110xxxxx -> 2        1110xxxx -> 3
//   11110xxx -> 4        111110xx -> 5        1111110x -> 6
//   10xxxxxx -> 0 (stray continuation byte)  0xFE/0xFF -> -1 (invalid)
int utf8CharLen(const char *s) {
    unsigned c = (unsigned char)s[0];
    if ((c & 0x80) == 0) {
        return 1;
    }
    if ((c & 0x40) == 0) {
        return 0;
    }
    if ((c & 0x20) == 0) {
        return 2;
    }
    if ((c & 0x10) == 0) {
        return 3;
    }
    if ((c & 0x08) == 0) {
        return 4;
    }
    if ((c & 0x04) == 0) {
        return 5;
    }
    return (c & 0x02) == 0 ? 6 : -1;
}

// Ghidra: pointInCircle @ 0x2d9bc — inclusive squared-distance hit test.
BOOL pointInCircle(int x, int y, int cx, int cy, int r) {
    return (y - cy) * (y - cy) + (x - cx) * (x - cx) <= r * r;
}

// Ghidra: loadDeviceImage @ 0x5bd28 — idiom/scale-aware bundled PNG loader.
// The retina suffix is "_pn" and the (legacy, scale==0) rebuild suffix is
// "_pn2"; both fall back to the plain "name.png" resource. When a "_pn2" (or
// its fallback) asset is used the image is rebuilt at scale 2.0 so it renders
// at the intended point size.
UIImage *loadDeviceImage(NSString *name) {
    NSString *path = nil;
    BOOL rebuildAtScale2 = NO;
    NSBundle *bundle = [NSBundle mainBundle];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        path = [bundle pathForResource:name ofType:@"png"];
        rebuildAtScale2 = NO;
    } else {
        CGFloat scale = [[UIScreen mainScreen] scale];
        if (scale != 0.0) {
            path = [bundle pathForResource:[name stringByAppendingString:@"_pn"] ofType:@"png"];
            if (path == nil) {
                path = [bundle pathForResource:name ofType:@"png"];
            }
            rebuildAtScale2 = NO;
        } else {
            path = [bundle pathForResource:[name stringByAppendingString:@"_pn2"] ofType:@"png"];
            if (path == nil) {
                path = [bundle pathForResource:name ofType:@"png"];
            }
            rebuildAtScale2 = YES;
        }
    }

    if (path == nil) {
        return nil;
    }

    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    if (image != nil && rebuildAtScale2) {
        image = [UIImage imageWithCGImage:image.CGImage
                                    scale:2.0f
                              orientation:UIImageOrientationUp];
    }
    return image;
}
