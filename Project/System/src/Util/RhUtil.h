//
//  RhUtil.h
//  pop'n rhythmin
//
//  Small shared helpers used across the app. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// These are C-linkage helpers defined in RhUtil.m; the extern "C" guard lets the
// C++ (.mm/.cpp) callers resolve the unmangled symbols the .m file emits.
#ifdef __cplusplus
extern "C" {
#endif

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

// Wall-clock time in milliseconds (gettimeofday: tv_sec*1000 + tv_usec/1000).
// The original 32-bit binary returned a 32-bit long; kept as long here.
// Ghidra: getTimeMillis @ 0x2dae0.
long getTimeMillis(void);

// Byte length (1..6) of the UTF-8 sequence whose lead byte is s[0]; 0 for a
// stray continuation byte, -1 for an invalid 0xFE/0xFF lead. Only the lead byte
// is inspected. Ghidra: utf8CharLen @ 0x17a84 (neTextTexture text layout).
int utf8CharLen(const char *s);

// YES if point (x,y) lies within (inclusive) radius r of centre (cx,cy).
// Pure integer squared-distance test. Ghidra: pointInCircle @ 0x2d9bc.
BOOL pointInCircle(int x, int y, int cx, int cy, int r);

// Load a bundled PNG named `name`, honouring the device idiom / screen scale.
// iPad: plain "name.png". iPhone: tries "name@2x"/"name~..." scaled variants and
// rebuilds a scale-2 UIImage via CGImage when the retina asset is used.
// Returns an autoreleased UIImage, or nil when no matching resource exists.
// Ghidra: loadDeviceImage @ 0x5bd28.
UIImage *loadDeviceImage(NSString *name);

#ifdef __cplusplus
}
#endif

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
