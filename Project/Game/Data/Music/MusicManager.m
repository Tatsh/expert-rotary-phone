//
//  MusicManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AcMusicData.h"
#import "AppDelegate.h"
#import "BFCodec.h"          // Blowfish cipher (cipherInit:/decipher:)
#import "MusicData.h"
#import "MusicManager.h"
#import "MusicPatch.h"
#import "RhUtil.h"           // RhFileExists / RhParsePlistArray / RhMD5Data

// Treasure/sugoroku song ids, one per main map (Ghidra: DAT_0012fa58).
static const int kTreasureMusicIds[9] = {
    100000000, 100000001, 100000002, 100000003, 100000004,
    100000005, 100000007, 100000006, 100000008,
};

@implementation MusicManager {
    NSMutableArray *m_MusicDataArray;
    BOOL m_MusicDataArrayDirty;
    NSMutableArray *m_AcMusicDataArray;
    BOOL m_AcMusicDataArrayDirty;
    NSMutableDictionary *m_PurchasedMusicDictionaris;
    NSMutableDictionary *m_PurchasedAcMusicDictionaris;
    NSArray *m_DefaultMusicIDs;
    NSArray *m_AcDefaultMusicIDs;
    NSArray *m_OpenTreasureMusicIDs;
    NSArray *m_OpenInviteMusicIDs;
    NSArray *m_OpenCollaboMusicIDs;
    NSArray *m_OpenLoginBonusMusicIDs;
    NSMutableArray *m_MusicLvPatchArray;
    BOOL m_IsMusicData;
}

// @ 0xc7dd8
+ (instancetype)getInstance {
    static MusicManager *sInstance = nil;
    if (sInstance == nil) {
        sInstance = [[MusicManager alloc] init];
    }
    return sInstance;
}

#pragma mark - Dirty flags / cache

// @ 0xcae18
- (void)setMusicDataArrayDirty { m_MusicDataArrayDirty = YES; }
// @ 0xcae2c
- (void)setAcMusicDataArrayDirty { m_AcMusicDataArrayDirty = YES; }
// @ 0xcb248 — no-op in this build.
- (void)releaseChacheMusicData { }

#pragma mark - Accessors

// @ 0xcae40
- (NSArray *)getMusicDataArray {
    if (m_MusicDataArray != nil && !m_MusicDataArrayDirty) {
        return m_MusicDataArray;
    }
    [self createMusicDataArray];
    return m_MusicDataArray;
}

// @ 0xcae84
- (NSArray *)getAcMusicDataArray {
    if (m_AcMusicDataArray != nil && !m_AcMusicDataArrayDirty) {
        return m_AcMusicDataArray;
    }
    [self createAcMusicDataArray];
    return m_AcMusicDataArray;
}

// @ 0xcb080 — linear search by MusicID.
- (MusicData *)getMusicData:(int)musicId {
    for (MusicData *data in m_MusicDataArray) {
        if (data.MusicID == musicId) {
            return data;
        }
    }
    return nil;
}

// @ 0xcb154 — rebuilds AC array if needed, then linear search by acMusicId.
- (AcMusicData *)getAcMusicData:(int)acMusicId {
    if (m_AcMusicDataArray == nil) {
        [self createAcMusicDataArray];
    }
    for (AcMusicData *data in m_AcMusicDataArray) {
        if (data.acMusicId == acMusicId) {
            return data;
        }
    }
    return nil;
}

// @ 0xc7e20
- (NSString *)getMusicDataFilename:(int)musicId {
    return [NSString stringWithFormat:@"%09d.orb", musicId];
}

- (NSString *)getAcMusicDataFilename:(int)acMusicId {
    // Same "%09d.orb" scheme (AC-specific prefix, if any, TBC).
    return [NSString stringWithFormat:@"%09d.orb", acMusicId];
}

// @ 0xcaec8 — every treasure song bundled with the app (one per main map).
- (NSArray *)getTreasureMusicDataArray {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 9; i++) {
        int musicId = kTreasureMusicIds[i];
        NSString *path = [self getPathFromBundle:musicId];
        if (RhFileExists(path)) {
            MusicData *data = [MusicData dataWithPath:path ID:musicId];
            if (data != nil) {
                [array addObject:data];
            }
        }
    }
    return [array mutableCopy];
}

#pragma mark - Cache building

// @ 0xca248 — assemble the playable song list from all unlock sources, then
// apply level patches. Sources: defaults, purchased, open treasure/invite/
// collabo/login-bonus songs.
- (void)createMusicDataArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];

    // 1) Default (always available) songs, bundled.
    for (NSNumber *idNum in m_DefaultMusicIDs) {
        int musicId = idNum.intValue;
        NSString *path = [self getPathFromBundle:musicId];
        if (RhFileExists(path)) {
            MusicData *data = [MusicData dataWithPath:path ID:musicId];
            if (data != nil) {
                [array addObject:data];
            }
        }
    }

    // 2) Purchased songs (downloaded into Documents), keyed "ID" in each entry.
    for (NSDictionary *entry in m_PurchasedMusicDictionaris) {
        NSNumber *idNum = entry[@"ID"];
        int musicId = idNum.intValue;
        NSString *path = [self getPathFromPurchased:musicId];
        if (RhFileExists(path)) {
            MusicData *data = [MusicData dataWithPath:path ID:musicId];
            if (data != nil) {
                [array addObject:data];
            }
        }
    }

    // 3) Unlocked treasure/invite/collabo/login-bonus songs, all bundled.
    NSArray *bundledSources[] = { m_OpenTreasureMusicIDs, m_OpenInviteMusicIDs,
                                  m_OpenCollaboMusicIDs, m_OpenLoginBonusMusicIDs };
    for (NSUInteger s = 0; s < 4; s++) {
        for (NSNumber *idNum in bundledSources[s]) {
            int musicId = idNum.intValue;
            NSString *path = [self getPathFromBundle:musicId];
            if (RhFileExists(path)) {
                MusicData *data = [MusicData dataWithPath:path ID:musicId];
                if (data != nil) {
                    [array addObject:data];
                }
            }
        }
    }

    // 4) Apply level patches (difficulty overrides) by matching musicId.
    [self createMusicLvPatchArray];
    for (MusicPatch *patch in m_MusicLvPatchArray) {
        for (MusicData *data in array) {
            if (patch.musicId == data.MusicID) {
                [data setLevelN:patch.lvN H:patch.lvH Ex:patch.lvEx];
                break;
            }
        }
    }

    m_MusicDataArray = [[NSMutableArray alloc] initWithArray:array];
    m_MusicDataArrayDirty = NO;
}

// @ 0xcaabc — arcade catalog: default AC songs (bundled, else purchased) plus
// purchased AC songs.
- (void)createAcMusicDataArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];

    for (NSNumber *idNum in m_AcDefaultMusicIDs) {
        int musicId = idNum.intValue;
        NSString *path = [NSBundle.mainBundle pathForResource:[self getAcMusicDataFilename:musicId]
                                                       ofType:nil];
        if (!RhFileExists(path)) {
            path = [self getAcPathFromPurchased:musicId];
            if (!RhFileExists(path)) {
                continue;
            }
        }
        AcMusicData *data = [AcMusicData dataWithPath:path ID:musicId];
        if (data != nil) {
            [array addObject:data];
        }
    }

    for (NSDictionary *entry in m_PurchasedAcMusicDictionaris) {
        int musicId = [entry[@"ID"] intValue];
        NSString *path = [self getAcPathFromPurchased:musicId];
        if (RhFileExists(path)) {
            AcMusicData *data = [AcMusicData dataWithPath:path ID:musicId];
            if (data != nil) {
                [array addObject:data];
            }
        }
    }

    m_AcMusicDataArray = [[NSMutableArray alloc] initWithArray:array];
    m_AcMusicDataArrayDirty = NO;
}

// @ 0xcb610 — load downloadable per-song level overrides ("rhythmin.lv", a JSON
// { "Music": [ { Id, N, H, Ex }, ... ] } in Application Support).
- (void)createMusicLvPatchArray {
    m_MusicLvPatchArray = nil;

    NSString *path = [[AppDelegate appAppSupportDirectory]
                      stringByAppendingPathComponent:@"rhythmin.lv"];
    if (!RhFileExists(path)) {
        return;
    }
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                        options:NSJSONReadingMutableContainers
                                                          error:nil];
    NSMutableArray *patches = [NSMutableArray array];
    for (NSDictionary *entry in json[@"Music"]) {
        NSNumber *idNum = entry[@"Id"];
        NSNumber *n = entry[@"N"];
        NSNumber *h = entry[@"H"];
        NSNumber *ex = entry[@"Ex"];
        if (idNum != nil && n != nil && h != nil && ex != nil) {
            MusicPatch *patch = [[MusicPatch alloc] init];
            patch.musicId = idNum.intValue;
            patch.lvN = n.intValue;
            patch.lvH = h.intValue;
            patch.lvEx = ex.intValue;
            [patches addObject:patch];
        }
    }
    m_MusicLvPatchArray = [patches mutableCopy];
}

#pragma mark - Purchased song lists (Blowfish)

// @ 0xc8820 — load "mulist"/"acmulist" from Documents, Blowfish-decrypt with the
// device uuId as key, skip the 4-byte header, parse into a dictionary.
- (void)loadPurchasedMusics {
    m_PurchasedMusicDictionaris = nil;
    m_PurchasedAcMusicDictionaris = nil;

    NSString *uuId = [AppDelegate appDelegate].uuId;

    // Local purchased songs: "mulist".
    NSString *muPath = [[AppDelegate appDocumentsDirectory]
                        stringByAppendingPathComponent:@"mulist"];
    if (RhFileExists(muPath)) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:muPath];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            m_PurchasedMusicDictionaris = RhParsePlistArray(body);
            [self setMusicDataArrayDirty];
        }
    }
    if (m_PurchasedMusicDictionaris == nil) {
        m_PurchasedMusicDictionaris = [[NSMutableArray alloc] initWithCapacity:64];
        [self setMusicDataArrayDirty];
    }

    // Arcade purchased songs: "acmulist".
    NSString *acPath = [[AppDelegate appDocumentsDirectory]
                        stringByAppendingPathComponent:@"acmulist"];
    if (RhFileExists(acPath)) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:acPath];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            m_PurchasedAcMusicDictionaris = RhParsePlistArray(body);
            [self setAcMusicDataArrayDirty];
        }
    }
    if (m_PurchasedAcMusicDictionaris == nil) {
        m_PurchasedAcMusicDictionaris = [[NSMutableArray alloc] initWithCapacity:64];
        [self setAcMusicDataArrayDirty];
    }
}

#pragma mark - Paths  [bodies inferred; confirm against getPathFromBundle_/Purchased_]

- (NSString *)getPathFromBundle:(int)musicId {
    return [NSBundle.mainBundle.resourcePath
            stringByAppendingPathComponent:[self getMusicDataFilename:musicId]];
}

- (NSString *)getPathFromPurchased:(int)musicId {
    return [[AppDelegate appDocumentsDirectory]
            stringByAppendingPathComponent:[self getMusicDataFilename:musicId]];
}

- (NSString *)getAcPathFromPurchased:(int)acMusicId {
    return [[AppDelegate appDocumentsDirectory]
            stringByAppendingPathComponent:[self getAcMusicDataFilename:acMusicId]];
}

// @ 0xc9bd0 — the recommended-pack id list: decode the encrypted "recpack" file (same
// Blowfish-with-MD5(uuid) scheme as the purchased-music lists), then collect each entry's
// "ID". Returns an empty array when there is no recommend file.
- (NSArray *)getRecommendPackArray {
    NSString *path = [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"recpack"];
    NSArray *entries = nil;
    if (RhFileExists(path)) {
        NSString *uuId = [AppDelegate appDelegate].uuId;
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            entries = RhParsePlistArray(body);
        }
    }
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *entry in entries) {
        [ids addObject:[entry objectForKey:@"ID"]];
    }
    return ids;
}

// @ 0xc9e20 — add `packID` to the encrypted "recpack" list (a no-op if it is already there).
// Decodes the existing list (same BFCodec + MD5(uuid) scheme), appends a {ID: packID} entry,
// then re-encodes it behind 4 random salt bytes and writes it back.
- (void)saveRecommendedPack:(unsigned int)packID {
    NSString *path = [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"recpack"];
    NSString *uuId = [AppDelegate appDelegate].uuId;

    NSMutableArray *entries = nil;
    if (RhFileExists(path)) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            entries = RhParsePlistArray(body);   // mutable array
            if (entries != nil) {
                for (NSDictionary *entry in entries) {
                    if ([[entry objectForKey:@"ID"] unsignedIntValue] == packID) {
                        return;   // already recommended
                    }
                }
            }
        }
    }
    if (entries == nil) {
        entries = [[NSMutableArray alloc] initWithCapacity:64];
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setObject:[NSNumber numberWithUnsignedInt:packID] forKey:@"ID"];
    [entries addObject:[NSDictionary dictionaryWithDictionary:dict]];

    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:entries
                                                            format:NSPropertyListXMLFormat_v1_0
                                                           options:0
                                                             error:NULL];
    NSMutableData *out = [[NSMutableData alloc] initWithCapacity:128];
    uint32_t salt = arc4random();
    [out appendBytes:&salt length:4];
    [out appendData:xml];

    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:RhMD5Data(uuId.UTF8String)];
    [codec encipher:out];

    [out writeToFile:path atomically:YES];
}

@end
