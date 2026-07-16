//
//  NSScanner_Extensions.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//
//  Every method here operates on the receiving NSScanner through its public
//  cursor API only: -string returns the backing NSString, -scanLocation /
//  -setScanLocation: move the cursor, and -characterAtIndex: reads a unichar.
//

#import "NSScanner_Extensions.h"

#import "NSCharacterSet_Extensions.h"

@implementation NSScanner (Extensions)

// @ 0x6682c
// @complete
- (NSString *)remainingString {
    return [[self string] substringFromIndex:[self scanLocation]];
}

// @ 0x66870
// @complete
- (unichar)currentCharacter {
    return [[self string] characterAtIndex:[self scanLocation]];
}

// @ 0x668b4
// @complete
- (unichar)scanCharacter {
    NSUInteger theScanLocation = [self scanLocation];
    unichar theCharacter = [[self string] characterAtIndex:theScanLocation];
    [self setScanLocation:theScanLocation + 1];
    return theCharacter;
}

// @ 0x6690c
// @complete
- (BOOL)scanCharacter:(unichar)inCharacter {
    NSUInteger theScanLocation = [self scanLocation];
    if ([[self string] characterAtIndex:theScanLocation] == inCharacter) {
        [self setScanLocation:theScanLocation + 1];
        return YES;
    }
    return NO;
}

// @ 0x6696c
// @complete
- (void)backtrack:(NSUInteger)inCount {
    NSUInteger theScanLocation = [self scanLocation];
    if (theScanLocation < inCount) {
        [NSException raise:NSGenericException format:@"Backtracked too far."];
    }
    [self setScanLocation:theScanLocation - inCount];
}

// @ 0x669dc
// @complete
- (BOOL)scanCStyleComment:(NSString **)outComment {
    if ([self scanString:@"/*" intoString:NULL] != YES) {
        return NO;
    }
    NSString *theComment = nil;
    if ([self scanUpToString:@"*/" intoString:&theComment] == NO) {
        [NSException raise:NSGenericException
                    format:@"Started to scan a C style comment but it wasn't terminated."];
    }
    NSRange theRange;
    if (theComment == nil) {
        theRange = NSMakeRange(0, 0);
    } else {
        theRange = [theComment rangeOfString:@"/*"];
        if (theRange.location == NSNotFound) {
            goto scanEnd;
        }
    }
    [NSException raise:NSGenericException format:@"C style comments should not be nested."];
scanEnd:
    if ([self scanString:@"*/" intoString:NULL] == NO) {
        [NSException raise:NSGenericException format:@"C style comment did not end correctly."];
    }
    if (outComment != NULL) {
        *outComment = theComment;
    }
    return YES;
}

// @ 0x66b3c
// @complete
- (BOOL)scanCPlusPlusStyleComment:(NSString **)outComment {
    if ([self scanString:@"//" intoString:NULL] == YES) {
        NSString *theComment = nil;
        [self scanUpToCharactersFromSet:[NSCharacterSet linebreaksCharacterSet]
                             intoString:&theComment];
        [self scanCharactersFromSet:[NSCharacterSet linebreaksCharacterSet] intoString:NULL];
        if (outComment != NULL) {
            *outComment = theComment;
        }
        return YES;
    }
    return NO;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
