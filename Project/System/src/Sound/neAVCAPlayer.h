//
//  neAVCAPlayer.h
//  pop'n rhythmin
//
//  Low-latency sound-effect backend built on CoreAudio (the caplayer / lib_rsnd
//  layer described in the bundle's readme.txt). It owns a pool of CASound slots;
//  a play handle packs the slot index and a generation counter so a stale handle
//  can't restart a recycled slot. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (Project/System/src/Sound region, FUN_00026xxx).
//

#pragma once

#include <cstdint>

// Handle bit layout (shared with AudioManager): low 28 bits = (slot << 16) |
// generation; 0x20000000 marks a CoreAudio (caplayer) instance.
constexpr uint32_t kCAPlayerHandleFlag = 0x20000000;

class neAVCAPlayer {
public:
    // Load a file into a new CASound slot; returns a source id, or 0xffffffff on
    // failure. Ghidra: FUN_00026320.
    uint32_t load(const char *path, bool loop);

    // As load(), but also register a call-name for later lookup. Ghidra: FUN_0002648c.
    uint32_t loadNamed(const char *path, const char *callName, bool loop);

    // Start the sound referenced by `handle` (slot generation must still match).
    // Ghidra: FUN_00026784.
    bool play(uint32_t handle);

    // AudioSession interruption handling. Ghidra: suspend FUN_000261e0 /
    // resume FUN_000261ec.
    void suspend();
    void resume();
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
