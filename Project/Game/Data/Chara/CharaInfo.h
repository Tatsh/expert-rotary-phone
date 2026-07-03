//
//  CharaInfo.h
//  pop'n rhythmin
//
//  A character display record (id + name + its skill). Reconstructed from
//  Ghidra project rb420, program PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface CharaInfo : NSObject

@property (atomic) int charaId;                 // getter @ 0x64130 / setter @ 0x64144
@property (nonatomic, strong) NSString *charaName;  // getter @ 0x6415c / setter @ 0x6416c
@property (nonatomic, strong) NSString *info;       // getter @ 0x6417c / setter @ 0x6418c
@property (atomic) int skillId;                 // getter @ 0x6419c / setter @ 0x641b0
@property (nonatomic, strong) NSString *skillName;  // getter @ 0x641c8 / setter @ 0x641d8
@property (atomic) int rarity;                  // getter @ 0x641e8 / setter @ 0x641fc

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
