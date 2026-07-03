//
//  CJSONSerializer.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CJSONSerializer.h"
#import "CJSONDataSerializer.h"

@implementation CJSONSerializer

// @ 0x6a2d8
- (id)init {
    if ((self = [super init]) != nil) {
        serializer = [[CJSONDataSerializer alloc] init];
    }
    return self;
}

// dealloc @ 0x6a33c — ARC-omitted (object ivars only).

// @ 0x6a38c
- (NSString *)serializeObject:(id)inObject {
    NSData *theData = [serializer serializeObject:inObject];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

// @ 0x6a3f4
- (NSString *)serializeArray:(NSArray *)inArray {
    NSData *theData = [serializer serializeArray:inArray];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

// @ 0x6a45c
- (NSString *)serializeDictionary:(NSDictionary *)inDictionary {
    NSData *theData = [serializer serializeDictionary:inDictionary];
    return [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
