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

@interface CJSONDeserializer : NSObject

- (id)deserialize:(NSData *)inData error:(NSError **)outError;
- (NSDictionary *)deserializeAsDictionary:(NSData *)inData error:(NSError **)outError;
- (NSArray *)deserializeAsArray:(NSData *)inData error:(NSError **)outError;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
