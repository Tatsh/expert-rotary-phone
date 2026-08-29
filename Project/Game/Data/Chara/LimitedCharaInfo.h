/**
 * @file
 * @brief A set of character ids available for a limited time.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One limited-time character set: the music that unlocks it and the characters it grants.
 */
@interface LimitedCharaInfo : NSObject

/** The music ids whose purchase unlocks this set. Getter @ 0x6434c, setter @ 0x6435c. */
@property(nonatomic, strong) NSArray *musicIds;
/** The character ids this set grants. Getter @ 0x6436c, setter @ 0x6437c. */
@property(nonatomic, strong) NSArray *charaIds;
/** Whether the set has been unlocked. Getter @ 0x6438c, setter @ 0x643a4. */
@property(atomic) BOOL getFlg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
