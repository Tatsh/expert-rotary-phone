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

@property (nonatomic) int MusicID;              // Ghidra: MusicID @ 0xc7cc0
@property (nonatomic, copy) NSString *musicName;
@property (nonatomic, copy) NSString *musicHira;
@property (nonatomic, copy) NSString *artistName;
@property (nonatomic, copy) NSString *artistHira;
@property (nonatomic) int lvNormal;
@property (nonatomic) int lvHyper;
@property (nonatomic) int lvEx;                 // Ghidra: lvEx @ 0xc7cfc
@property (nonatomic) int bpmMin;
@property (nonatomic) int bpmMax;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic) int decodeType;
@property (nonatomic, copy) NSString *musicSortName;
@property (nonatomic, copy) NSString *artistSortName;
@property (nonatomic, copy) NSString *musicNameInitial;
@property (nonatomic, copy) NSString *artistNameInitial;

// Decode + validate a song record from its .orb path (nil if id mismatch or
// level values out of range). Ghidra: +[MusicData dataWithPath:ID:] @ 0xc72c8
+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicId;

// Override the three difficulty levels (used by MusicManager level patches).
// Ghidra: -[MusicData setLevelN:H:Ex:] @ 0xc776c
- (void)setLevelN:(int)n H:(int)h Ex:(int)ex;

// The audio + chart entries stored in the .orb zip (BF-decoded on demand). The play
// scene loads `music` as the BGM and one of the three sheets as the note chart, per
// the chosen difficulty. Ghidra: getZipData: wrappers @ 0xc78d8/0xc78f4/0xc7910/
// 0xc792c/0xc7948.
- (NSData *)music;         // "bgm"     — the full BGM
- (NSData *)musicPre;      // "pre"     — the preview clip
- (NSData *)sheetNormal;   // "sheet_n"
- (NSData *)sheetHyper;    // "sheet_h"
- (NSData *)sheetEx;       // "sheet_ex"

// The @2x artwork / music-name-image PNGs stored in the .orb zip, decoded on
// demand. The result screen uploads these straight into GPU textures. Ghidra:
// -[MusicData artwork2xData] (selector @ 0x15a894, PlayResultTask FUN_0003dfe0
// @ 0x3e8ec) / -[MusicData musicNameImage2xData] (selector @ 0x15a818 @ 0x3e928).
- (NSData *)artwork2xData;
- (NSData *)musicNameImage2xData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
