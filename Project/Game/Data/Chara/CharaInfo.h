/**
 * @file
 * @brief A character display record: id, name and its skill.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One character's display record: its id, names, description, skill and rarity.
 */
@interface CharaInfo : NSObject

/** The character id. Getter @ 0x64130, setter @ 0x64144. */
@property(atomic) int charaId;
/** The character's display name. Getter @ 0x6415c, setter @ 0x6416c. */
@property(nonatomic, strong) NSString *charaName;
/** The character's description text. Getter @ 0x6417c, setter @ 0x6418c. */
@property(nonatomic, strong) NSString *info;
/** The id of the character's sugoroku skill. Getter @ 0x6419c, setter @ 0x641b0. */
@property(atomic) int skillId;
/** The skill's display name. Getter @ 0x641c8, setter @ 0x641d8. */
@property(nonatomic, strong) NSString *skillName;
/** The character's rarity tier. Getter @ 0x641e8, setter @ 0x641fc. */
@property(atomic) int rarity;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
