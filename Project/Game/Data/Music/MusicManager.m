//
//  MusicManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "MusicManager.h"
#import "AcMusicData.h"
#import "AppDelegate.h"
#import "BFCodec.h"      // Blowfish cipher (cipherInit:/decipher:)
#import "DownloadMain.h" // login-bonus id/count (getInstance/loginBonusId/loginCnt)
#import "MusicData.h"
#import "MusicPatch.h"
#import "RhUtil.h"             // RhFileExists / RhParsePlistArray / RhMD5Data
#import "StoreAcMusicInfo.h"   // -acMusicId/... (addPurchasedAcMusic:)
#import "StoreMusicInfo.h"     // -musicID/name/artist/itemURL/itunesURL (addPurchasedMusic:)
#import "TreasureData+Store.h" // +isOpenMusic:inManagedObjectContext:
#import "UserSettingData.h"    // inviteCnt / getOpenedLoginBonusId / isBemaniCollaboOpened
#import <UIKit/UIKit.h>

// LoginBonusView is a UI class without a project header in this reconstruction;
// only its +getRewardMaxCnt class method is referenced from here (Ghidra:
// LoginBonusView getRewardMaxCnt).
@interface LoginBonusView : NSObject
+ (int)getRewardMaxCnt;
@end

// Treasure/sugoroku song ids, one per main map (Ghidra: DAT_0012fa58).
static const int kTreasureMusicIds[9] = {
    100000000,
    100000001,
    100000002,
    100000003,
    100000004,
    100000005,
    100000007,
    100000006,
    100000008,
};

// Always-available bundled song ids (Ghidra: DAT_0012fa4c).
static const int kDefaultMusicIds[3] = {1, 2, 3};

// Default arcade catalog ids (Ghidra: DAT_0012fa80).
static const int kAcDefaultMusicIds[4] = {1, 2, 3, 300000000};

@implementation MusicManager {
    NSMutableArray *m_MusicDataArray;
    BOOL m_MusicDataArrayDirty;
    NSMutableArray *m_AcMusicDataArray;
    BOOL m_AcMusicDataArrayDirty;
    NSMutableArray *m_PurchasedMusicDictionaris;   // array OF plist dicts (name is a misnomer)
    NSMutableArray *m_PurchasedAcMusicDictionaris; // array OF plist dicts (name
                                                   // is a misnomer)
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

#pragma mark - Lifecycle

// @ 0xc81dc — build all of the built-in song tables up front. Purchased lists
// and level patches are loaded lazily/separately.
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        [self createDefaultMusics];
        [self createOpenTreasureMusics];
        [self createOpenInviteMusics];
        [self createOpenCollaboMusics];
        [self createOpenLoginBonusMusics];
        [self createAcDefaultMusics];
    }
    return self;
}

// @ 0xc827c — releases m_DefaultMusicIDs, m_PurchasedMusicDictionaris,
// m_PurchasedAcMusicDictionaris, m_MusicDataArray, m_AcDefaultMusicIDs and
// m_AcMusicDataArray, then [super dealloc]. All object-ivar cleanup; nothing
// else. Under ARC this is automatic, so -dealloc is omitted.

#pragma mark - Built-in song tables

// @ 0xc8384 — the three always-available bundled songs.
- (void)createDefaultMusics {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        [array addObject:[NSNumber numberWithInt:kDefaultMusicIds[i]]];
    }
    m_DefaultMusicIDs = [[NSArray alloc] initWithArray:array];
}

// @ 0xc8440 — treasure songs, one per main map (0..8), included only when the
// map's music-piece collection gate is open.
- (void)createOpenTreasureMusics {
    NSMutableArray *array = [NSMutableArray array];
    NSManagedObjectContext *moc = [AppDelegate appDelegate].managedObjectContext;
    for (int i = 0; i < 9; i++) {
        if ([TreasureData isOpenMusic:(short)i inManagedObjectContext:moc]) {
            [array addObject:[NSNumber numberWithInt:kTreasureMusicIds[i]]];
        }
    }
    m_OpenTreasureMusicIDs = array;
}

// @ 0xc8554 — invite-reward song (id 4), gated by the invite predicate.
- (void)createOpenInviteMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenInviteMusic:0]) {
        [array addObject:[NSNumber numberWithInt:4]];
    }
    m_OpenInviteMusicIDs = array;
}

// @ 0xc8604 — BEMANI-collabo song (id 5), gated by the collabo predicate.
- (void)createOpenCollaboMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenBemaniCollaboMusic]) {
        [array addObject:[NSNumber numberWithInt:5]];
    }
    m_OpenCollaboMusicIDs = array;
}

// @ 0xc86b4 — login-bonus song (id 6), gated by the login-bonus predicate.
- (void)createOpenLoginBonusMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenLoginBonusMusic:0]) {
        [array addObject:[NSNumber numberWithInt:6]];
    }
    m_OpenLoginBonusMusicIDs = array;
}

// @ 0xc8764 — default arcade catalog ids.
- (void)createAcDefaultMusics {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        [array addObject:[NSNumber numberWithInt:kAcDefaultMusicIds[i]]];
    }
    m_AcDefaultMusicIDs = [[NSArray alloc] initWithArray:array];
}

#pragma mark - Unlock gates

// @ 0xc7f94 — invite-reward unlock predicate. `index` selects the reward tier:
// tier 2 requires at least 7 accepted invites; tiers 0 and 1 require at least
// 5; any higher tier is never open. (Ghidra: reads UserSettingData.inviteCnt.)
+ (BOOL)isOpenInviteMusic:(int)index {
    int inviteCnt = [UserSettingData inviteCnt];
    if (index == 2) {
        if (inviteCnt < 7) {
            return NO;
        }
    } else if (index > 1 || inviteCnt < 5) {
        return NO;
    }
    return YES;
}

// YES if `musicId` is the invite-reward song (id 4).
+ (BOOL)isInviteMusic:(int)musicId {
    return musicId == 4;
} // @ 0xc7fd4

// @ 0xc7fe0 — BEMANI-collabo (jubeat plus x REFLEC BEAT plus x GITADORA) unlock
// predicate. Open when the bundled collabo song (id 5) is present AND either
// the saved collabo flag is set or all three companion BEMANI apps are
// installed (their URL schemes can be opened).
+ (BOOL)isOpenBemaniCollaboMusic {
    NSString *path = [MusicManager getPathFromBundle:5];
    if (!RhFileExists(path)) {
        return NO;
    }
    if ([UserSettingData isBemaniCollaboOpened]) {
        return YES;
    }
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:@"jubeatplus:"]] &&
        [app canOpenURL:[NSURL URLWithString:@"rbplus:"]] &&
        [app canOpenURL:[NSURL URLWithString:@"gitadora:"]]) {
        return YES;
    }
    return NO;
}

// @ 0xc8108 — login-bonus unlock predicate. `index` is the requested
// login-bonus reward tier. Requires a non-negative saved opened-login-bonus id
// and that the tier's bundled song file exists. An already-passed tier (index
// <= opened id) is open; the current tier (matching the DownloadMain
// login-bonus id) opens once the day count reaches the reward maximum. (Ghidra:
// DAT_0012fa48 is the login-bonus song-id table {6, ...}, indexed by the opened
// id.)
+ (BOOL)isOpenLoginBonusMusic:(int)index {
    if (index < 0) {
        return NO;
    }
    int openedId = [UserSettingData getOpenedLoginBonusId];
    if (openedId < 0) {
        return NO;
    }
    // Login-bonus song ids, indexed by the opened-login-bonus id (Ghidra
    // DAT_0012fa48). Only tier 0 (song id 6) exists in this build.
    static const int kLoginBonusMusicIds[] = {6};
    int musicId = kLoginBonusMusicIds[openedId];
    NSString *path = [MusicManager getPathFromBundle:musicId];
    if (!RhFileExists(path)) {
        return NO;
    }
    if (index <= openedId) {
        return YES;
    }
    DownloadMain *download = [DownloadMain getInstance];
    if (download.loginBonusId == index && download.loginCnt >= [LoginBonusView getRewardMaxCnt]) {
        return YES;
    }
    return NO;
}

#pragma mark - Dirty flags / cache

// @ 0xcae18
- (void)setMusicDataArrayDirty {
    m_MusicDataArrayDirty = YES;
}
// @ 0xcae2c
- (void)setAcMusicDataArrayDirty {
    m_AcMusicDataArrayDirty = YES;
}
// @ 0xcb248 — no-op in this build.
- (void)releaseChacheMusicData {
}

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

// @ 0xc7e20 — class method in the binary (stateless; no instance ivars).
+ (NSString *)getMusicDataFilename:(int)musicId {
    return [NSString stringWithFormat:@"%09d.orb", musicId];
}

// @ 0xc7e50
- (NSString *)getAcMusicDataFilename:(int)acMusicId {
    // Same "%09d.orb" scheme (AC-specific prefix, if any, TBC).
    return [NSString stringWithFormat:@"%09d.orb", acMusicId];
}

// @ 0xcaec8 — every treasure song bundled with the app (one per main map).
- (NSArray *)getTreasureMusicDataArray {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 9; i++) {
        int musicId = kTreasureMusicIds[i];
        NSString *path = [MusicManager getPathFromBundle:musicId];
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
        NSString *path = [MusicManager getPathFromBundle:musicId];
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
    NSArray *bundledSources[] = {m_OpenTreasureMusicIDs,
                                 m_OpenInviteMusicIDs,
                                 m_OpenCollaboMusicIDs,
                                 m_OpenLoginBonusMusicIDs};
    for (NSUInteger s = 0; s < 4; s++) {
        for (NSNumber *idNum in bundledSources[s]) {
            int musicId = idNum.intValue;
            NSString *path = [MusicManager getPathFromBundle:musicId];
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

    NSString *path =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"rhythmin.lv"];
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

// @ 0xc8820 — load "mulist"/"acmulist" from Documents, Blowfish-decrypt with
// the device uuId as key, skip the 4-byte header, parse into a dictionary.
- (void)loadPurchasedMusics {
    m_PurchasedMusicDictionaris = nil;
    m_PurchasedAcMusicDictionaris = nil;

    NSString *uuId = [AppDelegate appDelegate].uuId;

    // Local purchased songs: "mulist".
    NSString *muPath =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"mulist"];
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
    NSString *acPath =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"acmulist"];
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

// @ 0xc7e80 — class method in the binary. It uses no instance state, so the
// original calls it on the MusicManager class object (never through
// getInstance). That is what keeps the init-time open-song predicates
// (isOpenBemaniCollaboMusic / isOpenLoginBonusMusic, which run inside -init)
// from re-entering getInstance before its singleton global is assigned. The
// prior reconstruction made this an instance method, so those predicates called
// [[MusicManager getInstance] ...] and recursed forever during init -> stack
// overflow (SIGSEGV). NOTE: the binary's base directory is
// AppDelegate::appAppSupportDirectory (0xc7e80), not mainBundle.resourcePath --
// corrected below to match the binary (the .orb data files live under
// Application Support, not the app bundle).
+ (NSString *)getPathFromBundle:(int)musicId {
    return [[AppDelegate appAppSupportDirectory]
        stringByAppendingPathComponent:[MusicManager getMusicDataFilename:musicId]];
}

- (NSString *)getPathFromPurchased:(int)musicId {
    return [[AppDelegate appDocumentsDirectory]
        stringByAppendingPathComponent:[MusicManager getMusicDataFilename:musicId]];
}

- (NSString *)getAcPathFromPurchased:(int)acMusicId {
    return [[AppDelegate appDocumentsDirectory]
        stringByAppendingPathComponent:[self getAcMusicDataFilename:acMusicId]];
}

// @ 0xc9bd0 — the recommended-pack id list: decode the encrypted "recpack" file
// (same Blowfish-with-MD5(uuid) scheme as the purchased-music lists), then
// collect each entry's "ID". Returns an empty array when there is no recommend
// file.
- (NSArray *)getRecommendPackArray {
    NSString *path =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"recpack"];
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

// @ 0xc9e20 — add `packID` to the encrypted "recpack" list (a no-op if it is
// already there). Decodes the existing list (same BFCodec + MD5(uuid) scheme),
// appends a {ID: packID} entry, then re-encodes it behind 4 random salt bytes
// and writes it back.
- (void)saveRecommendedPack:(unsigned int)packID {
    NSString *path =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"recpack"];
    NSString *uuId = [AppDelegate appDelegate].uuId;

    NSMutableArray *entries = nil;
    if (RhFileExists(path)) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            entries = RhParsePlistArray(body); // mutable array
            if (entries != nil) {
                for (NSDictionary *entry in entries) {
                    if ([[entry objectForKey:@"ID"] unsignedIntValue] == packID) {
                        return; // already recommended
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

// @ 0xc8bec — Blowfish-encrypt each non-empty purchased list (device-uuid MD5
// key) behind 4 random salt bytes and write it back to "mulist"/"acmulist".
- (void)savePurchasedMusics {
    NSString *uuId = [AppDelegate appDelegate].uuId;

    if (m_PurchasedMusicDictionaris.count != 0) {
        NSString *path =
            [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"mulist"];
        NSData *xml = [NSPropertyListSerialization dataWithPropertyList:m_PurchasedMusicDictionaris
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                                options:0
                                                                  error:NULL];
        NSMutableData *out = [[NSMutableData alloc] initWithCapacity:0x80];
        uint32_t salt = arc4random();
        [out appendBytes:&salt length:4];
        [out appendData:xml];

        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:RhMD5Data(uuId.UTF8String)];
        [codec encipher:out];
        [out writeToFile:path atomically:YES];
    }

    if (m_PurchasedAcMusicDictionaris.count != 0) {
        NSString *path =
            [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"acmulist"];
        NSData *xml =
            [NSPropertyListSerialization dataWithPropertyList:m_PurchasedAcMusicDictionaris
                                                       format:NSPropertyListXMLFormat_v1_0
                                                      options:0
                                                        error:NULL];
        NSMutableData *out = [[NSMutableData alloc] initWithCapacity:0x80];
        uint32_t salt = arc4random();
        [out appendBytes:&salt length:4];
        [out appendData:xml];

        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:RhMD5Data(uuId.UTF8String)];
        [codec encipher:out];
        [out writeToFile:path atomically:YES];
    }
}

#pragma mark - Purchased list accessors

// @ 0xc8f28 — synthesized-style accessor.
- (NSMutableArray *)getPurchasedMusicDictionaris {
    return m_PurchasedMusicDictionaris;
}
// @ 0xc8f38 — synthesized-style accessor.
- (NSMutableArray *)getPurchasedAcMusicDictionaris {
    return m_PurchasedAcMusicDictionaris;
}

// @ 0xc8f48 — merge `item` into the local purchased list. If an entry with the
// same ID exists, update any differing metadata (returns YES only if something
// changed); otherwise append a new entry (always YES). Marks the cache dirty.
- (BOOL)addPurchasedMusic:(id)item {
    unsigned int musicID = (unsigned int)[item musicID];
    NSUInteger count = m_PurchasedMusicDictionaris.count;
    for (NSUInteger i = 0; i < count; i++) {
        NSDictionary *entry = [m_PurchasedMusicDictionaris objectAtIndex:i];
        if ([[entry objectForKey:@"ID"] unsignedIntValue] == musicID) {
            NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:entry];
            BOOL changed = NO;
            if ([item name] != nil && ![[item name] isEqualToString:[entry objectForKey:@"Name"]]) {
                [merged setObject:[item name] forKey:@"Name"];
                changed = YES;
            }
            if ([item artist] != nil &&
                ![[item artist] isEqualToString:[entry objectForKey:@"Artist"]]) {
                [merged setObject:[item artist] forKey:@"Artist"];
                changed = YES;
            }
            if ([item itemURL] != nil &&
                ![[item itemURL] isEqualToString:[entry objectForKey:@"ItemURL"]]) {
                [merged setObject:[item itemURL] forKey:@"ItemURL"];
                changed = YES;
            }
            BOOL result;
            if ([item iTunesURL] != nil &&
                ![[item iTunesURL] isEqualToString:[entry objectForKey:@"iTunesURL"]]) {
                [merged setObject:[item iTunesURL] forKey:@"iTunesURL"];
                result = YES;
            } else {
                result = changed;
            }
            if (result) {
                [m_PurchasedMusicDictionaris
                    replaceObjectAtIndex:i
                              withObject:[NSDictionary dictionaryWithDictionary:merged]];
            }
            [self setMusicDataArrayDirty];
            return result;
        }
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setObject:[NSNumber numberWithUnsignedInt:musicID] forKey:@"ID"];
    [dict setObject:([item name] != nil ? [item name] : @"") forKey:@"Name"];
    [dict setObject:([item artist] != nil ? [item artist] : @"") forKey:@"Artist"];
    if ([item itemURL] != nil) {
        [dict setObject:[item itemURL] forKey:@"ItemURL"];
    }
    if ([item iTunesURL] != nil) {
        [dict setObject:[item iTunesURL] forKey:@"iTunesURL"];
    }
    [m_PurchasedMusicDictionaris addObject:[NSDictionary dictionaryWithDictionary:dict]];
    [self setMusicDataArrayDirty];
    return YES;
}

// @ 0xc93f0 — arcade counterpart of -addPurchasedMusic: (keys Title/Genre/
// ItemURL/SampleURL, matched by acMusicId). Marks the AC cache dirty.
- (BOOL)addPurchasedAcMusic:(id)item {
    unsigned int acMusicId = (unsigned int)[item acMusicId];
    NSUInteger count = m_PurchasedAcMusicDictionaris.count;
    for (NSUInteger i = 0; i < count; i++) {
        NSDictionary *entry = [m_PurchasedAcMusicDictionaris objectAtIndex:i];
        if ([[entry objectForKey:@"ID"] unsignedIntValue] == acMusicId) {
            NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:entry];
            BOOL changed = NO;
            if ([item title] != nil &&
                ![[item title] isEqualToString:[entry objectForKey:@"Title"]]) {
                [merged setObject:[item title] forKey:@"Title"];
                changed = YES;
            }
            if ([item genre] != nil &&
                ![[item genre] isEqualToString:[entry objectForKey:@"Genre"]]) {
                [merged setObject:[item genre] forKey:@"Genre"];
                changed = YES;
            }
            if ([item itemURL] != nil &&
                ![[item itemURL] isEqualToString:[entry objectForKey:@"ItemURL"]]) {
                [merged setObject:[item itemURL] forKey:@"ItemURL"];
                changed = YES;
            }
            BOOL result;
            if ([item sampleURL] != nil &&
                ![[item sampleURL] isEqualToString:[entry objectForKey:@"SampleURL"]]) {
                [merged setObject:[item sampleURL] forKey:@"SampleURL"];
                result = YES;
            } else {
                result = changed;
            }
            if (result) {
                [m_PurchasedAcMusicDictionaris
                    replaceObjectAtIndex:i
                              withObject:[NSDictionary dictionaryWithDictionary:merged]];
            }
            [self setAcMusicDataArrayDirty];
            return result;
        }
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setObject:[NSNumber numberWithUnsignedInt:acMusicId] forKey:@"ID"];
    [dict setObject:([item title] != nil ? [item title] : @"") forKey:@"Title"];
    [dict setObject:([item genre] != nil ? [item genre] : @"") forKey:@"Genre"];
    if ([item itemURL] != nil) {
        [dict setObject:[item itemURL] forKey:@"ItemURL"];
    }
    if ([item sampleURL] != nil) {
        [dict setObject:[item sampleURL] forKey:@"SampleURL"];
    }
    [m_PurchasedAcMusicDictionaris addObject:[NSDictionary dictionaryWithDictionary:dict]];
    [self setAcMusicDataArrayDirty];
    return YES;
}

#pragma mark - Delete downloaded songs

// @ 0xc9898 — remove a downloaded local song file; YES if it existed.
- (BOOL)deleteMusic:(int)musicId {
    NSString *path = [self getPathFromPurchased:musicId];
    if (!RhFileExists(path)) {
        return NO;
    }
    NSError *err = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
    [self setMusicDataArrayDirty];
    return YES;
}

// @ 0xc9914 — arcade counterpart of -deleteMusic:.
- (BOOL)deleteAcMusic:(int)acMusicId {
    NSString *path = [self getAcPathFromPurchased:acMusicId];
    if (!RhFileExists(path)) {
        return NO;
    }
    NSError *err = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
    [self setAcMusicDataArrayDirty];
    return YES;
}

// @ 0xc9990 — YES if `packID` is present in the encrypted "recpack" list (same
// BFCodec + MD5(uuid) scheme as the purchased lists).
- (BOOL)isRecommendedPack:(int)packID {
    NSString *path =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"recpack"];
    if (RhFileExists(path)) {
        NSString *uuId = [AppDelegate appDelegate].uuId;
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:RhMD5Data(uuId.UTF8String)];
            [codec decipher:data];
            NSData *body = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            NSArray *entries = RhParsePlistArray(body);
            for (NSDictionary *entry in entries) {
                if ([[entry objectForKey:@"ID"] unsignedIntValue] == (unsigned int)packID) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

#pragma mark - Unlock gate refresh

// @ 0xcafc0 — re-evaluate the treasure gate and invalidate the local cache.
- (void)openTreasureMusic {
    [self createOpenTreasureMusics];
    [self setMusicDataArrayDirty];
}
// @ 0xcaff0
- (void)openInviteMusic {
    [self createOpenInviteMusics];
    [self setMusicDataArrayDirty];
}
// @ 0xcb020
- (void)openCollaboMusic {
    [self createOpenCollaboMusics];
    [self setMusicDataArrayDirty];
}
// @ 0xcb050
- (void)openLoginBonusMusic {
    [self createOpenLoginBonusMusics];
    [self setMusicDataArrayDirty];
}

#pragma mark - Flat id lists

// @ 0xcb24c — every currently-available local song id: defaults, then purchased
// (each entry's "ID"), then unlocked treasure ids. (Invite/collabo/login-bonus
// are intentionally not included here.)
- (NSMutableArray *)getMusicIDs {
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:4];
    for (NSNumber *idNum in m_DefaultMusicIDs) {
        [ids addObject:idNum];
    }
    for (NSDictionary *entry in m_PurchasedMusicDictionaris) {
        [ids addObject:[entry objectForKey:@"ID"]];
    }
    for (NSNumber *idNum in m_OpenTreasureMusicIDs) {
        [ids addObject:idNum];
    }
    return ids;
}

// @ 0xcb474 — arcade ids: default AC ids then purchased-AC entry "ID"s.
- (NSMutableArray *)getAcMusicIDs {
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:4];
    for (NSNumber *idNum in m_AcDefaultMusicIDs) {
        [ids addObject:idNum];
    }
    for (NSDictionary *entry in m_PurchasedAcMusicDictionaris) {
        [ids addObject:[entry objectForKey:@"ID"]];
    }
    return ids;
}

// @ 0xcb948 — synthesized-style accessor.
- (NSArray *)getMusicPatchArray {
    return m_MusicLvPatchArray;
}

@end
