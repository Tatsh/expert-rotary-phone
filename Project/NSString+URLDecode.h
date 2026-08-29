/**
 * @file
 * The ApplilinkReward SDK's NSString percent-decode category.
 *
 * The reward web-view controller and the recommend core use it to unescape query values.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <Foundation/Foundation.h>

/**
 * Percent-unescaping on NSString.
 */
@interface NSString (URLDecode)

/**
 * Percent-unescape the receiver as UTF-8.
 *
 * The decompiler labelled this category method as a free function, urlDecodeString.
 * @return The decoded string.
 * @ghidraAddress 0xfc218
 */
- (NSString *)URLDecodedString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
