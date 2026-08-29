/**
 * @file
 * @brief The TouchJSON front-end that serializes a Foundation object graph to an NSString of JSON.
 *
 * It wraps a CJSONDataSerializer (which produces the raw UTF-8 NSData) and decodes the result
 * back into a string. Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON;
 * init @ 0x6a2d8, serializeObject: @ 0x6a38c).
 */

#import <Foundation/Foundation.h>

@class CJSONDataSerializer;

/**
 * @brief Serializes a Foundation object graph to a JSON NSString, wrapping a CJSONDataSerializer
 * and decoding its UTF-8 output back into a string.
 */
@interface CJSONSerializer : NSObject {
    /** The wrapped serializer that produces the raw UTF-8 bytes. */
    CJSONDataSerializer *serializer;
}

/**
 * @brief An autoreleased serializer.
 * @return The new serializer.
 * @ghidraAddress 0x6a2a0
 */
+ (CJSONSerializer *)serializer;

/**
 * @brief Serialize any supported object.
 * @param inObject The object to serialize.
 * @return The JSON text, or nil for an unsupported type.
 * @ghidraAddress 0x6a38c
 */
- (NSString *)serializeObject:(id)inObject;
/**
 * @brief Serialize an array as a JSON array.
 * @param inArray The array to serialize.
 * @return The JSON text.
 */
- (NSString *)serializeArray:(NSArray *)inArray;
/**
 * @brief Serialize a dictionary as a JSON object.
 * @param inDictionary The dictionary to serialize.
 * @return The JSON text.
 */
- (NSString *)serializeDictionary:(NSDictionary *)inDictionary;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
