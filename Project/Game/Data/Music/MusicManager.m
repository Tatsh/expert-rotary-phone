//
//  MusicManager.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "MusicManager.h"

#import <UIKit/UIKit.h>

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

// LoginBonusView is a UI class without a project header in this reconstruction;
// only its +getRewardMaxCnt class method is referenced from here.
@interface LoginBonusView : NSObject
+ (int)getRewardMaxCnt;
@end

// Treasure/sugoroku song IDs, one per main map.
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

// Always-available bundled song IDs.
static const int kDefaultMusicIds[3] = {1, 2, 3};

// Default arcade catalog IDs.
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

+ (instancetype)getInstance {
    static MusicManager *sInstance = nil;
    if (sInstance == nil) {
        sInstance = [[MusicManager alloc] init];
    }
    return sInstance;
}

#pragma mark - Lifecycle

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

// -dealloc releases m_DefaultMusicIDs, m_PurchasedMusicDictionaris,
// m_PurchasedAcMusicDictionaris, m_MusicDataArray, m_AcDefaultMusicIDs and
// m_AcMusicDataArray, then [super dealloc]. All object-ivar cleanup; nothing
// else. Under ARC this is automatic, so -dealloc is omitted.

#pragma mark - Built-in song tables

- (void)createDefaultMusics {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        [array addObject:[NSNumber numberWithInt:kDefaultMusicIds[i]]];
    }
    m_DefaultMusicIDs = [[NSArray alloc] initWithArray:array];
}

- (void)createOpenTreasureMusics {
    NSMutableArray *array = [NSMutableArray array];
#ifndef ENABLE_PATCHES
    NSManagedObjectContext *moc = [AppDelegate appDelegate].managedObjectContext;
#endif
    for (int i = 0; i < 9; i++) {
#ifdef ENABLE_PATCHES
        // Every treasure song is always unlocked in the preservation build.
        [array addObject:@(kTreasureMusicIds[i])];
#else
        if ([TreasureData isOpenMusic:(short)i inManagedObjectContext:moc]) {
            [array addObject:[NSNumber numberWithInt:kTreasureMusicIds[i]]];
        }
#endif
    }
    m_OpenTreasureMusicIDs = array;
}

- (void)createOpenInviteMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenInviteMusic:0]) {
        [array addObject:[NSNumber numberWithInt:4]];
    }
    m_OpenInviteMusicIDs = array;
}

- (void)createOpenCollaboMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenBemaniCollaboMusic]) {
        [array addObject:[NSNumber numberWithInt:5]];
    }
    m_OpenCollaboMusicIDs = array;
}

- (void)createOpenLoginBonusMusics {
    NSMutableArray *array = [NSMutableArray array];
    if ([MusicManager isOpenLoginBonusMusic:0]) {
        [array addObject:[NSNumber numberWithInt:6]];
    }
    m_OpenLoginBonusMusicIDs = array;
}

- (void)createAcDefaultMusics {
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        [array addObject:[NSNumber numberWithInt:kAcDefaultMusicIds[i]]];
    }
    m_AcDefaultMusicIDs = [[NSArray alloc] initWithArray:array];
}

#pragma mark - Unlock gates

+ (BOOL)isOpenInviteMusic:(int)index {
#ifdef ENABLE_PATCHES
    return YES;
#else
    int inviteCnt = [UserSettingData inviteCnt];
    if (index == 2) {
        if (inviteCnt < 7) {
            return NO;
        }
    } else if (index > 1 || inviteCnt < 5) {
        return NO;
    }
    return YES;
#endif
}

+ (BOOL)isInviteMusic:(int)musicId {
    return musicId == 4;
}

+ (BOOL)isOpenBemaniCollaboMusic {
#ifdef ENABLE_PATCHES
    return YES;
#else
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
#endif
}

+ (BOOL)isOpenLoginBonusMusic:(int)index {
#ifdef ENABLE_PATCHES
    return YES;
#else
    if (index < 0) {
        return NO;
    }
    int openedId = [UserSettingData getOpenedLoginBonusId];
    if (openedId < 0) {
        return NO;
    }
    // Login-bonus song IDs, indexed by the opened-login-bonus id. Only tier 0
    // (song id 6) exists in this build.
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
#endif
}

#pragma mark - Dirty flags / cache

- (void)setMusicDataArrayDirty {
    m_MusicDataArrayDirty = YES;
}
- (void)setAcMusicDataArrayDirty {
    m_AcMusicDataArrayDirty = YES;
}
- (void)releaseChacheMusicData {
    // No-op in this build.
}

#pragma mark - Accessors

- (NSArray *)getMusicDataArray {
    if (m_MusicDataArray != nil && !m_MusicDataArrayDirty) {
        return m_MusicDataArray;
    }
    [self createMusicDataArray];
    return m_MusicDataArray;
}

- (NSArray *)getAcMusicDataArray {
    if (m_AcMusicDataArray != nil && !m_AcMusicDataArrayDirty) {
        return m_AcMusicDataArray;
    }
    [self createAcMusicDataArray];
    return m_AcMusicDataArray;
}

- (MusicData *)getMusicData:(int)musicId {
    for (MusicData *data in m_MusicDataArray) {
        if (data.MusicID == musicId) {
            return data;
        }
    }
    return nil;
}

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

+ (NSString *)getMusicDataFilename:(int)musicId {
    // Class method in the binary (stateless; no instance ivars).
    return [NSString stringWithFormat:@"%09d.orb", musicId];
}

- (NSString *)getAcMusicDataFilename:(int)acMusicId {
    return [NSString stringWithFormat:@"ac%09d.acv", acMusicId];
}

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

- (void)createMusicLvPatchArray {
    // The filename literal is "rhythmin_lv" with an underscore, not a dot.
    m_MusicLvPatchArray = nil;

#ifdef ENABLE_PATCHES
    NSString *path = [AppDelegate appAssetsPath:@"rhythmin_lv"];
#else
    NSString *path =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"rhythmin_lv"];
#endif
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

- (void)loadPurchasedMusics {
    m_PurchasedMusicDictionaris = nil;
    m_PurchasedAcMusicDictionaris = nil;

    NSString *uuId = [AppDelegate appDelegate].uuId;

#ifdef ENABLE_PATCHES
    // The bundle install is read-only, so a shipped assets/ copy of each list is copied into
    // Documents once; Documents is the read-write store from then on.
    [self seedListFromAssets:@"mulist"];
    [self seedListFromAssets:@"acmulist"];
#endif

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

#ifdef ENABLE_PATCHES
    // Reconcile against the charts actually present, then persist to Documents only when the
    // reconciliation changed something (a dropped-in custom song, or a removed one).
    if ([self reconcilePurchasedMusics]) {
        [self savePurchasedMusics];
    }
#endif
}

#ifdef ENABLE_PATCHES
- (void)seedListFromAssets:(NSString *)name {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *destination =
        [[AppDelegate appDocumentsDirectory] stringByAppendingPathComponent:name];
    if ([fileManager fileExistsAtPath:destination]) {
        return;
    }
    NSString *source = [AppDelegate appAssetsPath:name];
    if ([fileManager fileExistsAtPath:source]) {
        [fileManager copyItemAtPath:source toPath:destination error:nil];
    }
}

- (BOOL)reconcilePurchasedMusics {
    // Songs another catalogue source provides must never also appear in a purchased
    // list, or they would load twice. This is unconditional, independent of the
    // per-boot unlock gates: the reserved/default IDs 0-3, the invite/collabo/
    // login-bonus reward IDs 4-6, and the treasure songs.
    NSMutableSet<NSNumber *> *musicExcluded = [NSMutableSet set];
    for (int reservedId = 0; reservedId <= 6; reservedId++) {
        [musicExcluded addObject:@(reservedId)];
    }
    for (size_t i = 0; i < sizeof(kTreasureMusicIds) / sizeof(kTreasureMusicIds[0]); i++) {
        [musicExcluded addObject:@(kTreasureMusicIds[i])];
    }

    // Arcade defaults (1-3 and 300000000) come from the default source.
    NSMutableSet<NSNumber *> *acExcluded = [NSMutableSet set];
    for (NSNumber *acMusicId in m_AcDefaultMusicIDs) {
        [acExcluded addObject:acMusicId];
    }

    BOOL musicChanged = [self reconcileList:m_PurchasedMusicDictionaris
                                   excluded:musicExcluded
                                     prefix:@""
                                     suffix:@".orb"];
    BOOL acChanged = [self reconcileList:m_PurchasedAcMusicDictionaris
                                excluded:acExcluded
                                  prefix:@"ac"
                                  suffix:@".acv"];

    [self setMusicDataArrayDirty];
    [self setAcMusicDataArrayDirty];
    return musicChanged || acChanged;
}

- (BOOL)reconcileList:(NSMutableArray *)purchased
             excluded:(NSSet<NSNumber *> *)excluded
               prefix:(NSString *)prefix
               suffix:(NSString *)suffix {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSCharacterSet *nonDigits =
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet;
    BOOL changed = NO;

    // Prune: drop an entry that a bundled/unlock source already covers, that a
    // previous entry already listed, or whose chart file no longer resolves in
    // either assets/ or Application Support.
    NSMutableIndexSet *dropIndexes = [NSMutableIndexSet indexSet];
    NSMutableSet<NSNumber *> *present = [NSMutableSet set];
    for (NSUInteger index = 0; index < purchased.count; index++) {
        NSNumber *musicId = @([purchased[index][@"ID"] intValue]);
        NSString *filename =
            [NSString stringWithFormat:@"%@%09d%@", prefix, musicId.intValue, suffix];
        if ([excluded containsObject:musicId] || [present containsObject:musicId] ||
            !RhFileExists([MusicManager assetOrAppSupportPath:filename])) {
            [dropIndexes addIndex:index];
        } else {
            [present addObject:musicId];
        }
    }
    if (dropIndexes.count > 0) {
        changed = YES;
    }
    [purchased removeObjectsAtIndexes:dropIndexes];

    // Discover: register any chart present in assets/ (a jailbroken drop into the
    // bundle) or Application Support that is not already listed and not excluded.
    for (NSString *directory in
         @[[AppDelegate appAssetsDirectory], [AppDelegate appAppSupportDirectory]]) {
        for (NSString *entryName in [fileManager contentsOfDirectoryAtPath:directory error:nil]) {
            if (![entryName hasPrefix:prefix] || ![entryName hasSuffix:suffix]) {
                continue;
            }
            NSString *digits = [entryName
                substringWithRange:NSMakeRange(prefix.length,
                                               entryName.length - prefix.length - suffix.length)];
            if (digits.length != 9 ||
                [digits rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
                continue;
            }
            NSNumber *musicId = @(digits.intValue);
            if ([excluded containsObject:musicId] || [present containsObject:musicId]) {
                continue;
            }
            [purchased addObject:@{@"ID" : musicId}];
            [present addObject:musicId];
            changed = YES;
        }
    }
    return changed;
}
#endif

#pragma mark - Paths

#ifdef ENABLE_PATCHES
+ (NSString *)assetOrAppSupportPath:(NSString *)filename {
    // A class method with no instance state: the init-time open-song predicates
    // (isOpenBemaniCollaboMusic / isOpenLoginBonusMusic) call it on the class object,
    // so it never re-enters getInstance before the singleton global is assigned. As an
    // instance method it would recurse forever during -init and overflow the stack.
    NSString *assetPath =
        [[AppDelegate appAssetsDirectory] stringByAppendingPathComponent:filename];
    if (RhFileExists(assetPath)) {
        return assetPath;
    }
    return [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:filename];
}
#endif

+ (NSString *)getPathFromBundle:(int)musicId {
    NSString *filename = [MusicManager getMusicDataFilename:musicId];
#ifdef ENABLE_PATCHES
    return [MusicManager assetOrAppSupportPath:filename];
#else
    return [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:filename];
#endif
}

- (NSString *)getPathFromPurchased:(int)musicId {
    // Downloaded local songs also live under Application Support, not Documents.
    NSString *filename = [MusicManager getMusicDataFilename:musicId];
#ifdef ENABLE_PATCHES
    return [MusicManager assetOrAppSupportPath:filename];
#else
    return [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:filename];
#endif
}

- (NSString *)getAcPathFromPurchased:(int)acMusicId {
    NSString *filename = [self getAcMusicDataFilename:acMusicId];
#ifdef ENABLE_PATCHES
    return [MusicManager assetOrAppSupportPath:filename];
#else
    return [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:filename];
#endif
}

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
    NSMutableArray *IDs = [NSMutableArray array];
    for (NSDictionary *entry in entries) {
        [IDs addObject:[entry objectForKey:@"ID"]];
    }
    return IDs;
}

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

- (NSMutableArray *)getPurchasedMusicDictionaris {
    return m_PurchasedMusicDictionaris;
}
- (NSMutableArray *)getPurchasedAcMusicDictionaris {
    return m_PurchasedAcMusicDictionaris;
}

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

- (void)openTreasureMusic {
    [self createOpenTreasureMusics];
    [self setMusicDataArrayDirty];
}
- (void)openInviteMusic {
    [self createOpenInviteMusics];
    [self setMusicDataArrayDirty];
}
- (void)openCollaboMusic {
    [self createOpenCollaboMusics];
    [self setMusicDataArrayDirty];
}
- (void)openLoginBonusMusic {
    [self createOpenLoginBonusMusics];
    [self setMusicDataArrayDirty];
}

#pragma mark - Flat id lists

- (NSMutableArray *)getMusicIDs {
    NSMutableArray *IDs = [NSMutableArray arrayWithCapacity:4];
    for (NSNumber *idNum in m_DefaultMusicIDs) {
        [IDs addObject:idNum];
    }
    for (NSDictionary *entry in m_PurchasedMusicDictionaris) {
        [IDs addObject:[entry objectForKey:@"ID"]];
    }
    for (NSNumber *idNum in m_OpenTreasureMusicIDs) {
        [IDs addObject:idNum];
    }
    return IDs;
}

- (NSMutableArray *)getAcMusicIDs {
    NSMutableArray *IDs = [NSMutableArray arrayWithCapacity:4];
    for (NSNumber *idNum in m_AcDefaultMusicIDs) {
        [IDs addObject:idNum];
    }
    for (NSDictionary *entry in m_PurchasedAcMusicDictionaris) {
        [IDs addObject:[entry objectForKey:@"ID"]];
    }
    return IDs;
}

- (NSArray *)getMusicPatchArray {
    return m_MusicLvPatchArray;
}

@end
