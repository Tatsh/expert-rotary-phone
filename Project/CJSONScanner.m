//
//  CJSONScanner.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CJSONScanner.h"

NSString *const kJSONScannerErrorDomain = @"CJSONScannerErrorDomain";

// Map an ASCII hex digit to its value, or -1 if it is not a hex digit.
// (Mirrors the DAT_0012f6b0 lookup table used by the original \u decoder.)
static int HexToInt(unichar inCharacter) {
    if (inCharacter >= '0' && inCharacter <= '9') {
        return inCharacter - '0';
    }
    if (inCharacter >= 'a' && inCharacter <= 'f') {
        return inCharacter - 'a' + 10;
    }
    if (inCharacter >= 'A' && inCharacter <= 'F') {
        return inCharacter - 'A' + 10;
    }
    return -1;
}

@implementation CJSONScanner

// @ 0x67760
- (id)init {
    if ((self = [super init]) != nil) {
        strictEscapeCodes = NO;
    }
    return self;
}

// dealloc @ 0x677a0 — ARC-omitted (chains to super only; no owned ivars).

// @ 0x677cc
- (void)setData:(NSData *)inData {
    if (inData != NULL && [inData length] >= 4) {
        const char *theBytes = (const char *)[inData bytes];
        NSStringEncoding theEncoding = NSUTF8StringEncoding;
        BOOL theBOMFound = YES;
        if (theBytes[0] == 0) {
            if (theBytes[2] != 0 || theBytes[3] == 0) {
                theBOMFound = NO;
            } else if (theBytes[1] == 0) {
                theEncoding = NSUTF32BigEndianStringEncoding;
            } else {
                theEncoding = NSUTF16BigEndianStringEncoding;
            }
        } else {
            if (theBytes[1] != 0 || theBytes[3] != 0) {
                theBOMFound = NO;
            } else if (theBytes[2] == 0) {
                theEncoding = NSUTF32LittleEndianStringEncoding;
            } else {
                theEncoding = NSUTF16LittleEndianStringEncoding;
            }
        }
        if (theBOMFound) {
            NSString *theString = [[NSString alloc] initWithData:inData encoding:theEncoding];
            inData = [theString dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    [super setData:inData];
}

// @ 0x678d0
- (BOOL)scanJSONObject:(id *)outObject error:(NSError **)outError {
    [self skipWhitespace];
    id theObject = NULL;
    BOOL theResult = YES;
    unichar C = [self currentCharacter];
    switch (C) {
    case '{':
        theResult = [self scanJSONDictionary:(NSDictionary **)&theObject error:outError];
        break;
    case '[':
        theResult = [self scanJSONArray:(NSArray **)&theObject error:outError];
        break;
    case '"':
    case '\'':
        theResult = [self scanJSONStringConstant:(NSString **)&theObject error:outError];
        break;
    case '-':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
        theResult = [self scanJSONNumberConstant:(NSNumber **)&theObject error:outError];
        break;
    case 't':
        if ([self scanUTF8String:"true" intoString:NULL]) {
            theObject = [NSNumber numberWithBool:YES];
        }
        break;
    case 'f':
        if ([self scanUTF8String:"false" intoString:NULL]) {
            theObject = [NSNumber numberWithBool:NO];
        }
        break;
    case 'n':
        if ([self scanUTF8String:"null" intoString:NULL]) {
            theObject = [NSNull null];
        }
        break;
    default:
        break;
    }
    if (outObject != NULL) {
        *outObject = theObject;
    }
    return theResult;
}

// @ 0x67a74
- (BOOL)scanJSONDictionary:(NSDictionary **)outDictionary error:(NSError **)outError {
    NSUInteger theScanLocation = [self scanLocation];
    if ([self scanCharacter:'{'] == NO) {
        if (outError != NULL) {
            NSDictionary *theUserInfo = [NSDictionary
                dictionaryWithObjectsAndKeys:@"Could not scan dictionary. Dictionary that does "
                                             @"not start with '{' character.",
                                             NSLocalizedDescriptionKey,
                                             NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-1
                                        userInfo:theUserInfo];
        }
        return NO;
    }
    NSMutableDictionary *theDictionary = [[NSMutableDictionary alloc] init];
    while (1) {
        if ([self currentCharacter] == '}') {
            break;
        }
        [self skipWhitespace];
        if ([self currentCharacter] == '}') {
            break;
        }
        id theKey = NULL;
        if ([self scanJSONStringConstant:(NSString **)&theKey error:outError] == NO) {
            [self setScanLocation:theScanLocation];
            if (outError != NULL) {
                NSDictionary *theUserInfo =
                    [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Could not scan dictionary. Failed to scan a key.",
                                      NSLocalizedDescriptionKey,
                                      NULL];
                *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                code:-2
                                            userInfo:theUserInfo];
            }
            return NO;
        }
        [self skipWhitespace];
        if ([self scanCharacter:':'] == NO) {
            [self setScanLocation:theScanLocation];
            if (outError != NULL) {
                NSDictionary *theUserInfo = [NSDictionary
                    dictionaryWithObjectsAndKeys:@"Could not scan dictionary. Key was not "
                                                 @"terminated with a ':' character.",
                                                 NSLocalizedDescriptionKey,
                                                 NULL];
                *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                code:-3
                                            userInfo:theUserInfo];
            }
            return NO;
        }
        id theValue = NULL;
        if ([self scanJSONObject:&theValue error:outError] == NO) {
            [self setScanLocation:theScanLocation];
            if (outError != NULL) {
                NSDictionary *theUserInfo =
                    [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Could not scan dictionary. Failed to scan a value.",
                                      NSLocalizedDescriptionKey,
                                      NULL];
                *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                code:-4
                                            userInfo:theUserInfo];
            }
            return NO;
        }
        [theDictionary setValue:theValue forKey:theKey];
        [self skipWhitespace];
        if ([self scanCharacter:','] == NO) {
            if ([self currentCharacter] != '}') {
                [self setScanLocation:theScanLocation];
                if (outError != NULL) {
                    NSDictionary *theUserInfo = [NSDictionary
                        dictionaryWithObjectsAndKeys:@"Could not scan dictionary. Key value pairs "
                                                     @"not delimited with a ',' character.",
                                                     NSLocalizedDescriptionKey,
                                                     NULL];
                    *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                    code:-5
                                                userInfo:theUserInfo];
                }
                return NO;
            }
            break;
        }
        [self skipWhitespace];
        if ([self currentCharacter] == '}') {
            break;
        }
    }
    if ([self scanCharacter:'}'] == NO) {
        [self setScanLocation:theScanLocation];
        if (outError != NULL) {
            NSDictionary *theUserInfo =
                [NSDictionary dictionaryWithObjectsAndKeys:@"Could not scan dictionary. Dictionary "
                                                           @"not terminated by a '}' character.",
                                                           NSLocalizedDescriptionKey,
                                                           NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-6
                                        userInfo:theUserInfo];
        }
        return NO;
    }
    if (outDictionary != NULL) {
        *outDictionary = [theDictionary copy];
    }
    return YES;
}

// @ 0x67f48
- (BOOL)scanJSONArray:(NSArray **)outArray error:(NSError **)outError {
    NSUInteger theScanLocation = [self scanLocation];
    if ([self scanCharacter:'['] == NO) {
        if (outError != NULL) {
            NSDictionary *theUserInfo =
                [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Could not scan array. Array not started by a '[' character.",
                                  NSLocalizedDescriptionKey,
                                  NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-7
                                        userInfo:theUserInfo];
        }
        return NO;
    }
    NSMutableArray *theArray = [[NSMutableArray alloc] init];
    [self skipWhitespace];
    BOOL theCommaFound;
    do {
        if ([self currentCharacter] == ']') {
            goto finish;
        }
        id theValue = NULL;
        if ([self scanJSONObject:&theValue error:outError] == NO) {
            [self setScanLocation:theScanLocation];
            if (outError != NULL) {
                NSDictionary *theUserInfo = [NSDictionary
                    dictionaryWithObjectsAndKeys:@"Could not scan array. Could not scan a value.",
                                                 NSLocalizedDescriptionKey,
                                                 NULL];
                *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                code:-8
                                            userInfo:theUserInfo];
            }
            return NO;
        }
        [theArray addObject:theValue];
        [self skipWhitespace];
        theCommaFound = [self scanCharacter:','];
        [self skipWhitespace];
    } while (theCommaFound);
    if ([self currentCharacter] != ']') {
        [self setScanLocation:theScanLocation];
        if (outError != NULL) {
            NSDictionary *theUserInfo =
                [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Could not scan array. Array not terminated by a ']' character.",
                                  NSLocalizedDescriptionKey,
                                  NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-9
                                        userInfo:theUserInfo];
        }
        return NO;
    }
finish:
    [self skipWhitespace];
    if ([self scanCharacter:']'] == NO) {
        [self setScanLocation:theScanLocation];
        if (outError != NULL) {
            NSDictionary *theUserInfo =
                [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Could not scan array. Array not terminated by a ']' character.",
                                  NSLocalizedDescriptionKey,
                                  NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-10
                                        userInfo:theUserInfo];
        }
        return NO;
    }
    if (outArray != NULL) {
        *outArray = [theArray copy];
    }
    return YES;
}

// @ 0x682c8
- (BOOL)scanJSONStringConstant:(NSString **)outStringConstant error:(NSError **)outError {
    NSUInteger theScanLocation = [self scanLocation];
    [self skipWhitespace];
    NSMutableString *theString = [[NSMutableString alloc] init];
    if ([self scanCharacter:'"'] == NO) {
        [self setScanLocation:theScanLocation];
        if (outError != NULL) {
            NSDictionary *theUserInfo = [NSDictionary
                dictionaryWithObjectsAndKeys:@"Could not scan string constant. String not "
                                             @"started by a '\"' character.",
                                             NSLocalizedDescriptionKey,
                                             NULL];
            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                            code:-11
                                        userInfo:theUserInfo];
        }
        return NO;
    }
    if ([self scanCharacter:'"'] == NO) {
        while (1) {
            NSString *theScannedString = NULL;
            if ([self scanNotQuoteCharactersIntoString:&theScannedString]) {
                [theString appendString:theScannedString];
            }
            if ([self scanCharacter:'\\'] == YES) {
                unichar theCharacter = [self scanCharacter];
                switch (theCharacter) {
                case '"':
                case '/':
                case '\\':
                    break;
                case 'b':
                    theCharacter = '\b';
                    break;
                case 'f':
                    theCharacter = '\f';
                    break;
                case 'n':
                    theCharacter = '\n';
                    break;
                case 'r':
                    theCharacter = '\r';
                    break;
                case 't':
                    theCharacter = '\t';
                    break;
                case 'u': {
                    theCharacter = 0;
                    for (int theShift = 12; theShift >= 0; theShift -= 4) {
                        int theNibble = HexToInt([self scanCharacter]);
                        if (theNibble < 0) {
                            [self setScanLocation:theScanLocation];
                            if (outError != NULL) {
                                NSDictionary *theUserInfo = [NSDictionary
                                    dictionaryWithObjectsAndKeys:
                                        @"Could not scan string constant. Unicode character "
                                        @"could not be decoded.",
                                        NSLocalizedDescriptionKey,
                                        NULL];
                                *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                                code:-12
                                                            userInfo:theUserInfo];
                            }
                            return NO;
                        }
                        theCharacter |= (unichar)(theNibble << theShift);
                    }
                    break;
                }
                default:
                    if (strictEscapeCodes) {
                        [self setScanLocation:theScanLocation];
                        if (outError != NULL) {
                            NSDictionary *theUserInfo = [NSDictionary
                                dictionaryWithObjectsAndKeys:
                                    @"Could not scan string constant. Unknown escape code.",
                                    NSLocalizedDescriptionKey,
                                    NULL];
                            *outError = [NSError errorWithDomain:kJSONScannerErrorDomain
                                                            code:-13
                                                        userInfo:theUserInfo];
                        }
                        return NO;
                    }
                    break;
                }
                CFStringAppendCharacters((CFMutableStringRef)theString, &theCharacter, 1);
            }
            if ([self scanCharacter:'"'] == YES) {
                break;
            }
        }
    }
    if (outStringConstant != NULL) {
        *outStringConstant = [theString copy];
    }
    return YES;
}

// @ 0x68690
- (BOOL)scanJSONNumberConstant:(NSNumber **)outNumber error:(NSError **)outError {
    NSNumber *theNumber = NULL;
    if ([self scanNumber:&theNumber]) {
        if (outNumber != NULL) {
            *outNumber = theNumber;
        }
        return YES;
    }
    if (outError != NULL) {
        NSDictionary *theUserInfo =
            [NSDictionary dictionaryWithObjectsAndKeys:@"Could not scan number constant.",
                                                       NSLocalizedDescriptionKey,
                                                       NULL];
        *outError = [NSError errorWithDomain:kJSONScannerErrorDomain code:-14 userInfo:theUserInfo];
    }
    return NO;
}

// @ 0x68734
- (BOOL)scanNotQuoteCharactersIntoString:(NSString **)outString {
    // `current` and `end` are @protected byte-cursor ivars inherited from
    // CDataScanner.
    const char *P;
    for (P = current; P < end && *P != '"' && *P != '\\'; ++P) {
        ;
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

// @ 0x687e0
- (BOOL)strictEscapeCodes {
    return strictEscapeCodes;
}

@end
