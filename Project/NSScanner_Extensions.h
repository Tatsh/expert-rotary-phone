//
//  NSScanner_Extensions.h
//  pop'n rhythmin
//
//  TouchJSON category on Foundation's NSScanner adding the low-level scanning
//  primitives the JSON tooling relies on: peek/advance a single unichar,
//  backtrack the scan location, grab the remaining substring, and scan C / C++
//  style comments. Everything is expressed purely through NSScanner's public
//  API (-string, -scanLocation, -setScanLocation:, -characterAtIndex:,
//  -scanString:intoString:, ...), so it works on any NSScanner without touching
//  its internals. (Distinct from CDataScanner, which is a byte-cursor scanner
//  over an NSData and re-implements the same primitives directly.)
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import <Foundation/Foundation.h>

@interface NSScanner (Extensions)

- (NSString *)remainingString;

- (unichar)currentCharacter;
- (unichar)scanCharacter;
- (BOOL)scanCharacter:(unichar)inCharacter;

- (void)backtrack:(NSUInteger)inCount;

- (BOOL)scanCStyleComment:(NSString **)outComment;
- (BOOL)scanCPlusPlusStyleComment:(NSString **)outComment;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
