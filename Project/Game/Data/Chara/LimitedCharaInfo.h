//
//  LimitedCharaInfo.h
//  pop'n rhythmin
//
//  Set of character ids available for a limited time. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface LimitedCharaInfo : NSObject

// Synthesized: musicIds @ 0x6434c, setMusicIds: @ 0x6435c.
@property (nonatomic, strong) NSArray *musicIds;
// Synthesized: charaIds @ 0x6436c, setCharaIds: @ 0x6437c.
@property (nonatomic, strong) NSArray *charaIds;
// Synthesized: getFlg @ 0x6438c, setGetFlg: @ 0x643a4 (atomic unlock flag).
@property (atomic) BOOL getFlg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
