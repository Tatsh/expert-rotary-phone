//
//  NSString+URLDecode.h
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The ApplilinkReward SDK's NSString percent-decode category, used by the
//  reward web-view controller and the recommend core to unescape query values.
//

#import <Foundation/Foundation.h>

/**
 * @brief Percent-unescaping on NSString.
 */
@interface NSString (URLDecode)

/**
 * @brief Percent-unescape the receiver as UTF-8.
 *
 * The decompiler labelled this category method as a free function, urlDecodeString.
 * @return The decoded string.
 * @ghidraAddress 0xfc218
 */
- (NSString *)URLDecodedString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
