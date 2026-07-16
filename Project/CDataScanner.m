//
//  CDataScanner.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CDataScanner.h"

#import "NSCharacterSet_Extensions.h"

#import <ctype.h>
#import <string.h>

@implementation CDataScanner

// @ 0x6475c
// @complete
+ (id)scannerWithData:(NSData *)inData {
    CDataScanner *theScanner = [[self alloc] init];
    [theScanner setData:inData];
    return theScanner;
}

// @ 0x647ac
// @complete
- (id)init {
    if ((self = [super init]) != nil) {
        [self setDoubleCharacters:[NSCharacterSet
                                      characterSetWithCharactersInString:@"0123456789eE-."]];
    }
    return self;
}

// dealloc @ 0x64818 — ARC-omitted (object-only: setData:nil /
// setDoubleCharacters:nil then chains to super; ARC releases the owned ivars
// automatically).

// @ 0x64870
// @complete
- (NSUInteger)scanLocation {
    return (NSUInteger)(current - start);
}

// @ 0x64890
// @complete
- (NSData *)data {
    return data;
}

// @ 0x648a0
// @complete
- (void)setData:(NSData *)inData {
    if (data != inData) {
        data = inData;
        if (inData != nil) {
            start = (const char *)[data bytes];
            end = start + [data length];
            current = start;
            length = (unsigned)[data length];
        }
    }
}

// @ 0x6496c
// @complete
- (void)setScanLocation:(NSUInteger)inScanLocation {
    current = start + inScanLocation;
}

// @ 0x6498c
// @complete
- (BOOL)isAtEnd {
    return [self scanLocation] >= length;
}

// @ 0x649c0
// @complete
- (unichar)currentCharacter {
    return (unichar)(unsigned char)*current;
}

// @ 0x649d4
// @complete
- (unichar)scanCharacter {
    unichar theCharacter = (unichar)(unsigned char)*current;
    current += 1;
    return theCharacter;
}

// @ 0x649ec
// @complete
- (BOOL)scanCharacter:(unichar)inCharacter {
    if ((unsigned char)*current == inCharacter) {
        current += 1;
        return YES;
    }
    return NO;
}

// @ 0x64a14
// @complete
- (BOOL)scanUTF8String:(const char *)inString intoString:(NSString **)outString {
    size_t theLength = strlen(inString);
    if ((unsigned)(end - current) < theLength || strncmp(current, inString, theLength) != 0) {
        return NO;
    }
    current += theLength;
    if (outString != NULL) {
        *outString = [NSString stringWithUTF8String:inString];
    }
    return YES;
}

// @ 0x64a98
// @complete
- (BOOL)scanString:(NSString *)inString intoString:(NSString **)outString {
    if ([inString length] <= (unsigned)(end - current) &&
        strncmp(current, [inString UTF8String], [inString length]) == 0) {
        current += [inString length];
        if (outString != NULL) {
            *outString = inString;
        }
        return YES;
    }
    return NO;
}

// @ 0x64b40
// @complete
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString {
    const char *P = current;
    while (P < end && [inSet characterIsMember:(unichar)(unsigned char)*P]) {
        P += 1;
    }
    if (P == current) {
        return NO;
    }
    if (outString != NULL) {
        *outString = [[NSString alloc] initWithBytes:current
                                              length:(P - current)
                                            encoding:NSUTF8StringEncoding];
    }
    current = P;
    return YES;
}

// @ 0x64c1c
// @complete
- (BOOL)scanUpToString:(NSString *)inString intoString:(NSString **)outString {
    const char *P = strnstr(current, [inString UTF8String], end - current);
    if (P == NULL) {
        return NO;
    }
    if (outString != NULL) {
        *outString = [[NSString alloc] initWithBytes:current
                                              length:(P - current)
                                            encoding:NSUTF8StringEncoding];
    }
    current = P;
    return YES;
}

// @ 0x64cc4
// @complete
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)inSet intoString:(NSString **)outString {
    const char *P = current;
    while (P < end && ![inSet characterIsMember:(unichar)(unsigned char)*P]) {
        P += 1;
    }
    if (P == current) {
        return NO;
    }
    if (outString != NULL) {
        *outString = [[NSString alloc] initWithBytes:current
                                              length:(P - current)
                                            encoding:NSUTF8StringEncoding];
    }
    current = P;
    return YES;
}

// @ 0x64da0
// @complete
- (BOOL)scanNumber:(NSNumber **)outNumber {
    NSString *theString = nil;
    if ([self scanCharactersFromSet:doubleCharacters intoString:&theString]) {
        if (outNumber != NULL) {
            *outNumber = [NSNumber numberWithDouble:[theString doubleValue]];
        }
        return YES;
    }
    return NO;
}

// @ 0x64e14
// @complete
- (void)skipWhitespace {
    const char *P = current;
    while (P < end && isspace((unsigned char)*P)) {
        P += 1;
    }
    current = P;
}

// @ 0x64e84
// @complete
- (NSString *)remainingString {
    NSData *theData = [NSData dataWithBytes:current length:(end - current)];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

// @ 0x64f0c
// @complete
- (NSCharacterSet *)doubleCharacters {
    return doubleCharacters;
}

// @ 0x64f1c
// @complete
- (void)setDoubleCharacters:(NSCharacterSet *)inDoubleCharacters {
    doubleCharacters = inDoubleCharacters;
}

// @ 0x65204
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

// @ 0x65364
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
