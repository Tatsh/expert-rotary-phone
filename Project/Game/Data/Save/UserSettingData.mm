//
//  UserSettingData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): syncs last music/sheet into the C++ neAppEventCenter.
//

#import <string.h>

#import "AppDelegate.h"
#import "ArcadeScoreData.h"
#import "CharaTicketData.h"
#import "NSData+Crypt.h"
#import "OverScoreData.h"
#import "ScoreData.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

// AES-128-CBC key/IV protecting the save blobs (Ghidra string literals).
static NSString *const kAESKey = @"4ZMw025eJIOTx26f";
static NSString *const kAESIV  = @"13U4RnAI73EdVMXB";

// NSUserDefaults keys.
static NSString *const kKeyCrypt109     = @"c";           // encrypted 36-byte blob
static NSString *const kKeyGotCharaData = @"d";           // encrypted archived array
static NSString *const kKeyGotChara     = @"GotChara";    // plain int bitmask
static NSString *const kKeyLastMusic    = @"LastMusic";
static NSString *const kKeyLastSheet    = @"LastSheet";
static NSString *const kKeyIsEffectOn   = @"IsEffectOn";
static NSString *const kKeyIsLongNotesEffectOn = @"IsLongNotesEffectOn";

// Maps a sugoroku main-map id (0..8) to its touch-sound bit index. Ghidra:
// FUN_000a218c — a 9-entry table (DAT_0012f958 = {1,2,...,9}), i.e. id + 1 for a
// valid id, else 0.
static int neSugorokuTouchSoundBit(int mainMapId) {
    static const int kBits[9] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    unsigned id = (unsigned)mainMapId & 0xffff;
    return id < 9 ? kBits[id] : 0;
}

@implementation UserSettingData

#pragma mark - NSUserDefaults primitives

// @ 0x5f73c
+ (int)getInt:(NSString *)key {
    return (int)[NSUserDefaults.standardUserDefaults integerForKey:key];
}

// @ 0x5f990 — fetch a stored object (used for NSDate values).
+ (id)getDate:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults objectForKey:key];
}

// Store an object (an NSDate) under `key`.
+ (void)saveDate:(id)value Key:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
}

// @ 0x60824 — persist the birthday entered in the age gate.
+ (void)saveBirthDay:(NSDate *)date {
    [self saveDate:date Key:@"BirthDay"];
}

// @ 0x6084c — did the user dismiss the age gate without entering a birthday?
+ (BOOL)isBirthDayCanceled {
    return [self getBOOL:@"BirthDayCancel"];
}

// @ 0x60874 — record whether the age gate was cancelled.
+ (void)saveIsBirthDayCanceled:(BOOL)canceled {
    [self saveBOOL:canceled Key:@"BirthDayCancel"];
}

// @ 0x5ffc8 / 0x5fff0 — remembers whether the friend how-to has been shown (key best-effort).
+ (BOOL)isFriendSelected {
    return [self getBOOL:@"FriendSelected"];
}

+ (void)saveIsFriendSelected:(BOOL)selected {
    [self saveBOOL:selected Key:@"FriendSelected"];
}

// @ 0x607fc — the user's stored birthday (nil until they enter it in the age gate).
+ (NSDate *)birthDay {
    return [self getDate:@"BirthDay"];
}

// @ 0x6089c — when the monthly purchase total was last reset.
+ (NSDate *)lastUpdateSumPurchase {
    return [self getDate:@"LastUpdateSumPurchase"];
}

// @ 0x608ec — yen spent this month (clamped at 0), for the youth spending limit.
+ (int)sumPurchase {
    int value = [self getInt:@"SumPurchase"];
    return value < 0 ? 0 : value;
}

// @ 0x5f774
+ (void)saveInt:(int)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if ((int)[ud integerForKey:key] == value) {
        return; // no-op if unchanged (as in original)
    }
    [ud setObject:[NSNumber numberWithInt:value] forKey:key];
    [ud synchronize];
}

// @ 0x5f800
+ (float)getFloat:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults floatForKey:key];
}

// @ 0x5f838
+ (void)saveFloat:(float)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if ([ud floatForKey:key] == value) {
        return;
    }
    [ud setObject:[NSNumber numberWithFloat:value] forKey:key];
    [ud synchronize];
}

// @ 0x5f8d4
+ (NSString *)getString:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults stringForKey:key];
}

// @ 0x5f90c
+ (void)saveString:(NSString *)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSString *cur = [ud stringForKey:key];
    if (cur != nil && [cur isEqualToString:value]) {
        return;
    }
    [ud setObject:value forKey:key];
    [ud synchronize];
}

// @ 0x5fa4c
+ (BOOL)getBOOL:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

// @ 0x5fa84
+ (void)saveBOOL:(BOOL)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if ([ud boolForKey:key] == value) {
        return;
    }
    [ud setObject:[NSNumber numberWithBool:value] forKey:key];
    [ud synchronize];
}

// @ 0x5fba0
+ (NSData *)getData:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults valueForKey:key];
}

// @ 0x5fbd8
+ (void)saveData:(NSData *)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSData *cur = [ud valueForKey:key];
    if (cur != nil && [cur isEqualToData:value]) {
        return;
    }
    [ud setObject:value forKey:key];
    [ud synchronize];
}

// @ 0x5fb14
+ (NSArray *)getArray:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults arrayForKey:key];
}

// @ 0x5fb4c — unconditional write + synchronize (no unchanged-check, unlike saveData:).
+ (void)saveArray:(NSArray *)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud setObject:value forKey:key];
    [ud synchronize];
}

#pragma mark - Crypt109 blob

// @ 0x615b4 — read + AES-decrypt the 36-byte blob under key "c".
+ (void)crypt109Data:(Crypt109Data *)out {
    if (out == nullptr) {
        return;
    }
    NSData *blob = [self getData:kKeyCrypt109];
    if (blob != nil) {
        NSData *plain = [blob decryptWith128Key:kAESKey initVector:kAESIV];
        memset(out, 0, sizeof(Crypt109Data));
        NSUInteger n = MIN(plain.length, sizeof(Crypt109Data));
        memcpy(out, plain.bytes, n);
        return;
    }
    // No saved blob: start from a zeroed record (first run / pre-migration).
    memset(out, 0, sizeof(Crypt109Data));
}

// @ 0x61650 — AES-encrypt the 36-byte blob and store under key "c".
+ (void)saveCrypt109Data:(const Crypt109Data *)data {
    NSData *plain = [NSData dataWithBytes:data length:sizeof(Crypt109Data)];
    NSData *enc = [plain encryptWith128Key:kAESKey initVector:kAESIV];
    [self saveData:enc Key:kKeyCrypt109];
}

#pragma mark - Identity (plaintext)

// @ 0x60260 — the player's server-assigned id string.
+ (NSString *)playerId               { return [self getString:@"PlayerId"]; }
// @ 0x60210 — the player's display name.
+ (NSString *)playerName             { return [self getString:@"PlayerName"]; }
// @ 0x602b0 — the player's e-AMUSEMENT / KONAMI id (music-checker score sync).
+ (NSString *)konamiId               { return [self getString:@"KonamiId"]; }

#pragma mark - Friend list (plaintext)

// @ 0x607ac / 0x607d4 — friend ranking sort mode (best-score vs. total-score).
+ (BOOL)isBestScoreSort              { return [self getBOOL:@"IsBestScoreSort"]; }
+ (void)saveIsBestScoreSort:(BOOL)best { [self saveBOOL:best Key:@"IsBestScoreSort"]; }

#pragma mark - Effects (plaintext)

+ (BOOL)isEffectOn                   { return [self getBOOL:kKeyIsEffectOn]; }          // @ 0x606bc
+ (void)saveIsEffectOn:(BOOL)on      { [self saveBOOL:on Key:kKeyIsEffectOn]; }          // @ 0x606e4
+ (BOOL)isLongNotesEffectOn          { return [self getBOOL:kKeyIsLongNotesEffectOn]; }  // @ 0x6070c
+ (void)saveIsLongNotesEffectOn:(BOOL)on { [self saveBOOL:on Key:kKeyIsLongNotesEffectOn]; } // @ 0x60734

#pragma mark - Crypt109 field accessors
// Getters read the decrypted blob and clamp; setters read-modify-write it.

+ (int)inviteCnt {                    // @ 0x60950 (verified)
    Crypt109Data d; [self crypt109Data:&d];
    return d.inviteCnt < 0 ? 0 : d.inviteCnt;
}
+ (void)saveInviteCnt:(int)v {
    Crypt109Data d; [self crypt109Data:&d]; d.inviteCnt = v; [self saveCrypt109Data:&d];
}

+ (int)invitePresent {
    Crypt109Data d; [self crypt109Data:&d]; return d.invitePresent;
}
+ (void)saveInvitePresent:(int)v {
    Crypt109Data d; [self crypt109Data:&d]; d.invitePresent = v; [self saveCrypt109Data:&d];
}

+ (short)charaTicket {                // @ 0x61238 (verified)
    Crypt109Data d; [self crypt109Data:&d];
    return d.charaTicket < 1 ? 0 : d.charaTicket;
}
+ (void)saveCharaTicket:(short)v {
    Crypt109Data d; [self crypt109Data:&d]; d.charaTicket = v; [self saveCrypt109Data:&d];
}

+ (short)treasurePoint {
    Crypt109Data d; [self crypt109Data:&d]; return d.treasurePoint;
}
+ (void)saveTreasurePoint:(short)v {
    Crypt109Data d; [self crypt109Data:&d]; d.treasurePoint = v; [self saveCrypt109Data:&d];
}

+ (int)getOpenedLoginBonusId {
    Crypt109Data d; [self crypt109Data:&d]; return d.openedLoginBonusId;
}
+ (void)saveOpenedLoginBonusId:(int)v {
    Crypt109Data d; [self crypt109Data:&d]; d.openedLoginBonusId = v; [self saveCrypt109Data:&d];
}

+ (int)getLoginBonusCnt {
    Crypt109Data d; [self crypt109Data:&d]; return d.loginBonusCnt;
}
+ (void)saveLoginBonusCnt:(int)v {
    Crypt109Data d; [self crypt109Data:&d]; d.loginBonusCnt = v; [self saveCrypt109Data:&d];
}

+ (short)charaId {
    Crypt109Data d; [self crypt109Data:&d]; return d.charaId;
}
+ (void)saveCharaId:(short)v {
    Crypt109Data d; [self crypt109Data:&d]; d.charaId = v; [self saveCrypt109Data:&d];
}

+ (short)charaIdServer {
    Crypt109Data d; [self crypt109Data:&d]; return d.charaIdServer;
}
+ (void)saveCharaIdServer:(short)v {
    Crypt109Data d; [self crypt109Data:&d]; d.charaIdServer = v; [self saveCrypt109Data:&d];
}

+ (int)touchSoundKind {
    Crypt109Data d; [self crypt109Data:&d]; return d.touchSoundKind;
}
+ (void)saveTouchSoundKind:(int)v {
    Crypt109Data d; [self crypt109Data:&d]; d.touchSoundKind = v; [self saveCrypt109Data:&d];
}

+ (int)haveTouchSoundFlg {           // getter verified (used in loadSettingData)
    Crypt109Data d; [self crypt109Data:&d]; return d.haveTouchSoundFlg;
}
+ (void)saveHaveTouchSoundFlg:(int)v { // @ setter verified (saveHaveTouchSoundFlg_)
    Crypt109Data d; [self crypt109Data:&d]; d.haveTouchSoundFlg = v; [self saveCrypt109Data:&d];
}

+ (BOOL)isBemaniCollaboOpened {
    Crypt109Data d; [self crypt109Data:&d]; return d.isBemaniCollaboOpened != 0;
}
+ (void)saveIsBemaniCollaboOpened:(BOOL)v {
    Crypt109Data d; [self crypt109Data:&d];
    d.isBemaniCollaboOpened = v ? 1 : 0;
    [self saveCrypt109Data:&d];
}

#pragma mark - Owned characters

// @ 0x60f24 — plain int bitmask; bits 0 and 1 are always set (first two chara).
+ (int)gotChara {
    return [self getInt:kKeyGotChara] | 0x3;
}

// @ 0x60f54 — encrypted archived array of 32-bit bitmask words under key "d".
+ (NSArray *)gotCharaArray {
    NSData *data = [self getData:kKeyGotCharaData];
    if (data == nil) {
        // Seed with word 0 = 3 (first two characters unlocked).
        NSMutableArray *arr = [NSMutableArray array];
        [arr addObject:@3];
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr];
        NSData *enc = [archived encryptWith128Key:kAESKey initVector:kAESIV];
        [self saveData:enc Key:kKeyGotCharaData];
        return [arr copy];
    }
    NSData *plain = [data decryptWith128Key:kAESKey initVector:kAESIV];
    return [NSKeyedUnarchiver unarchiveObjectWithData:plain];
}

// @ 0x610a0 — set the bit for charaIndex, archive, encrypt, store under key "d".
+ (void)saveGotCharaArray:(short)charaIndex {
    NSMutableArray *arr = [[self gotCharaArray] mutableCopy];
    int word = charaIndex >> 5;
    int bit = 1 << (charaIndex & 0x1f);
    for (int i = 0; i <= word; i++) {
        if ((int)arr.count <= i) {
            [arr addObject:@0];
        }
        if (i == word) {
            int cur = [arr[word] intValue];
            arr[word] = [NSNumber numberWithInt:(cur | bit)];
        }
    }
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr];
    NSData *enc = [archived encryptWith128Key:kAESKey initVector:kAESIV];
    [self saveData:enc Key:kKeyGotCharaData];
}

#pragma mark - Legacy v108 readers (plaintext PascalCase keys)

+ (int)inviteCnt108 {                 // @ 0x5fc5c (verified: key "InviteCnt", clamp >=0)
    int v = [self getInt:@"InviteCnt"];
    return v < 0 ? 0 : v;
}
+ (int)invitePresent108        { int v = [self getInt:@"InvitePresent"]; return v < 0 ? 0 : v; }
+ (short)charaTicket108        { int v = [self getInt:@"CharaTicket"]; return (short)(v < 0 ? 0 : v); }
+ (short)treasurePoint108      { int v = [self getInt:@"TreasurePoint"]; return (short)(v < 0 ? 0 : v); }
+ (int)getOpenedLoginBonusId108{ return [self getInt:@"OpenedLoginBonusId"]; }
+ (int)getLoginBonusCnt108     { return [self getInt:@"LoginBonusCnt"]; }
+ (short)charaId108            { return (short)[self getInt:@"CharaId"]; }
+ (short)charaIdServer108      { return (short)[self getInt:@"CharaIdServer"]; }
+ (int)touchSoundKind108       { return [self getInt:@"TouchSoundKind"]; }
+ (int)haveTouchSoundFlg108    { return [self getInt:@"HaveTouchSoundFlg"]; } // @ 0x5fe2c
+ (BOOL)isBemaniCollaboOpened108 { return [self getBOOL:@"IsBemaniCollaboOpened"]; }

#pragma mark - Lifecycle

// @ 0x5efb4
+ (void)loadSettingData {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;

    // Register bundled defaults, then force the long-notes effect default on.
    NSString *path = [NSBundle.mainBundle pathForResource:@"DefaultUserData" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:path];
    if (defaults) {
        [ud registerDefaults:defaults];
    }
    [ud registerDefaults:@{ kKeyIsLongNotesEffectOn: @"YES" }];

    // v108 -> v109 one-time migration.
    int ver = [[AppDelegate appDelegate] getUsersettingVer].intValue;
    if (ver < 109) {
        Crypt109Data d;
        memset(&d, 0, sizeof(d));
        d.inviteCnt            = [self inviteCnt108];
        d.invitePresent        = [self invitePresent108];
        d.charaTicket          = [self charaTicket108];
        d.treasurePoint        = [self treasurePoint108];
        d.openedLoginBonusId   = [self getOpenedLoginBonusId108] + 1;
        d.loginBonusCnt        = [self getLoginBonusCnt108];
        d.charaId              = [self charaId108];
        d.charaIdServer        = [self charaIdServer108];
        d.touchSoundKind       = [self touchSoundKind108];
        d.haveTouchSoundFlg    = [self haveTouchSoundFlg108];
        d.isBemaniCollaboOpened = [self isBemaniCollaboOpened108] ? 1 : 0;
        [self saveCrypt109Data:&d];

        // Fan the old gotChara bitmask out into the encrypted array (30 chara).
        int got = [self gotChara];
        for (int i = 0; i < 30; i++) {
            if (got & (1 << i)) {
                [self saveGotCharaArray:(short)i];
            }
        }
        [[AppDelegate appDelegate] setUsersettingVer:109];
    }

    // Merge any legacy touch-sound bits that the current record is missing.
    {
        int flg108 = [self haveTouchSoundFlg108];
        int cur = [self haveTouchSoundFlg];
        int merged = cur;
        for (int i = 0; i < 7; i++) {
            int bit = 1 << i;
            if ((flg108 & bit) && !(cur & bit)) {
                merged |= bit;
            }
        }
        if (cur != merged) {
            [self saveHaveTouchSoundFlg:merged];
        }
    }

    // Restore last played music / sheet into the engine (sheet default 2, <2 kept, >=0).
    {
        int lastMusic = (int)[ud integerForKey:kKeyLastMusic];
        int lastSheet = (int)[ud integerForKey:kKeyLastSheet];
        auto &ec = neAppEventCenter::shared();
        int sheet = 2;
        if (lastSheet < 2) sheet = lastSheet;
        if (sheet < 0) sheet = 0;
        ec.setLastSheet(sheet);
        ec.setLastMusic(lastMusic);
    }

    // Reconcile touch-sound flags with sugoroku goal-touch progress (maps 0..8, sub-map 2).
    {
        int flg = [self haveTouchSoundFlg];
        int flg2 = flg;
        NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
        for (short mainMapId = 0; mainMapId < 9; mainMapId++) {
            TreasureData *td = [TreasureData getTreasureData:mainMapId
                                                   subMapId:2
                                     inManagedObjectContext:ctx];
            if (td != nil && td.goalTouchSound.intValue != 0) {
                flg2 |= 1 << neSugorokuTouchSoundBit(mainMapId);
            }
        }
        if (flg != flg2) {
            [self saveHaveTouchSoundFlg:flg2];
        }
    }
}

// @ 0x61448 — the "pending treasure" snapshot. If a blob is stored under the key
// "TreasureTmpData" copy it straight back (capped at the record size); otherwise
// hand back an empty record whose id fields are the -1 "nothing pending" sentinels.
// (The binary's empty-record branch also writes uninitialised NEON lanes into the
// unused fields — undefined values, not real state — so the faithful equivalent is a
// zeroed record with the three sentinels set.)
+ (TreasureTmpData)treasureTmp {
    TreasureTmpData out;
    NSData *data = [self getData:@"TreasureTmpData"];
    if (data != nil) {
        NSUInteger len = data.length;
        if (len > sizeof(out)) {
            len = sizeof(out);
        }
        memcpy(&out, data.bytes, len);
        return out;
    }
    memset(&out, 0, sizeof(out));
    out.subMapId = -1;
    out.raw0x04 = -1;
    out.raw0x44 = -1;
    return out;
}

// @ 0x614f0 — persist the "pending treasure" snapshot back under the key
// "TreasureTmpData". Serialises 0x54 bytes (the record + its trailing pad, as the
// binary does) and hands them to saveData:Key:. The map loader and the sugoroku task
// write the chosen bonus square / board state through here.
+ (void)saveTreasureTmp:(TreasureTmpData)data {
    NSData *blob = [NSData dataWithBytes:&data length:0x54];
    [self saveData:blob Key:@"TreasureTmpData"];
}

// @ 0x5f66c — persist last music/sheet (stored as floats, as in the original).
+ (void)saveSettingData {
    auto &ec = neAppEventCenter::shared();
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud setObject:[NSNumber numberWithFloat:(float)ec.lastMusic()] forKey:kKeyLastMusic];
    [ud setObject:[NSNumber numberWithFloat:(float)ec.lastSheet()] forKey:kKeyLastSheet];
    [ud synchronize];
}

#pragma mark - Audio volumes (plaintext)

// @ 0x60300 — BGM master volume, clamped to [0.0, 1.0].
+ (float)bgmVolume {
    float v = [self getFloat:@"BgmVolume"];
    if (v >= 1.0f) v = 1.0f;
    if (v < 0.0f)  v = 0.0f;
    return v;
}

// @ 0x60364 — clamp to [0.0, 1.0] then persist.
+ (void)saveBgmVolume:(float)volume {
    if (volume >= 1.0f) volume = 1.0f;
    if (volume < 0.0f)  volume = 0.0f;
    [self saveFloat:volume Key:@"BgmVolume"];
}

// @ 0x603c4 — SE master volume (0..127); values >= 127 cap at 127, negatives clamp to 0.
+ (short)seVolume {
    int v = [self getInt:@"SeVolume"];
    short r = 0x7f;
    if (v < 0x7f) r = (short)v;
    if (r < 0)    r = 0;
    return r;
}

// @ 0x60404 — cap at 127 (no lower clamp in the original) and persist.
+ (void)saveSeVolume:(short)volume {
    if (volume > 0x7e) volume = 0x7f;
    [self saveInt:volume Key:@"SeVolume"];
}

// @ 0x60438 — per-tap SE volume (0..127); same clamp as seVolume.
+ (short)touchSoundVolume {
    int v = [self getInt:@"TouchSoundVolume"];
    short r = 0x7f;
    if (v < 0x7f) r = (short)v;
    if (r < 0)    r = 0;
    return r;
}

// @ 0x60478 — cap at 127 and persist.
+ (void)saveTouchSoundVolume:(short)volume {
    if (volume > 0x7e) volume = 0x7f;
    [self saveInt:volume Key:@"TouchSoundVolume"];
}

#pragma mark - AC-viewer play options (plaintext)

// @ 0x618a4
+ (void)saveAcvHiSpeed:(int)v { [self saveInt:v Key:@"AcViewerHiSpeed"]; }
+ (void)saveAcvPopKun:(int)v  { [self saveInt:v Key:@"AcViewerPopKun"]; }
+ (void)saveAcvHidSud:(int)v  { [self saveInt:v Key:@"AcViewerHidSud"]; }
+ (void)saveAcvRanMir:(int)v  { [self saveInt:v Key:@"AcViewerRanMir"]; }
+ (int)acvHiSpeed { return [self getInt:@"AcViewerHiSpeed"]; }
// @ 0x618f4
+ (int)acvPopKun  { return [self getInt:@"AcViewerPopKun"]; }
// @ 0x61944
+ (int)acvHidSud  { return [self getInt:@"AcViewerHidSud"]; }
// @ 0x61994
+ (int)acvRanMir  { return [self getInt:@"AcViewerRanMir"]; }
// @ 0x619e4
+ (BOOL)isAcvGenreName { return [self getBOOL:@"AcViewerIsGenreName"]; }
// @ 0x61a0c
+ (void)saveIsAcvGenreName:(BOOL)genreName { [self saveBOOL:genreName Key:@"AcViewerIsGenreName"]; }

#pragma mark - Music-list sort (plaintext)

// @ 0x60dd0 — clamp the stored sort index to 0..5.
+ (short)musicSort {
    int v = [self getInt:@"MusicSort"];
    short sort = ((short)v < 5) ? (short)v : 5;
    if (sort < 0) {
        sort = 0;
    }
    return sort;
}

// @ 0x60e10 — anything above 4 collapses to 5 (best-score).
+ (void)saveMusicSort:(short)sort {
    if (sort > 4) {
        sort = 5;
    }
    [self saveInt:sort Key:@"MusicSort"];
}

#pragma mark - Simple mode / popkun

// @ 0x6075c
+ (BOOL)isSimpleMode { return [self getBOOL:@"SimpleMode"]; }
// @ 0x60784
+ (void)saveIsSimpleMode:(BOOL)on { [self saveBOOL:on Key:@"SimpleMode"]; }

// @ 0x60600 — note ("popkun") size, key "b". Valid range [50, 100]; anything outside
// (including an unset 0) falls back to the default 100.
+ (float)popkunSize {
    float v = [self getFloat:@"b"];
    if (v > 100.0f || v < 50.0f) {
        return 100.0f;
    }
    return v;
}

#pragma mark - Convert-code / device-change

// @ 0x61a34 — AES-decrypt the blob under key "a" and decode it as UTF-8.
+ (NSString *)convertCode {
    NSData *data = [self getData:@"a"];
    if (data != nil) {
        NSData *plain = [data decryptWith128Key:kAESKey initVector:kAESIV];
        return [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
    }
    return nil;
}

// @ 0x61ad0 — UTF-8 encode, AES-encrypt, store under key "a" (nil clears it).
+ (void)saveConvertCode:(NSString *)code {
    NSData *enc = nil;
    if (code != nil) {
        NSData *plain = [code dataUsingEncoding:NSUTF8StringEncoding];
        enc = [plain encryptWith128Key:kAESKey initVector:kAESIV];
    }
    [self saveData:enc Key:@"a"];
}

// @ 0x61c44
+ (BOOL)isFollowBonusGet { return [self getBOOL:@"IsFollowBonusGet"]; }
// @ 0x61c6c
+ (void)saveIsFollowBonusGet:(BOOL)got { [self saveBOOL:got Key:@"IsFollowBonusGet"]; }

// @ 0x61804 — the client version that last completed the device-change flow (key "LastCompletedClientVer").
+ (int)lastCompletedClientVer { return [self getInt:@"LastCompletedClientVer"]; }
// @ 0x6182c
+ (void)saveLastCompletedClientVer:(int)ver { [self saveInt:ver Key:@"LastCompletedClientVer"]; }
// @ 0x60090 — record acceptance of the privacy policy / terms (key "IsPolicyAccepted").
+ (void)saveIsPolicyAccepted:(BOOL)accepted { [self saveBOOL:accepted Key:@"IsPolicyAccepted"]; }

// @ 0x60a40 — whether the player has already redeemed an invite code (key "IsInputInviteCode").
+ (BOOL)isInputInviteCode { return [self getBOOL:@"IsInputInviteCode"]; }
// @ 0x60a68
+ (void)saveIsInputInviteCode:(BOOL)v { [self saveBOOL:v Key:@"IsInputInviteCode"]; }

// @ 0x5f418 — device-change reset: wipe the persistent domain, then re-seed the
// factory defaults and clear all local Core Data progress records.
+ (void)initForConvert {
    int clientVer = [self lastCompletedClientVer];

    NSString *bundleId = NSBundle.mainBundle.bundleIdentifier;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud removePersistentDomainForName:bundleId];

    [self saveSettingData];
    [self saveSeVolume:100];
    [self saveBgmVolume:1.0f];
    [self saveIsEffectOn:YES];
    [self saveIsLongNotesEffectOn:YES];
    [self saveTouchSoundVolume:100];
    [self saveTouchSoundKind:0];
    [ud setObject:[NSNumber numberWithFloat:0] forKey:kKeyLastMusic];
    [ud setObject:[NSNumber numberWithFloat:0] forKey:kKeyLastSheet];
    [self saveIsPolicyAccepted:YES];
    [self saveLastCompletedClientVer:clientVer];

    NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
    [ScoreData deleteAll:ctx];
    [TreasureData deleteAll:ctx];
    [CharaTicketData deleteAll:ctx];
    [ArcadeScoreData deleteAll:ctx];
    [OverScoreData deleteAll:ctx];
}

#pragma mark - Treasure

// @ 0x61540 — reset the pending-treasure snapshot to the empty/"nothing pending"
// record (the same default treasureTmp hands back) and persist it.
+ (void)initTreasureTmp {
    TreasureTmpData data;
    memset(&data, 0, sizeof(data));
    data.subMapId = -1;
    data.raw0x04  = -1;
    data.raw0x44  = -1;
    [self saveTreasureTmp:data];
}

// @ 0x61c94 — scan the "e" array of {mapid, readno} dictionaries for subMapId and
// return its readno, or 0 when the sub-map has no stored entry.
+ (int)treasureReadNo:(short)subMapId {
    NSArray *array = [self getArray:@"e"];
    for (NSDictionary *entry in array) {
        if ([[entry objectForKey:@"mapid"] shortValue] == subMapId) {
            return [[entry objectForKey:@"readno"] intValue];
        }
    }
    return 0;
}

// @ 0x61378 — read the "ConsumedTreasurePoint" int, clamped to >= 0.
+ (short)consumedTreasurePoint {
    short v = (short)[self getInt:@"ConsumedTreasurePoint"];
    return v < 1 ? 0 : v;
}

// @ 0x613b0 — clamp to [0, 9999] and store under "ConsumedTreasurePoint".
+ (void)saveConsumedTreasurePoint:(short)value {
    short clamped = value < 9999 ? value : 9999;
    [self saveInt:(clamped < 0 ? 0 : clamped) Key:@"ConsumedTreasurePoint"];
}

#pragma mark - Uncomplete score-save queue

// @ 0x60a90
+ (NSArray *)uncompleteSaveMusic { return [self getArray:@"UncompleteSaveMusic"]; }
// @ 0x60ab8
+ (NSArray *)uncompleteSaveSheet { return [self getArray:@"UncompleteSaveSheet"]; }

// @ 0x60ae0 — append music/sheet to the two parallel queues.
+ (void)addUncompleteSaveMusic:(int)music sheet:(short)sheet {
    NSArray *musicArr = [self uncompleteSaveMusic];
    NSArray *sheetArr = [self uncompleteSaveSheet];
    NSMutableArray *music2 = musicArr != nil ? [musicArr mutableCopy] : [NSMutableArray array];
    NSMutableArray *sheet2 = sheetArr != nil ? [sheetArr mutableCopy] : [NSMutableArray array];
    [music2 addObject:[NSNumber numberWithLong:music]];
    [sheet2 addObject:[NSNumber numberWithInt:sheet]];
    [self saveArray:[music2 copy] Key:@"UncompleteSaveMusic"];
    [self saveArray:[sheet2 copy] Key:@"UncompleteSaveSheet"];
}

// @ 0x60c74 — remove music/sheet from the two queues (no-op unless both exist).
+ (void)subUncompleteSaveMusic:(int)music sheet:(short)sheet {
    NSArray *musicArr = [self uncompleteSaveMusic];
    NSArray *sheetArr = [self uncompleteSaveSheet];
    if (musicArr != nil && sheetArr != nil) {
        NSMutableArray *music2 = [musicArr mutableCopy];
        NSMutableArray *sheet2 = [sheetArr mutableCopy];
        [music2 removeObject:[NSNumber numberWithLong:music]];
        [sheet2 removeObject:[NSNumber numberWithInt:sheet]];
        [self saveArray:[music2 copy] Key:@"UncompleteSaveMusic"];
        [self saveArray:[sheet2 copy] Key:@"UncompleteSaveSheet"];
    }
}

#pragma mark - Identity setters (plaintext)

// @ 0x60288
+ (void)savePlayerId:(NSString *)playerId { [self saveString:playerId Key:@"PlayerId"]; }
// @ 0x60238
+ (void)savePlayerName:(NSString *)name   { [self saveString:name Key:@"PlayerName"]; }

#pragma mark - Store / news / spending

// @ 0x61854 — last-seen store information banner id (note the original key's typo).
+ (int)lastInformationId { return [self getInt:@"LastInfomationId"]; }

// @ 0x5fe88 — timestamp string of the last store view.
+ (NSString *)lastStoreViewTimeString { return [self getString:@"LastUpdateTime"]; }

// @ 0x608c4 — when the monthly purchase total was last reset.
+ (void)saveLastUpdateSumPurchase:(NSDate *)date {
    [self saveDate:date Key:@"LastUpdateSumPurchase"];
}

// @ 0x60920 — yen spent this month, clamped to >= 0 before persisting.
+ (void)saveSumPurchase:(int)sum {
    if (sum < 0) {
        sum = 0;
    }
    [self saveInt:sum Key:@"SumPurchase"];
}

// --- Quiz progress counters (plaintext ints) ---
// @ 0x616c4 / 0x616ec
+ (int)lastAnswerQuizId          { return [self getInt:@"LastAnswerQuizId"]; }
+ (void)saveLastAnswerQuizId:(int)v { [self saveInt:v Key:@"LastAnswerQuizId"]; }
// @ 0x61714 / 0x6173c
+ (int)totalCorrectQuiz          { return [self getInt:@"TotalCorrectQuiz"]; }
+ (void)saveTotalCorrectQuiz:(int)v { [self saveInt:v Key:@"TotalCorrectQuiz"]; }
// @ 0x61764 / 0x6178c
+ (int)totalInCorrectQuiz        { return [self getInt:@"TotalInCorrectQuiz"]; }
+ (void)saveTotalInCorrectQuiz:(int)v { [self saveInt:v Key:@"TotalInCorrectQuiz"]; }
// @ 0x617b4 / 0x617dc
+ (int)consecutiveCorrectQuiz    { return [self getInt:@"ConsecutiveCorrectQuiz"]; }
+ (void)saveConsecutiveQuiz:(int)v { [self saveInt:v Key:@"ConsecutiveCorrectQuiz"]; }

// @ 0x612b0 — grant character tickets (Crypt109 charaTicket += count); no-op for 0.
+ (void)addCharaTicket:(int)count {
    if (count == 0) {
        return;
    }
    short cur = [self charaTicket];
    [self saveCharaTicket:(short)(cur + count)];
}

@end
