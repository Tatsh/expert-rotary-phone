//
//  TreasureTmpData.h
//  pop'n rhythmin
//
//  The "pending treasure" snapshot: a flat, byte-serialized record persisted
//  under the NSUserDefaults key "TreasureTmpData" and read back by
//  +[UserSettingData treasureTmp]. It carries the goal the player just reached
//  on the sugoroku board across the arcade launch: the arcade task (AcMainTask,
//  case 2) reads it each frame and, when a sub-map id is present (>= 0), loads
//  that map and starts play; a value of -1 means "nothing pending".
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (-[UserSettingData treasureTmp:] @ 0x61448). The record is a raw memory
//  image (memcpy'd straight in/out of the NSData blob), so the layout below is
//  byte-exact and the struct is packed to alignment 1. Field names are recovered
//  from the call sites (DownloadMain visitor JSON, SubMapSelectViewController
//  defaults, AcMainTask goal-apply, TreasureMap bonus pick); the few whose role
//  no call site pins down keep an offset name. Total size: 83 (0x53) bytes.
//

#pragma once

#include <stdint.h>

typedef struct __attribute__((packed)) TreasureTmpData {
    int16_t mainMapId;   // +0x00 main map id (parallels TreasureData.mainMapId)
    int16_t subMapId;    // +0x02 goal sub-map id (main*10+sub); -1 == nothing pending
    int16_t curSubMapId; // +0x04 current board node id; out of range -> reset to the start square
    int16_t
        lastBranchNodeId; // +0x06 last junction (>1 forward link) board node id; -1 in the default record
    int32_t musicPieceMask; // +0x08 music-piece bits earned at this goal (OR'd into the collection)
    int32_t wallPieceMask;  // +0x0c wallpaper-piece bits earned at this goal
    int16_t boardMoveState; // +0x10 board move / warp state (== 2 gate)
    int16_t goalCharaId;    // +0x12 goal character id (loads sugo_chara%03d)
    int32_t musicPiece;     // +0x14 downloaded goal music-piece reward (visitor JSON MusicPiece)
    int32_t wallPaperPiece; // +0x18 downloaded goal wallpaper-piece reward (WallPiece)
    int32_t friendship;     // +0x1c downloaded goal friendship value (Friendship)
    uint8_t friendPlayerId[8];  // +0x20 visiting friend's player id (NUL-terminated; PlayerId)
    uint8_t goalName[13];       // +0x28 goal / friend name (NUL-terminated; Name)
    uint8_t visitedSquares[15]; // +0x35 per-square visited flags (copied to m_boardVisited)
    int16_t
        rouletteMode; // +0x44 roulette mode / result; -1 in the default record (-> m_rouletteMode)
    uint8_t bonusSquareIndex; // +0x46 1-based chosen bonus-treasure square (rand % bonusCount + 1)
    uint8_t field47;          // +0x47 no reconstructed access; kept for the serialized layout
    uint8_t bonusRoll;        // +0x48 random 0..99 roll (getRandRangeInt(100))
    uint8_t field49[3];       // +0x49 no reconstructed access; the 3 bytes ahead of fastRecord
    int32_t
        fastRecord; // +0x4c best (minimum) fast-clear score (misaligned int in the packed record)
    uint8_t
        friendMeetFlag; // +0x50 non-zero -> a friend was met at this goal (bumps TreasureData.friendMeetCnt)
    uint8_t treasureProgress; // +0x51 treasure progress counter (-> m_treasureProgress)
    uint8_t listHalveCount;   // +0x52 list-halve counter (-> m_listHalveCount)
} TreasureTmpData;

static_assert(sizeof(TreasureTmpData) == 0x53,
              "TreasureTmpData must stay 83 bytes: it is a byte-exact serialized save record");

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
