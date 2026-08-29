/**
 * @file
 * @brief A single local (pop'n) song record, decoded from its "%09d.orb" file.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * The .orb is a zipped JSON dict with the keys ID, MusicName, MusicNameHira, ArtistName,
 * ArtistNameHira, Normal, Hyper, Ex, BpmMin and BpmMax. Sort initials (kana "yomi") are derived
 * from the *Hira reading strings.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One local song's metadata, charts, BGM and artwork.
 */
@interface MusicData : NSObject

/** The music id. Ghidra @ 0xc7cc0. */
@property(nonatomic) int MusicID;
// The four display-name strings compile to atomic copy getters (objc_getProperty), unlike the sort
// and initial strings below whose getters are plain nonatomic ivar loads.

/** The song title. Ghidra @ 0xc7d38. */
@property(copy) NSString *musicName;
/** The song title's hiragana reading. Ghidra @ 0xc7d4c. */
@property(copy) NSString *musicNameHira;
/** The artist name. Ghidra @ 0xc7d60. */
@property(copy) NSString *artistName;
/** The artist name's hiragana reading. Ghidra @ 0xc7d74. */
@property(copy) NSString *artistNameHira;
/** The Normal chart level. Ghidra @ 0xc7cd4. */
@property(nonatomic) int lvNormal;
/** The Hyper chart level. Ghidra @ 0xc7ce8. */
@property(nonatomic) int lvHyper;
/** The EX chart level. Ghidra @ 0xc7cfc. */
@property(nonatomic) int lvEx;
/** The lower bound of the song's BPM range. Ghidra @ 0xc7d10. */
@property(nonatomic) int bpm_MIN;
/** The upper bound of the song's BPM range. Ghidra @ 0xc7d24. */
@property(nonatomic) int bpm_MAX;
/** The path of the .orb file this record was decoded from. */
@property(nonatomic, copy) NSString *filePath;
/** The .orb decode variant this record was read with. */
@property(nonatomic) int decodeType;
/** The song title's sort key. Ghidra @ 0xc7d88. */
@property(nonatomic, copy) NSString *musicSortName;
/** The artist name's sort key. Ghidra @ 0xc7d9c. */
@property(nonatomic, copy) NSString *artistSortName;
/** The song title's sort initial. Ghidra @ 0xc7db0. */
@property(nonatomic, copy) NSString *musicNameInitial;
/** The artist name's sort initial. Ghidra @ 0xc7dc4. */
@property(nonatomic, copy) NSString *artistNameInitial;

/**
 * @brief Decode and validate a song record from its .orb path.
 * @param path The .orb file path.
 * @param musicId The expected music id.
 * @return The decoded record, or nil when the id does not match or a level is out of range.
 * @ghidraAddress 0xc72c8
 */
+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicId;

/**
 * @brief Override the three difficulty levels; used by MusicManager level patches.
 * @param n The Normal level.
 * @param h The Hyper level.
 * @param ex The EX level.
 * @ghidraAddress 0xc776c
 */
- (void)setLevelN:(int)n H:(int)h Ex:(int)ex;

// The audio and chart entries stored in the .orb zip, BF-decoded on demand. The play scene loads
// `music` as the BGM and one of the three sheets as the note chart, per the chosen difficulty.

/**
 * @brief The full BGM, from the "bgm" ZIP entry.
 * @return The decrypted audio.
 * @ghidraAddress 0xc78d8
 */
- (NSData *)music;
/**
 * @brief The preview clip, from the "pre" ZIP entry.
 * @return The decrypted audio.
 * @ghidraAddress 0xc78f4
 */
- (NSData *)musicPre;
/**
 * @brief The Normal note chart, from the "sheet_n" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0xc7910
 */
- (NSData *)sheetNormal;
/**
 * @brief The Hyper note chart, from the "sheet_h" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0xc792c
 */
- (NSData *)sheetHyper;
/**
 * @brief The EX note chart, from the "sheet_ex" ZIP entry.
 * @return The decrypted chart.
 * @ghidraAddress 0xc7948
 */
- (NSData *)sheetEx;

// The @2x artwork and name-image PNGs stored in the .orb zip, each pulled out and BF-decoded on
// demand — plain getZipData: wrappers, with no scaling. The result screen uploads these straight
// into GPU textures.

/**
 * @brief The @2x jacket artwork, from the "artwork2x" ZIP entry.
 * @return The decrypted PNG bytes.
 * @ghidraAddress 0xc7964
 */
- (NSData *)artwork2xData;
/**
 * @brief The @2x song-title image, from the "title_2x" ZIP entry.
 * @return The decrypted PNG bytes.
 * @ghidraAddress 0xc7980
 */
- (NSData *)musicNameImage2xData;
/**
 * @brief The @2x artist-name image, from the "artist_2x" ZIP entry.
 * @return The decrypted PNG bytes.
 * @ghidraAddress 0xc799c
 */
- (NSData *)artistNameImage2xData;

// Sort comparators used by MusicManager to order the song list.

/**
 * @brief The default comparator, by musicNameHira with the shorter reading first.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc79b8
 */
- (NSComparisonResult)compare:(MusicData *)other;
/**
 * @brief Compare by music id.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7a28
 */
- (NSComparisonResult)compareMusicID:(MusicData *)other;
/**
 * @brief Compare by the custom song-name sort key.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7a60
 */
- (NSComparisonResult)compareMusicNameCustom:(MusicData *)other;
/**
 * @brief Compare by the custom artist-name sort key, falling back to the song name on a tie.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7ad4
 */
- (NSComparisonResult)compareArtistNameCustom:(MusicData *)other;
/**
 * @brief Compare by the song name's hiragana reading.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7b3c
 */
- (NSComparisonResult)compareMusicNameHira:(MusicData *)other;
/**
 * @brief Compare by the artist name's hiragana reading, falling back to the song name on a tie.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7bb0
 */
- (NSComparisonResult)compareArtistNameHira:(MusicData *)other;
/**
 * @brief Compare by Normal level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7c18
 */
- (NSComparisonResult)compareDifficultyNormal:(MusicData *)other;
/**
 * @brief Compare by Hyper level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7c50
 */
- (NSComparisonResult)compareDifficultyHyper:(MusicData *)other;
/**
 * @brief Compare by EX level.
 * @param other The record to compare against.
 * @return The comparison result.
 * @ghidraAddress 0xc7c88
 */
- (NSComparisonResult)compareDifficultyEx:(MusicData *)other;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
