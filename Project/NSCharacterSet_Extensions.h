//
//  NSCharacterSet_Extensions.h
//  pop'n rhythmin
//
//  TouchJSON category on Foundation's NSCharacterSet. Provides the set of
//  Unicode line-break characters used by the comment/line scanners
//  (LF, FF, CR, NEL, LINE SEPARATOR, PARAGRAPH SEPARATOR).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import <Foundation/Foundation.h>

@interface NSCharacterSet (Extensions)

+ (NSCharacterSet *)linebreaksCharacterSet;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
