//
//  StorePackInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackInfo.h"
#import "StoreUtil.h"
#import "StoreMusicInfo.h"
#import "StoreAcMusicInfo.h"
#import <StoreKit/StoreKit.h>

@implementation StorePackInfo

// @ 0x568ac — record the pack id; product/details are filled in later.
- (instancetype)initWithPackID:(int)packID {
    if ((self = [super init])) {
        [self setPackID:packID];
    }
    return self;
}

// @ 0x5680c — build straight from a resolved product; derive the pack id from it.
- (instancetype)initWithProduct:(SKProduct *)product {
    if ((self = [super init]) && product != nil) {
        [self setProduct:product];
        [self setPackID:[StoreUtil packIDForProductID:m_Product.productIdentifier]];
    }
    return self;
}

// @ 0x57370 / 0x5692c
- (int)packID {
    return m_PackID;
}

- (void)setPackID:(int)packID {
    m_PackID = packID;
}

// @ 0x573b0
- (SKProduct *)product {
    return m_Product;
}

// @ 0x568f4 — bind the StoreKit product exactly once.
- (BOOL)setProduct:(SKProduct *)product {
    if (m_Product == nil) {
        if (product == nil) {
            return NO;
        }
        m_Product = [product retain];
        return YES;
    }
    return NO;
}

// @ 0x5693c — apply a server pack dictionary; only if the id matches ours.
- (BOOL)setDictionary:(NSDictionary *)dictionary {
    if ([dictionary[@"ID"] intValue] != m_PackID) {
        return NO;
    }

    NSArray *musicList = dictionary[@"MusicList"];
    NSArray *acvMusicList = dictionary[@"AcvMusicList"];

    [m_PackName release];
    m_PackName = nil;
    if (dictionary[@"Name"] != nil) {
        m_PackName = [dictionary[@"Name"] retain];
    }

    [m_Comment release];
    m_Comment = nil;
    if (dictionary[@"Comment"] != nil) {
        m_Comment = [dictionary[@"Comment"] retain];
    }

    [m_ShortComment release];
    m_ShortComment = nil;
    if (dictionary[@"ShortComment"] != nil) {
        m_ShortComment = [dictionary[@"ShortComment"] retain];
    }

    if (dictionary[@"IsNew"] != nil) {
        m_IsNew = [dictionary[@"IsNew"] boolValue];
    }

    [m_Copyright release];
    m_Copyright = nil;
    if (dictionary[@"Copyright"] != nil) {
        m_Copyright = [dictionary[@"Copyright"] retain];
    }

    [m_ArtworkURL release];
    m_ArtworkURL = nil;
    NSString *artworkURL = dictionary[@"ArtworkURL"];
    if (artworkURL != nil && [StoreUtil isValidURL:artworkURL]) {
        m_ArtworkURL = [artworkURL retain];
    }

    [m_ArtistURL release];
    m_ArtistURL = nil;
    NSString *artistURL = dictionary[@"ArtistURL"];
    if ([artistURL isKindOfClass:NSString.class] && [StoreUtil isValidURL:artistURL]) {
        m_ArtistURL = [artistURL retain];
    }

    [m_ArtistBunnerURL release];
    m_ArtistBunnerURL = nil;
    NSString *bannerURL = dictionary[@"ArtistBunnerURL"];
    if ([bannerURL isKindOfClass:NSString.class] && [StoreUtil isValidURL:bannerURL]) {
        m_ArtistBunnerURL = [bannerURL retain];
    }

    m_AcvNum = (dictionary[@"AcvNum"] != nil) ? [dictionary[@"AcvNum"] intValue] : 0;

    [self setAcvMusicInfo:acvMusicList];
    return [self setMusicInfo:musicList];
}

// @ 0x56d7c — build up to 4 StoreMusicInfo; ignored if already built.
- (BOOL)setMusicInfo:(NSArray *)musicList {
    if (m_MusicInfos != nil) {
        return YES;
    }
    if (musicList.count == 0) {
        return NO;
    }
    NSMutableArray *infos = [NSMutableArray arrayWithCapacity:4];
    for (NSDictionary *dict in musicList) {
        StoreMusicInfo *info = [[StoreMusicInfo alloc] initWithDictionary:dict];
        if (info != nil) {
            [infos addObject:info];
            [info release];
            if (infos.count > 3) {
                break;   // at most 4 songs shown per pack
            }
        }
    }
    if (infos.count != 0) {
        m_MusicInfos = [[NSArray alloc] initWithArray:infos];
        return YES;
    }
    return NO;
}

// @ 0x56f40 — build the arcade-viewer song list; ignored if already built.
- (BOOL)setAcvMusicInfo:(NSArray *)acvMusicList {
    if (m_AcvMusicInfos != nil) {
        return YES;
    }
    if (acvMusicList.count == 0) {
        return NO;
    }
    NSMutableArray *infos = [NSMutableArray arrayWithCapacity:4];
    for (NSDictionary *dict in acvMusicList) {
        StoreAcMusicInfo *info = [[StoreAcMusicInfo alloc] initWithDictionary:dict];
        if (info != nil) {
            [infos addObject:info];
            [info release];
        }
    }
    if (infos.count != 0) {
        m_AcvMusicInfos = [[NSArray alloc] initWithArray:infos];
        return YES;
    }
    return NO;
}

// @ 0x573a0 / 0x573d0 / 0x573c0 — name, full comment, short blurb.
- (NSString *)packName {
    return m_PackName;
}

// @ 0x573d0 (the accessor for m_Comment; the decompiler mis-typed its signature).
- (NSString *)comment {
    return m_Comment;
}

// @ 0x573c0
- (NSString *)s_comment {
    return m_ShortComment;
}

// @ 0x57380
- (BOOL)isNew {
    return m_IsNew;
}

// @ 0x573e0
- (NSString *)copyright {
    return m_Copyright;
}

// @ 0x57390 + the sibling URL accessors populated by setDictionary:.
- (NSString *)artworkURL {
    return m_ArtworkURL;
}

- (NSString *)artistURL {
    return m_ArtistURL;
}

- (NSString *)artistBunnerURL {
    return m_ArtistBunnerURL;
}

// @ 0x57430
- (int)acvNum {
    return m_AcvNum;
}

- (NSArray *)musicInfos {
    return m_MusicInfos;
}

- (NSArray *)acvMusicInfos {
    return m_AcvMusicInfos;
}

// @ 0x571fc — YES once every song in the pack (both the standard and arcade lists) has
// its purchased file on disk.
- (BOOL)allDownloaded {
    for (StoreMusicInfo *info in m_MusicInfos) {
        if (![info fileExist]) {
            return NO;
        }
    }
    for (StoreAcMusicInfo *info in m_AcvMusicInfos) {
        if (![info fileExist]) {
            return NO;
        }
    }
    return YES;
}

// @ 0x56d50 — always formatted live from the bound product.
- (NSString *)priceString {
    return [StoreUtil priceString:m_Product];
}

- (void)dealloc {
    [m_Product release];
    [m_PackName release];
    [m_Comment release];
    [m_ShortComment release];
    [m_Copyright release];
    [m_ArtworkURL release];
    [m_ArtistURL release];
    [m_ArtistBunnerURL release];
    [m_MusicInfos release];
    [m_AcvMusicInfos release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
