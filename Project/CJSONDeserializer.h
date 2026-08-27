//
//  CJSONDeserializer.h
//  pop'n rhythmin
//
//  TouchJSON front-end for parsing JSON NSData into a Foundation object graph.
//  Each entry point wraps a fresh CJSONScanner over the supplied data.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//  (deserialize:error: @ 0x67588).
//

#import <Foundation/Foundation.h>

/**
 * @brief Parses JSON NSData into a Foundation object graph, wrapping a fresh CJSONScanner per
 * call.
 */
@interface CJSONDeserializer : NSObject

/**
 * @brief An autoreleased deserializer.
 * @return The new deserializer.
 * @ghidraAddress 0x67550
 */
+ (CJSONDeserializer *)deserializer;

/**
 * @brief Parse JSON into whatever top-level object it describes.
 * @param inData The JSON bytes.
 * @param outError Receives the parse error; may be NULL.
 * @return The parsed object, or nil on failure.
 * @ghidraAddress 0x67588
 */
- (id)deserialize:(NSData *)inData error:(NSError **)outError;
/**
 * @brief Parse JSON expected to describe an object.
 * @param inData The JSON bytes.
 * @param outError Receives the parse error; may be NULL.
 * @return The parsed dictionary, or nil on failure.
 */
- (NSDictionary *)deserializeAsDictionary:(NSData *)inData error:(NSError **)outError;
/**
 * @brief Parse JSON expected to describe an array.
 * @param inData The JSON bytes.
 * @param outError Receives the parse error; may be NULL.
 * @return The parsed array, or nil on failure.
 */
- (NSArray *)deserializeAsArray:(NSData *)inData error:(NSError **)outError;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
