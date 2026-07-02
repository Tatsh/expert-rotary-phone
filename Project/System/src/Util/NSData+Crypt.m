//
//  NSData+Crypt.m
//  pop'n rhythmin
//
//  AES-128-CBC helpers (behavioral reconstruction — see NSData+Crypt.h).
//  Ghidra: NSData::encryptWith128Key_initVector_ (thunk @ 0x1a0506) and the
//  NSKeyedArchiver variant (thunk @ 0x1a1202); real bodies not disassemblable.
//

#import <CommonCrypto/CommonCryptor.h>

#import "NSData+Crypt.h"

@implementation NSData (Crypt)

static NSData *RhAESCrypt(NSData *input, NSString *key, NSString *iv, CCOperation op) {
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ivData = [iv dataUsingEncoding:NSUTF8StringEncoding];

    size_t bufferSize = input.length + kCCBlockSizeAES128;
    NSMutableData *output = [NSMutableData dataWithLength:bufferSize];

    size_t outMoved = 0;
    CCCryptorStatus status = CCCrypt(op,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     keyData.bytes, kCCKeySizeAES128,
                                     ivData.bytes,
                                     input.bytes, input.length,
                                     output.mutableBytes, bufferSize,
                                     &outMoved);
    if (status != kCCSuccess) {
        return nil;
    }
    output.length = outMoved;
    return output;
}

- (NSData *)encryptWith128Key:(NSString *)key initVector:(NSString *)iv {
    return RhAESCrypt(self, key, iv, kCCEncrypt);
}

- (NSData *)decryptWith128Key:(NSString *)key initVector:(NSString *)iv {
    return RhAESCrypt(self, key, iv, kCCDecrypt);
}

@end
