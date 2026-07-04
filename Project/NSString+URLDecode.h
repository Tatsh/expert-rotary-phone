//
//  NSString+URLDecode.h
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The ApplilinkReward SDK's NSString percent-decode category, used by the reward web-view
//  controller and the recommend core to unescape query values.
//

#import <Foundation/Foundation.h>

@interface NSString (URLDecode)

// Percent-unescape the receiver (UTF-8). Ghidra: urlDecodeString @ 0xfc218 (the decompiler
// labelled this category method as a free function).
- (NSString *)URLDecodedString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
