/** @file
 * A set of the player's preferred character ids. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One preferred-character set: the music that unlocks it and the characters it grants.
 */
@interface PreferredCharaInfo : NSObject

/** The music ids whose purchase unlocks this set. Getter @ 0x64278, setter @ 0x64288. */
@property(nonatomic, strong) NSArray *musicIds;
/** The character ids this set grants. Getter @ 0x64298, setter @ 0x642a8. */
@property(nonatomic, strong) NSArray *charaIds;
/** Whether the set has been unlocked. Getter @ 0x642b8, setter @ 0x642d0. */
@property(atomic) BOOL getFlg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
