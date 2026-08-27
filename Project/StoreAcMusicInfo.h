//
//  StoreAcMusicInfo.h
//  pop'n rhythmin
//
//  One arcade-viewer song listed inside a store pack: id, title, genre, and the
//  purchase + sample links. Built from a server dictionary.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithDictionary: @ 0x852dc).
//

#import <Foundation/Foundation.h>

/**
 * @brief One arcade song listed inside a store pack.
 */
@interface StoreAcMusicInfo : NSObject {
    int m_AcMusicId;       /**< The arcade song id. */
    NSString *m_Title;     /**< The song title. */
    NSString *m_Genre;     /**< The genre name. */
    NSString *m_ItemURL;   /**< The pack or product link. */
    NSString *m_SampleURL; /**< The preview clip URL. */
}

/**
 * @brief Build an arcade song from a server dictionary.
 * @param dictionary The server song dictionary.
 * @return The initialised song, or nil when the dictionary has no positive "ID".
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

/** The arcade song id. */
@property(nonatomic, readonly) int acMusicId;
/** The song title. */
@property(nonatomic, readonly) NSString *title;
/** The genre name. */
@property(nonatomic, readonly) NSString *genre;
/** The pack or product link. */
@property(nonatomic, readonly) NSString *itemURL;
/** The preview clip URL. */
@property(nonatomic, readonly) NSString *sampleURL;

/**
 * @brief Whether this arcade song's purchased file is already on disk.
 * @return YES when the file exists.
 * @ghidraAddress 0x85418
 */
- (BOOL)fileExist;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
