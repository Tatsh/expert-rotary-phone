//
//  NSString+URLDecode.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "NSString+URLDecode.h"

@implementation NSString (URLDecode)

// @ 0xfc218
// Percent-unescape via CFURLCreateStringByReplacingPercentEscapesUsingEncoding
// (UTF-8). The binary passes the "%d/%02d/15 12:00:00" CFString (@ 0x10869e) as
// charactersToLeaveEscaped — a reused date-format literal, unusual but
// recovered verbatim and kept faithful.
- (NSString *)URLDecodedString {
    return (NSString *)CFBridgingRelease(
        CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                (__bridge CFStringRef)self,
                                                                CFSTR("%d/%02d/15 12:00:00"),
                                                                kCFStringEncodingUTF8));
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
