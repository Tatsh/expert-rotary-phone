/**
 * @file
 * @brief The global user-settings and progress store.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. All methods are class methods.
 *
 * Two storage tiers:
 * - Plaintext NSUserDefaults (effects, last music and sheet).
 * - An AES-128-CBC-encrypted 36-byte "Crypt109" blob under key "c" holding player progress, plus
 *   an encrypted archived owned-characters array under key "d". This replaced the v108 layout,
 *   which stored each field as a separate plaintext PascalCase key; loadSettingData migrates v108
 *   to v109.
 */

#import <Foundation/Foundation.h>

#import "TreasureTmpData.h"

/**
 * @brief The four AC-viewer custom options, in row order.
 *
 * The value is both the option group index and which sub-setting the row edits (acvHiSpeed,
 * acvPopKun, acvHidSud or acvRanMir). It is shared here because the option-list controller and
 * both of its cells key off it.
 */
typedef NS_ENUM(NSInteger, AcvOptionRow) {
    AcvOptionRowHiSpeed = 0, /**< AcViewerHiSpeedViewController. */
    AcvOptionRowPopKun = 1,  /**< AcViewerPopKunViewController. */
    AcvOptionRowHidSud = 2,  /**< AcViewerHidSudViewController. */
    AcvOptionRowRanMir = 3,  /**< AcViewerRanMirViewController. */
    AcvOptionRowCount = 4,   /**< The number of option rows. */
};

/**
 * @brief The player-progress blob, version 109.
 *
 * Serialised as exactly 36 bytes (0x24), AES-128-CBC encrypted, and stored under NSUserDefaults
 * key "c". Field offsets and types were recovered from -[UserSettingData crypt109Data:] @
 * 0x615b4.
 */
typedef struct Crypt109Data {
    int32_t inviteCnt;             /**< 0x00 Invite codes redeemed. */
    int32_t invitePresent;         /**< 0x04 Invite presents outstanding. */
    int16_t charaTicket;           /**< 0x08 Owned character tickets. */
    int16_t treasurePoint;         /**< 0x0a Treasure-point balance. */
    int32_t openedLoginBonusId;    /**< 0x0c The login-bonus id most recently opened. */
    int32_t loginBonusCnt;         /**< 0x10 Login-bonus claim count. */
    int16_t charaId;               /**< 0x14 The locally-selected character id. */
    int16_t charaIdServer;         /**< 0x16 The character id the server last acknowledged. */
    int32_t touchSoundKind;        /**< 0x18 The selected touch-sound kind. */
    int32_t haveTouchSoundFlg;     /**< 0x1c Owned touch-sound bitmask; seven bits used. */
    uint8_t isBemaniCollaboOpened; /**< 0x20 Whether the BEMANI collaboration is unlocked. */
    uint8_t _pad[3];               /**< 0x21 Padding out to 0x24. */
} Crypt109Data;

/**
 * @brief The global user-settings and progress store. Every method is a class method.
 */
@interface UserSettingData : NSObject

#pragma mark NSUserDefaults primitives

/**
 * @brief Read a plaintext integer default.
 * @param key The defaults key.
 * @return The stored value, or 0 when absent.
 */
+ (int)getInt:(NSString *)key;
/**
 * @brief Write a plaintext integer default.
 * @param value The value to store.
 * @param key The defaults key.
 */
+ (void)saveInt:(int)value Key:(NSString *)key;
/**
 * @brief Read a plaintext NSDate default.
 * @param key The defaults key.
 * @return The stored NSDate, or nil when absent.
 * @ghidraAddress 0x5f990
 */
+ (id)getDate:(NSString *)key;
/**
 * @brief Write a plaintext NSDate default.
 * @param value The date to store.
 * @param key The defaults key.
 */
+ (void)saveDate:(id)value Key:(NSString *)key;
/**
 * @brief Read a plaintext float default.
 * @param key The defaults key.
 * @return The stored value, or 0 when absent.
 */
+ (float)getFloat:(NSString *)key;
/**
 * @brief Write a plaintext float default.
 * @param value The value to store.
 * @param key The defaults key.
 */
+ (void)saveFloat:(float)value Key:(NSString *)key;
/**
 * @brief Read a plaintext string default.
 * @param key The defaults key.
 * @return The stored string, or nil when absent.
 */
+ (NSString *)getString:(NSString *)key;
/**
 * @brief Write a plaintext string default.
 * @param value The string to store.
 * @param key The defaults key.
 */
+ (void)saveString:(NSString *)value Key:(NSString *)key;
/**
 * @brief Read a plaintext boolean default.
 * @param key The defaults key.
 * @return The stored value, or NO when absent.
 */
+ (BOOL)getBOOL:(NSString *)key;
/**
 * @brief Write a plaintext boolean default.
 * @param value The value to store.
 * @param key The defaults key.
 */
+ (void)saveBOOL:(BOOL)value Key:(NSString *)key;
/**
 * @brief Read a plaintext data default.
 * @param key The defaults key.
 * @return The stored data, or nil when absent.
 */
+ (NSData *)getData:(NSString *)key;
/**
 * @brief Write a plaintext data default.
 * @param value The data to store.
 * @param key The defaults key.
 */
+ (void)saveData:(NSData *)value Key:(NSString *)key;

#pragma mark Purchase / age-gate (youth spending limit)

/**
 * @brief The stored birth date used by the youth spending limit.
 * @return The birth date, or nil when unset.
 * @ghidraAddress 0x607fc
 */
+ (NSDate *)birthDay;
/**
 * @brief Store the birth date used by the youth spending limit.
 * @param date The birth date.
 * @ghidraAddress 0x60824
 */
+ (void)saveBirthDay:(NSDate *)date;
/**
 * @brief Whether the player dismissed the birth-date prompt.
 * @return YES when the prompt was cancelled.
 * @ghidraAddress 0x6084c
 */
+ (BOOL)isBirthDayCanceled;
/**
 * @brief Record whether the player dismissed the birth-date prompt.
 * @param canceled YES when the prompt was cancelled.
 * @ghidraAddress 0x60874
 */
+ (void)saveIsBirthDayCanceled:(BOOL)canceled;
/**
 * @brief Whether the friend how-to has been seen.
 * @return YES once the how-to has been shown.
 * @ghidraAddress 0x5ffc8
 */
+ (BOOL)isFriendSelected;
/**
 * @brief Record that the friend how-to has been seen.
 * @param selected YES once the how-to has been shown.
 * @ghidraAddress 0x5fff0
 */
+ (void)saveIsFriendSelected:(BOOL)selected;
/**
 * @brief When the monthly purchase total was last rolled over.
 * @return The rollover date, or nil when unset.
 * @ghidraAddress 0x6089c
 */
+ (NSDate *)lastUpdateSumPurchase;
/**
 * @brief The amount spent this month, in yen.
 * @return The total, clamped to 0 or above.
 * @ghidraAddress 0x608ec
 */
+ (int)sumPurchase;

#pragma mark Lifecycle

/**
 * @brief Load the settings store, migrating a v108 layout to v109 when one is found.
 * @ghidraAddress 0x5efb4
 */
+ (void)loadSettingData;
/**
 * @brief Write the settings store back out.
 * @ghidraAddress 0x5f66c
 */
+ (void)saveSettingData;

#pragma mark Identity (plaintext)

/**
 * @brief The player id (key "PlayerId").
 * @return The player id, or nil when unset.
 * @ghidraAddress 0x60260
 */
+ (NSString *)playerId;
/**
 * @brief The player name (key "PlayerName").
 * @return The player name, or nil when unset.
 * @ghidraAddress 0x60210
 */
+ (NSString *)playerName;
/**
 * @brief The e-AMUSEMENT KONAMI ID (key "KonamiId").
 * @return The KONAMI ID, or nil when unset.
 * @ghidraAddress 0x602b0
 */
+ (NSString *)konamiId;

#pragma mark Friend list (plaintext)

/**
 * @brief Whether the friend list sorts by best score (key "IsBestScoreSort").
 * @return YES to sort by best score.
 * @ghidraAddress 0x607ac
 */
+ (BOOL)isBestScoreSort;
/**
 * @brief Set whether the friend list sorts by best score.
 * @param best YES to sort by best score.
 * @ghidraAddress 0x607d4
 */
+ (void)saveIsBestScoreSort:(BOOL)best;

#pragma mark Effects (plaintext)

/**
 * @brief Whether note effects are enabled (key "IsEffectOn").
 * @return YES when effects are on.
 * @ghidraAddress 0x606bc
 */
+ (BOOL)isEffectOn;
/**
 * @brief Enable or disable note effects.
 * @param on YES to enable effects.
 * @ghidraAddress 0x606e4
 */
+ (void)saveIsEffectOn:(BOOL)on;
/**
 * @brief Whether long-note effects are enabled (key "IsLongNotesEffectOn").
 * @return YES when long-note effects are on.
 * @ghidraAddress 0x6070c
 */
+ (BOOL)isLongNotesEffectOn;
/**
 * @brief Enable or disable long-note effects.
 * @param on YES to enable long-note effects.
 * @ghidraAddress 0x60734
 */
+ (void)saveIsLongNotesEffectOn:(BOOL)on;

// Play-scene settings read by PlayTaskInit (Ghidra: FUN_0002e2d8).

/**
 * @brief The per-tap SE volume, stored at play data +0x9b4.
 * @return The touch-sound volume.
 */
+ (short)touchSoundVolume;
/**
 * @brief Whether the simplified note field is selected, stored at play data +0x9e4.
 * @return YES for simple mode.
 */
+ (BOOL)isSimpleMode;
/**
 * @brief The note ("popkun") size, truncated from float to a plain int at play data +0x9bc.
 * @return The note size.
 */
+ (float)popkunSize;

#pragma mark Treasure (sugoroku pending-goal snapshot)

/**
 * @brief Read back the "pending treasure" record stored under the key "TreasureTmpData": the goal
 * the player just reached on the sugoroku board, carried across the arcade launch.
 *
 * The arcade task polls this to know when to load a map and start play.
 * @return The stored record, or a default whose subMapId is -1 ("nothing pending").
 * @ghidraAddress 0x61448
 */
+ (TreasureTmpData)treasureTmp;

/**
 * @brief Persist the "pending treasure" record back under the key "TreasureTmpData"; the raw
 * memory image is memcpy'd straight into the stored NSData blob.
 *
 * The sugoroku map parser uses this to persist which bonus square it randomly picked as the
 * session's treasure.
 * @param data The record to store.
 * @ghidraAddress 0x614f0
 */
+ (void)saveTreasureTmp:(TreasureTmpData)data;

/**
 * @brief The main-map id whose sugoroku map-select / area screen is currently being shown, backed
 * by the plaintext int key "SelectedMapId". The pad map-select hub reads it to know which map to
 * build.
 * @return The selected map id.
 * @ghidraAddress 0x6209c
 */
+ (short)treasureSelectedMapId;
/**
 * @brief Set the currently-shown sugoroku main-map id.
 * @param mapId The map id.
 * @ghidraAddress 0x620cc
 */
+ (void)saveTreasureSelectedMapId:(short)mapId;

/**
 * @brief Whether the sugoroku "treasure" first-run how-to has been shown, so the two-page how-to
 * only appears once. Backed by a plaintext BOOL key.
 * @return YES once the how-to has been shown.
 * @ghidraAddress 0x60018
 */
+ (BOOL)isTreasureSelected;
/**
 * @brief Record that the sugoroku "treasure" first-run how-to has been shown.
 * @param selected YES once the how-to has been shown.
 * @ghidraAddress 0x60040
 */
+ (void)saveIsTreasureSelected:(BOOL)selected;

/**
 * @brief The persisted "treasure read" progress index for a sugoroku sub-map: how far the player
 * has advanced its board story. The arcade map loader reads it to resume the board.
 *
 * Ghidra: -[UserSettingData treasureReadNo:] (selector PTR_s_treasureReadNo__ @ 0x15b6c8).
 * @param subMapId The sub-map id.
 * @return The read progress index, or a negative sentinel when unread.
 */
+ (int)treasureReadNo:(short)subMapId;

/**
 * @brief The consumed sugoroku treasure-point total, backed by the plaintext int key
 * "ConsumedTreasurePoint".
 * @return The total, clamped to 0 or above.
 * @ghidraAddress 0x61378
 */
+ (short)consumedTreasurePoint;
/**
 * @brief Set the consumed sugoroku treasure-point total.
 * @param value The total; clamped to [0, 9999] on save.
 * @ghidraAddress 0x613b0
 */
+ (void)saveConsumedTreasurePoint:(short)value;

#pragma mark Crypt109 blob (key "c")

/**
 * @brief Read and decrypt the player-progress blob.
 * @param out Receives the decrypted blob.
 * @ghidraAddress 0x615b4
 */
+ (void)crypt109Data:(Crypt109Data *)out;
/**
 * @brief Encrypt and write the player-progress blob.
 * @param data The blob to store.
 * @ghidraAddress 0x61650
 */
+ (void)saveCrypt109Data:(const Crypt109Data *)data;

#pragma mark Crypt109 field accessors

// Getters read the decrypted blob; setters read-modify-write it. Verified: inviteCnt @ 0x60950,
// charaTicket @ 0x61238, and the haveTouchSoundFlg getter and setter. The remaining selector names
// follow the observed convention (getters are the field name, setters are save<Field>:; the
// login-bonus getters keep the "get" prefix).

/**
 * @brief The number of invite codes redeemed.
 * @return The invite count.
 */
+ (int)inviteCnt;
/**
 * @brief Set the number of invite codes redeemed.
 * @param v The invite count.
 */
+ (void)saveInviteCnt:(int)v;
/**
 * @brief The number of invite presents outstanding.
 * @return The invite-present count.
 */
+ (int)invitePresent;
/**
 * @brief Set the number of invite presents outstanding.
 * @param v The invite-present count.
 */
+ (void)saveInvitePresent:(int)v;
/**
 * @brief The number of owned character tickets.
 * @return The ticket count.
 */
+ (short)charaTicket;
/**
 * @brief Set the number of owned character tickets.
 * @param v The ticket count.
 */
+ (void)saveCharaTicket:(short)v;
/**
 * @brief The treasure-point balance.
 * @return The balance.
 */
+ (short)treasurePoint;
/**
 * @brief Set the treasure-point balance.
 * @param v The balance.
 */
+ (void)saveTreasurePoint:(short)v;
/**
 * @brief The login-bonus id most recently opened.
 * @return The login-bonus id.
 */
+ (int)getOpenedLoginBonusId;
/**
 * @brief Set the login-bonus id most recently opened.
 * @param v The login-bonus id.
 */
+ (void)saveOpenedLoginBonusId:(int)v;
/**
 * @brief The login-bonus claim count.
 * @return The claim count.
 */
+ (int)getLoginBonusCnt;
/**
 * @brief Set the login-bonus claim count.
 * @param v The claim count.
 */
+ (void)saveLoginBonusCnt:(int)v;
/**
 * @brief The locally-selected character id.
 * @return The character id.
 */
+ (short)charaId;
/**
 * @brief Set the locally-selected character id.
 * @param v The character id.
 */
+ (void)saveCharaId:(short)v;
/**
 * @brief The character id the server last acknowledged.
 * @return The character id.
 */
+ (short)charaIdServer;
/**
 * @brief Set the character id the server last acknowledged.
 * @param v The character id.
 */
+ (void)saveCharaIdServer:(short)v;
/**
 * @brief The selected touch-sound kind.
 * @return The touch-sound kind index.
 */
+ (int)touchSoundKind;
/**
 * @brief Set the selected touch-sound kind.
 * @param v The touch-sound kind index.
 */
+ (void)saveTouchSoundKind:(int)v;
#ifdef ENABLE_PATCHES
/**
 * @brief The last difficulty the player picked in the song-select overlay, so the overlay re-opens
 * on it instead of always defaulting to Normal.
 *
 * Backed by a plain NSUserDefaults key, which caches in memory and is flushed by the OS at an
 * opportune time.
 * @return The sheet index: 0 Normal, 1 Hyper, 2 Ex.
 * @newCode
 */
+ (int)lastPickedDifficulty;
/**
 * @brief Set the last difficulty the player picked in the song-select overlay.
 * @param v The sheet index: 0 Normal, 1 Hyper, 2 Ex.
 * @newCode
 */
+ (void)saveLastPickedDifficulty:(int)v;
#endif
/**
 * @brief The owned touch-sound bitmask.
 * @return The bitmask; seven bits are used.
 */
+ (int)haveTouchSoundFlg;
/**
 * @brief Set the owned touch-sound bitmask.
 * @param v The bitmask.
 */
+ (void)saveHaveTouchSoundFlg:(int)v;
/**
 * @brief Whether the BEMANI collaboration is unlocked.
 * @return YES when unlocked.
 */
+ (BOOL)isBemaniCollaboOpened;
/**
 * @brief Set whether the BEMANI collaboration is unlocked.
 * @param v YES when unlocked.
 */
+ (void)saveIsBemaniCollaboOpened:(BOOL)v;

#pragma mark Owned characters

/**
 * @brief The owned-character bitmask (the "GotChara" int), with bits 0 and 1 forced on.
 * @return The bitmask.
 * @ghidraAddress 0x60f24
 */
+ (int)gotChara;
/**
 * @brief The owned-character list: an encrypted archived array under key "d".
 * @return The archived array, or nil when none is stored.
 * @ghidraAddress 0x60f54
 */
+ (NSArray *)gotCharaArray;
/**
 * @brief Append a character to the owned-character list.
 * @param charaIndex The character index to add.
 * @ghidraAddress 0x610a0
 */
+ (void)saveGotCharaArray:(short)charaIndex;

#pragma mark Uncomplete score-save queue

// When a finished play cannot be uploaded immediately (the score improved but the HTTP save is
// deferred), the result screen queues the music and sheet here and flushes the pending entry on a
// later result. Referenced by PlayResultTask::resultSetup (Ghidra FUN_0003dfe0 @ 0x3e246, 0x3e482
// and 0x3e49c).

/**
 * @brief Queue a deferred score upload.
 * @param music The music id.
 * @param sheet The sheet index.
 */
+ (void)addUncompleteSaveMusic:(int)music sheet:(short)sheet;
/**
 * @brief The queued music ids awaiting upload.
 * @return An NSArray of NSNumber, parallel to +uncompleteSaveSheet.
 */
+ (NSArray *)uncompleteSaveMusic;
/**
 * @brief The queued sheet indices awaiting upload.
 * @return An NSArray of NSNumber, parallel to +uncompleteSaveMusic.
 */
+ (NSArray *)uncompleteSaveSheet;

#pragma mark Audio volumes (plaintext)

/**
 * @brief The BGM master volume used when a scene (re)loads its BGM.
 *
 * Read by PlayResultTask::resultSetup @ 0x3f0ac before -[AudioManager setBgmVolume:].
 * @return The BGM volume.
 */
+ (float)bgmVolume;
/**
 * @brief Set the BGM master volume; written by -[SoundSettingView dealloc] and
 * -[SoundSettingView bgmSliderValChanged:] on iPad.
 * @param volume The BGM volume.
 */
+ (void)saveBgmVolume:(float)volume;

/**
 * @brief The SE master volume, stored as a plain short. Read by SoundSettingView to seed its SE
 * slider.
 * @return The SE volume, 0..127.
 */
+ (short)seVolume;
/**
 * @brief Set the SE master volume.
 * @param volume The SE volume, 0..127.
 */
+ (void)saveSeVolume:(short)volume;

/**
 * @brief Set the per-tap SE volume; the setter paired with +touchSoundVolume. Written by
 * SoundSettingView.
 * @param volume The touch-sound volume.
 */
+ (void)saveTouchSoundVolume:(short)volume;

#pragma mark Legacy v108 readers (plaintext PascalCase keys; used by migration)

/**
 * @brief The v108 invite count (key "InviteCnt").
 * @return The stored value.
 * @ghidraAddress 0x5fc5c
 */
+ (int)inviteCnt108;
/**
 * @brief The v108 invite-present count (key "InvitePresent").
 * @return The stored value.
 * @ghidraAddress 0x5fc90
 */
+ (int)invitePresent108;
/**
 * @brief The v108 character-ticket count (key "CharaTicket").
 * @return The stored value.
 * @ghidraAddress 0x5fcc4
 */
+ (short)charaTicket108;
/**
 * @brief The v108 treasure-point balance (key "TreasurePoint").
 * @return The stored value.
 * @ghidraAddress 0x5fcfc
 */
+ (short)treasurePoint108;
/**
 * @brief The v108 opened login-bonus id (key "OpenedLoginBonusId").
 * @return The stored value.
 * @ghidraAddress 0x5fd34
 */
+ (int)getOpenedLoginBonusId108;
/**
 * @brief The v108 login-bonus count (key "LoginBonusCnt").
 * @return The stored value.
 * @ghidraAddress 0x5fd64
 */
+ (int)getLoginBonusCnt108;
/**
 * @brief The v108 character id (key "CharaId").
 * @return The stored value.
 * @ghidraAddress 0x5fd8c
 */
+ (short)charaId108;
/**
 * @brief The v108 server character id (key "CharaIdServer").
 * @return The stored value.
 * @ghidraAddress 0x5fdbc
 */
+ (short)charaIdServer108;
/**
 * @brief The v108 touch-sound kind (key "TouchSoundKind").
 * @return The stored value.
 * @ghidraAddress 0x5fdec
 */
+ (int)touchSoundKind108;
/**
 * @brief The v108 owned touch-sound bitmask (key "HaveTouchSoundFlg").
 * @return The stored value.
 * @ghidraAddress 0x5fe2c
 */
+ (int)haveTouchSoundFlg108;
/**
 * @brief The v108 BEMANI-collaboration flag (key "IsBemaniCollaboOpened").
 * @return The stored value.
 * @ghidraAddress 0x5fe60
 */
+ (BOOL)isBemaniCollaboOpened108;

#pragma mark Recovered selectors

// Recovered from call sites; previously declared as local extern or category seams.

/**
 * @brief The arcade-viewer hi-speed option index.
 * @return The stored index.
 */
+ (int)acvHiSpeed;
/**
 * @brief The arcade-viewer pop-kun option index.
 * @return The stored index.
 */
+ (int)acvPopKun;
/**
 * @brief The arcade-viewer hidden/sudden option index.
 * @return The stored index.
 */
+ (int)acvHidSud;
/**
 * @brief The arcade-viewer random/mirror option index.
 * @return The stored index.
 */
+ (int)acvRanMir;

// Paired setters for the arcade-viewer play options, written by the per-option detail screens
// (AcViewerHiSpeed/PopKun/HidSud/RanMirViewController) when a row is selected.

/**
 * @brief Set the arcade-viewer hi-speed option index.
 * @param value The index to store.
 */
+ (void)saveAcvHiSpeed:(int)value;
/**
 * @brief Set the arcade-viewer pop-kun option index.
 * @param value The index to store.
 */
+ (void)saveAcvPopKun:(int)value;
/**
 * @brief Set the arcade-viewer hidden/sudden option index.
 * @param value The index to store.
 */
+ (void)saveAcvHidSud:(int)value;
/**
 * @brief Set the arcade-viewer random/mirror option index.
 * @param value The index to store.
 */
+ (void)saveAcvRanMir:(int)value;
/**
 * @brief Whether the arcade viewer shows the genre name instead of the song name.
 * @return YES to show the genre name.
 */
+ (BOOL)isAcvGenreName;
/**
 * @brief Toggle the arcade-viewer genre versus song-name mode; written by the AC-viewer song
 * list's change button. Key "AcViewerIsGenreName".
 * @param genreName YES to show the genre name.
 * @ghidraAddress 0x61a0c
 */
+ (void)saveIsAcvGenreName:(BOOL)genreName;

/**
 * @brief The music-list sort mode, read and written by the sort-select screen. Key "MusicSort".
 * @return 0 title, 1 artist, 2 level N, 3 level H, 4 level EX, 5 best score; clamped to 0..5.
 * @ghidraAddress 0x60dd0
 */
+ (short)musicSort;
/**
 * @brief Set the music-list sort mode.
 * @param sort The sort mode, clamped to 0..5.
 * @ghidraAddress 0x60e10
 */
+ (void)saveMusicSort:(short)sort;

/**
 * @brief The arcade convert-code linking the app to an arcade e-AMUSEMENT account.
 * @return The convert code, or nil when unset.
 */
+ (NSString *)convertCode;
/**
 * @brief Set the arcade convert-code.
 * @param code The convert code.
 */
+ (void)saveConvertCode:(NSString *)code;
/**
 * @brief Whether the one-shot "follow bonus" (Twitter follow reward) has been claimed.
 * @return YES once claimed.
 */
+ (BOOL)isFollowBonusGet;
/**
 * @brief Record that the one-shot "follow bonus" has been claimed.
 * @param got YES once claimed.
 */
+ (void)saveIsFollowBonusGet:(BOOL)got;
/**
 * @brief Reset the convert-code and follow-bonus state.
 */
+ (void)initForConvert;
/**
 * @brief The client version that last completed the device-change flow.
 * @return The client version.
 */
+ (int)lastCompletedClientVer;
/**
 * @brief Set the client version that last completed the device-change flow.
 * @param ver The client version.
 */
+ (void)saveLastCompletedClientVer:(int)ver;
/**
 * @brief Record whether the privacy policy and terms have been accepted.
 * @param accepted YES once accepted.
 */
+ (void)saveIsPolicyAccepted:(BOOL)accepted;

/**
 * @brief Whether the player has already redeemed an invite code; a code may be entered only once.
 * Backed by the plaintext BOOL key "IsInputInviteCode".
 * @return YES once a code has been redeemed.
 * @ghidraAddress 0x60a40
 */
+ (BOOL)isInputInviteCode;
/**
 * @brief Record that an invite code has been redeemed.
 * @param v YES once a code has been redeemed.
 * @ghidraAddress 0x60a68
 */
+ (void)saveIsInputInviteCode:(BOOL)v;

/**
 * @brief Whether the pop'n-link first-run how-to has already been shown.
 *
 * The pop'n-link top screen sets it the first time the KID-input screen is pushed, so the
 * "firstplay_popnlink" how-to only appears once. Backed by a plaintext BOOL key; read and written
 * by -[PopnLinkTopViewController startOpenAnimation] @ 0xcd5a8.
 * @return YES once the how-to has been shown.
 */
+ (BOOL)isPopnLinkSelected;
/**
 * @brief Record that the pop'n-link first-run how-to has been shown.
 * @param selected YES once the how-to has been shown.
 */
+ (void)saveIsPopnLinkSelected:(BOOL)selected;

/**
 * @brief The last-seen store information banner id.
 * @return The banner id.
 */
+ (int)lastInformationId;
/**
 * @brief The timestamp string of the last store view.
 * @return The timestamp string, or nil when unset.
 */
+ (NSString *)lastStoreViewTimeString;

/**
 * @brief Set the player id; paired with +playerId.
 * @param playerId The player id.
 */
+ (void)savePlayerId:(NSString *)playerId;
/**
 * @brief Set the player name; paired with +playerName.
 * @param name The player name.
 */
+ (void)savePlayerName:(NSString *)name;
/**
 * @brief Store the e-AMUSEMENT KONAMI ID (key "KonamiId"), written when the KID-input screen's
 * decide button starts the pop'n-link.
 * @param konamiId The KONAMI ID.
 * @ghidraAddress 0x602d8
 */
+ (void)saveKonamiId:(NSString *)konamiId;

/**
 * @brief Remove a queued uncomplete score-save entry; paired with
 * +addUncompleteSaveMusic:sheet:.
 * @param music The music id.
 * @param sheet The sheet index.
 */
+ (void)subUncompleteSaveMusic:(int)music sheet:(short)sheet;

/**
 * @brief Clear the pending-treasure snapshot.
 */
+ (void)initTreasureTmp;
/**
 * @brief Set the simple-mode flag; paired with +isSimpleMode.
 * @param on YES for simple mode.
 */
+ (void)saveIsSimpleMode:(BOOL)on;

// Quiz progress counters: plaintext NSUserDefaults ints via +getInt: and +saveInt:Key:, read and
// written by QuizMainViewController.

/**
 * @brief The id of the last quiz answered (key "LastAnswerQuizId").
 * @return The quiz id.
 * @ghidraAddress 0x616c4
 */
+ (int)lastAnswerQuizId;
/**
 * @brief Set the id of the last quiz answered.
 * @param v The quiz id.
 * @ghidraAddress 0x616ec
 */
+ (void)saveLastAnswerQuizId:(int)v;
/**
 * @brief The total number of quizzes answered correctly (key "TotalCorrectQuiz").
 * @return The total.
 * @ghidraAddress 0x61714
 */
+ (int)totalCorrectQuiz;
/**
 * @brief Set the total number of quizzes answered correctly.
 * @param v The total.
 * @ghidraAddress 0x6173c
 */
+ (void)saveTotalCorrectQuiz:(int)v;
/**
 * @brief The total number of quizzes answered incorrectly (key "TotalInCorrectQuiz").
 * @return The total.
 * @ghidraAddress 0x61764
 */
+ (int)totalInCorrectQuiz;
/**
 * @brief Set the total number of quizzes answered incorrectly.
 * @param v The total.
 * @ghidraAddress 0x6178c
 */
+ (void)saveTotalInCorrectQuiz:(int)v;
/**
 * @brief The current run of consecutive correct quiz answers (key "ConsecutiveCorrectQuiz").
 * @return The run length.
 * @ghidraAddress 0x617b4
 */
+ (int)consecutiveCorrectQuiz;
/**
 * @brief Set the current run of consecutive correct quiz answers.
 * @param v The run length.
 * @ghidraAddress 0x617dc
 */
+ (void)saveConsecutiveQuiz:(int)v;

/**
 * @brief Grant character tickets, adding to the Crypt109 charaTicket field.
 * @param count The number of tickets to grant.
 */
+ (void)addCharaTicket:(int)count;
/**
 * @brief Set when the monthly purchase total was last rolled over; paired with
 * +lastUpdateSumPurchase.
 * @param date The rollover date.
 */
+ (void)saveLastUpdateSumPurchase:(NSDate *)date;
/**
 * @brief Set the amount spent this month; paired with +sumPurchase.
 * @param sum The total, in yen.
 */
+ (void)saveSumPurchase:(int)sum;

#pragma mark Store / recommend view timestamps

/**
 * @brief Set the timestamp string of the last store view; paired with +lastStoreViewTimeString.
 * Both back the key "LastUpdateTime".
 * @param time The timestamp string.
 * @ghidraAddress 0x5feb0
 */
+ (void)saveLastStoreViewTimeString:(NSString *)time;
/**
 * @brief The timestamp string of the last store-recommend view (key "LastRecommendViewTime").
 * @return The timestamp string, or nil when unset.
 * @ghidraAddress 0x5fed8
 */
+ (NSString *)lastRecommendViewTimeString;
/**
 * @brief Set the timestamp string of the last store-recommend view.
 * @param time The timestamp string.
 * @ghidraAddress 0x5ff00
 */
+ (void)saveLastRecommendViewTimeString:(NSString *)time;

#pragma mark Tutorial / policy

/**
 * @brief Whether the first-run tutorial has already been played (key "IsTutorialPlayed").
 * @return YES once played.
 * @ghidraAddress 0x5ff28
 */
+ (BOOL)isTutorialPlayed;
/**
 * @brief Record that the first-run tutorial has been played.
 * @param played YES once played.
 * @ghidraAddress 0x5ff50
 */
+ (void)saveIsTutorialPlayed:(BOOL)played;
/**
 * @brief Whether the privacy policy and terms have been accepted; paired with
 * +saveIsPolicyAccepted:.
 * @return YES once accepted.
 * @ghidraAddress 0x60068
 */
+ (BOOL)isPolicyAccepted;

#pragma mark Touch radius / popkun setter

/**
 * @brief The note ("popkun") touch radius.
 *
 * In the binary this getter is a hardcoded constant, 68.0, independent of the stored value.
 * @return The touch radius.
 * @ghidraAddress 0x605a4
 */
+ (float)touchRadius;
/**
 * @brief Set the note touch radius (key "TouchRadius").
 * @param radius The radius; clamped to [40, 148] before persisting.
 * @ghidraAddress 0x605ac
 */
+ (void)saveTouchRadius:(float)radius;
/**
 * @brief Set the note size (key "b"); paired with +popkunSize.
 * @param size The note size; clamped to [50, 100].
 * @ghidraAddress 0x60668
 */
+ (void)savePopkunSize:(float)size;

#pragma mark Store information banner

/**
 * @brief Set the last-seen store information banner id; paired with +lastInformationId. Note the
 * original key's typo, "LastInfomationId".
 * @param informationId The banner id.
 * @ghidraAddress 0x6187c
 */
+ (void)saveLastInformationId:(int)informationId;
/**
 * @brief The day the store information banner was last viewed (key "InfoViewDay").
 * @return The stored day, or nil when unset.
 * @ghidraAddress 0x61b44
 */
+ (NSDate *)getInfoViewDay;
/**
 * @brief Set the day the store information banner was last viewed.
 * @param day The day to store.
 * @ghidraAddress 0x61b6c
 */
+ (void)saveInfoViewDay:(NSDate *)day;
/**
 * @brief Compare @p day against the stored information-view day at yyyy/MM/dd granularity.
 * @param day The day to compare.
 * @return YES when the two fall on the same day.
 * @ghidraAddress 0x61b94
 */
+ (BOOL)isEqualToInfoViewDay:(NSDate *)day;

#pragma mark Treasure (consumed points / read progress)

/**
 * @brief Add to the consumed sugoroku treasure-point total (key "ConsumedTreasurePoint").
 * @param value The amount to add; the total is clamped to [0, 9999].
 * @ghidraAddress 0x613ec
 */
+ (void)addConsumedTreasurePoint:(short)value;
/**
 * @brief Persist the "treasure read" progress index for a sugoroku sub-map into the "e" array of
 * {mapid, readno} dictionaries, updating the matching entry or appending a new one.
 * @param subMapId The sub-map id.
 * @param no The read progress index.
 * @ghidraAddress 0x61dc0
 */
+ (void)saveTreasureReadNo:(short)subMapId no:(int)no;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
