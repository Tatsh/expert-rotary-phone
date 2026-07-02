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

@property (atomic) int musicId;  // Ghidra: setMusicId: @ 0x78834
@property (atomic) int lvN;      // Ghidra: lvN @ 0x7884c
@property (atomic) int lvH;      // Ghidra: lvH @ 0x78878
@property (atomic) int lvEx;     // Ghidra: lvEx @ 0x788a4

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
