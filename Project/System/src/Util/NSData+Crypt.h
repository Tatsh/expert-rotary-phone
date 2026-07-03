//
//  NSData+Crypt.h
//  pop'n rhythmin
//
//  AES-128-CBC helpers used to protect the user's save data.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Both public
//  wrappers are thin: they forward to the shared core -mainOperation:key:initVector:
//  with kCCEncrypt / kCCDecrypt. Key/IV are 16-char NSStrings copied to C via
//  -getCString:maxLength:encoding: (key "4ZMw025eJIOTx26f", IV "13U4RnAI73EdVMXB")
//  and the cipher is AES-128-CBC with PKCS#7 padding (kCCOptionPKCS7Padding).
//

#import <CommonCrypto/CommonCryptor.h> // CCOperation

#import <Foundation/Foundation.h>

@interface NSData (Crypt)

// Encrypt the receiver with AES-128-CBC. `key` and `iv` are 16-char NSStrings.
- (NSData *)encryptWith128Key:(NSString *)key initVector:(NSString *)iv;

// Decrypt an AES-128-CBC blob produced by the method above.
- (NSData *)decryptWith128Key:(NSString *)key initVector:(NSString *)iv;

// Shared AES-128-CBC core: `op` is kCCEncrypt or kCCDecrypt.
// Ghidra: -[NSData mainOperation:key:initVector:] @ 0xbeaf8
- (NSData *)mainOperation:(CCOperation)op key:(NSString *)key initVector:(NSString *)iv;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
