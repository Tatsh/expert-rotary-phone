/**
 * @file
 * The in-memory model of one purchasable song pack in the store.
 *
 * It carries the numeric pack id, the resolved StoreKit product, and the descriptive fields
 * fetched from the pack list server: name, comments, copyright, artwork and artist URLs, and the
 * contained music and arcade-viewer song lists. Price text is derived on demand from the bound
 * SKProduct via StoreUtil.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: initWithPackID: @ 0x568ac,
 * initWithProduct: @ 0x5680c, setDictionary: @ 0x5693c, packID @ 0x57370, setPackID: @ 0x5692c,
 * product @ 0x573b0, setProduct: @ 0x568f4, packName @ 0x573a0, comment @ 0x573d0, s_comment @
 * 0x573c0, isNew @ 0x57380, copyright @ 0x573e0, artworkURL @ 0x57390, acvNum @ 0x57430,
 * priceString @ 0x56d50, setMusicInfo: @ 0x56d7c, and setAcvMusicInfo: @ 0x56f40.
 * StorePackListController builds and caches it (addPackInfoFromID: @ 0x57b28, getPackInfo: @
 * 0x57a54).
 */

#import <Foundation/Foundation.h>

@class SKProduct;

/**
 * One purchasable music pack: its metadata, its StoreKit product and its song lists.
 */
@interface StorePackInfo : NSObject {
    int m_PackID;             /**< The server-assigned numeric pack identifier. */
    SKProduct *m_Product;     /**< The resolved StoreKit product; bound once, see -setProduct:. */
    NSString *m_PackName;     /**< The display name, from the dictionary key "Name". */
    NSString *m_Comment;      /**< The full description, from "Comment". */
    NSString *m_ShortComment; /**< The one-line blurb, from "ShortComment". */
    BOOL m_IsNew;             /**< Whether to show the "new" marker, from "IsNew". */
    NSString *m_Copyright;    /**< The copyright line, from "Copyright". */
    NSString *m_ArtworkURL;   /**< The pack jacket URL, validated, from "ArtworkURL". */
    NSString *m_ArtistURL;    /**< The artist page URL, validated, from "ArtistURL". */
    /** The artist banner URL, validated, from "ArtistBunnerURL"; the key's spelling is the
     * server's. */
    NSString *m_ArtistBunnerURL;
    int m_AcvNum;             /**< The arcade-viewer song count, from "AcvNum". */
    NSArray *m_MusicInfos;    /**< Up to four StoreMusicInfo, from "MusicList". */
    NSArray *m_AcvMusicInfos; /**< The StoreAcMusicInfo list, from "AcvMusicList". */
}

/**
 * Build a pack by id; the StoreKit product is bound later.
 * @param packID The pack id.
 * @return The initialised pack.
 */
- (instancetype)initWithPackID:(int)packID;
/**
 * Build a pack straight from a resolved StoreKit product; the pack id is derived from its
 * product identifier.
 * @param product The StoreKit product.
 * @return The initialised pack.
 */
- (instancetype)initWithProduct:(SKProduct *)product;

/**
 * The pack id.
 * @return The id.
 */
- (int)packID;
/**
 * Set the pack id.
 * @param packID The id.
 */
- (void)setPackID:(int)packID;

/**
 * The bound StoreKit product.
 * @return The product, or nil before one is bound.
 */
- (SKProduct *)product;
/**
 * The set-once product binder: it assigns and retains only while no product is bound yet
 * and a non-nil product is supplied.
 * @param product The product to bind.
 * @return YES when this call performed the binding.
 */
- (BOOL)setProduct:(SKProduct *)product;

/**
 * Populate the descriptive fields and song lists from a server pack dictionary.
 * @param dictionary The server pack dictionary.
 * @return NO, doing nothing, unless `dictionary["ID"]` matches this pack's id.
 */
- (BOOL)setDictionary:(NSDictionary *)dictionary;
/**
 * Set the standard song list.
 * @param musicList The StoreMusicInfo list; it is capped at four entries.
 * @return YES when the list was stored.
 */
- (BOOL)setMusicInfo:(NSArray *)musicList;
/**
 * Set the arcade song list.
 * @param acvMusicList The StoreAcMusicInfo list.
 * @return YES when the list was stored.
 */
- (BOOL)setAcvMusicInfo:(NSArray *)acvMusicList;

/**
 * The pack's display name.
 * @return The name.
 */
- (NSString *)packName;
/**
 * The pack's full description.
 * @return The description.
 */
- (NSString *)comment;
/**
 * The pack's one-line blurb. The selector's spelling is the binary's.
 * @return The blurb.
 */
- (NSString *)s_comment;
/**
 * Whether to show the "new" marker.
 * @return YES for a new pack.
 */
- (BOOL)isNew;
/**
 * The pack's copyright line.
 * @return The copyright text.
 */
- (NSString *)copyright;
/**
 * The pack jacket URL.
 * @return The URL string.
 */
- (NSString *)artworkURL;
/**
 * The artist page URL.
 * @return The URL string.
 */
- (NSString *)artistURL;
/**
 * The artist banner URL. The selector's spelling is the binary's.
 * @return The URL string.
 */
- (NSString *)artistBunnerURL;
/**
 * The arcade-viewer song count.
 * @return The count.
 */
- (int)acvNum;
/**
 * The standard song list.
 * @return An array of StoreMusicInfo.
 */
- (NSArray *)musicInfos;
/**
 * The arcade song list.
 * @return An array of StoreAcMusicInfo.
 */
- (NSArray *)acvMusicInfos;

/**
 * The localised price text, derived live from the bound StoreKit product via StoreUtil.
 * @return The price string.
 */
- (NSString *)priceString;

/**
 * Whether the pack still needs its detail info fetched: the song lists are not built yet,
 * so -setDictionary: has not run.
 * @return YES while the detail is missing.
 * @ghidraAddress 0x571e4
 */
- (BOOL)downloadDetailInfo;

/**
 * Whether every song in the pack, standard and arcade, is downloaded.
 * @return YES when the pack is fully installed.
 * @ghidraAddress 0x571fc
 */
- (BOOL)allDownloaded;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
