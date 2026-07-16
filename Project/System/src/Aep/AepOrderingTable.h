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

class neTextureForiOS; // the sprite/frame-atlas object a sprite command references

// Fixed capacities (Ghidra: AepOrderingTable.mm:0x3d / 0x3e).
constexpr int kOtRegistMax = 2047; // OT_REGIST_MAX
constexpr int kOtPriMax = 50;      // OT_PRI_MAX

// The clip rectangle carried by a sprite command (Ghidra: AepClipRect, 16 bytes,
// four ints). Defaults to the screen bounds when the fill supplies no explicit
// rect.
struct AepClipRect {
    int32_t nLeft;   // +0x00
    int32_t nTop;    // +0x04
    int32_t nRight;  // +0x08
    int32_t nBottom; // +0x0c
};

// One queued ordering-table draw command (Ghidra: AepOtSpriteCmd — the command
// block of a 0x134-byte pool entry). The first 0x50 bytes are the named payload
// the fills (drawSprite FUN_00011468, drawTransitionOverlay FUN_0001151c,
// aepEmitSprite FUN_000113d0) write; the tail is per-command scratch, and the
// fills spill an 8-byte source-rect word into the *next* entry, so the whole
// entry stride (0x134) is reserved here. wFlags @+0x04 is the type discriminator
// renderAepOrderingTable (FUN_000115d0) switches on: 0 sprite, 1 stretched
// sprite, 2 line, 3 triangle, 4 rect (the transition-fade overlay), 5 quad, 6
// text. Field names are Ghidra's; where a slot's role varies by command type the
// per-fill comment gives the concrete meaning.
struct AepOtSpriteCmd {
    AepOtSpriteCmd *pListNext; // +0x00  priority-bucket link
    uint16_t wFlags;           // +0x04  command type discriminator
    int16_t nPriority;         // +0x06  bucket priority (bookkeeping, not traversal)
    int32_t nBank;             // +0x08  texture bank / layer slot
    // +0x0c/+0x10  Source origin. Line/rect/quad/text commands use nTexU/nTexV as
    // plain ints; a type-0 sprite instead packs its u/v/w/h source rect into the
    // same 8 bytes as four shorts (srcRect), and a type-1 sprite uses nTexV as the
    // frame column (its texture lives in pTexObj). srcRect is exactly the two int
    // slots, so the union adds no size and shifts no offset.
    union {
        struct {
            int32_t nTexU;
            int32_t nTexV;
        };
        int16_t srcRect[4]; // type-0 sprite: packed {u, v, w, h}
    };
    int32_t nPosX, nPosY;       // +0x14/+0x18  screen position
    float flPosXf, flPosYf;     // +0x1c/+0x20  sub-pixel float position / scale
    int32_t nOfsX, nOfsY;       // +0x24/+0x28  offset (end pos for stretched sprites)
    int32_t nColorA, nColorMul; // +0x2c/+0x30  colour + colour-multiply
    int16_t nUKey, nVKey;       // +0x34/+0x36  UV keys
    int32_t nBlendFlags;        // +0x38
    int32_t nColorRGB;          // +0x3c
    AepClipRect clipRect;       // +0x40..0x4f  clip rect (defaults to screen bounds)
    // The clip-spill (drawSprite) writes clipRect.nBottom plus the following 12
    // bytes into +0x4c..+0x5b of this tail.
    uint8_t scratch0[0x60 - 0x50]; // +0x50..+0x5f  per-command / clip-spill tail
    // Rebuild-only field (NOT present in the 32-bit binary's layout): the sprite's
    // source texture object. The binary packs this pointer into the 32-bit nTexU
    // slot; storing it as a real typed pointer here avoids truncating a 64-bit
    // pointer into an int. Only sprite commands (wFlags 0/1) use it — it is the
    // neTextureFrames* the flush walks (drawAepOtSpriteStretch ->
    // drawAepSpriteClipped). The concrete stored type is neTextureForiOS.
    neTextureForiOS *pTexObj;                        // +0x60 (rebuild-only)
    uint8_t scratch1[0x134 - 0x60 - sizeof(void *)]; // remaining per-command state
};

// A queued text draw command (Ghidra: AepTextCmd — the type-6 entry
// PushAepOtTextCmd fills, the same 0x134-byte pool slot as AepOtSpriteCmd
// reinterpreted by nType). The string occupies the slot the sprite view uses for
// its texture/source-rect words (+0x0c), and the glyph parameters follow it at
// +0x10c — which the flush reaches as the 4th 80-byte AepOtSpriteCmd-sized block
// (pCmd[3]) of the entry.
struct AepTextCmd {
    AepOtSpriteCmd *pNext; // +0x00
    int16_t nType;         // +0x04  == 6 (same discriminator slot as AepOtSpriteCmd::wFlags)
    int16_t nPriority;     // +0x06  bucket priority
    int32_t nReserved8;    // +0x08
    char pText[256];       // +0x0c..+0x10b  (force-terminated at pText[255])
    float flPosXf;         // +0x10c  pen position x
    float flPosYf;         // +0x110  pen position y
    int32_t nColorTL;      // +0x114  per-corner colours (top-left / top-right /
    int32_t nColorTR;      // +0x118  bottom-left / bottom-right)
    int32_t nColorBL;      // +0x11c
    int32_t nColorBR;      // +0x120
    int32_t pAClipVec[4];  // +0x124..+0x133  clip vector, or {0,0,screenW,screenH}
};

class AepOrderingTable {
public:
    AepOrderingTable();

    // Reset the buffer for a new frame (Ghidra: m_OtCount -> 0, buckets cleared).
    void reset();

    // Reserve a command entry at `priority` and link it into that bucket; returns
    // the command to fill. Ghidra: get_aepOt/allocEntry FUN_00010be0.
    AepOtSpriteCmd *allocEntry(int priority);

    // Fill a stretched-sprite command (wFlags=1) for the sprite `pTexture` at
    // priority `nPriority`, forwarding position, scale, colour, blend and clip.
    // This is the fill neTextureForiOS::draw drives; the flush later dispatches the
    // command through drawAepOtSpriteStretch. Ghidra: AepOrderingTable::drawSprite
    // (FUN_00011468).
    AepOtSpriteCmd *drawSprite(neTextureForiOS *pTexture,
                               int nTexV,
                               int nPosX,
                               int nPosY,
                               float flPosXf,
                               float flPosYf,
                               int nOfsX,
                               int nOfsY,
                               int nColorA,
                               int nColorMul,
                               int nKeys,
                               int nBlendFlags,
                               int nColorRGB,
                               int16_t clipLeftLo,
                               int16_t clipLeftHi,
                               int clipTop,
                               int clipRight,
                               const void *clipSpill,
                               int nPriority);

    // Flush: walk the priority buckets high-to-low and dispatch each command by
    // wFlags to its per-type draw handler. Ghidra: renderAepOrderingTable
    // (FUN_000115d0).
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
    // Ghidra: orderingTable.flScreenHalfScale (+0x9a1a8, i.e. AepManager + 0x7c16e0).
    // BootLogoTask setup/finish write it directly to switch to native scale (1.0) for
    // the branding logos and restore the saved UI half-scale on exit.
    void setRenderScale(float scale) {
        m_renderScale = scale;
    }

private:
    // Per-type draw handlers the flush dispatches each command to. In Ghidra these
    // are AepOrderingTable methods (AepOrderingTable::drawAepOt*(AepOrderingTable
    // *this, ...)); only renderAepOrderingTable (flush) calls them in this title,
    // so they are private. Ghidra: FUN_00010c90 / _10e18 / _10f98 / _11054 /
    // _1113c / _111f8 / _11310. Each transforms its coordinates by renderScale()
    // and issues the matching neGraphics primitive.
    void drawAepOtSprite(const int16_t *spriteRec,
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
    void drawAepOtSpriteStretch(neTextureForiOS *pFrames,
                                int nU,
                                int nV,
                                int nPosX,
                                int nPosY,
                                int nScaleX,
                                int nScaleY,
                                float nOfsX,
                                float nOfsY,
                                int nColorMul,
                                int nColorA,
                                int nAlpha,
                                int nColorFlags,
                                uint32_t nColorA2,
                                uint32_t nBlendMask,
                                const int *pClipRect,
                                int nBlendFlag,
                                uint32_t nColorRGB);
    void drawAepOtLine(int x0, int y0, int x1, int y1, int alpha, uint32_t color);
    void
    drawAepOtTriangle(int x0, int y0, int x1, int y1, int x2, int y2, int alpha, uint32_t color);
    void drawAepOtRect(int x0, int y0, int x1, int y1, int alpha, uint32_t color);
    void drawAepOtQuad(
        int x0, int y0, int x1, int y1, int x2, int y2, int x3, int y3, int alpha, uint32_t color);
    void drawAepOtText(const char *text,
                       const char *font,
                       int x,
                       int y,
                       int size,
                       int p7,
                       int alpha,
                       const void *colorVec,
                       uint32_t color);

    int m_screenW = 0;                      // +0x04
    int m_screenH = 0;                      // +0x08
    AepOtSpriteCmd m_entries[kOtRegistMax]; // the frame's command pool
    AepOtSpriteCmd *m_buckets[kOtPriMax];   // per-priority list heads (pCurrentByPri /
                                            // pHeadByPri, +0x9a014 / +0x9a0dc — both track the
                                            // newest entry per bucket)
    int m_count = 0;                        // m_OtCount (+0x9a00c)
    int m_maxPriority = 0;                  // highest used priority (+0x9a010)
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

// The seven per-type draw handlers (drawAepOtSprite / …Stretch / …Line /
// …Triangle / …Rect / …Quad / …Text) are AepOrderingTable member functions
// declared in the class above — in Ghidra they take the OT as `this`, and only
// the flush dispatches to them.

// The clipped textured-quad immediate draw (Ghidra: FUN_00012020). `frameObj`
// is the animated texture object: it holds the sub-frame count (+0x04), the
// per-frame width and duration tables (+0x08 / +0x0c) and the render-state
// slots (+0x14). It picks the active sub-frame from `frameTime`, composes the
// source rect, sets the render state and issues neDrawTexturedQuad, optionally
// through a scaled clip rect.
void drawAepSpriteClipped(neTextureForiOS *pFrames,
                          int nWidth,
                          int nFrameIn,
                          int nSrcV,
                          int nSrcU,
                          float flDstX,
                          float flDstY,
                          float flDstW,
                          float flDstH,
                          int nRawAngle,
                          float flScaleX,
                          float flScaleY,
                          int nAlpha,
                          float flParam14,
                          uint32_t nFlags,
                          const int *pClipRect,
                          int nUseClip,
                          uint32_t nColor);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
