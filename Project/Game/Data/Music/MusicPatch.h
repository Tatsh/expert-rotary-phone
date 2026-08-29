/**
 * @file
 * @brief A downloadable per-song difficulty override, applied by MusicManager after building the
 * catalogue.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. It is a plain scalar record with
 * atomic accessors.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One song's downloaded difficulty-level override.
 */
@interface MusicPatch : NSObject

/** The music id this patch applies to. Getter @ 0x78820, setter @ 0x78834. */
@property(atomic) int musicId;
/** The overriding Normal level. Getter @ 0x7884c, setter @ 0x78860. */
@property(atomic) int lvN;
/** The overriding Hyper level. Getter @ 0x78878, setter @ 0x7888c. */
@property(atomic) int lvH;
/** The overriding EX level. Getter @ 0x788a4, setter @ 0x788b8. */
@property(atomic) int lvEx;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
