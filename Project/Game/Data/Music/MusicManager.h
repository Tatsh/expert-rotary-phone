//
//  MusicManager.h
//  pop'n rhythmin
//
//  Music-catalog singleton. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Builds and caches the arrays of playable MusicData (local) and
//  AcMusicData (arcade) records, tracks purchased songs, and applies level
//  patches. Song data files are "%09d.orb" (Blowfish/plain per source).
//

#import <Foundation/Foundation.h>

@class MusicData, AcMusicData;

@interface MusicManager : NSObject

// Shared singleton (Ghidra: getInstance @ 0xc7dd8, storage DAT_00188318).
+ (instancetype)getInstance;

// Cached, lazily (re)built arrays. Rebuilt when the matching dirty flag is set.
- (NSArray *)getMusicDataArray;      // @ 0xcae40
- (NSArray *)getAcMusicDataArray;    // @ 0xcae84
- (NSArray *)getTreasureMusicDataArray; // @ 0xcaec8 (all treasure songs from bundle)

// Linear lookup in the cached arrays by id.
- (MusicData *)getMusicData:(int)musicId;      // @ 0xcb080 (matches .MusicID)
- (AcMusicData *)getAcMusicData:(int)acMusicId; // @ 0xcb154 (matches .acMusicId)

// "%09d.orb" data-file names.
- (NSString *)getMusicDataFilename:(int)musicId;   // @ 0xc7e20
- (NSString *)getAcMusicDataFilename:(int)acMusicId;

// Rebuild the caches (clears the dirty flag).
- (void)createMusicDataArray;        // @ 0xca248
- (void)createAcMusicDataArray;      // @ 0xcaabc
- (void)createMusicLvPatchArray;     // loads rhythmin.lv level patches

// Load & Blowfish-decrypt the purchased-song lists ("mulist"/"acmulist").
- (void)loadPurchasedMusics;         // @ 0xc8820

// Mark a cache stale so the next getter rebuilds it.
- (void)setMusicDataArrayDirty;      // @ 0xcae18
- (void)setAcMusicDataArrayDirty;    // @ 0xcae2c
- (void)releaseChacheMusicData;      // @ 0xcb248 (no-op in this build)

// Resolve a song id to its bundled / purchased (.orb) path.
- (NSString *)getPathFromBundle:(int)musicId;
- (NSString *)getPathFromPurchased:(int)musicId;   // @ 0xc7edc
- (NSString *)getAcPathFromPurchased:(int)acMusicId;   // @ 0xc7f38 (arcade music variant)

// The recommended-pack id list (decoded from the encrypted "recpack" file). Ghidra:
// @ 0xc9bd0.
- (NSArray *)getRecommendPackArray;

// Add a pack id to the encrypted "recpack" list (no-op if already present). Ghidra: @ 0xc9e20.
- (void)saveRecommendedPack:(unsigned int)packID;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
