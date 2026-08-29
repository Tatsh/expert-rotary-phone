/**
 * @file
 * The TouchJSON serializer that turns a Foundation object graph into UTF-8 encoded JSON
 * NSData.
 *
 * It handles NSNull, NSNumber, NSString, NSArray, NSDictionary, NSData, and CSerializedJSONData.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON; serializeObject: @
 * 0x66e00).
 */

#import <Foundation/Foundation.h>

/**
 * Turns a Foundation object graph into UTF-8 encoded JSON NSData.
 */
@interface CJSONDataSerializer : NSObject

/**
 * An autoreleased serializer.
 * @return The new serializer.
 * @ghidraAddress 0x66dc8
 */
+ (CJSONDataSerializer *)serializer;

/**
 * Serialize any supported object: NSNull, NSNumber, NSString, NSArray, NSDictionary,
 * NSData or CSerializedJSONData.
 * @param inObject The object to serialize.
 * @return The UTF-8 JSON bytes, or nil for an unsupported type.
 * @ghidraAddress 0x66e00
 */
- (NSData *)serializeObject:(id)inObject;
/**
 * Serialize a null as the JSON literal `null`.
 * @param inNull The null to serialize.
 * @return The UTF-8 JSON bytes.
 */
- (NSData *)serializeNull:(NSNull *)inNull;
/**
 * Serialize a number as a JSON number or boolean.
 * @param inNumber The number to serialize.
 * @return The UTF-8 JSON bytes.
 */
- (NSData *)serializeNumber:(NSNumber *)inNumber;
/**
 * Serialize a string as a quoted, escaped JSON string.
 * @param inString The string to serialize.
 * @return The UTF-8 JSON bytes.
 */
- (NSData *)serializeString:(NSString *)inString;
/**
 * Serialize an array as a JSON array.
 * @param inArray The array to serialize.
 * @return The UTF-8 JSON bytes.
 */
- (NSData *)serializeArray:(NSArray *)inArray;
/**
 * Serialize a dictionary as a JSON object.
 * @param inDictionary The dictionary to serialize.
 * @return The UTF-8 JSON bytes.
 */
- (NSData *)serializeDictionary:(NSDictionary *)inDictionary;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
