//
//  NSData+Crypt.h
//  pop'n rhythmin
//
//  AES-128-CBC helpers used to protect the user's save data.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Both public
//  wrappers are thin: they forward to the shared core
//  -mainOperation:key:initVector: with kCCEncrypt / kCCDecrypt. Key/IV are
//  16-char NSStrings copied to C via -getCString:maxLength:encoding: (key
//  "4ZMw025eJIOTx26f", IV "13U4RnAI73EdVMXB") and the cipher is AES-128-CBC
//  with PKCS#7 padding (kCCOptionPKCS7Padding).
//

#import <CommonCrypto/CommonCryptor.h>
#import <Foundation/Foundation.h>

@interface NSData (Crypt)
/**
 * @brief Encrypts the receiver using AES-128-CBC with the provided key and initialization vector.
 * @param key The 16-character key.
 * @param iv The 16-character initialization vector.
 * @return A new NSData object containing the encrypted data, or nil if encryption fails.
 */
- (NSData *)encryptWith128Key:(NSString *)key initVector:(NSString *)iv;
/**
 * @brief Decrypts the receiver using AES-128-CBC with the provided key and initialization vector.
 * @param key The 16-character key as an NSString.
 * @param iv The 16-character initialization vector as an NSString.
 * @return A new NSData object containing the decrypted data, or nil if decryption fails.
 */
- (NSData *)decryptWith128Key:(NSString *)key initVector:(NSString *)iv;
/**
 * @brief Performs AES-128-CBC encryption or decryption on the receiver.
 * @param op The operation to perform (kCCEncrypt or kCCDecrypt).
 * @param key The 16-character key as an NSString.
 * @param iv The 16-character initialization vector as an NSString.
 * @return A new NSData object containing the result of the operation, or nil if an error occurred.
    */
- (NSData *)mainOperation:(CCOperation)op key:(NSString *)key initVector:(NSString *)iv;
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
