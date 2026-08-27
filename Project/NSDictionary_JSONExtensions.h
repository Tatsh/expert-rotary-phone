//
//  NSDictionary_JSONExtensions.h
//  pop'n rhythmin (reconstructed TouchJSON category)
//
//  TouchJSON convenience category: build an NSDictionary from JSON data/string
//  through CJSONDeserializer. The binary's Downloader::getDataInJSON (@
//  0x62948) calls +[NSDictionary dictionaryWithJSONData:error:] as its
//  pre-iOS-5 (NSJSONSerialization-absent) fallback; provided here to keep that
//  call site faithful. On the iOS 12 target NSJSONSerialization is always
//  present, so this path compiles but never runs.
//

#import <Foundation/Foundation.h>

/**
 * @brief TouchJSON convenience constructors that parse JSON into a dictionary.
 */
@interface NSDictionary (NSDictionary_JSONExtensions)
/**
 * @brief Parse JSON bytes into a dictionary.
 * @param inData The JSON bytes.
 * @param outError Receives the parse error; may be NULL.
 * @return The parsed dictionary, or nil on failure.
 */
+ (NSDictionary *)dictionaryWithJSONData:(NSData *)inData error:(NSError **)outError;
/**
 * @brief Parse a JSON string into a dictionary.
 * @param inString The JSON text.
 * @param outError Receives the parse error; may be NULL.
 * @return The parsed dictionary, or nil on failure.
 */
+ (NSDictionary *)dictionaryWithJSONString:(NSString *)inString error:(NSError **)outError;
@end
