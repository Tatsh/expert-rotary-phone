//
//  NSDictionary_JSONExtensions.h
//  pop'n rhythmin (vendored TouchJSON)
//
//  TouchJSON convenience category: build an NSDictionary from JSON data/string
//  through CJSONDeserializer. The binary's Downloader::getDataInJSON (@ 0x62948)
//  calls +[NSDictionary dictionaryWithJSONData:error:] as its pre-iOS-5
//  (NSJSONSerialization-absent) fallback; provided here to keep that call site
//  faithful. On the iOS 12 target NSJSONSerialization is always present, so this
//  path compiles but never runs.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (NSDictionary_JSONExtensions)
+ (NSDictionary *)dictionaryWithJSONData:(NSData *)inData error:(NSError **)outError;
+ (NSDictionary *)dictionaryWithJSONString:(NSString *)inString error:(NSError **)outError;
@end
