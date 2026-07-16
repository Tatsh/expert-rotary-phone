//
//  NSCharacterSet_Extensions.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//
//  The six code points decoded from the binary's UTF-16 literal at 0x12f748:
//    0x000A LF, 0x000C FF, 0x000D CR, 0x0085 NEL,
//    0x2028 LINE SEPARATOR, 0x2029 PARAGRAPH SEPARATOR.
//

#import "NSCharacterSet_Extensions.h"

@implementation NSCharacterSet (Extensions)

// @ 0x65404
// @complete
+ (NSCharacterSet *)linebreaksCharacterSet {
    static const unichar theCharacters[] = {0x000A, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029};
    return [NSCharacterSet
        characterSetWithCharactersInString:[NSString stringWithCharacters:theCharacters length:6]];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
