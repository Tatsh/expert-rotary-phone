//
//  UserSettingData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): syncs last music/sheet into the C++ neAppEventCenter.
//

#import "UserSettingData.h"

#import <string.h>

#import "AppDelegate.h"
#import "ArcadeScoreData.h"
#import "CharaTicketData.h"
#import "NSData+Crypt.h"
#import "OverScoreData.h"
#import "ScoreData.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "neEngineBridge.h"

// AES-128-CBC key/IV protecting the save blobs (Ghidra string literals).
static NSString *const kAESKey = @"4ZMw025eJIOTx26f";
static NSString *const kAESIV = @"13U4RnAI73EdVMXB";

// NSUserDefaults keys.
static NSString *const kKeyCrypt109 = @"c";        // encrypted 36-byte blob
static NSString *const kKeyGotCharaData = @"d";    // encrypted archived array
static NSString *const kKeyGotChara = @"GotChara"; // plain int bitmask
static NSString *const kKeyLastMusic = @"LastMusic";
static NSString *const kKeyLastSheet = @"LastSheet";
static NSString *const kKeyIsEffectOn = @"IsEffectOn";
static NSString *const kKeyIsLongNotesEffectOn = @"IsLongNotesEffectOn";

// Maps a sugoroku main-map id (0..8) to its touch-sound bit index. Ghidra:
// FUN_000a218c — uxth the id, return 0 when it exceeds 8, else index a 9-entry
// table at DAT_0012f958 = {1,2,...,9} (verified), i.e. id + 1 for a valid id.
static int neSugorokuTouchSoundBit(int mainMapId) {
    static constexpr int kBits[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    unsigned id = static_cast<unsigned>(mainMapId) & 0xffff;
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

// @ 0x5f9c8 — store an object (an NSDate) under `key`. Skips the write and the
// synchronise when the stored date already equals `value` (isEqualToDate:), as
// the binary does.
+ (void)saveDate:(id)value Key:(NSString *)key {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSDate *cur = [ud objectForKey:key];
    if (cur != nil && [cur isEqualToDate:value]) {
        return;
    }
    [ud setObject:value forKey:key];
    [ud synchronize];
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

// @ 0x5ffc8 / 0x5fff0 — remembers whether the friend how-to has been shown.
// Key is "IsFriendSelected" (both the getter's boolForKey and the setter's
// saveBOOL: reference the shared CFString "IsFriendSelected").
+ (BOOL)isFriendSelected {
    return [self getBOOL:@"IsFriendSelected"];
}

+ (void)saveIsFriendSelected:(BOOL)selected {
    [self saveBOOL:selected Key:@"IsFriendSelected"];
}

// @ 0x6209c / 0x620cc — the main-map id whose sugoroku map-select screen is
// shown (key "SelectedMapId").
+ (short)treasureSelectedMapId {
    return (short)[self getInt:@"SelectedMapId"];
}

+ (void)saveTreasureSelectedMapId:(short)mapId {
    [self saveInt:mapId Key:@"SelectedMapId"];
}

// @ 0x60018 / 0x60040 — remembers whether the treasure how-to has been shown
// (key "IsTreasureSelected").
+ (BOOL)isTreasureSelected {
    return [self getBOOL:@"IsTreasureSelected"];
}

+ (void)saveIsTreasureSelected:(BOOL)selected {
    [self saveBOOL:selected Key:@"IsTreasureSelected"];
}

// @ 0x5ff78 / 0x5ffa0 — remembers whether the pop'n-link first-run how-to has
// been shown. Key is "IsPopnLinkSelected" (shared CFString on both accessors).
+ (BOOL)isPopnLinkSelected {
    return [self getBOOL:@"IsPopnLinkSelected"];
}

+ (void)saveIsPopnLinkSelected:(BOOL)selected {
    [self saveBOOL:selected Key:@"IsPopnLinkSelected"];
}

// @ 0x607fc — the user's stored birthday (nil until they enter it in the age
// gate).
+ (NSDate *)birthDay {
    return [self getDate:@"BirthDay"];
}

// @ 0x6089c — when the monthly purchase total was last reset.
+ (NSDate *)lastUpdateSumPurchase {
    return [self getDate:@"LastUpdateSumPurchase"];
}

// @ 0x608ec — yen spent this month (clamped at 0), for the youth spending
// limit.
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

// @ 0x5fb4c — unconditional write + synchronize (no unchanged-check, unlike
// saveData:).
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
        // The binary copies the full 36 bytes straight out of the decrypted
        // buffer (vld1/vst1 of 0x20 bytes + the trailing word), so mirror an
        // exact-size copy here.
        memcpy(out, plain.bytes, sizeof(Crypt109Data));
        return;
    }
    // No saved blob: a zeroed record except haveTouchSoundFlg (0x1c), which the
    // binary seeds to 1 (movs r0,#1; strd r0,r1,[r4,#0x1c]).
    memset(out, 0, sizeof(Crypt109Data));
    out->haveTouchSoundFlg = 1;
}

// @ 0x61650 — AES-encrypt the 36-byte blob and store under key "c".
+ (void)saveCrypt109Data:(const Crypt109Data *)data {
    NSData *plain = [NSData dataWithBytes:data length:sizeof(Crypt109Data)];
    NSData *enc = [plain encryptWith128Key:kAESKey initVector:kAESIV];
    [self saveData:enc Key:kKeyCrypt109];
}

#pragma mark - Identity (plaintext)

// @ 0x60260 — the player's server-assigned id string.
+ (NSString *)playerId {
    return [self getString:@"PlayerId"];
}
// @ 0x60210 — the player's display name.
+ (NSString *)playerName {
    return [self getString:@"PlayerName"];
}
// @ 0x602b0 — the player's e-AMUSEMENT / KONAMI id (music-checker score sync).
+ (NSString *)konamiId {
    return [self getString:@"KonamiId"];
}

#pragma mark - Friend list (plaintext)

// @ 0x607ac / 0x607d4 — friend ranking sort mode (best-score vs. total-score).
+ (BOOL)isBestScoreSort {
    return [self getBOOL:@"IsBestScoreSort"];
}
+ (void)saveIsBestScoreSort:(BOOL)best {
    [self saveBOOL:best Key:@"IsBestScoreSort"];
}

#pragma mark - Effects (plaintext)

// @ 0x606bc
+ (BOOL)isEffectOn {
    return [self getBOOL:kKeyIsEffectOn];
}
// @ 0x606e4
+ (void)saveIsEffectOn:(BOOL)on {
    [self saveBOOL:on Key:kKeyIsEffectOn];
}
// @ 0x6070c
+ (BOOL)isLongNotesEffectOn {
    return [self getBOOL:kKeyIsLongNotesEffectOn];
}
// @ 0x60734
+ (void)saveIsLongNotesEffectOn:(BOOL)on {
    [self saveBOOL:on Key:kKeyIsLongNotesEffectOn];
}

#pragma mark - Crypt109 field accessors
// Getters read the decrypted blob and clamp; setters read-modify-write it.

+ (int)inviteCnt { // @ 0x60950 (verified)
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.inviteCnt < 0 ? 0 : d.inviteCnt;
}
// @ 0x60980 — the input is clamped to >= 0 before storing (cmp r4,#0;
// mov.lt r4,#0).
+ (void)saveInviteCnt:(int)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.inviteCnt = v < 0 ? 0 : v;
    [self saveCrypt109Data:&d];
}

// @ 0x609c8 — clamped to >= 0 (cmp #0; mov.lt r0,#0), matching inviteCnt.
+ (int)invitePresent {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.invitePresent < 0 ? 0 : d.invitePresent;
}
// @ 0x609f8 — the input is clamped to >= 0 before storing (cmp r4,#0;
// mov.lt r4,#0).
+ (void)saveInvitePresent:(int)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.invitePresent = v < 0 ? 0 : v;
    [self saveCrypt109Data:&d];
}

+ (short)charaTicket { // @ 0x61238 (verified)
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.charaTicket < 1 ? 0 : d.charaTicket;
}
// @ 0x6126c
+ (void)saveCharaTicket:(short)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.charaTicket = v;
    [self saveCrypt109Data:&d];
}

// @ 0x612f4 — clamped to >= 0 (ldrsh; cmp #0; it le; mov.le r0,#0), i.e. a
// non-positive stored value reads back as 0.
+ (short)treasurePoint {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.treasurePoint < 1 ? 0 : d.treasurePoint;
}
// @ 0x61328 — the input is capped at 9999 before storing (movw r1,#0x270f;
// cmp r4,r1; it lt; mov.lt r1,r4), i.e. min(v, 9999). No lower clamp.
+ (void)saveTreasurePoint:(short)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.treasurePoint = v < 9999 ? v : 9999;
    [self saveCrypt109Data:&d];
}

// @ 0x60130 — returns the stored id minus 1 (subs r0,#1); the value is stored
// biased by +1 (see loadSettingData and the v108 migration), so the getter
// unbiases it.
+ (int)getOpenedLoginBonusId {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.openedLoginBonusId - 1;
}
// @ 0x6015c — stores the value biased by +1 (adds r1,r4,#1); the getter
// unbiases with -1.
+ (void)saveOpenedLoginBonusId:(int)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.openedLoginBonusId = v + 1;
    [self saveCrypt109Data:&d];
}

// @ 0x601a0
+ (int)getLoginBonusCnt {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.loginBonusCnt;
}
// @ 0x601cc
+ (void)saveLoginBonusCnt:(int)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.loginBonusCnt = v;
    [self saveCrypt109Data:&d];
}

// @ 0x60e44
+ (short)charaId {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.charaId;
}
// @ 0x60e70
+ (void)saveCharaId:(short)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.charaId = v;
    [self saveCrypt109Data:&d];
}

// @ 0x60eb4
+ (short)charaIdServer {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.charaIdServer;
}
// @ 0x60ee0
+ (void)saveCharaIdServer:(short)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.charaIdServer = v;
    [self saveCrypt109Data:&d];
}

// @ 0x604ac — clamped to [0, 10]: the binary reads the field with a signed
// 16-bit load (ldrsh [sp,#0x18]) then does cmp #0xa/ge->0xa and cmp #0/lt->0.
+ (int)touchSoundKind {
    Crypt109Data d;
    [self crypt109Data:&d];
    int v = static_cast<int16_t>(d.touchSoundKind);
    if (v >= 10) {
        v = 10;
    }
    if (v < 0) {
        v = 0;
    }
    return v;
}
// @ 0x604e8 — the binary writes only the low 16 bits (strh [sp,#0x18]); the
// getter likewise reads a signed 16-bit value, so the field is effectively
// 16-bit and this full-width store is equivalent for every value the getter
// can observe.
+ (void)saveTouchSoundKind:(int)v {
    Crypt109Data d;
    [self crypt109Data:&d];
    d.touchSoundKind = v;
    [self saveCrypt109Data:&d];
}

// @ 0x6052c — bit 0 is always set (movs r1,#1; bics r1,r0; orrs r0,r1 == r0 | 1),
// so the default touch sound is always reported as owned.
+ (int)haveTouchSoundFlg { // getter verified (used in loadSettingData)
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.haveTouchSoundFlg | 0x1;
}
// @ 0x6055c — bit 0 is forced set before storing (movs r1,#1; bics r1,r4;
// orrs r1,r4 == v | 1), matching the getter.
+ (void)saveHaveTouchSoundFlg:(int)v { // @ setter verified (saveHaveTouchSoundFlg_)
    Crypt109Data d;
    [self crypt109Data:&d];
    d.haveTouchSoundFlg = v | 0x1;
    [self saveCrypt109Data:&d];
}

// @ 0x600b8 — returns the raw byte at 0x20 (ldrsb) as the BOOL.
+ (BOOL)isBemaniCollaboOpened {
    Crypt109Data d;
    [self crypt109Data:&d];
    return d.isBemaniCollaboOpened != 0;
}
// @ 0x600e4 — stores 1 if the low byte of the input is non-zero, else 0
// (uxtb; cmp #0; it ne; mov.ne r1,#1).
+ (void)saveIsBemaniCollaboOpened:(BOOL)v {
    Crypt109Data d;
    [self crypt109Data:&d];
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
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr
                                                 requiringSecureCoding:NO
                                                                 error:nil];
#else
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr];
#endif
        NSData *enc = [archived encryptWith128Key:kAESKey initVector:kAESIV];
        [self saveData:enc Key:kKeyGotCharaData];
        return [arr copy];
    }
    NSData *plain = [data decryptWith128Key:kAESKey initVector:kAESIV];
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:plain
                                                                                error:nil];
    unarchiver.requiresSecureCoding = NO;
    id result = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    [unarchiver finishDecoding];
    return result;
#else
    return [NSKeyedUnarchiver unarchiveObjectWithData:plain];
#endif
}

// @ 0x610a0 — set the bit for charaIndex, archive, encrypt, store under key
// "d".
+ (void)saveGotCharaArray:(short)charaIndex {
    NSMutableArray *arr = [[self gotCharaArray] mutableCopy];
    int word = charaIndex >> 5;
    int bit = 1 << (charaIndex & 0x1f);
    for (int i = 0; i <= word; i++) {
        if (static_cast<int>(arr.count) <= i) {
            [arr addObject:@0];
        }
        if (i == word) {
            int cur = [arr[word] intValue];
            arr[word] = [NSNumber numberWithInt:(cur | bit)];
        }
    }
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr
                                             requiringSecureCoding:NO
                                                             error:nil];
#else
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:arr];
#endif
    NSData *enc = [archived encryptWith128Key:kAESKey initVector:kAESIV];
    [self saveData:enc Key:kKeyGotCharaData];
}

#pragma mark - Legacy v108 readers (plaintext PascalCase keys)

+ (int)inviteCnt108 { // @ 0x5fc5c (verified: key "InviteCnt", clamp >=0)
    int v = [self getInt:@"InviteCnt"];
    return v < 0 ? 0 : v;
}
// @ 0x5fc90 — key "InvitePresent", clamped >= 0.
+ (int)invitePresent108 {
    int v = [self getInt:@"InvitePresent"];
    return v < 0 ? 0 : v;
}
// @ 0x5fcc4 — key "CharaTicket"; the value is sign-extended to 16 bits and a
// non-positive result reads back as 0 (le clamp).
+ (short)charaTicket108 {
    int v = static_cast<int16_t>([self getInt:@"CharaTicket"]);
    return static_cast<short>(v < 1 ? 0 : v);
}
// @ 0x5fcfc — key "TreasurePoint"; same sign-extend and le clamp as charaTicket.
+ (short)treasurePoint108 {
    int v = static_cast<int16_t>([self getInt:@"TreasurePoint"]);
    return static_cast<short>(v < 1 ? 0 : v);
}
// @ 0x5fd34 — key "OpenedLoginBonusId"; returns the stored value minus 1
// (subs r0,#1), unbiasing the +1 the setter applied.
+ (int)getOpenedLoginBonusId108 {
    return [self getInt:@"OpenedLoginBonusId"] - 1;
}
// @ 0x5fd64 — key "LoginBonusCnt".
+ (int)getLoginBonusCnt108 {
    return [self getInt:@"LoginBonusCnt"];
}
// @ 0x5fd8c — key "CharaId" (sign-extended to 16 bits).
+ (short)charaId108 {
    return (short)[self getInt:@"CharaId"];
}
// @ 0x5fdbc — key "CharaIdServer" (sign-extended to 16 bits).
+ (short)charaIdServer108 {
    return (short)[self getInt:@"CharaIdServer"];
}
// @ 0x5fdec — key "TouchSoundKind"; sign-extended to 16 bits and clamped to
// [0, 10] (default 10 when >= 10, then a negative result clamps to 0).
+ (int)touchSoundKind108 {
    int v = static_cast<int16_t>([self getInt:@"TouchSoundKind"]);
    if (v >= 10) {
        v = 10;
    }
    if (v < 0) {
        v = 0;
    }
    return v;
}
// @ 0x5fe2c — key "HaveTouchSoundFlg"; bit 0 is forced set (v | 1).
+ (int)haveTouchSoundFlg108 {
    return [self getInt:@"HaveTouchSoundFlg"] | 0x1;
}
// @ 0x5fe60 — key "IsBemaniCollaboOpen" (the v108 key has no trailing "ed",
// unlike the selector).
+ (BOOL)isBemaniCollaboOpened108 {
    return [self getBOOL:@"IsBemaniCollaboOpen"];
}

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
    [ud registerDefaults:@{kKeyIsLongNotesEffectOn : @"YES"}];

    // v108 -> v109 one-time migration.
    int ver = [[AppDelegate appDelegate] getUsersettingVer].intValue;
    if (ver < 109) {
        Crypt109Data d;
        memset(&d, 0, sizeof(d));
        d.inviteCnt = [self inviteCnt108];
        d.invitePresent = [self invitePresent108];
        d.charaTicket = [self charaTicket108];
        d.treasurePoint = [self treasurePoint108];
        d.openedLoginBonusId = [self getOpenedLoginBonusId108] + 1;
        d.loginBonusCnt = [self getLoginBonusCnt108];
        d.charaId = [self charaId108];
        d.charaIdServer = [self charaIdServer108];
        d.touchSoundKind = [self touchSoundKind108];
        d.haveTouchSoundFlg = [self haveTouchSoundFlg108];
        d.isBemaniCollaboOpened = [self isBemaniCollaboOpened108] ? 1 : 0;
        [self saveCrypt109Data:&d];

        // Fan the old gotChara bitmask out into the encrypted array (30 chara).
        int got = [self gotChara];
        for (int i = 0; i < 30; i++) {
            if (got & (1 << i)) {
                [self saveGotCharaArray:static_cast<short>(i)];
            }
        }
        [[AppDelegate appDelegate] setUsersettingVer:@"109"]; // @0x137548 CFString "109"
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

    // Restore last played music / sheet into the engine (sheet default 2, <2
    // kept, >=0).
    {
        int lastMusic = (int)[ud integerForKey:kKeyLastMusic];
        int lastSheet = (int)[ud integerForKey:kKeyLastSheet];
        auto &ec = neAppEventCenter::shared();
        int sheet = 2;
        if (lastSheet < 2) {
            sheet = lastSheet;
        }
        if (sheet < 0) {
            sheet = 0;
        }
        ec.setLastSheet(sheet);
        ec.setLastMusic(lastMusic);
    }

    // Reconcile touch-sound flags with sugoroku goal-touch progress (maps 0..8,
    // sub-map 2).
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

// @ 0x61448 — the "pending treasure" snapshot. If a blob is stored under the
// key "TreasureTmpData" copy it straight back (capped at the record size);
// otherwise hand back an empty record whose id fields are the -1 "nothing
// pending" sentinels. (The binary's empty-record branch also writes
// uninitialised NEON lanes into the unused fields — undefined values, not real
// state — so the faithful equivalent is a zeroed record with the three
// sentinels set.)
//
// The empty-record branch writes a 32-bit -1 at offset 0x2 (covering subMapId
// and curSubMapId) and a 16-bit 0xffff at 0x44, i.e. the three sentinels below.
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
    out.curSubMapId = -1;
    out.rouletteMode = -1;
    return out;
}

// @ 0x614f0 — persist the "pending treasure" snapshot back under the key
// "TreasureTmpData". Serialises 0x54 bytes (the record + its trailing pad, as
// the binary does) and hands them to saveData:Key:. The map loader and the
// sugoroku task write the chosen bonus square / board state through here.
+ (void)saveTreasureTmp:(TreasureTmpData)data {
    NSData *blob = [NSData dataWithBytes:&data length:0x54];
    [self saveData:blob Key:@"TreasureTmpData"];
}

// @ 0x5f66c — persist last music/sheet (stored as floats, as in the original).
+ (void)saveSettingData {
    auto &ec = neAppEventCenter::shared();
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud setObject:[NSNumber numberWithFloat:static_cast<float>(ec.lastMusic())]
           forKey:kKeyLastMusic];
    [ud setObject:[NSNumber numberWithFloat:static_cast<float>(ec.lastSheet())]
           forKey:kKeyLastSheet];
    [ud synchronize];
}

#pragma mark - Audio volumes (plaintext)

// @ 0x60300 — BGM master volume, clamped to [0.0, 1.0].
+ (float)bgmVolume {
    float v = [self getFloat:@"BgmVolume"];
    if (v >= 1.0f) {
        v = 1.0f;
    }
    if (v < 0.0f) {
        v = 0.0f;
    }
    return v;
}

// @ 0x60364 — clamp to [0.0, 1.0] then persist.
+ (void)saveBgmVolume:(float)volume {
    if (volume >= 1.0f) {
        volume = 1.0f;
    }
    if (volume < 0.0f) {
        volume = 0.0f;
    }
    [self saveFloat:volume Key:@"BgmVolume"];
}

// @ 0x603c4 — SE master volume (0..127); values >= 127 cap at 127, negatives
// clamp to 0.
+ (short)seVolume {
    int v = [self getInt:@"SeVolume"];
    short r = 0x7f;
    if (static_cast<short>(v) < 0x7f) {
        r = static_cast<short>(v);
    }
    if (r < 0) {
        r = 0;
    }
    return r;
}

// @ 0x60404 — cap at 127 (cmp #0x7f; ge->0x7f) then clamp negatives to 0
// (cmp #0; lt->0) before persisting.
+ (void)saveSeVolume:(short)volume {
    if (volume >= 0x7f) {
        volume = 0x7f;
    }
    if (volume < 0) {
        volume = 0;
    }
    [self saveInt:volume Key:@"SeVolume"];
}

// @ 0x60438 — per-tap SE volume (0..127); same clamp as seVolume.
+ (short)touchSoundVolume {
    int v = [self getInt:@"TouchSoundVolume"];
    short r = 0x7f;
    if (static_cast<short>(v) < 0x7f) {
        r = static_cast<short>(v);
    }
    if (r < 0) {
        r = 0;
    }
    return r;
}

// @ 0x60478 — cap at 127 (ge->0x7f) then clamp negatives to 0 (lt->0), same as
// saveSeVolume, and persist.
+ (void)saveTouchSoundVolume:(short)volume {
    if (volume >= 0x7f) {
        volume = 0x7f;
    }
    if (volume < 0) {
        volume = 0;
    }
    [self saveInt:volume Key:@"TouchSoundVolume"];
}

#pragma mark - AC-viewer play options (plaintext)

// @ 0x618cc
+ (void)saveAcvHiSpeed:(int)v {
    [self saveInt:v Key:@"AcViewerHiSpeed"];
}
// @ 0x6191c
+ (void)saveAcvPopKun:(int)v {
    [self saveInt:v Key:@"AcViewerPopKun"];
}
// @ 0x6196c
+ (void)saveAcvHidSud:(int)v {
    [self saveInt:v Key:@"AcViewerHidSud"];
}
// @ 0x619bc
+ (void)saveAcvRanMir:(int)v {
    [self saveInt:v Key:@"AcViewerRanMir"];
}
// @ 0x618a4
+ (int)acvHiSpeed {
    return [self getInt:@"AcViewerHiSpeed"];
}
// @ 0x618f4
+ (int)acvPopKun {
    return [self getInt:@"AcViewerPopKun"];
}
// @ 0x61944
+ (int)acvHidSud {
    return [self getInt:@"AcViewerHidSud"];
}
// @ 0x61994
+ (int)acvRanMir {
    return [self getInt:@"AcViewerRanMir"];
}
// @ 0x619e4
+ (BOOL)isAcvGenreName {
    return [self getBOOL:@"AcViewerIsGenreName"];
}
// @ 0x61a0c
+ (void)saveIsAcvGenreName:(BOOL)genreName {
    [self saveBOOL:genreName Key:@"AcViewerIsGenreName"];
}

#pragma mark - Music-list sort (plaintext)

// @ 0x60dd0 — clamp the stored sort index to 0..5.
+ (short)musicSort {
    int v = [self getInt:@"MusicSort"];
    short sort = (static_cast<short>(v) < 5) ? static_cast<short>(v) : 5;
    if (sort < 0) {
        sort = 0;
    }
    return sort;
}

// @ 0x60e10 — anything at/above 5 collapses to 5 (best-score; cmp #5, ge->5),
// then negatives clamp to 0 (cmp #0, lt->0).
+ (void)saveMusicSort:(short)sort {
    if (sort >= 5) {
        sort = 5;
    }
    if (sort < 0) {
        sort = 0;
    }
    [self saveInt:sort Key:@"MusicSort"];
}

#pragma mark - Simple mode / popkun

// @ 0x6075c
+ (BOOL)isSimpleMode {
    return [self getBOOL:@"SimpleMode"];
}
// @ 0x60784
+ (void)saveIsSimpleMode:(BOOL)on {
    [self saveBOOL:on Key:@"SimpleMode"];
}

// @ 0x60600 — note ("popkun") size, key "b". Valid range [50, 100]; anything
// outside (including an unset 0) falls back to the default 100.
+ (float)popkunSize {
    float v = [self getFloat:@"b"];
    if (v > 100.0f || v < 50.0f) {
        return 100.0f;
    }
    return v;
}

#pragma mark - Convert-code / device-change

// @ 0x61a34 — AES-decrypt the blob under key "ConvertCode" and decode it as
// UTF-8. The getData argument resolves to cf_ConvertCode (the same literal the
// setter stores under), not "a".
+ (NSString *)convertCode {
    NSData *data = [self getData:@"ConvertCode"];
    if (data != nil) {
        NSData *plain = [data decryptWith128Key:kAESKey initVector:kAESIV];
        return [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
    }
    return nil;
}

// @ 0x61ad0 — UTF-8 encode, AES-encrypt, store under key "ConvertCode" (nil
// clears it).
+ (void)saveConvertCode:(NSString *)code {
    NSData *enc = nil;
    if (code != nil) {
        NSData *plain = [code dataUsingEncoding:NSUTF8StringEncoding];
        enc = [plain encryptWith128Key:kAESKey initVector:kAESIV];
    }
    [self saveData:enc Key:@"ConvertCode"];
}

// @ 0x61c44
+ (BOOL)isFollowBonusGet {
    return [self getBOOL:@"IsFollowBonusGet"];
}
// @ 0x61c6c
+ (void)saveIsFollowBonusGet:(BOOL)got {
    [self saveBOOL:got Key:@"IsFollowBonusGet"];
}

// @ 0x61804 — the client version that last completed the device-change flow
// (key "LastCompletedClientVer").
+ (int)lastCompletedClientVer {
    return [self getInt:@"LastCompletedClientVer"];
}
// @ 0x6182c
+ (void)saveLastCompletedClientVer:(int)ver {
    [self saveInt:ver Key:@"LastCompletedClientVer"];
}
// @ 0x60090 — record acceptance of the privacy policy / terms. The persisted
// key is the misspelled "IsPolicyAccesped" (verified: the setter's boolForKey
// compare and setObject both reference that CFString).
+ (void)saveIsPolicyAccepted:(BOOL)accepted {
    [self saveBOOL:accepted Key:@"IsPolicyAccesped"];
}

// @ 0x60a40 — whether the player has already redeemed an invite code (key
// "IsInputInviteCode").
+ (BOOL)isInputInviteCode {
    return [self getBOOL:@"IsInputInviteCode"];
}
// @ 0x60a68
+ (void)saveIsInputInviteCode:(BOOL)v {
    [self saveBOOL:v Key:@"IsInputInviteCode"];
}

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

// @ 0x61540 — reset the pending-treasure snapshot to the empty/"nothing
// pending" record (the same default treasureTmp hands back) and persist it.
// The binary zeroes the record then writes 0xffff at 0x2, 0x4, and 0x44.
+ (void)initTreasureTmp {
    TreasureTmpData data;
    memset(&data, 0, sizeof(data));
    data.subMapId = -1;
    data.curSubMapId = -1;
    data.rouletteMode = -1;
    [self saveTreasureTmp:data];
}

// @ 0x61c94 — scan the "e" array of {mapid, readno} dictionaries for subMapId
// and return its readno, or 0 when the sub-map has no stored entry.
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
+ (NSArray *)uncompleteSaveMusic {
    return [self getArray:@"UncompleteSaveMusic"];
}
// @ 0x60ab8
+ (NSArray *)uncompleteSaveSheet {
    return [self getArray:@"UncompleteSaveSheet"];
}

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
+ (void)savePlayerId:(NSString *)playerId {
    [self saveString:playerId Key:@"PlayerId"];
}
// @ 0x60238
+ (void)savePlayerName:(NSString *)name {
    [self saveString:name Key:@"PlayerName"];
}
// @ 0x602d8
+ (void)saveKonamiId:(NSString *)konamiId {
    [self saveString:konamiId Key:@"KonamiId"];
}

#pragma mark - Store / news / spending

// @ 0x61854 — last-seen store information banner id (note the original key's
// typo).
+ (int)lastInformationId {
    return [self getInt:@"LastInfomationId"];
}

// @ 0x5fe88 — timestamp string of the last store view.
+ (NSString *)lastStoreViewTimeString {
    return [self getString:@"LastUpdateTime"];
}

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
+ (int)lastAnswerQuizId {
    return [self getInt:@"LastAnswerQuizId"];
}
+ (void)saveLastAnswerQuizId:(int)v {
    [self saveInt:v Key:@"LastAnswerQuizId"];
}
// @ 0x61714 / 0x6173c
+ (int)totalCorrectQuiz {
    return [self getInt:@"TotalCorrectQuiz"];
}
+ (void)saveTotalCorrectQuiz:(int)v {
    [self saveInt:v Key:@"TotalCorrectQuiz"];
}
// @ 0x61764 / 0x6178c
+ (int)totalInCorrectQuiz {
    return [self getInt:@"TotalInCorrectQuiz"];
}
+ (void)saveTotalInCorrectQuiz:(int)v {
    [self saveInt:v Key:@"TotalInCorrectQuiz"];
}
// @ 0x617b4 / 0x617dc
+ (int)consecutiveCorrectQuiz {
    return [self getInt:@"ConsecutiveCorrectQuiz"];
}
+ (void)saveConsecutiveQuiz:(int)v {
    [self saveInt:v Key:@"ConsecutiveCorrectQuiz"];
}

// @ 0x612b0 — grant character tickets (Crypt109 charaTicket += count); no-op
// for count < 1 (cmp #1; it lt; return), so zero and negative counts do nothing.
// The sum is truncated to 16 bits (sxth) before saving.
+ (void)addCharaTicket:(int)count {
    if (count < 1) {
        return;
    }
    short cur = [self charaTicket];
    [self saveCharaTicket:static_cast<short>(cur + count)];
}

#pragma mark - Store / recommend view timestamps

// @ 0x5feb0 — paired setter for +lastStoreViewTimeString (same key
// "LastUpdateTime").
+ (void)saveLastStoreViewTimeString:(NSString *)time {
    [self saveString:time Key:@"LastUpdateTime"];
}

// @ 0x5fed8 — timestamp string of the last store-recommend view.
+ (NSString *)lastRecommendViewTimeString {
    return [self getString:@"LastRecommendViewTime"];
}

// @ 0x5ff00 — persist the last store-recommend view timestamp string.
+ (void)saveLastRecommendViewTimeString:(NSString *)time {
    [self saveString:time Key:@"LastRecommendViewTime"];
}

#pragma mark - Tutorial / policy

// @ 0x5ff28 / 0x5ff50 — first-run tutorial played flag (key
// "IsTutorialPlayed").
+ (BOOL)isTutorialPlayed {
    return [self getBOOL:@"IsTutorialPlayed"];
}
+ (void)saveIsTutorialPlayed:(BOOL)played {
    [self saveBOOL:played Key:@"IsTutorialPlayed"];
}

// @ 0x60068 — getter paired with +saveIsPolicyAccepted:. The binary's shared
// CFString literal is the misspelled "IsPolicyAccesped", so the key here matches
// it exactly (both accessors read/write the same persisted key).
+ (BOOL)isPolicyAccepted {
    return [self getBOOL:@"IsPolicyAccesped"];
}

#pragma mark - Touch radius / popkun setter

// @ 0x605a4 — the note touch radius. In the binary this getter returns a
// hardcoded constant (0x42880000 == 68.0), ignoring the stored value.
+ (float)touchRadius {
    return 68.0f;
}

// @ 0x605ac — clamp to [40.0, 148.0] (min against 148.0, then vmax against
// 40.0) and persist.
+ (void)saveTouchRadius:(float)radius {
    float v = radius < 148.0f ? radius : 148.0f;
    v = v > 40.0f ? v : 40.0f;
    [self saveFloat:v Key:@"TouchRadius"];
}

// @ 0x60668 — clamp to [50.0, 100.0] (min against 100.0, then vmax against
// 50.0) and persist (key "b").
+ (void)savePopkunSize:(float)size {
    float v = size < 100.0f ? size : 100.0f;
    v = v > 50.0f ? v : 50.0f;
    [self saveFloat:v Key:@"b"];
}

#pragma mark - Store information banner / info-view day

// @ 0x6187c — setter paired with +lastInformationId (note the original key's
// typo).
+ (void)saveLastInformationId:(int)informationId {
    [self saveInt:informationId Key:@"LastInfomationId"];
}

// @ 0x61b44 / 0x61b6c — the day the store information banner was last viewed
// (key "InfoViewDay").
+ (NSDate *)getInfoViewDay {
    return [self getDate:@"InfoViewDay"];
}
+ (void)saveInfoViewDay:(NSDate *)day {
    [self saveDate:day Key:@"InfoViewDay"];
}

// @ 0x61b94 — YES if `day` and the stored InfoViewDay fall on the same calendar
// day, compared as "yyyy/MM/dd"-formatted strings.
+ (BOOL)isEqualToInfoViewDay:(NSDate *)day {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"yyyy/MM/dd"];
    NSString *stored = [fmt stringFromDate:[self getInfoViewDay]];
    NSString *other = [fmt stringFromDate:day];
    return [stored isEqualToString:other];
}

#pragma mark - Treasure (consumed points / read progress)

// @ 0x613ec — add to the consumed treasure-point total, clamped to [0, 9999]
// (key "ConsumedTreasurePoint").
+ (void)addConsumedTreasurePoint:(short)value {
    short cur = [self consumedTreasurePoint];
    int total = static_cast<short>(cur + value);
    if (total > 9998) { // Ghidra: 0x270e < total
        total = 9999;
    }
    if (total < 0) {
        total = 0;
    }
    [self saveInt:total Key:@"ConsumedTreasurePoint"];
}

// @ 0x61dc0 — persist the "treasure read" progress index for a sugoroku sub-map
// into the "e" array of {mapid, readno} dictionaries: update the matching
// entry's readno, or append a new {mapid, readno} entry when the sub-map has
// none yet.
+ (void)saveTreasureReadNo:(short)subMapId no:(int)no {
    NSMutableArray *array = [[self getArray:@"e"] mutableCopy];
    BOOL matched = NO;
    NSUInteger index = 0;
    for (NSDictionary *entry in array) {
        if ([[entry objectForKey:@"mapid"] shortValue] == subMapId) {
            NSMutableDictionary *updated = [entry mutableCopy];
            if (updated == nil) {
                break; // Ghidra: falls through to the append branch
            }
            [updated setObject:[NSNumber numberWithInt:no] forKey:@"readno"];
            [array replaceObjectAtIndex:index withObject:[updated copy]];
            matched = YES;
            break;
        }
        index++;
    }
    if (!matched) {
        if (array == nil) {
            array = [NSMutableArray array];
        }
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:[NSNumber numberWithShort:subMapId] forKey:@"mapid"];
        [entry setObject:[NSNumber numberWithShort:static_cast<short>(no)] forKey:@"readno"];
        [array addObject:entry];
        NSLog(@"%@", entry);
    }
    NSLog(@"%@", array);
    [self saveArray:[array copy] Key:@"e"];
}

@end
