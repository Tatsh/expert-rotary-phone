//
//  AepOrderingTable.h
//  pop'n rhythmin
//
//  The Aep ordering table: a PER-FRAME sprite command buffer. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (AepOrderingTable.mm).
//
//  Each frame the scene fills the buffer with textured-quad draw commands
//  (drawLayer/FUN_000113d0 -> allocEntry/FUN_00010be0), bucketed by priority;
//  the flush then walks the buckets high-priority-first and emits a GL quad per
//  command through neGLES_11. Constants from get_aepOt asserts:
//  OT_REGIST_MAX = 2047 entries, OT_PRI_MAX = 50 priorities.
//

#pragma once

#include <cstdint>

// Fixed capacities (Ghidra: AepOrderingTable.mm:0x3d / 0x3e).
constexpr int kOtRegistMax = 2047;   // OT_REGIST_MAX
constexpr int kOtPriMax = 50;        // OT_PRI_MAX

// One queued sprite draw command (Ghidra: OT entry, 0x134 bytes; the payload the
// fill writes starts at +0x4 after the intrusive bucket link at +0x0). Only the
// fields recovered from FUN_000113d0 are named; the tail is opaque per-command
// state carried to the flush.
struct AepSpriteCommand {
    AepSpriteCommand *next;   // +0x00  priority-bucket link
    int16_t priority;         // (stored at entry+0x12 by allocEntry)
    int16_t reserved4;        // +0x04
    int32_t textureId;        // +0x08  layer/texture id (param17)
    int32_t u, v;             // +0x0c/+0x10  source origin
    int32_t x, y;             // +0x14/+0x18  screen position
    int32_t sx, sy;           // +0x1c/+0x20  scale
    int32_t w, h;             // +0x24/+0x28  size
    int32_t ex, ey;           // +0x2c/+0x30  extra (end pos for stretched sprites)
    int16_t color0, color1;   // +0x34/+0x36
    int32_t rotation;         // +0x38
    int32_t blend;            // +0x3c
    int16_t clip[4];          // +0x40..0x46  clip rect (defaults to screen bounds)
    uint8_t opaque[0x134 - 0x48];  // remaining per-command state
};

class AepOrderingTable {
public:
    AepOrderingTable();

    // Reset the buffer for a new frame (Ghidra: m_OtCount -> 0, buckets cleared).
    void reset();

    // Reserve a command entry at `priority` and link it into that bucket; returns
    // the command to fill. Ghidra: get_aepOt/allocEntry FUN_00010be0.
    AepSpriteCommand *allocEntry(int priority);

    // Flush: walk the buckets from the highest used priority down, emitting a GL
    // quad per command via neGLES_11. Ghidra: FUN_000115d0.
    void flush();

    int drawnCount() const { return m_drawnCount; }   // Ghidra: FUN_000117dc

private:
    AepSpriteCommand m_entries[kOtRegistMax];   // the frame's command pool
    AepSpriteCommand *m_buckets[kOtPriMax];     // per-priority list heads (+0x9a0dc)
    int m_count = 0;                            // m_OtCount (+0x9a00c)
    int m_maxPriority = 0;                      // highest used priority (+0x9a010)
    int m_drawnCount = 0;
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
