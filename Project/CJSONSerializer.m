//
//  CJSONSerializer.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CJSONSerializer.h"
#import "CJSONDataSerializer.h"

@implementation CJSONSerializer

// +[CJSONSerializer serializer]  @ 0x6a2a0 — autoreleased convenience instance.
// Verified: [[self alloc] init] then tail-call autorelease (ARC).
// @complete
+ (CJSONSerializer *)serializer {
    return [[self alloc] init];
}

// @ 0x6a2d8 — verified: [super init]; on non-nil, serializer =
// [[CJSONDataSerializer alloc] init].
// @complete
- (id)init {
    if ((self = [super init]) != nil) {
        serializer = [[CJSONDataSerializer alloc] init];
    }
    return self;
}

// dealloc @ 0x6a33c — ARC-omitted (object ivars only).

// @ 0x6a38c — verified: [serializer serializeObject:inObject]; [[NSString alloc]
// initWithData:theData encoding:0x4] (NSUTF8StringEncoding).
// @complete
- (NSString *)serializeObject:(id)inObject {
    NSData *theData = [serializer serializeObject:inObject];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

// @ 0x6a3f4 — verified: [serializer serializeArray:inArray]; [[NSString alloc]
// initWithData:theData encoding:0x4].
// @complete
- (NSString *)serializeArray:(NSArray *)inArray {
    NSData *theData = [serializer serializeArray:inArray];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

// @ 0x6a45c — verified: [serializer serializeDictionary:inDictionary];
// [[NSString alloc] initWithData:theData encoding:0x4].
// @complete
- (NSString *)serializeDictionary:(NSDictionary *)inDictionary {
    NSData *theData = [serializer serializeDictionary:inDictionary];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

@end
