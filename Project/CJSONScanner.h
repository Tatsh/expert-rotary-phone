/**
 * @file
 * The TouchJSON recursive-descent JSON parser.
 *
 * It is a subclass of CDataScanner (the raw byte-cursor scanner over an NSData) and adds the JSON
 * grammar: objects, dictionaries, arrays, string constants (with escape handling), and number
 * constants.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON;
 * scanJSONObject:error: @ 0x678d0, setData: @ 0x677cc).
 *
 * The superclass is determined from Ghidra: the init, dealloc, and setData: chain reaches
 * CDataScanner, and scanNotQuoteCharactersIntoString: reads CDataScanner's `current` and `end`
 * byte-cursor ivars directly. CDataScanner (see CDataScanner.h) supplies scannerWithData:,
 * skipWhitespace, currentCharacter, scanCharacter, scanCharacter:, scanLocation,
 * setScanLocation:, scanNumber:, scanUTF8String:intoString:, and the protected `current` and
 * `end` ivars used below.
 */

#import <Foundation/Foundation.h>

#import "CDataScanner.h"

/**
 * The recursive-descent JSON parser: a CDataScanner that adds the JSON grammar.
 */
@interface CJSONScanner : CDataScanner {
    /** Whether an unrecognised backslash escape is rejected rather than passed through. */
    BOOL strictEscapeCodes;
}

/**
 * Scan any JSON value.
 * @param outObject Receives the parsed value.
 * @param outError Receives the parse error; may be NULL.
 * @return YES on success.
 * @ghidraAddress 0x678d0
 */
- (BOOL)scanJSONObject:(id *)outObject error:(NSError **)outError;
/**
 * Scan a JSON object.
 * @param outDictionary Receives the parsed dictionary.
 * @param outError Receives the parse error; may be NULL.
 * @return YES on success.
 */
- (BOOL)scanJSONDictionary:(NSDictionary **)outDictionary error:(NSError **)outError;
/**
 * Scan a JSON array.
 * @param outArray Receives the parsed array.
 * @param outError Receives the parse error; may be NULL.
 * @return YES on success.
 */
- (BOOL)scanJSONArray:(NSArray **)outArray error:(NSError **)outError;
/**
 * Scan a quoted JSON string, resolving its escapes.
 * @param outStringConstant Receives the parsed string.
 * @param outError Receives the parse error; may be NULL.
 * @return YES on success.
 */
- (BOOL)scanJSONStringConstant:(NSString **)outStringConstant error:(NSError **)outError;
/**
 * Scan a JSON number.
 * @param outNumber Receives the parsed number.
 * @param outError Receives the parse error; may be NULL.
 * @return YES on success.
 */
- (BOOL)scanJSONNumberConstant:(NSNumber **)outNumber error:(NSError **)outError;
/**
 * Consume the run of characters up to the next double quote, reading the inherited
 * `current` and `end` cursors directly.
 * @param outString Receives the consumed run; may be NULL.
 * @return YES when at least one character was consumed.
 */
- (BOOL)scanNotQuoteCharactersIntoString:(NSString **)outString;
/**
 * Whether unrecognised backslash escapes are rejected.
 * @return YES in strict mode.
 */
- (BOOL)strictEscapeCodes;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
