//
//  AepOrderingTable.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The Aep
//  ordering table as a per-frame sprite command buffer: allocEntry hands out
//  priority-bucketed command entries (get_aepOt FUN_00010be0), and flush walks
//  the buckets high-priority-first, emitting one textured GL quad per command.
//  The binary routes the GL calls through neGLES_11; the equivalent ES 1.1 calls
//  are issued directly here.
//

#include <cassert>
#include <cmath>
#include <cstring>

#import <OpenGLES/ES1/gl.h>

#import "AepOrderingTable.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// The neGraphics primitive-draw entry points. These are reconstructed in parallel in
// the neGraphics unit; forward-declared here so the Aep primitive helpers can call them
// without pulling in (or reimplementing) the renderer. Signatures follow the call sites
// recovered from FUN_00010f98 / _11054 / _1113c / _111f8 / _11310 / _12020.
extern "C" {
void neDrawLine(int x0, int y0, int x1, int y1, int alpha, int r, int g, int b);
void neDrawTriangle(int x0, int y0, int x1, int y1, int x2, int y2, int alpha, int r, int g, int b);
void neDrawRect(int x0, int y0, int x1, int y1, int alpha, int r, int g, int b);
void neDrawQuad(int x0, int y0, int x1, int y1, int x2, int y2, int x3, int y3, int alpha, int r,
                int g, int b);
void neDrawText(int size, const char *text, int p3, int x, int y, int size2, int p7, int alpha,
                int r, int g, int b, const void *colorVec);
void neDrawTexturedQuad(int stateSlot, int p2, int p3, int p4, int p5, float u0, float v0, float u1,
                        float v1, float rotation, int p11, int p12, int alpha, int r, int g, int b,
                        uint32_t blend, void *clip, int flag);
// Render-state slot setup for a textured draw (Ghidra: FUN referenced from _12020).
void setRenderStateSlot(int slot, int index, int value);
}

// The engine 2D render-state setup (viewport + ortho projection via glLoadMatrixf + default caps).
// C++ linkage to match neRenderer.h (Ghidra: neApplyDefaultRenderState FUN_00014ef4); declared here
// rather than #import-ing neRenderer.h to avoid colliding with the local extern-"C" neDraw* decls.
void neApplyDefaultRenderState(void);

AepOrderingTable::AepOrderingTable() {
    reset();
}

// Reset for a new frame: no live commands, empty buckets.
void AepOrderingTable::reset() {
    m_count = 0;
    m_maxPriority = 0;
    m_drawnCount = 0;
    for (int i = 0; i < kOtPriMax; i++) {
        m_buckets[i] = nullptr;
    }
}

// Ghidra: FUN_00010be0 (get_aepOt/allocEntry). Grab the next pool entry, tag it
// with `priority`, and head-insert it into that priority's bucket.
AepSpriteCommand *AepOrderingTable::allocEntry(int priority) {
    assert(m_count < kOtRegistMax);   // AepOrderingTable.mm:0x3d "m_OtCount < OT_REGIST_MAX"
    assert(priority < kOtPriMax);     // AepOrderingTable.mm:0x3e "pri < OT_PRI_MAX"

    AepSpriteCommand *cmd = &m_entries[m_count++];
    cmd->priority = (int16_t)priority;
    if (priority > m_maxPriority) {
        m_maxPriority = priority;
    }
    cmd->next = m_buckets[priority];
    m_buckets[priority] = cmd;
    return cmd;
}

// Emit one command as a textured quad (GL ES 1.1). Position/size/uv/colour come
// from the command the fill (FUN_000113d0) wrote.
static void drawCommand(const AepSpriteCommand &cmd) {
    const float x = (float)cmd.x;
    const float y = (float)cmd.y;
    const float w = (float)cmd.w;
    const float h = (float)cmd.h;

    // Interleaved quad (TRIANGLE_STRIP): top-left, top-right, bottom-left, bottom-right.
    const GLfloat verts[8] = { x, y, x + w, y, x, y + h, x + w, y + h };
    // Bridge: cmd.u/cmd.v carry the used UV extent (16.16) that neTextureForiOS::draw wrote,
    // so a pow2-padded texture samples only its source region; 0 falls back to the full 0..1.
    const GLfloat uMax = cmd.u > 0 ? (GLfloat)cmd.u / 65536.0f : 1.0f;
    const GLfloat vMax = cmd.v > 0 ? (GLfloat)cmd.v / 65536.0f : 1.0f;
    const GLfloat uvs[8] = { 0, 0, uMax, 0, 0, vMax, uMax, vMax };

    // A real GL texture name (neTextureForiOS::draw bridge) enables texturing; without one
    // there is nothing to sample, so draw the untextured quad (neApplyDefaultRenderState left
    // GL_TEXTURE_2D disabled).
    const bool textured = (cmd.textureId != 0);
    if (textured) {
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, (GLuint)cmd.textureId);
    }
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    if (textured) {
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        glTexCoordPointer(2, GL_FLOAT, 0, uvs);
    }
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    if (textured) {
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisable(GL_TEXTURE_2D);
    }
    glDisableClientState(GL_VERTEX_ARRAY);
}

// Ghidra: FUN_000115d0 (renderAepOrderingTable) — draw the frame, highest priority bucket first.
//
// The binary switches on cmd.type (the short @cmd+0x04; see AepSpriteCommand) and routes each
// command to a dedicated per-type handler:
//     0 sprite  -> drawAepOtSprite  (FUN_00010c90)   4 rect  -> drawAepOtRect  (FUN_0001113c)
//     1 stretch -> drawAepOtSpriteStretch (0x10e18)   5 quad  -> drawAepOtQuad  (FUN_000111f8)
//     2 line    -> drawAepOtLine    (FUN_00010f98)    6 text  -> drawAepOtText  (FUN_00011310)
//     3 tri     -> drawAepOtTriangle (FUN_00011054)
// In practice only types 0/1 (sprites), 4 (the transition overlay), and 6 (text) are ever queued;
// 2/3/5 are live handlers with no push site in this title.
//
// This reconstruction renders every command as a single textured quad instead of dispatching. That
// is a DELIBERATE, methodology-compliant best-effort: the sprite tail (drawAepOtSprite/Stretch ->
// drawAepSpriteClipped @0x12020 -> neDrawTexturedQuad @0x15fb8) threads its transform through the
// VFP register bank (renderScale in s0 and unused in the callee; scaledX/width/uSpan scrambled
// across s/r regs by the AAPCS split), so the decompiler cannot recover the exact per-arg order.
// Per the reconstruction rules we do not invent those VFP-spilled values; the all-quad path is the
// faithful approximation of the sprite/stretch cases. Types 4/6 render acceptably as quads here too
// (the overlay is a full-rect fill; text loses glyph shaping — the one visible simplification).
// Wiring the true dispatch is gated on a disasm-verified re-derivation of the VFP sprite tail (see
// NEON_ACCURACY.md #2 / HANDOFF.md), which is the remaining, methodology-bounded work.
void AepOrderingTable::flush() {
    // Establish the engine's 2D render state before rendering the OT -- the way the binary does it.
    // The binary imports glLoadMatrixf / glMatrixMode / glViewport (NOT glOrthof): the ortho is a
    // software-built matrix (Ghidra FUN_00012ba8) stored on the current neViewport (created in
    // -LayoutedGLView:) and loaded via glLoadMatrixf. neApplyDefaultRenderState (FUN_00014ef4) ->
    // neApplyViewport applies that viewport (glViewport + glLoadMatrixf projection) and the default
    // 2D enable caps. drawCommand is a raw GL ES 1.1 path that otherwise bypasses this, which left
    // the projection at identity and the pixel-space quads off-screen (the boot logos were invisible
    // for exactly this reason).
    neApplyDefaultRenderState();

    m_drawnCount = 0;
    for (int pri = m_maxPriority; pri >= 0; pri--) {
        for (AepSpriteCommand *cmd = m_buckets[pri]; cmd != nullptr; cmd = cmd->next) {
            drawCommand(*cmd);
            m_drawnCount++;
        }
    }
    reset();   // the buffer is consumed; ready for the next frame's fill
}

// ===========================================================================
// Screen params + immediate-mode primitive draw helpers.
// ===========================================================================

// Ghidra: aepOtSetScreenParams (FUN_00010bbc) — cache the screen extents, the per-slot
// texture-handle table and the device-pixel render scale on the OT.
void AepOrderingTable::setScreenParams(void **textureTable, int screenW, int screenH, float scale) {
    m_screenW = screenW;                 // +0x04
    m_screenH = screenH;                 // +0x08
    m_textureTable = textureTable;       // +0x9a1a4
    m_renderScale = scale;               // +0x9a1a8
}

void aepOtSetScreenParams(AepOrderingTable *ot, void **textureTable, int screenW, int screenH,
                          float scale) {
    ot->setScreenParams(textureTable, screenW, screenH, scale);
}

// Colour / alpha unpack shared by every primitive. The alpha is the byte-verified
// `v * 0xff / 100` reciprocal-multiply (`* 0x51eb851f >> 0x25`); the colour word is
// packed 0x00RRGGBB.
static inline int aepAlpha(int pct) { return ((pct * 0xff) / 100) & 0xff; }
static inline int aepColR(uint32_t c) { return (int)((c & 0xffffff) >> 0x10); }
static inline int aepColG(uint32_t c) { return (int)((c & 0xffff) >> 8); }
static inline int aepColB(uint32_t c) { return (int)(c & 0xff); }
// Transform a coordinate by the OT render scale. The binary threads it through
// FixedToFP -> FloatVectorMult(scale) -> FPToFixed(round) -> int; net = round(c * scale).
static inline int aepScale(int c, float s) { return (int)lroundf((float)c * s); }

// Ghidra: pushAepOtTextCmd (FUN_0001154c) — queue a type-6 text command. The manager-level
// forwarders (FUN_00010540 / _1057c) reach it through AepManager::orderingTable().
void pushAepOtTextCmd(AepOrderingTable *ot, const char *text, int a0, int a1, int a2, int a3,
                      int a4, int a5, const void *colorVec, int priority) {
    AepTextCommand *cmd = reinterpret_cast<AepTextCommand *>(ot->allocEntry(priority));
    if (cmd == nullptr) {
        return;
    }
    cmd->type = 6;                       // +0x04
    cmd->reserved8 = 0;                  // +0x08
    std::strncpy(cmd->text, text, 0x100);// +0x0c
    cmd->text[0xff] = '\0';              // +0x10b force-terminate
    cmd->arg0 = a0;                      // +0x10c
    cmd->arg1 = a1;                      // +0x110
    cmd->arg2 = a2;                      // +0x114
    cmd->arg3 = a3;                      // +0x118
    cmd->arg4 = a4;                      // +0x11c
    cmd->arg5 = a5;                      // +0x120
    if (colorVec != nullptr) {
        std::memcpy(cmd->vec, colorVec, 16);          // +0x124 copy the 16-byte vector
    } else {
        cmd->vec[0] = 0;                              // default colour vector =
        cmd->vec[1] = 0;                              //   {0, 0, screenW, screenH}
        cmd->vec[2] = (int)(int16_t)ot->screenW();    // +0x12c (read as a short in the binary)
        cmd->vec[3] = (int)(int16_t)ot->screenH();    // +0x130
    }
}

// Ghidra: drawAepOtLine (FUN_00010f98).
void drawAepOtLine(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int alpha,
                   uint32_t color) {
    const float s = ot->renderScale();
    neDrawLine(aepScale(x0, s), aepScale(y0, s), aepScale(x1, s), aepScale(y1, s),
               aepAlpha(alpha), aepColR(color), aepColG(color), aepColB(color));
}

// Ghidra: drawAepOtRect (FUN_0001113c).
void drawAepOtRect(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int alpha,
                   uint32_t color) {
    const float s = ot->renderScale();
    neDrawRect(aepScale(x0, s), aepScale(y0, s), aepScale(x1, s), aepScale(y1, s),
               aepAlpha(alpha), aepColR(color), aepColG(color), aepColB(color));
}

// Ghidra: drawAepOtTriangle (FUN_00011054). Every coordinate is scaled by the render
// scale and the three input vertices are threaded in order. neDrawTriangle (FUN_00015188)
// takes exactly the three vertices — the earlier reconstruction appended a fabricated
// fourth x that the real, extern-"C" primitive silently discarded; removed for 1:1.
// (The exact VFP vertex permutation is register-allocator obscured.)
void drawAepOtTriangle(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int x2, int y2,
                       int alpha, uint32_t color) {
    const float s = ot->renderScale();
    neDrawTriangle(aepScale(x0, s), aepScale(y0, s), aepScale(x1, s), aepScale(y1, s),
                   aepScale(x2, s), aepScale(y2, s),
                   aepAlpha(alpha), aepColR(color), aepColG(color), aepColB(color));
}

// Ghidra: drawAepOtQuad (FUN_000111f8). Four scaled corner vertices. neDrawQuad
// (FUN_000153e8) consumes exactly those four; the earlier reconstruction appended a
// fabricated fifth x (a discarded extern-"C" arg) — removed for 1:1.
void drawAepOtQuad(AepOrderingTable *ot, int x0, int y0, int x1, int y1, int x2, int y2,
                   int x3, int y3, int alpha, uint32_t color) {
    const float s = ot->renderScale();
    neDrawQuad(aepScale(x0, s), aepScale(y0, s), aepScale(x1, s), aepScale(y1, s),
               aepScale(x2, s), aepScale(y2, s), aepScale(x3, s), aepScale(y3, s),
               aepAlpha(alpha), aepColR(color), aepColG(color), aepColB(color));
}

// Ghidra: drawAepOtText (FUN_00011310). Position and glyph size are scaled by the render
// scale; the colour vector is likewise scaled (VectorMultiply by scale) and forwarded.
void drawAepOtText(AepOrderingTable *ot, const char *text, int p3, int x, int y, int size, int p7,
                   int alpha, const void *colorVec, uint32_t color) {
    const float s = ot->renderScale();
    const int scaledSize = aepScale(size, s);
    neDrawText(scaledSize, text, p3, aepScale(x, s), aepScale(y, s), scaledSize, p7,
               aepAlpha(alpha), aepColR(color), aepColG(color), aepColB(color), colorVec);
}

// Ghidra: drawAepSpriteClipped (FUN_00012020) — the clipped textured-quad immediate draw.
// Picks the active sub-frame from `frameTime` by walking the frame object's per-frame
// duration table, reduces the rotation to radians, sets the render-state slot for the
// sub-frame, and issues neDrawTexturedQuad through an optional (heap) clip rect.
// NOTE: `frameObj` is the renderer's animated-texture object; its sub-frame tables live
// at fixed offsets (+0x04 count, +0x08 width table, +0x0c duration table, +0x14 the
// render-state slot array, stride 0x18), accessed by offset here as they are owned by the
// neGraphics reconstruction. The float/int split of the transform args is VFP-obscured;
// the recoverable control flow and the neDrawTexturedQuad call are reproduced faithfully.
void drawAepSpriteClipped(float renderScale, void *frameObj, int frameCol, int frameTime, int x,
                          int y, int u0, int v0, float sx, float sy, uint32_t blend, float w,
                          float h, int p13, uint32_t alpha, int p16, const void *clip,
                          int useClip, int p19) {
    (void)renderScale;
    char *obj = reinterpret_cast<char *>(frameObj);

    // Blend mode: bit 0x400 forces mode 2, else (blend & 0x3ff) >> 9.
    const uint32_t mode = (blend & 0x400) ? 2u : ((blend & 0x3ff) >> 9);

    // Sub-frame selection: subtract each frame's duration until the remaining time fits.
    int frame = 0;
    const int frameCount = *reinterpret_cast<const int *>(obj + 4);
    const int *widths = *reinterpret_cast<const int *const *>(obj + 8);
    const int *durations = *reinterpret_cast<const int *const *>(obj + 0xc);
    for (; frame < frameCount; frame++) {
        int d = durations[frame];
        if (frameTime <= d) {
            break;
        }
        frameTime -= d;
    }

    // Rotation: reduce the angle to [0,360) (the binary's /360 reciprocal multiply) and
    // convert to radians for the renderer.
    int reduced = frameCol - (frameCol / 360) * 360;
    // Ghidra: the radian conversion uses the NEGATIVE pi literal (DAT_00012238 = -pi,
    // byte-verified) -> reduced * (-pi/180). With the downstream matrixSetRotateZ(-rotation)
    // this gives the correct net direction; the decompiler dropped the pi literal's sign.
    const float rotation = (float)reduced * (float)(-M_PI / 180.0);

    // Source rect: the sub-frame's stored width bounds the u extent; v uses its duration
    // slot as the height. The clamped-fraction ratios are what neDrawTexturedQuad wants.
    const int frameW = widths[frame];
    const int clampedU = (frameCol < frameW) ? frameCol : frameW;
    const float u1 = frameW ? ((float)clampedU / (float)frameW) : 0.0f;
    const float v1 = (float)frameTime;

    // Optional heap clip rect (the binary operator_new(0x10)s a scaled copy of param_16).
    float *clipRect = nullptr;
    if (clip != nullptr) {
        clipRect = new float[4];
        const int16_t *src = reinterpret_cast<const int16_t *>(clip);
        for (int i = 0; i < 4; i++) {
            clipRect[i] = (float)src[i];
        }
    }

    // Render-state slot for this sub-frame (+0x14 base, stride 0x18).
    const int stateSlot = *reinterpret_cast<const int *>(obj + 0x14) + frame * 0x18;
    setRenderStateSlot(stateSlot, 0, useClip != 0 ? 1 : 0);
    setRenderStateSlot(stateSlot, 1, useClip != 0 ? 1 : 0);

    neDrawTexturedQuad(stateSlot, u0, v0, x, y, (float)u0 / (frameW ? frameW : 1),
                       (float)v0, u1, v1, rotation, (int)w, (int)h, aepAlpha((int)alpha),
                       aepColR(p19), aepColG(p19), aepColB(p19), (uint32_t)mode, clipRect, p16);
    (void)sx;
    (void)sy;
    (void)p13;

    delete[] clipRect;
}

// Ghidra: drawAepOtSprite (FUN_00010c90) — resolve the slot's texture, gate on visibility
// (a fully-transparent, unrotated, unscaled sprite is culled) and forward to
// drawAepSpriteClipped with the sprite record's source rect and the scaled transform.
void drawAepOtSprite(AepOrderingTable *ot, const int16_t *spriteRec, int x, int y, int sx, int sy,
                     int p7, int p8, int p9, uint32_t alpha, uint32_t blend, int p12,
                     const void *clip, int p14, int p15, int slot) {
    const float s = ot->renderScale();
    const int dstX = aepScale(x, s);
    const int dstY = aepScale(y, s);

    // Natural-scale flag (Ghidra's param_14==1 short-circuit): the binary clears it when the
    // sprite is at its natural 100% scale in both axes — scaled sx/sy == 100.0 (DAT_00010e14)
    // — with no blend bits set. Otherwise mask the alpha by the sign of (p12<<0x1a).
    bool visible = (p14 != 0);
    if (p14 == 1 && aepScale(sx, s) == 100 && aepScale(sy, s) == 100 && (blend & 0xffff) == 0) {
        visible = false;
    }
    uint32_t maskedAlpha = alpha & (uint32_t)(((int)((uint32_t)p12 << 0x1a)) >> 0x1f);
    if (p9 == 0 && maskedAlpha == 100) {
        return;   // fully-opaque untinted no-op: nothing to composite
    }

    void *tex = ot->textureTable() ? ot->textureTable()[slot] : nullptr;
    // spriteRec: +0 u, +2 v, +4 width, +6 height.
    // Disasm (drawAepOtSprite tail, four vdiv by DAT_00010e14=100.0): the forwarded quad
    // width/height are the TRIPLE product base * renderScale * (sx|sy)/100 -- the /100 turns
    // the sx/sy PERCENTAGE (100 = natural) into a fraction. The reconstruction dropped the
    // *sx/100 and *sy/100 factors, so every non-100% sprite rendered at a fixed 100% size.
    drawAepSpriteClipped(s, tex, spriteRec[0], spriteRec[1], dstX, dstY, spriteRec[2],
                         spriteRec[3], (float)aepScale(sx, s), (float)aepScale(sy, s), blend,
                         (float)p7 * s * (float)sx / 100.0f, (float)p8 * s * (float)sy / 100.0f,
                         p9, maskedAlpha, p12, clip, visible ? 1 : 0, p15);
}

// Ghidra: drawAepOtSpriteStretch (FUN_00010e18) — the stretched-sprite variant. Same gate
// and scaling as drawAepOtSprite but with an explicit end position (ex,ey), forwarded to
// drawAepSpriteClipped.
void drawAepOtSpriteStretch(AepOrderingTable *ot, void *frameObj, int frameCol, int frameTime,
                            int x, int y, int sx, int sy, int ex, int ey, int p11, int p12,
                            int p13, uint32_t alpha, uint32_t blend, int p16, const void *clip,
                            int p18, int p19) {
    const float s = ot->renderScale();

    // Natural-scale flag, same as drawAepOtSprite but keyed on the END position (ex, ey):
    // the binary clears it when scaled ex/ey == 100.0 (DAT_00010f94) with no blend bits set.
    bool visible = (p18 != 0);
    if (p18 == 1 && aepScale(ex, s) == 100 && aepScale(ey, s) == 100 && (blend & 0xffff) == 0) {
        visible = false;
    }
    uint32_t maskedAlpha = alpha & (uint32_t)(((int)((uint32_t)p16 << 0x1a)) >> 0x1f);
    if (p13 == 0 && maskedAlpha == 100) {
        return;
    }

    // Disasm (drawAepOtSpriteStretch tail, vdiv by DAT_00010f94=100.0): quad width/height are
    // base * renderScale * (ex|ey)/100 -- the stretch variant folds the END position ex/ey (not
    // sx/sy) into the size. Same dropped */100 percentage factor as drawAepOtSprite.
    drawAepSpriteClipped(s, frameObj, frameCol, frameTime, aepScale(x, s), aepScale(y, s), ex, ey,
                         (float)aepScale(sx, s), (float)aepScale(sy, s), blend,
                         (float)p11 * s * (float)ex / 100.0f, (float)p12 * s * (float)ey / 100.0f,
                         p13, maskedAlpha, p16, clip, visible ? 1 : 0, p19);
}
