//
//  NSData+Crypt.h
//  pop'n rhythmin
//
//  AES-128-CBC helpers used to protect the user's save data.
//
//  NOTE ON FIDELITY: in the shipping binary the method bodies of
//  -encryptWith128Key:initVector: / -decryptWith128Key:initVector: resolve only
//  to import thunks (Ghidra: NSData::encryptWith128Key_initVector_ @ 0x1a0506,
//  NSKeyedArchiver variant @ 0x1a1202) — the disassembly is not recoverable.
//  The behavior is reconstructed from the observable contract: a 16-byte key
//  ("4ZMw025eJIOTx26f") and 16-byte IV ("13U4RnAI73EdVMXB") passed as NSStrings,
//  i.e. AES-128-CBC. PKCS#7 padding is assumed (the CommonCrypto default for
//  this idiom). If a decrypted save fails to parse, revisit the padding/no-pad
//  choice here.
//

#import <Foundation/Foundation.h>

@interface NSData (Crypt)

// Encrypt the receiver with AES-128-CBC. `key` and `iv` are 16-char NSStrings.
- (NSData *)encryptWith128Key:(NSString *)key initVector:(NSString *)iv;

// Decrypt an AES-128-CBC blob produced by the method above.
- (NSData *)decryptWith128Key:(NSString *)key initVector:(NSString *)iv;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
