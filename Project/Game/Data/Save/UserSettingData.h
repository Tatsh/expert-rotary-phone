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

// The four AC-viewer custom options, in row order. The value is both the option
// group index and which sub-setting the row edits (acvHiSpeed / acvPopKun /
// acvHidSud / acvRanMir). Shared here because the option-list controller and
// both of its cells key off it.
typedef NS_ENUM(NSInteger, AcvOptionRow) {
    AcvOptionRowHiSpeed = 0, // AcViewerHiSpeedViewController
    AcvOptionRowPopKun = 1,  // AcViewerPopKunViewController
    AcvOptionRowHidSud = 2,  // AcViewerHidSudViewController
    AcvOptionRowRanMir = 3,  // AcViewerRanMirViewController
    AcvOptionRowCount = 4,
};

// Player-progress blob, version 109. Serialized as exactly 36 bytes (0x24),
// AES-128-CBC encrypted, and stored under NSUserDefaults key "c".
// Field offsets/types recovered from -[UserSettingData crypt109Data:] @
// 0x615b4.
typedef struct Crypt109Data {
    int32_t inviteCnt;             // 0x00
    int32_t invitePresent;         // 0x04
    int16_t charaTicket;           // 0x08
    int16_t treasurePoint;         // 0x0a
    int32_t openedLoginBonusId;    // 0x0c
    int32_t loginBonusCnt;         // 0x10
    int16_t charaId;               // 0x14
    int16_t charaIdServer;         // 0x16
    int32_t touchSoundKind;        // 0x18
    int32_t haveTouchSoundFlg;     // 0x1c  (bitmask, 7 bits used)
    uint8_t isBemaniCollaboOpened; // 0x20
    uint8_t _pad[3];               // 0x21..0x23
} Crypt109Data;                    // sizeof == 0x24 (36)

@interface UserSettingData : NSObject

#pragma mark NSUserDefaults primitives
+ (int)getInt:(NSString *)key;
+ (void)saveInt:(int)value Key:(NSString *)key;
+ (id)getDate:(NSString *)key; // @ 0x5f990 (stored NSDate)
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
+ (NSDate *)birthDay;                          // @ 0x607fc
+ (void)saveBirthDay:(NSDate *)date;           // @ 0x60824
+ (BOOL)isBirthDayCanceled;                    // @ 0x6084c
+ (void)saveIsBirthDayCanceled:(BOOL)canceled; // @ 0x60874
+ (BOOL)isFriendSelected;                      // @ 0x5ffc8 (friend how-to seen)
+ (void)saveIsFriendSelected:(BOOL)selected;   // @ 0x5fff0
+ (NSDate *)lastUpdateSumPurchase;             // @ 0x6089c
+ (int)sumPurchase;                            // @ 0x608ec (yen spent this month, clamped >= 0)

#pragma mark Lifecycle
+ (void)loadSettingData; // @ 0x5efb4
+ (void)saveSettingData; // @ 0x5f66c

#pragma mark Identity (plaintext)
+ (NSString *)playerId;   // @ 0x60260  (key "PlayerId")
+ (NSString *)playerName; // @ 0x60210  (key "PlayerName")
+ (NSString *)konamiId;   // @ 0x602b0  (key "KonamiId")

#pragma mark Friend list (plaintext)
+ (BOOL)isBestScoreSort;                // @ 0x607ac  (key "IsBestScoreSort")
+ (void)saveIsBestScoreSort:(BOOL)best; // @ 0x607d4

#pragma mark Effects (plaintext)
+ (BOOL)isEffectOn;                       // @ 0x606bc  (key "IsEffectOn")
+ (void)saveIsEffectOn:(BOOL)on;          // @ 0x606e4
+ (BOOL)isLongNotesEffectOn;              // @ 0x6070c  (key "IsLongNotesEffectOn")
+ (void)saveIsLongNotesEffectOn:(BOOL)on; // @ 0x60734

// Play-scene settings read by PlayTaskInit (Ghidra: FUN_0002e2d8).
// touchSoundVolume is the per-tap SE volume (stored at play data +0x9b4);
// isSimpleMode selects the simplified note field (+0x9e4); popkunSize is the
// note ("popkun") size, truncated from float to a plain int at +0x9bc.
+ (short)touchSoundVolume; // -[UserSettingData touchSoundVolume]
+ (BOOL)isSimpleMode;      // -[UserSettingData isSimpleMode]
+ (float)popkunSize;       // -[UserSettingData popkunSize]

#pragma mark Treasure (sugoroku pending-goal snapshot)
// Read back the "pending treasure" record stored under the key
// "TreasureTmpData": the goal the player just reached on the sugoroku board,
// carried across the arcade launch. When no record is stored, returns a default
// whose subMapId is -1 ("nothing pending"). The arcade task polls this to know
// when to load a map and start play. Ghidra: -[UserSettingData treasureTmp:] @
// 0x61448.
+ (TreasureTmpData)treasureTmp;

// Persist the "pending treasure" record back under the key "TreasureTmpData"
// (the raw memory image is memcpy'd straight into the stored NSData blob). The
// sugoroku map parser uses this to persist which bonus square it randomly
// picked as the session's treasure. Ghidra: -[UserSettingData saveTreasureTmp:]
// @ 0x614f0.
+ (void)saveTreasureTmp:(TreasureTmpData)data;

// The main-map id whose sugoroku map-select/area screen is currently being
// shown, backed by the plaintext int key "SelectedMapId". The pad map-select
// hub reads it to know which map to build. Ghidra: treasureSelectedMapId @
// 0x6209c / saveTreasureSelectedMapId: @ 0x620cc.
+ (short)treasureSelectedMapId;
+ (void)saveTreasureSelectedMapId:(short)mapId;

// Remembers whether the sugoroku "treasure" first-run how-to has been shown (so
// the two-page how-to only appears once), backed by a plaintext BOOL key.
// Ghidra: isTreasureSelected @ 0x60018 / saveIsTreasureSelected: @ 0x60040.
+ (BOOL)isTreasureSelected;
+ (void)saveIsTreasureSelected:(BOOL)selected;

// The persisted "treasure read" progress index for a sugoroku sub-map (how far
// the player has advanced its board story), or a negative sentinel when unread.
// The arcade map loader reads it to resume the board. Ghidra: -[UserSettingData
// treasureReadNo:] (selector PTR_s_treasureReadNo__ @ 0x15b6c8).
+ (int)treasureReadNo:(short)subMapId;

// The consumed sugoroku "treasure point" total, clamped to [0, 9999] on save
// and to >= 0 on read. Backed by the plaintext int key "ConsumedTreasurePoint".
// Ghidra: consumedTreasurePoint @ 0x61378 / saveConsumedTreasurePoint: @
// 0x613b0.
+ (short)consumedTreasurePoint;
+ (void)saveConsumedTreasurePoint:(short)value;

#pragma mark Crypt109 blob (key "c")
+ (void)crypt109Data:(Crypt109Data *)out;            // @ 0x615b4 (read+decrypt)
+ (void)saveCrypt109Data:(const Crypt109Data *)data; // @ 0x61650 (encrypt+write)

#pragma mark Crypt109 field accessors
// Getters read the decrypted blob; setters read-modify-write it. Verified:
// inviteCnt @ 0x60950, charaTicket @ 0x61238, haveTouchSoundFlg getter/setter.
// The remaining selector names follow the observed convention (getters = field
// name, save<Field>: setters; loginBonus getters keep the "get" prefix).
+ (int)inviteCnt;
+ (void)saveInviteCnt:(int)v;
+ (int)invitePresent;
+ (void)saveInvitePresent:(int)v;
+ (short)charaTicket;
+ (void)saveCharaTicket:(short)v;
+ (short)treasurePoint;
+ (void)saveTreasurePoint:(short)v;
+ (int)getOpenedLoginBonusId;
+ (void)saveOpenedLoginBonusId:(int)v;
+ (int)getLoginBonusCnt;
+ (void)saveLoginBonusCnt:(int)v;
+ (short)charaId;
+ (void)saveCharaId:(short)v;
+ (short)charaIdServer;
+ (void)saveCharaIdServer:(short)v;
+ (int)touchSoundKind;
+ (void)saveTouchSoundKind:(int)v;
+ (int)haveTouchSoundFlg;
+ (void)saveHaveTouchSoundFlg:(int)v;
+ (BOOL)isBemaniCollaboOpened;
+ (void)saveIsBemaniCollaboOpened:(BOOL)v;

#pragma mark Owned characters
+ (int)gotChara;                             // @ 0x60f24  ("GotChara" int, bits 0/1 forced on)
+ (NSArray *)gotCharaArray;                  // @ 0x60f54  (encrypted archived array, key "d")
+ (void)saveGotCharaArray:(short)charaIndex; // @ 0x610a0

#pragma mark Uncomplete score-save queue
// When a finished play cannot be uploaded immediately (score improved but the
// HTTP save is deferred), the result screen queues the music/sheet here and
// flushes the pending entry on a later result. The two getters return parallel
// NSArrays of NSNumber (music ids / sheet indices). Referenced by
// PlayResultTask::resultSetup (Ghidra FUN_0003dfe0 @ 0x3e246 / 0x3e482 /
// 0x3e49c).
+ (void)addUncompleteSaveMusic:(int)music sheet:(short)sheet; // selector @ 0x15a8e0
+ (NSArray *)uncompleteSaveMusic;                             // selector @ 0x15a8e8
+ (NSArray *)uncompleteSaveSheet;                             // selector @ 0x15a8ec

#pragma mark Audio volumes (plaintext)
// BGM master volume used when a scene (re)loads its BGM. Ghidra:
// -[UserSettingData bgmVolume] (selector PTR_s_bgmVolume_0015a754), read by
// PlayResultTask::resultSetup
// @ 0x3f0ac before -[AudioManager setBgmVolume:].
+ (float)bgmVolume;
// Paired setter for +bgmVolume. Ghidra: -[UserSettingData saveBgmVolume:]
// (PTR_s_saveBgmVolume__0015afc0), written by -[SoundSettingView dealloc] and
// -[SoundSettingView bgmSliderValChanged:] (iPad).
+ (void)saveBgmVolume:(float)volume;

// SE master volume, stored as a plain short (0..127). Read by
// SoundSettingView to seed its SE slider. Ghidra: -[UserSettingData seVolume]
// (PTR_s_seVolume_0015a758) / -[UserSettingData saveSeVolume:]
// (PTR_s_saveSeVolume__0015afbc).
+ (short)seVolume;
+ (void)saveSeVolume:(short)volume;

// Paired setter for +touchSoundVolume (declared under "Effects" above). Ghidra:
// -[UserSettingData saveTouchSoundVolume:]
// (PTR_s_saveTouchSoundVolume__0015afc4), written by SoundSettingView.
+ (void)saveTouchSoundVolume:(short)volume;

#pragma mark Legacy v108 readers (plaintext PascalCase keys; used by migration)
+ (int)inviteCnt108;              // key "InviteCnt"          @ 0x5fc5c
+ (int)invitePresent108;          // key "InvitePresent"      @ 0x5fc90
+ (short)charaTicket108;          // key "CharaTicket"        @ 0x5fcc4
+ (short)treasurePoint108;        // key "TreasurePoint"      @ 0x5fcfc
+ (int)getOpenedLoginBonusId108;  // key "OpenedLoginBonusId" @ 0x5fd34
+ (int)getLoginBonusCnt108;       // key "LoginBonusCnt"      @ 0x5fd64
+ (short)charaId108;              // key "CharaId"            @ 0x5fd8c
+ (short)charaIdServer108;        // key "CharaIdServer"      @ 0x5fdbc
+ (int)touchSoundKind108;         // key "TouchSoundKind"     @ 0x5fdec
+ (int)haveTouchSoundFlg108;      // key "HaveTouchSoundFlg"  @ 0x5fe2c
+ (BOOL)isBemaniCollaboOpened108; // key "IsBemaniCollaboOpened" @ 0x5fe60

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as local extern/category
// seams).

// Arcade-viewer play options (stored index per option kind).
+ (int)acvHiSpeed;
+ (int)acvPopKun;
+ (int)acvHidSud;
+ (int)acvRanMir;
// Paired setters for the arcade-viewer play options, written by the per-option
// detail screens (AcViewerHiSpeed/PopKun/HidSud/RanMirViewController) when a
// row is selected. Ghidra selector pointers: -[UserSettingData saveAcvHiSpeed:]
// (PTR_s_saveAcvHiSpeed__0015a764), saveAcvPopKun:
// (PTR_s_saveAcvPopKun__0015b390), saveAcvHidSud:
// (PTR_s_saveAcvHidSud__0015a3c0), saveAcvRanMir:
// (PTR_s_saveAcvRanMir__0015b6f8).
+ (void)saveAcvHiSpeed:(int)value;
+ (void)saveAcvPopKun:(int)value;
+ (void)saveAcvHidSud:(int)value;
+ (void)saveAcvRanMir:(int)value;
// YES if the arcade viewer shows the genre name instead of the song name.
+ (BOOL)isAcvGenreName;
// Toggle the arcade-viewer genre/song-name mode (written by the AC-viewer song
// list's change button). Ghidra: saveIsAcvGenreName: @ 0x61a0c (key
// "AcViewerIsGenreName").
+ (void)saveIsAcvGenreName:(BOOL)genreName;

// Music-list sort mode (0 title / 1 artist / 2 Lv N / 3 Lv H / 4 Lv EX / 5
// best-score), clamped to 0..5. Read/written by the sort-select screen. Ghidra:
// musicSort @ 0x60dd0 / saveMusicSort: @ 0x60e10 (key "MusicSort").
+ (short)musicSort;
+ (void)saveMusicSort:(short)sort;

// Arcade convert-code (links the app to an arcade eAmusement account).
+ (NSString *)convertCode;
+ (void)saveConvertCode:(NSString *)code;
// One-shot "follow bonus" (Twitter follow reward) claimed flag.
+ (BOOL)isFollowBonusGet;
+ (void)saveIsFollowBonusGet:(BOOL)got;
// Reset the convert-code / follow-bonus state.
+ (void)initForConvert;
// Client version that last completed the device-change flow; policy-accepted
// flag.
+ (int)lastCompletedClientVer;
+ (void)saveLastCompletedClientVer:(int)ver;
+ (void)saveIsPolicyAccepted:(BOOL)accepted;

// Whether the player has already redeemed an invite code (a code may be entered
// only once). Backed by the plaintext BOOL key "IsInputInviteCode".
// Ghidra: isInputInviteCode @ 0x60a40 / saveIsInputInviteCode: @ 0x60a68.
+ (BOOL)isInputInviteCode;
+ (void)saveIsInputInviteCode:(BOOL)v;

// Whether the pop'n-link first-run how-to has already been shown. The
// pop'n-link top screen sets it the first time the KID-input screen is pushed
// (so the "firstplay_popnlink" how-to only appears once). Backed by a plaintext
// BOOL key. Ghidra: isPopnLinkSelected / saveIsPopnLinkSelected: (read/written
// by PopnLinkTopViewController startOpenAnimation @ 0xcd5a8).
+ (BOOL)isPopnLinkSelected;
+ (void)saveIsPopnLinkSelected:(BOOL)selected;

// Last-seen store information banner id and last store-view timestamp string.
+ (int)lastInformationId;
+ (NSString *)lastStoreViewTimeString;

// Identity setters (paired with +playerId / +playerName getters above).
+ (void)savePlayerId:(NSString *)playerId;
+ (void)savePlayerName:(NSString *)name;
// Store the e-AMUSEMENT KONAMI ID (key "KonamiId"), written when the KID-input
// screen's decide button starts the pop'n-link. Ghidra: saveKonamiId: @
// 0x602d8.
+ (void)saveKonamiId:(NSString *)konamiId;

// Remove a queued uncomplete score-save entry (paired with
// addUncompleteSaveMusic:sheet:).
+ (void)subUncompleteSaveMusic:(int)music sheet:(short)sheet;

// Clear the pending-treasure snapshot.
+ (void)initTreasureTmp;
// Setter paired with +isSimpleMode.
+ (void)saveIsSimpleMode:(BOOL)on;

// Quiz progress counters (plaintext NSUserDefaults ints, via
// getInt:/saveInt:Key:). Ghidra: lastAnswerQuizId @ 0x616c4 /
// saveLastAnswerQuizId: @ 0x616ec (key "LastAnswerQuizId"), totalCorrectQuiz @
// 0x61714 / saveTotalCorrectQuiz: @ 0x6173c (key "TotalCorrectQuiz"),
// totalInCorrectQuiz @ 0x61764 / saveTotalInCorrectQuiz:
// @ 0x6178c (key "TotalInCorrectQuiz"), consecutiveCorrectQuiz @ 0x617b4 /
// saveConsecutiveQuiz: @ 0x617dc (key "ConsecutiveCorrectQuiz"). Read/written
// by QuizMainViewController.
+ (int)lastAnswerQuizId;
+ (void)saveLastAnswerQuizId:(int)v;
+ (int)totalCorrectQuiz;
+ (void)saveTotalCorrectQuiz:(int)v;
+ (int)totalInCorrectQuiz;
+ (void)saveTotalInCorrectQuiz:(int)v;
+ (int)consecutiveCorrectQuiz;
+ (void)saveConsecutiveQuiz:(int)v;

// Grant character tickets (Crypt109 charaTicket += count).
+ (void)addCharaTicket:(int)count;
// Setters paired with +lastUpdateSumPurchase / +sumPurchase (age-gate spending
// totals).
+ (void)saveLastUpdateSumPurchase:(NSDate *)date;
+ (void)saveSumPurchase:(int)sum;

#pragma mark Store / recommend view timestamps
// Setter paired with +lastStoreViewTimeString (both back the key
// "LastUpdateTime"). Ghidra: saveLastStoreViewTimeString: @ 0x5feb0.
+ (void)saveLastStoreViewTimeString:(NSString *)time;
// Timestamp string of the last store-recommend view (key
// "LastRecommendViewTime"). Ghidra: lastRecommendViewTimeString @ 0x5fed8 /
// saveLastRecommendViewTimeString: @ 0x5ff00.
+ (NSString *)lastRecommendViewTimeString;
+ (void)saveLastRecommendViewTimeString:(NSString *)time;

#pragma mark Tutorial / policy
// Whether the first-run tutorial has already been played (key
// "IsTutorialPlayed"). Ghidra: isTutorialPlayed @ 0x5ff28 /
// saveIsTutorialPlayed: @ 0x5ff50.
+ (BOOL)isTutorialPlayed;
+ (void)saveIsTutorialPlayed:(BOOL)played;
// Getter paired with +saveIsPolicyAccepted: (privacy policy / terms
// acceptance). Ghidra: isPolicyAccepted @ 0x60068.
+ (BOOL)isPolicyAccepted;

#pragma mark Touch radius / popkun setter
// Note ("popkun") touch radius. In the binary the getter is a hardcoded
// constant (68.0), independent of the stored value; the setter clamps to [40,
// 148] before persisting (key "TouchRadius"). Ghidra: touchRadius @ 0x605a4 /
// saveTouchRadius: @ 0x605ac.
+ (float)touchRadius;
+ (void)saveTouchRadius:(float)radius;
// Setter paired with +popkunSize (key "b"); clamps to [50, 100].
// Ghidra: savePopkunSize: @ 0x60668.
+ (void)savePopkunSize:(float)size;

#pragma mark Store information banner
// Setter paired with +lastInformationId (note the original key's typo
// "LastInfomationId"). Ghidra: saveLastInformationId: @ 0x6187c.
+ (void)saveLastInformationId:(int)informationId;
// The day (NSDate) the store information banner was last viewed (key
// "InfoViewDay"). isEqualToInfoViewDay: compares against the stored day at
// yyyy/MM/dd granularity. Ghidra: getInfoViewDay @ 0x61b44 / saveInfoViewDay: @
// 0x61b6c / isEqualToInfoViewDay: @ 0x61b94.
+ (NSDate *)getInfoViewDay;
+ (void)saveInfoViewDay:(NSDate *)day;
+ (BOOL)isEqualToInfoViewDay:(NSDate *)day;

#pragma mark Treasure (consumed points / read progress)
// Add to the consumed sugoroku "treasure point" total, clamped to [0, 9999]
// (key "ConsumedTreasurePoint"). Ghidra: addConsumedTreasurePoint: @ 0x613ec.
+ (void)addConsumedTreasurePoint:(short)value;
// Persist the "treasure read" progress index for a sugoroku sub-map into the
// "e" array of {mapid, readno} dictionaries (update the matching entry, or
// append a new one). Ghidra: saveTreasureReadNo:no: @ 0x61dc0.
+ (void)saveTreasureReadNo:(short)subMapId no:(int)no;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
