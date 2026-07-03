//
//  CSerializedJSONData.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (TouchJSON).
//

#import "CSerializedJSONData.h"

@implementation CSerializedJSONData

// @ 0x6a4c4
- (id)initWithData:(NSData *)inData {
    if ((self = [super init]) == nil) {
        return nil;
    }
    data = inData;
    return self;
}

// dealloc @ 0x6a4f0 — ARC-omitted (object ivars only).

// @ 0x6a540
- (NSData *)data {
    return data;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
