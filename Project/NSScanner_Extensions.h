/**
 * @file
 * The TouchJSON category on Foundation's NSScanner.
 *
 * It adds the low-level scanning primitives the JSON tooling relies on: peek and advance a single
 * unichar, backtrack the scan location, grab the remaining substring, and scan C or C++ style
 * comments. Everything is expressed purely through NSScanner's public API (-string, -scanLocation,
 * -setScanLocation:, -characterAtIndex:, -scanString:intoString:, and so on), so it works on any
 * NSScanner without touching its internals. It is distinct from CDataScanner, which is a
 * byte-cursor scanner over an NSData that re-implements the same primitives directly.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
 */

#import <Foundation/Foundation.h>

/**
 * TouchJSON's character-level scanning helpers on NSScanner.
 */
@interface NSScanner (Extensions)

/**
 * The string from the scan location to the end.
 * @return The remaining text.
 */
- (NSString *)remainingString;

/**
 * The character at the scan location, without advancing it.
 * @return The character, or 0 at the end.
 */
- (unichar)currentCharacter;
/**
 * Consume and return the character at the scan location.
 * @return The character, or 0 at the end.
 */
- (unichar)scanCharacter;
/**
 * Consume the character at the scan location if it matches.
 * @param inCharacter The character to match.
 * @return YES when the character matched and was consumed.
 */
- (BOOL)scanCharacter:(unichar)inCharacter;

/**
 * Move the scan location back.
 * @param inCount How many characters to rewind.
 */
- (void)backtrack:(NSUInteger)inCount;

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
