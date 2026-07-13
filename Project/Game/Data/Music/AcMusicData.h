//
//  AcMusicData.h
//  pop'n rhythmin
//
//  A single arcade ("AC") song record, decoded from its zipped JSON .orb file.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  JSON keys: ID, MusicName, MusicNameKana, GenreName, GenreNameKana, Easy,
//  Normal, Hyper, Ex, BpmEs, BpmN, BpmH, BpmEx, Category. Note BPM values are
//  kept as strings (ranges like "150-180"); levels and category are ints.
//

#import <Foundation/Foundation.h>

@interface AcMusicData : NSObject

@property(nonatomic) int acMusicId;                 // Ghidra: acMusicId @ 0x666ec
@property(nonatomic, copy) NSString *musicName;     // Ghidra: musicName @ 0x667b4
@property(nonatomic, copy) NSString *musicNameKana; // Ghidra: musicNameKana @ 0x667c8
@property(nonatomic, copy) NSString *genreName;     // Ghidra: genreName @ 0x667dc
@property(nonatomic, copy) NSString *genreNameKana; // Ghidra: genreNameKana @ 0x667f0
@property(nonatomic) int lvEasy;                    // Ghidra: lvEasy @ 0x66700
@property(nonatomic) int lvNormal;                  // Ghidra: lvNormal @ 0x66714
@property(nonatomic) int lvHyper;                   // Ghidra: lvHyper @ 0x66728
@property(nonatomic) int lvEx;                      // Ghidra: lvEx @ 0x6673c
@property(nonatomic, copy) NSString *bpmEasy;       // Ghidra: bpmEasy @ 0x66750
@property(nonatomic, copy) NSString *bpmNormal;     // Ghidra: bpmNormal @ 0x66764
@property(nonatomic, copy) NSString *bpmHyper;      // Ghidra: bpmHyper @ 0x66778
@property(nonatomic, copy) NSString *bpmEx;         // Ghidra: bpmEx @ 0x6678c
@property(nonatomic) int category;                  // clamped to 0..23; Ghidra: category @ 0x667a0
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, copy) NSString *musicNameInitial; // Ghidra: musicNameInitial @ 0x66804
@property(nonatomic, copy) NSString *genreNameInitial; // Ghidra: genreNameInitial @ 0x66818

// Decode a record from its .orb path (nil on id mismatch).
// Ghidra: +[AcMusicData dataWithPath:ID:] @ 0x65e2c
+ (instancetype)dataWithPath:(NSString *)path ID:(int)acMusicId;

// The decoded note chart for each difficulty tier — the ZIP entries "sheet_es"/
// "sheet_n"/"sheet_h"/"sheet_ex" of the .acv, BF-decrypted (4-byte header +
// 20-byte note records; see NoteMng). The play loader picks one by difficulty
// and hands it to -[NoteMng initPlayDataWithData:]. Ghidra: sheetEasy @ 0x66418
// / sheetNormal @ 0x66434 / sheetHyper @ 0x66450 / sheetEx @ 0x6646c.
- (NSData *)sheetEasy;
- (NSData *)sheetNormal;
- (NSData *)sheetHyper;
- (NSData *)sheetEx;

// The decoded backing (BGM) track for a difficulty tier — ZIP entries "bgm_es"/
// "bgm_h"/"bgm_ex" of the .acv, BF-decrypted; falls back to "bgm_n" when the
// per-tier entry is absent (and for Normal). difficulty: 0=Easy, 2=Hyper, 3=Ex.
// Ghidra: getBackTrack: @ 0x66394
- (NSData *)getBackTrack:(int)difficulty;

// Sort comparators (NSComparisonResult), used with sortUsingSelector:. The kana
// name variants tie-break a shorter reading before a longer one; the "Custom"
// variants compare with NSLiteralSearch and genre defers to music name on a
// tie. Ghidra: compare: @ 0x66488 / compareAcMusicId: @ 0x664f8 /
// compareMusicNameCustom: @ 0x66530 / compareGenreNameCustom: @ 0x665a4 /
// compareLvEasy: @ 0x6660c / compareLvNormal: @ 0x66644 /
// compareLvHyper: @ 0x6667c / compareLvEx: @ 0x666b4.
- (NSComparisonResult)compare:(AcMusicData *)other;
- (NSComparisonResult)compareAcMusicId:(AcMusicData *)other;
- (NSComparisonResult)compareMusicNameCustom:(AcMusicData *)other;
- (NSComparisonResult)compareGenreNameCustom:(AcMusicData *)other;
- (NSComparisonResult)compareLvEasy:(AcMusicData *)other;
- (NSComparisonResult)compareLvNormal:(AcMusicData *)other;
- (NSComparisonResult)compareLvHyper:(AcMusicData *)other;
- (NSComparisonResult)compareLvEx:(AcMusicData *)other;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
