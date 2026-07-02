//
//  PreferredCharaInfo.h
//  pop'n rhythmin
//
//  Set of the player's preferred/favorite character ids. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface PreferredCharaInfo : NSObject

@property (nonatomic, strong) NSArray *musicIds;   // Ghidra: setMusicIds:
@property (nonatomic, strong) NSArray *charaIds;   // Ghidra: charaIds @ 0x64298
@property (atomic) BOOL getFlg;                    // Ghidra: getFlg/setGetFlg: (unlock flag)

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
