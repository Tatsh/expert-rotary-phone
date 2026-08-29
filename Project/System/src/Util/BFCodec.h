/**
 * @file
 * The Blowfish (CBC) codec protecting the purchased-song lists ("mulist"/"acmulist").
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * Wire format (produced by -encipher:, consumed by -decipher:):
 * `[ ciphertext (paddedLen bytes) ][ origLen : uint32 BE ][ paddedLen : uint32 BE ]`
 * where `paddedLen == (origLen + 7) & ~7`. The CBC initialisation vector is a fixed 8-byte
 * constant.
 */

#import <Foundation/Foundation.h>

/**
 * Blowfish (CBC) codec protecting the purchased-song lists.
 */
@interface BFCodec : NSObject

/**
 * Initialise the cipher key schedule from an NSData key.
 * @param key The key material.
 * @ghidraAddress 0x5ad64
 */
- (void)cipherInit:(NSData *)key;

/**
 * Initialise the cipher key schedule from a raw key buffer.
 * @param key The key material.
 * @param length Length of @p key in bytes.
 * @ghidraAddress 0x5ad0c
 */
- (void)cipherInit:(const char *)key keyLength:(int)length;

/**
 * Encrypt @p data in place (CBC), appending the 8-byte length trailer.
 * @param data The plaintext, replaced by the ciphertext plus trailer.
 * @return The padded ciphertext length in bytes.
 * @ghidraAddress 0x5adb4
 */
- (unsigned int)encipher:(NSMutableData *)data;

/**
 * Decrypt @p data in place (CBC), validating and stripping the trailer and truncating to
 * the original length.
 * @param data The ciphertext, replaced by the plaintext.
 * @return NO on a malformed blob, YES otherwise.
 * @ghidraAddress 0x5af78
 */
- (BOOL)decipher:(NSMutableData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
