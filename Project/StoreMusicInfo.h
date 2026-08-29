/**
 * @file
 * @brief One playable song listed inside a store pack.
 *
 * It carries the id, title and artist, the purchase, sample, artwork, and iTunes links, and the
 * three difficulty levels (Basic, Medium, and Hard, each clamped to a valid range). It is built
 * from a server dictionary.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithDictionary: @ 0x56398).
 */

#import <Foundation/Foundation.h>

/**
 * @brief One song listed inside a store pack.
 */
@interface StoreMusicInfo : NSObject {
    int m_MusicID;          /**< The song id. */
    NSString *m_Name;       /**< The song title. */
    NSString *m_Artist;     /**< The artist name. */
    NSString *m_ItemURL;    /**< The pack or product link. */
    NSString *m_SampleURL;  /**< The preview clip; kept only when it is a valid HTTP(S) URL. */
    NSString *m_ArtworkURL; /**< The jacket; kept only when it is a valid URL. */
    NSString *m_iTunesURL;  /**< The iTunes link; kept only when it is a valid URL. */
    int m_LvBasic;          /**< The basic difficulty level, 1..10. */
    int m_LvMedium;         /**< The medium difficulty level, 1..10. */
    int m_LvHard;           /**< The hard difficulty level, 1..11. */
}

/**
 * @brief Build a song from a server dictionary.
 * @param dictionary The server song dictionary.
 * @return The initialised song, or nil when the dictionary has no positive "ID".
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

/** The song id. */
@property(nonatomic, readonly) int musicID;
/** The song title. */
@property(nonatomic, readonly) NSString *name;
/** The artist name. */
@property(nonatomic, readonly) NSString *artist;
/** The pack or product link. */
@property(nonatomic, readonly) NSString *itemURL;
/** The preview clip URL, or nil when the server's value was not a valid URL. */
@property(nonatomic, readonly) NSString *sampleURL;
/** The jacket URL, or nil when the server's value was not a valid URL. */
@property(nonatomic, readonly) NSString *artworkURL;
/** The iTunes link, or nil when the server's value was not a valid URL. */
@property(nonatomic, readonly) NSString *iTunesURL;
/** The basic difficulty level. */
@property(nonatomic, readonly) int lvBasic;
/** The medium difficulty level. */
@property(nonatomic, readonly) int lvMedium;
/** The hard difficulty level. */
@property(nonatomic, readonly) int lvHard;

/**
 * @brief Whether this song's purchased file is already on disk.
 * @return YES when the file exists.
 * @ghidraAddress 0x56678
 */
- (BOOL)fileExist;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
