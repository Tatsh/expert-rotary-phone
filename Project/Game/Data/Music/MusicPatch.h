//
//  MusicPatch.h
//  pop'n rhythmin
//
//  A downloadable per-song difficulty override applied by MusicManager after
//  building the catalog. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Plain scalar record with atomic accessors.
//

#import <Foundation/Foundation.h>

@interface MusicPatch : NSObject

// Synthesized: musicId @ 0x78820, setMusicId: @ 0x78834.
@property (atomic) int musicId;
// Synthesized: lvN @ 0x7884c, setLvN: @ 0x78860.
@property (atomic) int lvN;
// Synthesized: lvH @ 0x78878, setLvH: @ 0x7888c.
@property (atomic) int lvH;
// Synthesized: lvEx @ 0x788a4, setLvEx: @ 0x788b8.
@property (atomic) int lvEx;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
