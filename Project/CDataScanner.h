/**
 * @file
 * The TouchJSON raw byte-cursor scanner over an NSData.
 *
 * It walks a UTF-8 byte buffer with three `const char *` cursors (start, end, current) and
 * provides the low-level scanning primitives: scan a literal string, scan characters from a set,
 * scan up to a string or set, scan a number, skip whitespace, and scan C or C++ style comments.
 * CJSONScanner is a subclass that layers the JSON grammar on top and reads the @protected
 * `current` and `end` cursors directly.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
 *
 * The superclass is determined from Ghidra: the init and dealloc chain reaches NSObject (class_ro
 * superclass = NSObject), and init and dealloc call NSObject::init and NSObject::dealloc.
 *
 * The ivars are decoded from Ghidra (setData: @ 0x648a0): `data` is the retained backing NSData,
 * `start` is data.bytes (the buffer origin), `end` is start + data.length (one past the last
 * byte), `current` is the moving byte cursor, `length` is data.length, and `doubleCharacters` is
 * the set of characters valid in a number. Note that start, end, and current are byte POINTERS
 * into data.bytes, not char values.
 */

#import <Foundation/Foundation.h>

/**
 * A raw byte-cursor scanner over an NSData, supplying TouchJSON's low-level scanning
 * primitives.
 */
@interface CDataScanner : NSObject {
@protected
    NSData *data;                     /**< The retained backing data. */
    const char *start;                /**< data.bytes: the buffer origin. */
    const char *end;                  /**< start + data.length: one past the last byte. */
    const char *current;              /**< The moving byte cursor. */
    unsigned length;                  /**< data.length. */
    NSCharacterSet *doubleCharacters; /**< The characters that may appear in a number. */
}

/**
 * An autoreleased scanner over @p inData.
 * @param inData The buffer to scan.
 * @return The new scanner.
 */
+ (id)scannerWithData:(NSData *)inData;

/**
 * The backing data.
 * @return The buffer being scanned.
 */
- (NSData *)data;
/**
 * Replace the backing data and reset the cursor to its start.
 * @param inData The new buffer to scan.
 */
- (void)setData:(NSData *)inData;

/**
 * The characters that may appear in a number.
 * @return The character set.
 */
- (NSCharacterSet *)doubleCharacters;
/**
 * Set the characters that may appear in a number.
 * @param inDoubleCharacters The character set.
 */
- (void)setDoubleCharacters:(NSCharacterSet *)inDoubleCharacters;

/**
 * The cursor's byte offset from the start of the buffer.
 * @return The offset.
 */
- (NSUInteger)scanLocation;
/**
 * Move the cursor to a byte offset from the start of the buffer.
 * @param inScanLocation The offset to seek to.
 */
- (void)setScanLocation:(NSUInteger)inScanLocation;
/**
 * Whether the cursor has reached the end of the buffer.
 * @return YES at the end.
 */
- (BOOL)isAtEnd;

/**
 * The character under the cursor, without advancing it.
 * @return The character, or 0 at the end of the buffer.
 */
- (unichar)currentCharacter;
/**
 * Consume and return the character under the cursor.
 * @return The character, or 0 at the end of the buffer.
 */
- (unichar)scanCharacter;
/**
 * Consume the character under the cursor if it matches.
 * @param inCharacter The character to match.
 * @return YES when the character matched and was consumed.
 */
- (BOOL)scanCharacter:(unichar)inCharacter;

/**
 * Consume a literal UTF-8 string if the cursor is on it.
 * @param inString The nul-terminated literal to match.
 * @param outString Receives the matched text; may be NULL.
 * @return YES when the literal matched and was consumed.
 */
- (BOOL)scanUTF8String:(const char *)inString intoString:(NSString **)outString;
/**
 * Consume a literal string if the cursor is on it.
 * @param inString The literal to match.
 * @param outString Receives the matched text; may be NULL.
 * @return YES when the literal matched and was consumed.
 */
- (BOOL)scanString:(NSString *)inString intoString:(NSString **)outString;
/**
 * Consume the run of characters that belong to a set.
 * @param inSet The characters to accept.
 * @param outString Receives the consumed run; may be NULL.
 * @return YES when at least one character was consumed.
 */
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString;
/**
 * Consume everything up to, but not including, a literal string.
 * @param inString The literal to stop before.
 * @param outString Receives the consumed text; may be NULL.
 * @return YES when the literal was found.
 */
- (BOOL)scanUpToString:(NSString *)inString intoString:(NSString **)outString;
/**
 * Consume everything up to, but not including, the first character in a set.
 * @param inSet The characters to stop before.
 * @param outString Receives the consumed text; may be NULL.
 * @return YES when such a character was found.
 */
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString;
/**
 * Consume a number.
 * @param outNumber Receives the parsed number; may be NULL.
 * @return YES when a number was consumed.
 */
- (BOOL)scanNumber:(NSNumber **)outNumber;

/**
 * Advance the cursor past any whitespace.
 */
- (void)skipWhitespace;
/**
 * The buffer from the cursor to the end, as a string.
 * @return The remaining text.
 */
- (NSString *)remainingString;

/**
 * Consume a C-style block comment.
 * @param outComment Receives the comment text; may be NULL.
 * @return YES when a comment was consumed.
 */
- (BOOL)scanCStyleComment:(NSString **)outComment;
/**
 * Consume a C++-style line comment.
 * @param outComment Receives the comment text; may be NULL.
 * @return YES when a comment was consumed.
 */
- (BOOL)scanCPlusPlusStyleComment:(NSString **)outComment;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
