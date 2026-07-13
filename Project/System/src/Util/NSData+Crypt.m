//
//  NSData+Crypt.m
//  pop'n rhythmin
//
//  AES-128-CBC helpers. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin:
//    -[NSData mainOperation:key:initVector:] @ 0xbeaf8 (shared core)
//    -[NSData encryptWith128Key:initVector:] @ 0xbec18 (kCCEncrypt wrapper)
//    -[NSData decryptWith128Key:initVector:] @ 0xbec3c (kCCDecrypt wrapper)
//

#import <CommonCrypto/CommonCryptor.h>

#import "NSData+Crypt.h"

@implementation NSData (Crypt)

// @ 0xbec18 — forward to the core with kCCEncrypt.
- (NSData *)encryptWith128Key:(NSString *)key initVector:(NSString *)iv {
    return [self mainOperation:kCCEncrypt key:key initVector:iv];
}

// @ 0xbec3c — forward to the core with kCCDecrypt.
- (NSData *)decryptWith128Key:(NSString *)key initVector:(NSString *)iv {
    return [self mainOperation:kCCDecrypt key:key initVector:iv];
}

// @ 0xbeaf8 — AES-128-CBC (PKCS#7) core shared by encrypt/decrypt.
- (NSData *)mainOperation:(CCOperation)op key:(NSString *)key initVector:(NSString *)iv {
    // Copy the key/IV NSStrings into fixed 17-byte C buffers (16 chars + NUL);
    // Ghidra: -getCString:maxLength:0x11 encoding:4 (NSUTF8StringEncoding).
    char keyBytes[17] = {0};
    char ivBytes[17] = {0};
    [key getCString:keyBytes maxLength:sizeof(keyBytes) encoding:NSUTF8StringEncoding];
    [iv getCString:ivBytes maxLength:sizeof(ivBytes) encoding:NSUTF8StringEncoding];

    size_t dataLength = self.length;
    size_t bufferSize = dataLength + kCCBlockSizeAES128; // len + 0x10
    void *dataOut = malloc(bufferSize);

    size_t outMoved = 0;
    CCCryptorStatus status = CCCrypt(op,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     keyBytes,
                                     kCCKeySizeAES128,
                                     ivBytes,
                                     self.bytes,
                                     dataLength,
                                     dataOut,
                                     bufferSize,
                                     &outMoved);
    if (status == kCCSuccess) {
        // Hand the malloc'd buffer to NSData (freed with free() on dealloc).
        return [NSData dataWithBytesNoCopy:dataOut length:outMoved];
    }
    free(dataOut);
    return nil;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
