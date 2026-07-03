//
//  UserSettingData.h
//  pop'n rhythmin
//
//  Global user-settings / progress store. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin. All methods are class methods.
//
//  Two storage tiers:
//   * Plaintext NSUserDefaults (effects, last music/sheet).
//   * An AES-128-CBC-encrypted 36-byte "Crypt109" blob under key "c" holding
//     player progress, plus an encrypted archived owned-characters array under
//     key "d". This replaced the v108 layout, which stored each field as a
//     separate plaintext PascalCase key; loadSettingData migrates v108 -> v109.
//

#import <Foundation/Foundation.h>

#import "TreasureTmpData.h"

// Player-progress blob, version 109. Serialized as exactly 36 bytes (0x24),
// AES-128-CBC encrypted, and stored under NSUserDefaults key "c".
// Field offsets/types recovered from -[UserSettingData crypt109Data:] @ 0x615b4.
typedef struct Crypt109Data {
    int32_t  inviteCnt;             // 0x00
    int32_t  invitePresent;         // 0x04
    int16_t  charaTicket;           // 0x08
    int16_t  treasurePoint;         // 0x0a
    int32_t  openedLoginBonusId;    // 0x0c
    int32_t  loginBonusCnt;         // 0x10
    int16_t  charaId;               // 0x14
    int16_t  charaIdServer;         // 0x16
    int32_t  touchSoundKind;        // 0x18
    int32_t  haveTouchSoundFlg;     // 0x1c  (bitmask, 7 bits used)
    uint8_t  isBemaniCollaboOpened; // 0x20
    uint8_t  _pad[3];               // 0x21..0x23
} Crypt109Data;                     // sizeof == 0x24 (36)

@interface UserSettingData : NSObject

#pragma mark NSUserDefaults primitives
+ (int)getInt:(NSString *)key;
+ (void)saveInt:(int)value Key:(NSString *)key;
+ (id)getDate:(NSString *)key;   // @ 0x5f990 (stored NSDate)
+ (void)saveDate:(id)value Key:(NSString *)key;
+ (float)getFloat:(NSString *)key;
+ (void)saveFloat:(float)value Key:(NSString *)key;
+ (NSString *)getString:(NSString *)key;
+ (void)saveString:(NSString *)value Key:(NSString *)key;
+ (BOOL)getBOOL:(NSString *)key;
+ (void)saveBOOL:(BOOL)value Key:(NSString *)key;
+ (NSData *)getData:(NSString *)key;
+ (void)saveData:(NSData *)value Key:(NSString *)key;

#pragma mark Purchase / age-gate (youth spending limit)
+ (NSDate *)birthDay;                // @ 0x607fc
+ (void)saveBirthDay:(NSDate *)date; // @ 0x60824
+ (BOOL)isBirthDayCanceled;          // @ 0x6084c
+ (void)saveIsBirthDayCanceled:(BOOL)canceled;  // @ 0x60874
+ (BOOL)isFriendSelected;                       // @ 0x5ffc8 (friend how-to seen)
+ (void)saveIsFriendSelected:(BOOL)selected;    // @ 0x5fff0
+ (NSDate *)lastUpdateSumPurchase;   // @ 0x6089c
+ (int)sumPurchase;                  // @ 0x608ec (yen spent this month, clamped >= 0)

#pragma mark Lifecycle
+ (void)loadSettingData;      // @ 0x5efb4
+ (void)saveSettingData;      // @ 0x5f66c

#pragma mark Identity (plaintext)
+ (NSString *)playerId;                   // @ 0x60260  (key "PlayerId")
+ (NSString *)playerName;                 // @ 0x60210  (key "PlayerName")

#pragma mark Friend list (plaintext)
+ (BOOL)isBestScoreSort;                  // @ 0x607ac  (key "IsBestScoreSort")
+ (void)saveIsBestScoreSort:(BOOL)best;   // @ 0x607d4

#pragma mark Effects (plaintext)
+ (BOOL)isEffectOn;                       // @ 0x606bc  (key "IsEffectOn")
+ (void)saveIsEffectOn:(BOOL)on;          // @ 0x606e4
+ (BOOL)isLongNotesEffectOn;              // @ 0x6070c  (key "IsLongNotesEffectOn")
+ (void)saveIsLongNotesEffectOn:(BOOL)on; // @ 0x60734

// Play-scene settings read by PlayTaskInit (Ghidra: FUN_0002e2d8). touchSoundVolume
// is the per-tap SE volume (stored at play data +0x9b4); isSimpleMode selects the
// simplified note field (+0x9e4); popkunSize is the note ("popkun") size, converted
// to 16.16 fixed at +0x9bc.
+ (short)touchSoundVolume;                // -[UserSettingData touchSoundVolume]
+ (BOOL)isSimpleMode;                     // -[UserSettingData isSimpleMode]
+ (float)popkunSize;                      // -[UserSettingData popkunSize]

#pragma mark Treasure (sugoroku pending-goal snapshot)
// Read back the "pending treasure" record stored under the key "TreasureTmpData":
// the goal the player just reached on the sugoroku board, carried across the arcade
// launch. When no record is stored, returns a default whose subMapId is -1 ("nothing
// pending"). The arcade task polls this to know when to load a map and start play.
// Ghidra: -[UserSettingData treasureTmp:] @ 0x61448.
+ (TreasureTmpData)treasureTmp;

// Persist the "pending treasure" record back under the key "TreasureTmpData" (the raw
// memory image is memcpy'd straight into the stored NSData blob). The sugoroku map
// parser uses this to persist which bonus square it randomly picked as the session's
// treasure. Ghidra: -[UserSettingData saveTreasureTmp:] @ 0x614f0.
+ (void)saveTreasureTmp:(TreasureTmpData)data;

// The persisted "treasure read" progress index for a sugoroku sub-map (how far the
// player has advanced its board story), or a negative sentinel when unread. The
// arcade map loader reads it to resume the board. Ghidra: -[UserSettingData
// treasureReadNo:] (selector PTR_s_treasureReadNo__ @ 0x15b6c8).
+ (int)treasureReadNo:(short)subMapId;

#pragma mark Crypt109 blob (key "c")
+ (void)crypt109Data:(Crypt109Data *)out;         // @ 0x615b4 (read+decrypt)
+ (void)saveCrypt109Data:(const Crypt109Data *)data; // @ 0x61650 (encrypt+write)

#pragma mark Crypt109 field accessors
// Getters read the decrypted blob; setters read-modify-write it. Verified:
// inviteCnt @ 0x60950, charaTicket @ 0x61238, haveTouchSoundFlg getter/setter.
// The remaining selector names follow the observed convention (getters = field
// name, save<Field>: setters; loginBonus getters keep the "get" prefix).
+ (int)inviteCnt;                 + (void)saveInviteCnt:(int)v;
+ (int)invitePresent;             + (void)saveInvitePresent:(int)v;
+ (short)charaTicket;             + (void)saveCharaTicket:(short)v;
+ (short)treasurePoint;           + (void)saveTreasurePoint:(short)v;
+ (int)getOpenedLoginBonusId;     + (void)saveOpenedLoginBonusId:(int)v;
+ (int)getLoginBonusCnt;          + (void)saveLoginBonusCnt:(int)v;
+ (short)charaId;                 + (void)saveCharaId:(short)v;
+ (short)charaIdServer;           + (void)saveCharaIdServer:(short)v;
+ (int)touchSoundKind;            + (void)saveTouchSoundKind:(int)v;
+ (int)haveTouchSoundFlg;         + (void)saveHaveTouchSoundFlg:(int)v;
+ (BOOL)isBemaniCollaboOpened;    + (void)saveIsBemaniCollaboOpened:(BOOL)v;

#pragma mark Owned characters
+ (int)gotChara;                    // @ 0x60f24  ("GotChara" int, bits 0/1 forced on)
+ (NSArray *)gotCharaArray;         // @ 0x60f54  (encrypted archived array, key "d")
+ (void)saveGotCharaArray:(short)charaIndex; // @ 0x610a0

#pragma mark Uncomplete score-save queue
// When a finished play cannot be uploaded immediately (score improved but the
// HTTP save is deferred), the result screen queues the music/sheet here and
// flushes the pending entry on a later result. The two getters return parallel
// NSArrays of NSNumber (music ids / sheet indices). Referenced by
// PlayResultTask::resultSetup (Ghidra FUN_0003dfe0 @ 0x3e246 / 0x3e482 / 0x3e49c).
+ (void)addUncompleteSaveMusic:(int)music sheet:(short)sheet; // selector @ 0x15a8e0
+ (NSArray *)uncompleteSaveMusic;                             // selector @ 0x15a8e8
+ (NSArray *)uncompleteSaveSheet;                             // selector @ 0x15a8ec

#pragma mark Audio volumes (plaintext)
// BGM master volume used when a scene (re)loads its BGM. Ghidra: -[UserSettingData
// bgmVolume] (selector PTR_s_bgmVolume_0015a754), read by PlayResultTask::resultSetup
// @ 0x3f0ac before -[AudioManager setBgmVolume:].
+ (float)bgmVolume;

#pragma mark Legacy v108 readers (plaintext PascalCase keys; used by migration)
+ (int)inviteCnt108;              // key "InviteCnt"          @ 0x5fc5c
+ (int)invitePresent108;         // key "InvitePresent"      @ 0x5fc90
+ (short)charaTicket108;         // key "CharaTicket"        @ 0x5fcc4
+ (short)treasurePoint108;       // key "TreasurePoint"      @ 0x5fcfc
+ (int)getOpenedLoginBonusId108; // key "OpenedLoginBonusId" @ 0x5fd34
+ (int)getLoginBonusCnt108;      // key "LoginBonusCnt"      @ 0x5fd64
+ (short)charaId108;             // key "CharaId"            @ 0x5fd8c
+ (short)charaIdServer108;       // key "CharaIdServer"      @ 0x5fdbc
+ (int)touchSoundKind108;        // key "TouchSoundKind"     @ 0x5fdec
+ (int)haveTouchSoundFlg108;     // key "HaveTouchSoundFlg"  @ 0x5fe2c
+ (BOOL)isBemaniCollaboOpened108;// key "IsBemaniCollaboOpened" @ 0x5fe60

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
