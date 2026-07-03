//
//  CSerializedJSONData.h
//  pop'n rhythmin
//
//  TouchJSON helper: a wrapper around an NSData blob that is already-serialized
//  JSON. When handed to CJSONDataSerializer it is emitted verbatim instead of
//  being re-encoded.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//  (initWithData: @ 0x6a4c4, data @ 0x6a540).
//

#import <Foundation/Foundation.h>

@interface CSerializedJSONData : NSObject {
    NSData *data;
}

- (id)initWithData:(NSData *)inData;
- (NSData *)data;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
