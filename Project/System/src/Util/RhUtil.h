/**
 * @file
 * Small shared helpers used across the app.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// These are C-linkage helpers defined in RhUtil.m; the extern "C" guard lets
// the C++ (.mm/.cpp) callers resolve the unmangled symbols the .m file emits.
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Parse a property-list blob and return its root dictionary.
 *
 * The decoded .orb and list payloads are plists, not JSON. The original branched on iOS below 4.0
 * (CFPropertyListCreateFromXMLData) versus newer (CFPropertyListCreateWithData); it is modernised
 * here to NSPropertyListSerialization.
 *
 * @param data The plist blob.
 * @return The root, or nil when it is not a dictionary.
 * @ghidraAddress 0x5c258
 */
NSDictionary *RhParsePlistDict(NSData *data);
/**
 * Parse a property-list blob and return its root array.
 * @param data The plist blob.
 * @return The root, or nil when it is not an array.
 * @ghidraAddress 0x5c330
 */
NSMutableArray *RhParsePlistArray(NSData *data);

/**
 * Report whether a regular file, not a directory, exists at a path.
 * @param path The path to test.
 * @return YES when a regular file exists there.
 * @ghidraAddress 0x5c434
 */
BOOL RhFileExists(NSString *path);

/**
 * The byte size of the file at a path.
 *
 * It gates on RhFileExists, then reads the NSFileSize attribute.
 *
 * @param path The path to measure.
 * @return The size in bytes, or -1 when no such file exists.
 * @ghidraAddress 0x5c48c
 */
int getFileSize(NSString *path);

/**
 * Test one bit of an NSArray of NSNumber treated as a packed bitfield of 32 bits per
 * element.
 *
 * Element `bit / 32`'s intValue is tested against `1 << (bit & 31)`. Out-of-range indices read as
 * 0.
 *
 * @param numberArray The packed bitfield.
 * @param bit The bit index to test.
 * @return YES when the bit is set.
 * @ghidraAddress 0x28aa4
 */
BOOL RhTestBitInNumberArray(NSArray *numberArray, unsigned bit);

/**
 * The MD5 of a C string as a 16-byte NSData.
 *
 * It is used as the Blowfish key, which is MD5(uuId).
 *
 * @param cString The string to hash.
 * @return The 16-byte digest.
 * @ghidraAddress 0x5b4b8
 */
NSData *RhMD5Data(const char *cString);

/**
 * The lowercase hex MD5 digest of a C string.
 * @param cString The string to hash.
 * @return The digest as a hex string.
 * @ghidraAddress 0x5b534
 */
NSString *ComputeMD5HexString(const char *cString);
/**
 * The lowercase hex SHA-256 digest of a C string.
 * @param cString The string to hash.
 * @return The digest as a hex string.
 * @ghidraAddress 0x5bc04
 */
NSString *ComputeSHA256HexString(const char *cString);

/**
 * The wall-clock time in milliseconds, from gettimeofday as tv_sec * 1000 + tv_usec / 1000.
 *
 * The original 32-bit binary returned a 32-bit long; it is kept as a long here.
 *
 * @return The time in milliseconds.
 * @ghidraAddress 0x2dae0
 */
long getTimeMillis(void);

/**
 * The byte length of the UTF-8 sequence whose lead byte is s[0].
 *
 * Only the lead byte is inspected. Used by the neTextTexture text layout.
 *
 * @param s The string whose first byte is the lead byte.
 * @return 1 to 6 for a valid lead byte, 0 for a stray continuation byte, and -1 for an invalid
 * 0xFE or 0xFF lead.
 * @ghidraAddress 0x17a84
 */
int utf8CharLen(const char *s);

/**
 * Report whether a point lies within a circle, inclusive of the boundary.
 *
 * It is a pure integer squared-distance test.
 *
 * @param x The point's x.
 * @param y The point's y.
 * @param cx The centre's x.
 * @param cy The centre's y.
 * @param r The radius.
 * @return YES when the point is inside.
 * @ghidraAddress 0x2d9bc
 */
BOOL pointInCircle(int x, int y, int cx, int cy, int r);

/**
 * Load a bundled PNG, honouring the device idiom and screen scale.
 *
 * On iPad it loads a plain "name.png". On iPhone it tries the "name@2x" and "name~..." scaled
 * variants and rebuilds a scale-2 UIImage via CGImage when the retina asset is used.
 *
 * @param name The bare resource name.
 * @return An autoreleased UIImage, or nil when no matching resource exists.
 * @ghidraAddress 0x5bd28
 */
UIImage *loadDeviceImage(NSString *name);

#ifdef __cplusplus
}
#endif

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
