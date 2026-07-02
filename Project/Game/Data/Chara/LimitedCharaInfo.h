//
//  LimitedCharaInfo.h
//  pop'n rhythmin
//
//  Set of character ids available for a limited time. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface LimitedCharaInfo : NSObject

@property (nonatomic, strong) NSArray *musicIds;   // Ghidra: setMusicIds:
@property (nonatomic, strong) NSArray *charaIds;   // Ghidra: charaIds @ 0x6436c

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
