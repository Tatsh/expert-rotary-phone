//
//  CharaInfo.h
//  pop'n rhythmin
//
//  A character display record (id + name + its skill). Reconstructed from
//  Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface CharaInfo : NSObject

@property (atomic) int charaId;                 // Ghidra: charaId @ 0x64130
@property (nonatomic, strong) NSString *charaName;
@property (nonatomic, strong) NSString *info;
@property (atomic) int skillId;                 // Ghidra: skillId @ 0x6419c
@property (nonatomic, strong) NSString *skillName;
@property (atomic) int rarity;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
