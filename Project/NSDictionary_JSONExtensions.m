//
//  NSDictionary_JSONExtensions.m
//  pop'n rhythmin (vendored TouchJSON)
//

#import "NSDictionary_JSONExtensions.h"

#import "CJSONDeserializer.h"

@implementation NSDictionary (NSDictionary_JSONExtensions)

+ (NSDictionary *)dictionaryWithJSONData:(NSData *)inData error:(NSError **)outError {
    return [[CJSONDeserializer deserializer] deserializeAsDictionary:inData error:outError];
}

+ (NSDictionary *)dictionaryWithJSONString:(NSString *)inString error:(NSError **)outError {
    NSData *data = [inString dataUsingEncoding:NSUTF8StringEncoding];
    return [[CJSONDeserializer deserializer] deserializeAsDictionary:data error:outError];
}

@end
