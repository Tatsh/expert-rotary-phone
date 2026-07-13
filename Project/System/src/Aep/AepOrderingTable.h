//
//  AepOrderingTable.h
//  pop'n rhythmin
//
//  The Aep ordering table: a PER-FRAME sprite command buffer. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (AepOrderingTable.mm).
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
constexpr int kOtRegistMax = 2047; // OT_REGIST_MAX
constexpr int kOtPriMax = 50;      // OT_PRI_MAX

// One queued sprite draw command (Ghidra: OT entry, 0x134 bytes; the payload
// the fill writes starts at +0x4 after the intrusive bucket link at +0x0). Only
// the fields recovered from FUN_000113d0 are named; the tail is opaque
// per-command state carried to the flush.
struct AepSpriteCommand {
    AepSpriteCommand *next;       // +0x00  priority-bucket link
    int16_t type;                 // +0x04  command type discriminator. renderAepOrderingTable
                                  //        (FUN_000115d0) switches on the short @+0x04:
                                  //        0 sprite, 1 stretch, 2 line, 3 tri, 4 rect, 5 quad, 6
                                  //        text.
    int16_t priority;             // +0x06  bucket priority (allocAepOtEntry writes short
                                  // @entry+0x12,
                                  //        i.e. cmd+0x06; used only as bookkeeping, not for
                                  //        traversal)
    int32_t textureId;            // +0x08  layer/texture id (param17)
    int32_t u, v;                 // +0x0c/+0x10  source origin
    int32_t x, y;                 // +0x14/+0x18  screen position
    int32_t sx, sy;               // +0x1c/+0x20  scale
    int32_t w, h;                 // +0x24/+0x28  size
    int32_t ex, ey;               // +0x2c/+0x30  extra (end pos for stretched sprites)
    int16_t color0, color1;       // +0x34/+0x36
    int32_t rotation;             // +0x38
    int32_t blend;                // +0x3c
    int16_t clip[4];              // +0x40..0x46  clip rect (defaults to screen bounds)
    uint8_t opaque[0x134 - 0x48]; // remaining per-command state
};

// A queued text draw command (Ghidra: the type-6 entry pushAepOtTextCmd fills,
// same 0x134-byte pool slot as AepSpriteCommand, reinterpreted by type). The
// string sits in the slot that the sprite view uses for its
// source-rect/geometry words.
struct AepTextCommand {
    AepSpriteCommand *next; // +0x00
    int16_t type;           // +0x04  == 6 (discriminator short @+0x04, same slot as
                            //        AepSpriteCommand::type)
    int16_t priority;       // +0x06  bucket priority
    int32_t reserved8;      // +0x08
    char text[0x100];       // +0x0c..+0x10b  (force-terminated at text[0xff])
    // Six positional draw words (+0x10c..+0x123). The flush handler drawAepOtText
    // assigns their meaning (position / size / colour); they are copied through
    // verbatim by the push, so they are named positionally here to avoid
    // asserting the wrong roles.
    int32_t arg0;   // +0x10c
    int32_t arg1;   // +0x110
    int32_t arg2;   // +0x114
    int32_t arg3;   // +0x118
    int32_t arg4;   // +0x11c
    int32_t arg5;   // +0x120
    int32_t vec[4]; // +0x124..+0x133  colour vector, or {0,0,screenW,screenH}
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

    int drawnCount() const {
        return m_drawnCount;
    } // Ghidra: FUN_000117dc

    // Screen extents and the device-pixel render scale the immediate-mode
    // primitive helpers (the drawAepOt* set) transform their coordinates by, plus
    // the per-slot GL texture-handle table sprites resolve their texture from.
    // Ghidra: aepOtSetScreenParams FUN_00010bbc (writes +0x04 / +0x08 / +0x9a1a4
    // / +0x9a1a8).
    void setScreenParams(void **textureTable, int screenW, int screenH, float scale);
    int screenW() const {
        return m_screenW;
    } // +0x04
    int screenH() const {
        return m_screenH;
    } // +0x08
    void **textureTable() const {
        return m_textureTable;
    } // +0x9a1a4
    float renderScale() const {
        return m_renderScale;
    } // +0x9a1a8

private:
    int m_screenW = 0;                        // +0x04
    int m_screenH = 0;                        // +0x08
    AepSpriteCommand m_entries[kOtRegistMax]; // the frame's command pool
    AepSpriteCommand *m_buckets[kOtPriMax];   // per-priority list heads (+0x9a0dc)
    int m_count = 0;                          // m_OtCount (+0x9a00c)
    int m_maxPriority = 0;                    // highest used priority (+0x9a010)
    int m_drawnCount = 0;
    void **m_textureTable = nullptr; // +0x9a1a4  per-slot GL texture handles
    float m_renderScale = 1.0f;      // +0x9a1a8  device-pixel scale
};

// ---------------------------------------------------------------------------
// The ordering table's immediate-mode primitive draw helpers. Each takes the OT
// (for the render scale + texture table), transforms its coordinates by
// OT::renderScale(), unpacks the packed colour (0xRRGGBB) and 0..100 alpha, and
// issues the corresponding neGraphics primitive. These are the type-dispatch
// handlers the flush runs per queued command; they are also called directly by
// the UI draws. The neDraw* renderer entries are reconstructed in parallel in
// the neGraphics unit (forward-declared in the .mm).
// ---------------------------------------------------------------------------

// Set the OT's screen extents, per-slot texture table and render scale.
// Ghidra: aepOtSetScreenParams (FUN_00010bbc).
void aepOtSetScreenParams(
    AepOrderingTable *ot, void **textureTable, int screenW, int screenH, float scale);

// Queue a text draw command (type 6) at `priority`. `colorVec` (16 bytes)
// overrides the per-glyph colour vector; when null it defaults to
// {0,0,screenW,screenH}. Ghidra: pushAepOtTextCmd (FUN_0001154c).
void pushAepOtTextCmd(AepOrderingTable *ot,
                      const char *text,
                      int a0,
                      int a1,
                      int a2,
                      int a3,
                      int a4,
                      int a5,
                      const void *colorVec,
                      int priority);

// Immediate-mode primitive draws (Ghidra: FUN_00010f98 / _11054 / _1113c /
// _111f8 / _11310).
void drawAepOtLine(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int alpha, uint32_t color);
void drawAepOtTriangle(AepOrderingTable *ot,
                       int x0,
                       int y0,
                       int x1,
                       int y1,
                       int x2,
                       int y2,
                       int alpha,
                       uint32_t color);
void drawAepOtRect(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int alpha, uint32_t color);
void drawAepOtQuad(AepOrderingTable *ot,
                   int x0,
                   int y0,
                   int x1,
                   int y1,
                   int x2,
                   int y2,
                   int x3,
                   int y3,
                   int alpha,
                   uint32_t color);
void drawAepOtText(AepOrderingTable *ot,
                   const char *text,
                   int p3,
                   int x,
                   int y,
                   int size,
                   int p7,
                   int alpha,
                   const void *colorVec,
                   uint32_t color);

// Textured sprite draws (Ghidra: FUN_00010c90 / FUN_00010e18 ->
// drawAepSpriteClipped FUN_00012020). `spriteRec` points at the sprite's 8-byte
// source-rect record.
void drawAepOtSprite(AepOrderingTable *ot,
                     const int16_t *spriteRec,
                     int x,
                     int y,
                     int sx,
                     int sy,
                     int p7,
                     int p8,
                     int p9,
                     uint32_t alpha,
                     uint32_t blend,
                     int p12,
                     const void *clip,
                     int p14,
                     int p15,
                     int slot);
void drawAepOtSpriteStretch(AepOrderingTable *ot,
                            void *frameObj,
                            int frameCol,
                            int frameTime,
                            int x,
                            int y,
                            int sx,
                            int sy,
                            int ex,
                            int ey,
                            int p11,
                            int p12,
                            int p13,
                            uint32_t alpha,
                            uint32_t blend,
                            int p16,
                            const void *clip,
                            int p18,
                            int p19);

// The clipped textured-quad immediate draw (Ghidra: FUN_00012020). `frameObj`
// is the animated texture object: it holds the sub-frame count (+0x04), the
// per-frame width and duration tables (+0x08 / +0x0c) and the render-state
// slots (+0x14). It picks the active sub-frame from `frameTime`, composes the
// source rect, sets the render state and issues neDrawTexturedQuad, optionally
// through a scaled clip rect.
void drawAepSpriteClipped(float renderScale,
                          void *frameObj,
                          int frameCol,
                          int frameTime,
                          int x,
                          int y,
                          int u0,
                          int v0,
                          float sx,
                          float sy,
                          uint32_t blend,
                          float w,
                          float h,
                          int p13,
                          uint32_t alpha,
                          int p16,
                          const void *clip,
                          int useClip,
                          int p19);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
