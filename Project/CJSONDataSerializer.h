//
//  CJSONDataSerializer.h
//  pop'n rhythmin
//
//  TouchJSON serializer that turns a Foundation object graph (NSNull, NSNumber,
//  NSString, NSArray, NSDictionary, NSData, CSerializedJSONData) into UTF-8
//  encoded JSON NSData.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//  (serializeObject: @ 0x66e00).
//

#import <Foundation/Foundation.h>

@interface CJSONDataSerializer : NSObject

- (NSData *)serializeObject:(id)inObject;
- (NSData *)serializeNull:(NSNull *)inNull;
- (NSData *)serializeNumber:(NSNumber *)inNumber;
- (NSData *)serializeString:(NSString *)inString;
- (NSData *)serializeArray:(NSArray *)inArray;
- (NSData *)serializeDictionary:(NSDictionary *)inDictionary;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
