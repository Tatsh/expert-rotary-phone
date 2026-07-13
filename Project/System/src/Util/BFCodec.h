//
//  BFCodec.h
//  pop'n rhythmin
//
//  Blowfish (CBC) codec used to protect the purchased-song lists
//  ("mulist"/"acmulist"). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//
//  Wire format (produced by -encipher:, consumed by -decipher:):
//    [ ciphertext (paddedLen bytes) ][ origLen : uint32 BE ][ paddedLen :
//    uint32 BE ]
//  where paddedLen == (origLen + 7) & ~7. The CBC IV is a fixed 8-byte
//  constant.
//

#import <Foundation/Foundation.h>

@interface BFCodec : NSObject

// Initialize the cipher key schedule from an NSData key.
// Ghidra: -[BFCodec cipherInit:] @ 0x5ad64
- (void)cipherInit:(NSData *)key;

// Initialize from a raw key buffer. Ghidra: -[BFCodec cipherInit:keyLength:] @
// 0x5ad0c
- (void)cipherInit:(const char *)key keyLength:(int)length;

// Encrypt `data` in place (CBC), appending the 8-byte length trailer.
// Returns the padded ciphertext length. Ghidra: -[BFCodec encipher:] @ 0x5adb4
- (unsigned int)encipher:(NSMutableData *)data;

// Decrypt `data` in place (CBC), validating + stripping the trailer and
// truncating to the original length. Returns NO on a malformed blob.
// Ghidra: -[BFCodec decipher:] @ 0x5af78
- (BOOL)decipher:(NSMutableData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
