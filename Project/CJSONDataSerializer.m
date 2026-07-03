//
//  CJSONDataSerializer.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CJSONDataSerializer.h"
#import "CSerializedJSONData.h"

// Cached constant JSON tokens (g_pJsonNullData / g_pJsonTrueData / g_pJsonFalseData).
static NSData *g_pJsonNullData = nil;
static NSData *g_pJsonTrueData = nil;
static NSData *g_pJsonFalseData = nil;

@implementation CJSONDataSerializer

+ (void)initialize {
    if (g_pJsonNullData == nil) {
        g_pJsonNullData = [[NSData alloc] initWithBytes:"null" length:4];
        g_pJsonTrueData = [[NSData alloc] initWithBytes:"true" length:4];
        g_pJsonFalseData = [[NSData alloc] initWithBytes:"false" length:5];
    }
}

// @ 0x66e00
- (NSData *)serializeObject:(id)inObject {
    NSData *theResult = NULL;
    if ([inObject isKindOfClass:[NSNull class]]) {
        theResult = [self serializeNull:inObject];
    } else if ([inObject isKindOfClass:[NSNumber class]]) {
        theResult = [self serializeNumber:inObject];
    } else if ([inObject isKindOfClass:[NSString class]]) {
        theResult = [self serializeString:inObject];
    } else if ([inObject isKindOfClass:[NSArray class]]) {
        theResult = [self serializeArray:inObject];
    } else if ([inObject isKindOfClass:[NSDictionary class]]) {
        theResult = [self serializeDictionary:inObject];
    } else if ([inObject isKindOfClass:[NSData class]]) {
        NSString *theString = [[NSString alloc] initWithData:inObject encoding:NSUTF8StringEncoding];
        theResult = [self serializeString:theString];
    } else if ([inObject isKindOfClass:[CSerializedJSONData class]]) {
        theResult = [inObject data];
    } else {
        [NSException raise:NSGenericException
                    format:@"Cannot serialize data of type '%@'", NSStringFromClass([inObject class])];
    }
    if (theResult == NULL) {
        [NSException raise:NSGenericException
                    format:@"Could not serialize object '%@'", inObject];
    }
    return theResult;
}

// @ 0x6704c
- (NSData *)serializeNull:(NSNull *)inNull {
    return g_pJsonNullData;
}

// @ 0x6705c
- (NSData *)serializeNumber:(NSNumber *)inNumber {
    NSData *theResult = NULL;
    if (CFNumberGetType((CFNumberRef)inNumber) == kCFNumberCharType) {
        int theValue = [inNumber intValue];
        if (theValue == 1) {
            return g_pJsonTrueData;
        }
        if (theValue == 0) {
            return g_pJsonFalseData;
        }
    }
    theResult = [[inNumber stringValue] dataUsingEncoding:NSASCIIStringEncoding];
    return theResult;
}

// @ 0x670cc
- (NSData *)serializeString:(NSString *)inString {
    NSMutableString *theString = [inString mutableCopy];
    [theString replaceOccurrencesOfString:@"\\" withString:@"\\\\"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\"" withString:@"\\\""
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"/" withString:@"\\/"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\b" withString:@"\\b"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\f" withString:@"\\f"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\n" withString:@"\\n"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\r" withString:@"\\r"
                                  options:0 range:NSMakeRange(0, [theString length])];
    [theString replaceOccurrencesOfString:@"\t" withString:@"\\t"
                                  options:0 range:NSMakeRange(0, [theString length])];
    NSString *theQuotedString = [NSString stringWithFormat:@"\"%@\"", theString];
    return [theQuotedString dataUsingEncoding:NSUTF8StringEncoding];
}

// @ 0x672cc
- (NSData *)serializeArray:(NSArray *)inArray {
    NSMutableData *theData = [NSMutableData data];
    [theData appendBytes:"[" length:1];
    NSEnumerator *theEnumerator = [inArray objectEnumerator];
    id theObject = NULL;
    NSUInteger theIndex = 1;
    while ((theObject = [theEnumerator nextObject]) != NULL) {
        [theData appendData:[self serializeObject:theObject]];
        if (theIndex < [inArray count]) {
            [theData appendBytes:"," length:1];
        }
        theIndex += 1;
    }
    [theData appendBytes:"]" length:1];
    return theData;
}

// @ 0x673d0
- (NSData *)serializeDictionary:(NSDictionary *)inDictionary {
    NSMutableData *theData = [NSMutableData data];
    [theData appendBytes:"{" length:1];
    NSArray *theKeys = [inDictionary allKeys];
    NSEnumerator *theEnumerator = [theKeys objectEnumerator];
    id theKey = NULL;
    while ((theKey = [theEnumerator nextObject]) != NULL) {
        id theValue = [inDictionary objectForKey:theKey];
        [theData appendData:[self serializeString:theKey]];
        [theData appendBytes:":" length:1];
        [theData appendData:[self serializeObject:theValue]];
        if (theKey != [theKeys lastObject]) {
            [theData appendData:[@"," dataUsingEncoding:NSASCIIStringEncoding]];
        }
    }
    [theData appendBytes:"}" length:1];
    return theData;
}

@end
