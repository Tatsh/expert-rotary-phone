//
//  MusicData.h
//  pop'n rhythmin
//
//  A single local (pop'n) song record, decoded from its "%09d.orb" file.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  The .orb is a zipped JSON dict with keys: ID, MusicName, MusicNameHira,
//  ArtistName, ArtistNameHira, Normal, Hyper, Ex, BpmMin, BpmMax. Sort initials
//  (kana "yomi") are derived from the *Hira reading strings.
//

#import <Foundation/Foundation.h>

@interface MusicData : NSObject

@property(nonatomic) int MusicID; // Ghidra: MusicID @ 0xc7cc0
// The four display-name strings compile to *atomic* copy getters
// (objc_getProperty), unlike the sort/initial strings below whose getters are
// plain nonatomic ivar loads.
@property(copy) NSString *musicName;      // @ 0xc7d38
@property(copy) NSString *musicNameHira;  // @ 0xc7d4c
@property(copy) NSString *artistName;     // @ 0xc7d60
@property(copy) NSString *artistNameHira; // @ 0xc7d74
@property(nonatomic) int lvNormal;        // @ 0xc7cd4
@property(nonatomic) int lvHyper;         // @ 0xc7ce8
@property(nonatomic) int lvEx;            // Ghidra: lvEx @ 0xc7cfc
@property(nonatomic) int bpm_MIN;         // @ 0xc7d10
@property(nonatomic) int bpm_MAX;         // @ 0xc7d24
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic) int decodeType;
@property(nonatomic, copy) NSString *musicSortName;     // @ 0xc7d88
@property(nonatomic, copy) NSString *artistSortName;    // @ 0xc7d9c
@property(nonatomic, copy) NSString *musicNameInitial;  // @ 0xc7db0
@property(nonatomic, copy) NSString *artistNameInitial; // @ 0xc7dc4

// Decode + validate a song record from its .orb path (nil if id mismatch or
// level values out of range). Ghidra: +[MusicData dataWithPath:ID:] @ 0xc72c8
+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicId;

// Override the three difficulty levels (used by MusicManager level patches).
// Ghidra: -[MusicData setLevelN:H:Ex:] @ 0xc776c
- (void)setLevelN:(int)n H:(int)h Ex:(int)ex;

// The audio + chart entries stored in the .orb zip (BF-decoded on demand). The
// play scene loads `music` as the BGM and one of the three sheets as the note
// chart, per the chosen difficulty. Ghidra: getZipData: wrappers @
// 0xc78d8/0xc78f4/0xc7910/ 0xc792c/0xc7948.
- (NSData *)music;       // "bgm"     — the full BGM
- (NSData *)musicPre;    // "pre"     — the preview clip
- (NSData *)sheetNormal; // "sheet_n"
- (NSData *)sheetHyper;  // "sheet_h"
- (NSData *)sheetEx;     // "sheet_ex"

// The @2x artwork / name-image PNGs stored in the .orb zip, each pulled out
// (and BF-decoded) on demand — plain getZipData: wrappers, no scaling. The
// result screen uploads these straight into GPU textures. Ghidra: artwork2xData
// @ 0xc7964 (entry "artwork2x"), musicNameImage2xData @ 0xc7980 (entry
// "title_2x"), artistNameImage2xData @ 0xc799c (entry "artist_2x").
- (NSData *)artwork2xData;
- (NSData *)musicNameImage2xData;
- (NSData *)artistNameImage2xData;

// Sort comparators used by MusicManager to order the song list. `compare:` is
// the default (by musicNameHira, shorter reading first); the rest sort by ID,
// by the custom/hira sort keys (artist variants fall back to the music variant
// on a tie), and by each difficulty level. Ghidra: compare: @ 0xc79b8,
// compareMusicID: @ 0xc7a28, compareMusicNameCustom: @ 0xc7a60,
// compareArtistNameCustom: @ 0xc7ad4, compareMusicNameHira: @ 0xc7b3c,
// compareArtistNameHira: @ 0xc7bb0, compareDifficultyNormal: @ 0xc7c18,
// compareDifficultyHyper: @ 0xc7c50, compareDifficultyEx: @ 0xc7c88.
- (NSComparisonResult)compare:(MusicData *)other;
- (NSComparisonResult)compareMusicID:(MusicData *)other;
- (NSComparisonResult)compareMusicNameCustom:(MusicData *)other;
- (NSComparisonResult)compareArtistNameCustom:(MusicData *)other;
- (NSComparisonResult)compareMusicNameHira:(MusicData *)other;
- (NSComparisonResult)compareArtistNameHira:(MusicData *)other;
- (NSComparisonResult)compareDifficultyNormal:(MusicData *)other;
- (NSComparisonResult)compareDifficultyHyper:(MusicData *)other;
- (NSComparisonResult)compareDifficultyEx:(MusicData *)other;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
