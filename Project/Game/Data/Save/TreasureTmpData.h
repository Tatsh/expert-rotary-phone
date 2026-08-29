/**
 * @file
 * The "pending treasure" snapshot.
 *
 * A flat, byte-serialised record persisted under the
 * NSUserDefaults key "TreasureTmpData" and read back by +[UserSettingData treasureTmp]. It carries
 * the goal the player just reached on the sugoroku board across the arcade launch: the arcade task
 * (AcMainTask, case 2) reads it each frame and, when a sub-map id is present (0 or above), loads
 * that map and starts play; a value of -1 means "nothing pending".
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (-[UserSettingData treasureTmp:] @
 * 0x61448). The record is a raw memory image, memcpy'd straight in and out of the NSData blob, so
 * the layout below is byte-exact and the struct is packed to alignment 1. Field names are recovered
 * from the call sites (DownloadMain visitor JSON, SubMapSelectViewController defaults, AcMainTask
 * goal-apply, TreasureMap bonus pick); the few whose role no call site pins down keep an offset
 * name. The total size is 83 (0x53) bytes.
 */

#pragma once

#include <stdint.h>

#import <Foundation/Foundation.h>

/**
 * The byte-exact "pending treasure" save record carried across an arcade launch.
 */
typedef struct __attribute__((packed)) TreasureTmpData {
    int16_t mainMapId; /**< +0x00 Main map id; parallels TreasureData.mainMapId. */
    int16_t subMapId;  /**< +0x02 Goal sub-map id (main*10+sub); -1 means nothing pending. */
    /** +0x04 Current board node id; out of range resets to the start square. */
    int16_t curSubMapId;
    /** +0x06 Last junction (more than one forward link) board node id; -1 in the default
     * record. */
    int16_t lastBranchNodeId;
    /** +0x08 Music-piece bits earned at this goal, OR'd into the collection. */
    int32_t musicPieceMask;
    int32_t wallPieceMask;  /**< +0x0c Wallpaper-piece bits earned at this goal. */
    int16_t boardMoveState; /**< +0x10 Board move / warp state; 2 is the gate value. */
    int16_t goalCharaId;    /**< +0x12 Goal character id, which loads sugo_chara%03d. */
    /** +0x14 Downloaded goal music-piece reward (visitor JSON MusicPiece). */
    int32_t musicPiece;
    int32_t wallPaperPiece; /**< +0x18 Downloaded goal wallpaper-piece reward (WallPiece). */
    int32_t friendship;     /**< +0x1c Downloaded goal friendship value (Friendship). */
    char friendPlayerId[8]; /**< +0x20 Visiting friend's player id; nul-terminated (PlayerId). */
    char goalName[13];      /**< +0x28 Goal or friend name; nul-terminated (Name). */
    /** +0x35 Per-square animation and event state (see AcMainTask::BoardSquareState); copied to
     * and from m_boardSquareState. */
    int8_t boardSquareState[15];
    /** +0x44 Roulette mode / result; -1 in the default record, feeding m_rouletteMode. */
    int16_t rouletteMode;
    /** +0x46 The 1-based chosen bonus-treasure square, `rand % bonusCount + 1`. */
    uint8_t bonusSquareIndex;
    /** +0x47 Get-visitor request counter, incremented before each startGetVisitorHttp (AcMainTask
     * update state 0x11) and persisted. */
    uint8_t visitorFetchCount;
    uint8_t bonusRoll;   /**< +0x48 A random 0..99 roll, `getRandRangeInt(100)`. */
    uint8_t unused49[3]; /**< +0x49 Alignment padding before fastRecord; no access. */
    /** +0x4c Best (minimum) fast-clear score; a misaligned int in the packed record. */
    int32_t fastRecord;
    /** +0x50 Non-zero when a friend was met at this goal, which bumps
     * TreasureData.friendMeetCnt. */
    uint8_t friendMeetFlag;
    uint8_t treasureProgress; /**< +0x51 Treasure progress counter, feeding m_treasureProgress. */
    uint8_t listHalveCount;   /**< +0x52 List-halve counter, feeding m_listHalveCount. */
} TreasureTmpData;

static_assert(sizeof(TreasureTmpData) == 0x53,
              "TreasureTmpData must stay 83 bytes: it is a byte-exact serialized save record");
