//
//  RhUtil.h
//  pop'n rhythmin
//
//  Small shared helpers used across the app. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

// Parse a property-list blob (the decoded .orb / list payloads are plists, not
// JSON). Returns the root only if it is a dictionary / array respectively.
// The original branched on iOS < 4.0 (CFPropertyListCreateFromXMLData) vs newer
// (CFPropertyListCreateWithData); modernized here to NSPropertyListSerialization.
NSDictionary *RhParsePlistDict(NSData *data);      // Ghidra: FUN_0005c258
NSMutableArray *RhParsePlistArray(NSData *data);   // Ghidra: FUN_0005c330

// YES if a regular file (not a directory) exists at `path`.
BOOL RhFileExists(NSString *path);                 // Ghidra: FUN_0005c434

// Byte size of the file at `path` as an int, or -1 when no such file exists
// (RhFileExists gate; then the NSFileSize attribute). Ghidra: FUN_0005c48c.
int getFileSize(NSString *path);

// Treat an NSArray of NSNumber as a packed bitfield (32 bits per element) and
// return whether bit `bit` is set: element `bit/32`'s intValue tested against
// `1 << (bit & 31)`. Out-of-range indices read as 0. Ghidra: FUN_00028aa4.
BOOL RhTestBitInNumberArray(NSArray *numberArray, unsigned bit);

// MD5 of a C string, as a 16-byte NSData (used as the Blowfish key = MD5(uuId)).
NSData *RhMD5Data(const char *cString);            // Ghidra: FUN_0005b4b8

// Lowercase hex-string digests of a C string.
NSString *ComputeMD5HexString(const char *cString);     // Ghidra: FUN_0005b534 (CC_MD5)
NSString *ComputeSHA256HexString(const char *cString);  // Ghidra: FUN_0005bc04 (CC_SHA256)

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
