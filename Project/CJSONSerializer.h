//
//  CJSONSerializer.h
//  pop'n rhythmin
//
//  TouchJSON front-end that serializes a Foundation object graph to an NSString
//  of JSON. It wraps a CJSONDataSerializer (which produces the raw UTF-8
//  NSData) and decodes the result back into a string.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//  (init @ 0x6a2d8, serializeObject: @ 0x6a38c).
//

#import <Foundation/Foundation.h>

@class CJSONDataSerializer;

@interface CJSONSerializer : NSObject {
    CJSONDataSerializer *serializer;
}

+ (CJSONSerializer *)serializer; // @ 0x6a2a0 (convenience constructor)

- (NSString *)serializeObject:(id)inObject;
- (NSString *)serializeArray:(NSArray *)inArray;
- (NSString *)serializeDictionary:(NSDictionary *)inDictionary;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
