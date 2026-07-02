//
//  StorePackInfo.h
//  pop'n rhythmin
//
//  In-memory model of one purchasable song pack in the store: its numeric pack id,
//  the resolved StoreKit product, and the descriptive fields fetched from the pack
//  list server (name, comments, copyright, artwork/artist URLs, and the contained
//  music + arcade-viewer song lists). Price text is derived on demand from the
//  bound SKProduct via StoreUtil.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithPackID:  @ 0x568ac   initWithProduct: @ 0x5680c   setDictionary: @ 0x5693c
//    packID @ 0x57370  setPackID: @ 0x5692c   product @ 0x573b0  setProduct: @ 0x568f4
//    packName @ 0x573a0  comment @ 0x573d0  s_comment @ 0x573c0  isNew @ 0x57380
//    copyright @ 0x573e0  artworkURL @ 0x57390  acvNum @ 0x57430  priceString @ 0x56d50
//    setMusicInfo: @ 0x56d7c  setAcvMusicInfo: @ 0x56f40
//  Built/cached by StorePackListController (addPackInfoFromID: @ 0x57b28,
//  getPackInfo: @ 0x57a54).
//

#import <Foundation/Foundation.h>

@class SKProduct;

@interface StorePackInfo : NSObject {
    int m_PackID;               // numeric pack identifier (server-assigned)
    SKProduct *m_Product;       // resolved StoreKit product (bound once, see setProduct:)
    NSString *m_PackName;       // display name (dict "Name")
    NSString *m_Comment;        // full description (dict "Comment")
    NSString *m_ShortComment;   // one-line blurb (dict "ShortComment")
    BOOL m_IsNew;               // shows the "new" marker (dict "IsNew")
    NSString *m_Copyright;      // copyright line (dict "Copyright")
    NSString *m_ArtworkURL;     // pack jacket URL (validated; dict "ArtworkURL")
    NSString *m_ArtistURL;      // artist page URL (validated; dict "ArtistURL")
    NSString *m_ArtistBunnerURL;// artist banner URL (validated; dict "ArtistBunnerURL", sic)
    int m_AcvNum;               // arcade-viewer song count (dict "AcvNum")
    NSArray *m_MusicInfos;      // up to 4 StoreMusicInfo (dict "MusicList")
    NSArray *m_AcvMusicInfos;   // StoreAcMusicInfo list (dict "AcvMusicList")
}

// Designated initialisers: by pack id (product bound later), or straight from a
// resolved SKProduct (the pack id is derived from its product identifier).
- (instancetype)initWithPackID:(int)packID;
- (instancetype)initWithProduct:(SKProduct *)product;

- (int)packID;
- (void)setPackID:(int)packID;

- (SKProduct *)product;
// Set-once binder: assigns/retains only while no product is bound yet and a
// non-nil product is supplied. Returns YES if this call performed the binding.
- (BOOL)setProduct:(SKProduct *)product;

// Populate the descriptive fields + song lists from a server pack dictionary.
// No-op (returns NO) unless dict["ID"] matches this pack's id.
- (BOOL)setDictionary:(NSDictionary *)dictionary;
- (BOOL)setMusicInfo:(NSArray *)musicList;      // caps at 4 StoreMusicInfo
- (BOOL)setAcvMusicInfo:(NSArray *)acvMusicList;

- (NSString *)packName;
- (NSString *)comment;      // full description
- (NSString *)s_comment;    // short blurb (Ghidra selector "s_comment")
- (BOOL)isNew;
- (NSString *)copyright;
- (NSString *)artworkURL;
- (NSString *)artistURL;
- (NSString *)artistBunnerURL;
- (int)acvNum;
- (NSArray *)musicInfos;
- (NSArray *)acvMusicInfos;

// Localised price text, derived live from the bound SKProduct (StoreUtil).
- (NSString *)priceString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
