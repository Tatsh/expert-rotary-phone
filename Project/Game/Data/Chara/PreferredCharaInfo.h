//
//  PreferredCharaInfo.h
//  pop'n rhythmin
//
//  Set of the player's preferred/favorite character ids. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface PreferredCharaInfo : NSObject

// Synthesized: musicIds @ 0x64278, setMusicIds: @ 0x64288.
@property(nonatomic, strong) NSArray *musicIds;
// Synthesized: charaIds @ 0x64298, setCharaIds: @ 0x642a8.
@property(nonatomic, strong) NSArray *charaIds;
// Synthesized: getFlg @ 0x642b8, setGetFlg: @ 0x642d0 (atomic unlock flag).
@property(atomic) BOOL getFlg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
