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
- (NSArray *)getMusicDataArray;         // @ 0xcae40
- (NSArray *)getAcMusicDataArray;       // @ 0xcae84
- (NSArray *)getTreasureMusicDataArray; // @ 0xcaec8 (all treasure songs from bundle)

// Linear lookup in the cached arrays by id.
- (MusicData *)getMusicData:(int)musicId;       // @ 0xcb080 (matches .MusicID)
- (AcMusicData *)getAcMusicData:(int)acMusicId; // @ 0xcb154 (matches .acMusicId)

// "%09d.orb" data-file names.
+ (NSString *)getMusicDataFilename:(int)musicId; // @ 0xc7e20 (class method: stateless "%09d.orb")
- (NSString *)getAcMusicDataFilename:(int)acMusicId;

// Rebuild the caches (clears the dirty flag).
- (void)createMusicDataArray;    // @ 0xca248
- (void)createAcMusicDataArray;  // @ 0xcaabc
- (void)createMusicLvPatchArray; // loads rhythmin.lv level patches

// Built-in song tables, assembled in -init from constant id lists / unlock
// gates.
- (void)createDefaultMusics;        // @ 0xc8384 (ids {1,2,3})
- (void)createOpenTreasureMusics;   // @ 0xc8440 (treasure ids, gated per main map)
- (void)createOpenInviteMusics;     // @ 0xc8554 (id 4, invite gate)
- (void)createOpenCollaboMusics;    // @ 0xc8604 (id 5, BEMANI-collabo gate)
- (void)createOpenLoginBonusMusics; // @ 0xc86b4 (id 6, login-bonus gate)
- (void)createAcDefaultMusics;      // @ 0xc8764 (ids {1,2,3,300000000})

// Load & Blowfish-decrypt the purchased-song lists ("mulist"/"acmulist").
- (void)loadPurchasedMusics; // @ 0xc8820

// Blowfish-encrypt & write the purchased-song lists back to
// "mulist"/"acmulist".
- (void)savePurchasedMusics; // @ 0xc8bec

// Accessors for the in-memory purchased-song lists.
- (NSMutableArray *)getPurchasedMusicDictionaris;   // @ 0xc8f28
- (NSMutableArray *)getPurchasedAcMusicDictionaris; // @ 0xc8f38

// Add/merge a purchased song into the list (returns YES when the list changed).
- (BOOL)addPurchasedMusic:(id)item;   // @ 0xc8f48
- (BOOL)addPurchasedAcMusic:(id)item; // @ 0xc93f0

// Delete a downloaded (.orb) song file; returns YES if the file existed.
- (BOOL)deleteMusic:(int)musicId;     // @ 0xc9898
- (BOOL)deleteAcMusic:(int)acMusicId; // @ 0xc9914

// YES if `packID` appears in the encrypted "recpack" recommended list.
- (BOOL)isRecommendedPack:(int)packID; // @ 0xc9990

// Re-evaluate an unlock gate and mark the local cache dirty.
- (void)openTreasureMusic;   // @ 0xcafc0
- (void)openInviteMusic;     // @ 0xcaff0
- (void)openCollaboMusic;    // @ 0xcb020
- (void)openLoginBonusMusic; // @ 0xcb050

// Flat lists of all currently-available song ids (NSNumber).
- (NSMutableArray *)getMusicIDs;   // @ 0xcb24c (default + purchased + treasure)
- (NSMutableArray *)getAcMusicIDs; // @ 0xcb474 (ac-default + purchased-ac)

// The loaded level-patch records (rhythmin.lv), or nil.
- (NSArray *)getMusicPatchArray; // @ 0xcb948

// Mark a cache stale so the next getter rebuilds it.
- (void)setMusicDataArrayDirty;   // @ 0xcae18
- (void)setAcMusicDataArrayDirty; // @ 0xcae2c
- (void)releaseChacheMusicData;   // @ 0xcb248 (no-op in this build)

// Resolve a song id to its bundled / purchased (.orb) path.
+ (NSString *)getPathFromBundle:(int)musicId;    // @ 0xc7e80 (class method: no instance state;
                                                 // the original calls it on the class, so the
                                                 // init-time open-song predicates do NOT re-enter
                                                 // getInstance -- see the recursion fix in .m)
- (NSString *)getPathFromPurchased:(int)musicId; // @ 0xc7edc
- (NSString *)getAcPathFromPurchased:(int)acMusicId; // @ 0xc7f38 (arcade music variant)

// The recommended-pack id list (decoded from the encrypted "recpack" file).
// Ghidra:
// @ 0xc9bd0.
- (NSArray *)getRecommendPackArray;

// Add a pack id to the encrypted "recpack" list (no-op if already present).
// Ghidra: @ 0xc9e20.
- (void)saveRecommendedPack:(unsigned int)packID;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as a local category seam).

// Unlock-gate queries used by the store / song-select UI.
+ (BOOL)isOpenInviteMusic:(int)index;
+ (BOOL)isInviteMusic:(int)musicId; // @ 0xc7fd4 (YES if id == 4)
+ (BOOL)isOpenBemaniCollaboMusic;
+ (BOOL)isOpenLoginBonusMusic:(int)index;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
