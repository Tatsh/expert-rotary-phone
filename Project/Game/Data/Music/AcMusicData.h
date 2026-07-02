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

@property (nonatomic) int acMusicId;            // Ghidra: acMusicId @ 0x666ec
@property (nonatomic, copy) NSString *musicName;
@property (nonatomic, copy) NSString *musicNameKana;
@property (nonatomic, copy) NSString *genreName;
@property (nonatomic, copy) NSString *genreNameKana;
@property (nonatomic) int lvEasy;
@property (nonatomic) int lvNormal;
@property (nonatomic) int lvHyper;
@property (nonatomic) int lvEx;                 // Ghidra: lvEx @ 0x6673c
@property (nonatomic, copy) NSString *bpmEasy;
@property (nonatomic, copy) NSString *bpmNormal;
@property (nonatomic, copy) NSString *bpmHyper;
@property (nonatomic, copy) NSString *bpmEx;
@property (nonatomic) int category;             // clamped to 0..23
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *musicNameInitial;
@property (nonatomic, copy) NSString *genreNameInitial;

// Decode a record from its .orb path (nil on id mismatch).
// Ghidra: +[AcMusicData dataWithPath:ID:] @ 0x65e2c
+ (instancetype)dataWithPath:(NSString *)path ID:(int)acMusicId;

// The decoded note chart for each difficulty tier — the ZIP entries "sheet_es"/
// "sheet_n"/"sheet_h"/"sheet_ex" of the .acv, BF-decrypted (4-byte header +
// 20-byte note records; see NoteMng). The play loader picks one by difficulty and
// hands it to -[NoteMng initPlayDataWithData:].
// Ghidra: sheetEasy @ 0x66418 / sheetNormal @ 0x66434 / sheetHyper @ 0x66450 /
// sheetEx @ 0x6646c.
- (NSData *)sheetEasy;
- (NSData *)sheetNormal;
- (NSData *)sheetHyper;
- (NSData *)sheetEx;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
