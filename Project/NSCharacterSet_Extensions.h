/**
 * @file
 * @brief The TouchJSON category on Foundation's NSCharacterSet.
 *
 * It provides the set of Unicode line-break characters the comment and line scanners use: LF, FF,
 * CR, NEL, LINE SEPARATOR, and PARAGRAPH SEPARATOR.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
 */

#import <Foundation/Foundation.h>

/**
 * @brief TouchJSON's extra character sets.
 */
@interface NSCharacterSet (Extensions)

/**
 * @brief The set of line-break characters.
 * @return The character set.
 */
+ (NSCharacterSet *)linebreaksCharacterSet;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
