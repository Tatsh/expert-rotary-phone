/**
 * @file
 * @brief A single arcade ("AC") song record, decoded from its zipped JSON .orb file.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * JSON keys: ID, MusicName, MusicNameKana, GenreName, GenreNameKana, Easy, Normal, Hyper, Ex,
 * BpmEs, BpmN, BpmH, BpmEx and Category. BPM values are kept as strings, since they may be ranges
 * such as "150-180"; levels and category are ints.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The four arcade chart difficulties, in ascending order.
 *
 * It keys the per-tier level, BPM, sheet and back-track lookups.
 */
typedef NS_ENUM(NSInteger, AcvDifficulty) {
    AcvDifficultyEasy = 0,   /**< The Easy chart. */
    AcvDifficultyNormal = 1, /**< The Normal chart. */
    AcvDifficultyHyper = 2,  /**< The Hyper chart. */
    AcvDifficultyEx = 3,     /**< The EX chart. */
};

/**
 * @brief One arcade song's metadata, charts and backing tracks.
 */
@interface AcMusicData : NSObject

/** The arcade music id. Ghidra @ 0x666ec. */
@property(nonatomic) int acMusicId;
/** The song title. Ghidra @ 0x667b4. */
@property(nonatomic, copy) NSString *musicName;
/** The song title's kana reading. Ghidra @ 0x667c8. */
@property(nonatomic, copy) NSString *musicNameKana;
/** The genre name. Ghidra @ 0x667dc. */
@property(nonatomic, copy) NSString *genreName;
/** The genre name's kana reading. Ghidra @ 0x667f0. */
@property(nonatomic, copy) NSString *genreNameKana;
/** The Easy chart level. Ghidra @ 0x66700. */
@property(nonatomic) int lvEasy;
/** The Normal chart level. Ghidra @ 0x66714. */
@property(nonatomic) int lvNormal;
/** The Hyper chart level. Ghidra @ 0x66728. */
@property(nonatomic) int lvHyper;
/** The EX chart level. Ghidra @ 0x6673c. */
@property(nonatomic) int lvEx;
/** The Easy chart BPM, which may be a range. Ghidra @ 0x66750. */
@property(nonatomic, copy) NSString *bpmEasy;
/** The Normal chart BPM, which may be a range. Ghidra @ 0x66764. */
@property(nonatomic, copy) NSString *bpmNormal;
/** The Hyper chart BPM, which may be a range. Ghidra @ 0x66778. */
@property(nonatomic, copy) NSString *bpmHyper;
/** The EX chart BPM, which may be a range. Ghidra @ 0x6678c. */
@property(nonatomic, copy) NSString *bpmEx;
/** The song category, clamped to 0..23. Ghidra @ 0x667a0. */
@property(nonatomic) int category;
/** The path of the .orb file this record was decoded from. */
@property(nonatomic, copy) NSString *filePath;
/** The song title's sort initial, derived from the kana reading. Ghidra @ 0x66804. */
@property(nonatomic, copy) NSString *musicNameInitial;
/** The genre name's sort initial, derived from the kana reading. Ghidra @ 0x66818. */
@property(nonatomic, copy) NSString *genreNameInitial;

/**
 * @brief Decode a record from its .orb path.
 * @param path The .orb file path.
 * @param acMusicId The expected arcade music id.
 * @return The decoded record, or nil when the id does not match.
 * @ghidraAddress 0x65e2c
 */
+ (instancetype)dataWithPath:(NSString *)path ID:(int)acMusicId;

// The decoded note chart for each difficulty tier — the ZIP entries "sheet_es", "sheet_n",
// "sheet_h" and "sheet_ex" of the .acv, BF-decrypted (a 4-byte header plus 20-byte note records;
// see NoteMng). The play loader picks one by difficulty and hands it to -[NoteMng
// initPlayDataWithData:].

/**
 * @brief The Easy note chart, from the "sheet_es" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0x66418
 */
- (NSData *)sheetEasy;
/**
 * @brief The Normal note chart, from the "sheet_n" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0x66434
 */
- (NSData *)sheetNormal;
/**
 * @brief The Hyper note chart, from the "sheet_h" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0x66450
 */
- (NSData *)sheetHyper;
/**
 * @brief The EX note chart, from the "sheet_ex" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0x6646c
 */
- (NSData *)sheetEx;

/**
 * @brief The decoded backing (BGM) track for a difficulty tier.
 *
 * Reads the ZIP entries "bgm_es", "bgm_h" or "bgm_ex" of the .acv, BF-decrypted, and falls back to
 * "bgm_n" when the per-tier entry is absent, and for Normal.
 * @param difficulty 0 for Easy, 2 for Hyper, 3 for EX.
 * @return The decrypted backing track.
 * @ghidraAddress 0x66394
 */
- (NSData *)getBackTrack:(int)difficulty;

// Sort comparators used with sortUsingSelector:. The kana name variants tie-break a shorter
// reading before a longer one; the "Custom" variants compare with NSLiteralSearch, and genre
// defers to music name on a tie.

/**
 * @brief The default comparator, by kana song name.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x66488
 */
- (NSComparisonResult)compare:(AcMusicData *)other;
/**
 * @brief Compare by arcade music id.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x664f8
 */
- (NSComparisonResult)compareAcMusicId:(AcMusicData *)other;
/**
 * @brief Compare by song name using NSLiteralSearch.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x66530
 */
- (NSComparisonResult)compareMusicNameCustom:(AcMusicData *)other;
/**
 * @brief Compare by genre name using NSLiteralSearch, deferring to the song name on a tie.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x665a4
 */
- (NSComparisonResult)compareGenreNameCustom:(AcMusicData *)other;
/**
 * @brief Compare by Easy level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x6660c
 */
- (NSComparisonResult)compareLvEasy:(AcMusicData *)other;
/**
 * @brief Compare by Normal level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x66644
 */
- (NSComparisonResult)compareLvNormal:(AcMusicData *)other;
/**
 * @brief Compare by Hyper level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x6667c
 */
- (NSComparisonResult)compareLvHyper:(AcMusicData *)other;
/**
 * @brief Compare by EX level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0x666b4
 */
- (NSComparisonResult)compareLvEx:(AcMusicData *)other;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
