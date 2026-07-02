//
//  TreasureTmpData.h
//  pop'n rhythmin
//
//  The "pending treasure" snapshot: a flat, byte-serialized record persisted
//  under the NSUserDefaults key "TreasureTmpData" and read back by
//  +[UserSettingData treasureTmp]. It carries the goal the player just reached on
//  the sugoroku board across the arcade launch: the arcade task (AcMainTask, case
//  2) reads it each frame and, when a sub-map id is present (>= 0), loads that map
//  and starts play; a value of -1 means "nothing pending".
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (-[UserSettingData treasureTmp:] @ 0x61448). The record is a raw memory image
//  (memcpy'd straight in/out of the NSData blob), so the field layout below is
//  byte-exact and the struct is packed to alignment 1 to match. Only subMapId is
//  semantically recovered from a verified call site; the remaining fields keep
//  their Ghidra byte offsets and are named by offset until a call site pins their
//  meaning. Total size: 83 (0x53) bytes.
//

#pragma once

#include <stdint.h>

#pragma pack(push, 1)
typedef struct TreasureTmpData {
    int16_t mainMapId;    // +0x00  main map (inferred; parallels TreasureData.mainMapId)
    int16_t subMapId;     // +0x02  goal sub-map id; -1 == nothing pending
                          //        (verified: AcMainTask case 2 gates play on this)
    int16_t raw0x04;      // +0x04  set to -1 in the default (empty) record with subMapId
    int16_t raw0x06;      // +0x06
    int32_t raw0x08;      // +0x08
    int32_t raw0x0c;      // +0x0c
    int16_t raw0x10;      // +0x10
    int16_t raw0x12;      // +0x12
    int32_t raw0x14;      // +0x14
    int32_t raw0x18;      // +0x18
    int32_t raw0x1c;      // +0x1c
    uint8_t raw0x20[8];   // +0x20
    uint8_t raw0x28[13];  // +0x28
    uint8_t raw0x35[15];  // +0x35
    int16_t raw0x44;      // +0x44  third -1 sentinel in the default record
    uint8_t raw0x46;      // +0x46
    uint8_t raw0x47;      // +0x47
    uint8_t raw0x48;      // +0x48
    int32_t raw0x49;      // +0x49
    int32_t raw0x4d;      // +0x4d
    uint8_t raw0x51;      // +0x51
    uint8_t raw0x52;      // +0x52
} TreasureTmpData;        // sizeof == 0x53 (83)
#pragma pack(pop)

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
