//
//  CJSONDeserializer.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CJSONDeserializer.h"

#import "CJSONScanner.h"

NSString *const kJSONDeserializerErrorDomain = @"CJSONDeserializerErrorDomain";

@implementation CJSONDeserializer

// +[CJSONDeserializer deserializer]  @ 0x67550 — autoreleased convenience
// instance.
// @complete
+ (CJSONDeserializer *)deserializer {
    return [[self alloc] init];
}

// @ 0x67588
// @complete
- (id)deserialize:(NSData *)inData error:(NSError **)outError {
    if (inData != NULL && [inData length] != 0) {
        CJSONScanner *theScanner = [CJSONScanner scannerWithData:inData];
        id theObject = NULL;
        if ([theScanner scanJSONObject:&theObject error:outError] != YES) {
            theObject = NULL;
        }
        return theObject;
    }
    if (outError != NULL) {
        *outError = [NSError errorWithDomain:kJSONDeserializerErrorDomain code:-1 userInfo:NULL];
    }
    return NULL;
}

// @ 0x67628
// @complete
- (NSDictionary *)deserializeAsDictionary:(NSData *)inData error:(NSError **)outError {
    id theResult = NULL;
    if (inData == NULL || [inData length] == 0) {
        if (outError != NULL) {
            *outError = [NSError errorWithDomain:kJSONDeserializerErrorDomain
                                            code:-1
                                        userInfo:NULL];
        }
    } else {
        CJSONScanner *theScanner = [CJSONScanner scannerWithData:inData];
        id theObject = NULL;
        if ([theScanner scanJSONDictionary:&theObject error:outError] == YES) {
            theResult = theObject;
        }
    }
    return theResult;
}

// @ 0x676c4
// @complete
- (NSArray *)deserializeAsArray:(NSData *)inData error:(NSError **)outError {
    id theResult = NULL;
    if (inData == NULL || [inData length] == 0) {
        if (outError != NULL) {
            *outError = [NSError errorWithDomain:kJSONDeserializerErrorDomain
                                            code:-1
                                        userInfo:NULL];
        }
    } else {
        CJSONScanner *theScanner = [CJSONScanner scannerWithData:inData];
        id theObject = NULL;
        if ([theScanner scanJSONArray:&theObject error:outError] == YES) {
            theResult = theObject;
        }
    }
    return theResult;
}

@end
