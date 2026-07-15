//
//  AepOrderingTable.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The Aep
//  ordering table as a per-frame sprite command buffer: allocEntry hands out
//  priority-bucketed command entries (get_aepOt FUN_00010be0), and flush walks
//  the buckets high-priority-first, emitting one textured GL quad per command.
//  The binary routes the GL calls through neGLES_11; the equivalent ES 1.1
//  calls are issued directly here.
//

#include <cassert>
#include <cstring>

#import <OpenGLES/ES1/gl.h>

#import "AepOrderingTable.h"
#import "neRenderer.h"    // neDrawLine/Triangle/Rect/Quad/TexturedQuad
#import "neTextTexture.h" // neDrawText (FUN_0001551c)
#import "neTextureRef.h"  // neTextureRef::setRenderStateSlot (FUN_00016710)

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

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
AepOtSpriteCmd *AepOrderingTable::allocEntry(int priority) {
    assert(m_count < kOtRegistMax); // AepOrderingTable.mm:0x3d "m_OtCount < OT_REGIST_MAX"
    assert(priority < kOtPriMax);   // AepOrderingTable.mm:0x3e "pri < OT_PRI_MAX"

    AepOtSpriteCmd *cmd = &m_entries[m_count++];
    cmd->nPriority = (int16_t)priority;
    if (priority > m_maxPriority) {
        m_maxPriority = priority;
    }
    // get_aepOt head-inserts into the bucket and updates both pCurrentByPri and
    // pHeadByPri to the newest entry; m_buckets models the (identical) head.
    cmd->pListNext = m_buckets[priority];
    m_buckets[priority] = cmd;
    return cmd;
}

// Ghidra: AepOrderingTable::drawSprite (FUN_00011468) — fill a stretched-sprite
// command (wFlags=1) and link it at `nPriority`. `pTexture` is the source
// neTextureForiOS*; it is stored verbatim in nTexU and the flush later
// reinterprets it as the neTextureFrames* drawAepOtSpriteStretch walks (the two
// are the same object: tile count @+0x04, width/height tables @+0x08/+0x0c, and
// the per-tile render-state records @+0x14, stride 0x18). The trailing clip words
// spill into the next pool entry exactly as the binary does.
AepOtSpriteCmd *AepOrderingTable::drawSprite(neTextureForiOS *pTexture,
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
                                             int nPriority) {
    AepOtSpriteCmd *cmd = allocEntry(nPriority);
    if (cmd == nullptr) {
        return nullptr;
    }
    cmd->wFlags = 1; // type 1 = stretched sprite
    cmd->nBank = 0;
    cmd->pTexObj = pTexture; // sprite texture object (the binary packs it into nTexU)
    cmd->nTexU = 0;          // unused for sprites here; the texture lives in pTexObj
    cmd->nTexV = nTexV;      // frame column
    cmd->nPosX = nPosX;
    cmd->nPosY = nPosY;
    cmd->flPosXf = flPosXf;
    cmd->flPosYf = flPosYf;
    cmd->nOfsX = nOfsX;
    cmd->nOfsY = nOfsY;
    cmd->nColorA = nColorA;
    cmd->nColorMul = nColorMul;
    cmd->nUKey = (int16_t)nKeys;
    cmd->nVKey = (int16_t)(nKeys >> 16);
    cmd->nBlendFlags = nBlendFlags;
    cmd->nColorRGB = nColorRGB;
    // clipRect.nLeft carries two packed shorts; nTop / nRight follow.
    cmd->clipRect.nLeft = (int)((uint16_t)clipLeftLo | ((uint32_t)(uint16_t)clipLeftHi << 16));
    cmd->clipRect.nTop = clipTop;
    cmd->clipRect.nRight = clipRight;
    // The binary spills a 16-byte clip block starting at clipRect.nBottom (+0x4c),
    // flowing into the entry's scratch tail. Ghidra addresses the trailing 8 bytes
    // as pAVar1[1].wFlags/.nBank because it models the pool entry as the 80-byte
    // AepOtSpriteCmd; that is the SAME 0x134 slot's scratch, not a second entry, so
    // write it in place (advancing a whole AepOtSpriteCmd here would clobber the
    // next pooled command).
    if (clipSpill != nullptr) {
        std::memcpy(&cmd->clipRect.nBottom, clipSpill, 16);
    } else {
        std::memset(&cmd->clipRect.nBottom, 0, 16);
    }
    return cmd;
}

// Establish the per-frame 2D render state. This is NOT part of
// renderAepOrderingTable (which is pure dispatch): in the binary the renderer
// facade / GL view sets the projection and default render state at frame begin,
// outside the OT flush. The reconstruction has not yet routed that frame-begin
// setup through the facade, so this stand-in loads the top-left-origin ortho and
// the default 2D blend state here, guarded by the cached screen extents
// (setScreenParams). Once the facade's frame-begin path is wired this can be
// dropped. Kept separate from the dispatch loop so the loop stays bit-exact.
static void establishFrame2DState(int screenW, int screenH) {
    if (screenW <= 0 || screenH <= 0) {
        return;
    }
    const GLfloat W = (GLfloat)screenW;
    const GLfloat H = (GLfloat)screenH;
    // glOrtho(0, W, H, 0, -1, 1) as a column-major matrix (top-left origin).
    const GLfloat ortho[16] = {
        2.0f / W,
        0.0f,
        0.0f,
        0.0f,
        0.0f,
        -2.0f / H,
        0.0f,
        0.0f,
        0.0f,
        0.0f,
        -1.0f,
        0.0f,
        -1.0f,
        1.0f,
        0.0f,
        1.0f,
    };
    static const GLfloat identity[16] = {
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
    };
    // Do NOT set glViewport here -- MainViewController -draw sets it to the full
    // drawable so this content-resolution ortho stretches across the whole screen.
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(ortho);
    glMatrixMode(GL_MODELVIEW);
    glLoadMatrixf(identity);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

// Ghidra: renderAepOrderingTable (FUN_000115d0) — walk the priority buckets from
// OT_PRI_MAX-1 (0x31) down to 0 (high priority drawn first = back-to-front) and
// dispatch each queued command by its wFlags tag to the matching per-type draw
// handler. Each handler receives the raw command fields in the exact order the
// binary passes them (the field slots are reinterpreted per type; the handler
// bodies follow their own FUN_* decompiles). Priority 0 draws last = frontmost.
void AepOrderingTable::flush() {
    establishFrame2DState(m_screenW, m_screenH); // frame-begin bridge (see above)

    m_drawnCount = 0;
    for (int pri = kOtPriMax - 1; pri >= 0; pri--) {
        for (AepOtSpriteCmd *cmd = m_buckets[pri]; cmd != nullptr; cmd = cmd->pListNext) {
            switch (cmd->wFlags) {
            case 0:                           // textured sprite -> drawAepOtSprite (FUN_00010c90)
                drawAepOtSprite(cmd->srcRect, // packed {u, v, w, h} source rect
                                cmd->nPosX,
                                cmd->nPosY,
                                (int)cmd->flPosXf,
                                (int)cmd->flPosYf,
                                cmd->nOfsX,
                                cmd->nOfsY,
                                cmd->nColorA,
                                (uint32_t)cmd->nColorMul,
                                (int)cmd->nUKey,
                                (uint32_t)(uint16_t)cmd->nVKey,
                                &cmd->clipRect.nLeft,
                                cmd->nBlendFlags,
                                cmd->nColorRGB,
                                cmd->nBank);
                break;
            case 1: { // stretched sprite -> drawAepOtSpriteStretch (FUN_00010e18)
                const int nKeys = (uint16_t)cmd->nUKey | (cmd->nVKey << 16);
                drawAepOtSpriteStretch(cmd->pTexObj, // the sprite texture object (typed)
                                       cmd->nTexV,
                                       cmd->nPosX,
                                       cmd->nPosY,
                                       (int)cmd->flPosXf,
                                       (int)cmd->flPosYf,
                                       cmd->nOfsX,
                                       cmd->nOfsY,
                                       cmd->nColorA,
                                       cmd->nColorMul,
                                       nKeys,
                                       cmd->nBlendFlags,
                                       (uint32_t)cmd->nColorRGB,
                                       (int)(int16_t)cmd->clipRect.nLeft,
                                       (int)(uint16_t)((uint32_t)cmd->clipRect.nLeft >> 16),
                                       &cmd->clipRect.nBottom,
                                       cmd->clipRect.nTop,
                                       cmd->clipRect.nRight);
                break;
            }
            case 2: // line -> drawAepOtLine (FUN_00010f98)
                drawAepOtLine(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              (int)cmd->flPosXf,
                              (uint32_t)cmd->flPosYf);
                break;
            case 3: // triangle -> drawAepOtTriangle (FUN_00011054)
                drawAepOtTriangle(cmd->nTexU,
                                  cmd->nTexV,
                                  cmd->nPosX,
                                  cmd->nPosY,
                                  (int)cmd->flPosXf,
                                  (int)cmd->flPosYf,
                                  cmd->nOfsX,
                                  cmd->nOfsY);
                break;
            case 4: // rect (transition fade overlay) -> drawAepOtRect (FUN_0001113c)
                drawAepOtRect(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              (int)cmd->flPosXf,
                              (uint32_t)cmd->flPosYf);
                break;
            case 5: // quad -> drawAepOtQuad (FUN_000111f8)
                drawAepOtQuad(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              (int)cmd->flPosXf,
                              (int)cmd->flPosYf,
                              cmd->nOfsX,
                              cmd->nOfsY,
                              cmd->nColorA,                           // alpha (+0x2c)
                              static_cast<uint32_t>(cmd->nColorMul)); // colour (+0x30)
                break;
            case 6: { // text -> drawAepOtText (FUN_00011310)
                // The type-6 entry is an AepTextCmd overlaid on the same pool slot:
                // the string lives at +0x0c (the nTexU slot) and the glyph
                // parameters at +0x10c. (The binary reaches them as pCmd[3].* using
                // the 80-byte AepOtSpriteCmd view; the named overlay is equivalent.)
                const AepTextCmd *t = reinterpret_cast<const AepTextCmd *>(cmd);
                drawAepOtText(t->pText,
                              0x1020bd,
                              (int)t->flPosXf,
                              (int)t->flPosYf,
                              t->nColorTL,
                              t->nColorTR,
                              t->nColorBL,
                              t->pAClipVec,
                              (uint32_t)t->nColorBR);
                break;
            }
            default:
                break;
            }
            m_drawnCount++;
        }
    }
    reset(); // the buffer is consumed; ready for the next frame's fill
}

// ===========================================================================
// Screen params + immediate-mode primitive draw helpers.
// ===========================================================================

// Ghidra: aepOtSetScreenParams (FUN_00010bbc) — cache the screen extents, the
// per-slot texture-handle table and the device-pixel render scale on the OT.
void AepOrderingTable::setScreenParams(void **textureTable, int screenW, int screenH, float scale) {
    m_screenW = screenW;           // +0x04
    m_screenH = screenH;           // +0x08
    m_textureTable = textureTable; // +0x9a1a4
    m_renderScale = scale;         // +0x9a1a8
}

void aepOtSetScreenParams(
    AepOrderingTable *ot, void **textureTable, int screenW, int screenH, float scale) {
    ot->setScreenParams(textureTable, screenW, screenH, scale);
}

// Colour / alpha unpack shared by every primitive. The alpha is the
// byte-verified `v * 0xff / 100` reciprocal-multiply (`* 0x51eb851f >> 0x25`);
// the colour word is packed 0x00RRGGBB.
static inline int aepAlpha(int pct) {
    return ((pct * 0xff) / 100) & 0xff;
}
static inline int aepColR(uint32_t c) {
    return (int)((c & 0xffffff) >> 0x10);
}
static inline int aepColG(uint32_t c) {
    return (int)((c & 0xffff) >> 8);
}
static inline int aepColB(uint32_t c) {
    return (int)(c & 0xff);
}
// Transform a coordinate by the OT render scale. The binary converts the int to
// float, multiplies by the scale, and snaps back with vcvt.s32.f32 — the NEON
// float-to-int conversion, which always rounds toward zero — i.e. a plain (int)
// cast, not round-to-nearest. Verified in drawAepOtLine (0x10f98) and
// drawAepOtRect (0x1113c): vmul.f32 by the scale, then vcvt.s32.f32 with no bias.
static inline int aepScale(int c, float s) {
    return (int)((float)c * s);
}

// Ghidra: pushAepOtTextCmd (FUN_0001154c) — queue a type-6 text command. The
// manager-level forwarders (FUN_00010540 / _1057c) reach it through
// AepManager::orderingTable().
void pushAepOtTextCmd(AepOrderingTable *ot,
                      const char *text,
                      int a0,
                      int a1,
                      int a2,
                      int a3,
                      int a4,
                      int a5,
                      const void *colorVec,
                      int priority) {
    AepTextCmd *cmd = reinterpret_cast<AepTextCmd *>(ot->allocEntry(priority));
    if (cmd == nullptr) {
        return;
    }
    cmd->nType = 6;                      // +0x04
    cmd->nReserved8 = 0;                 // +0x08
    std::strncpy(cmd->pText, text, 256); // +0x0c
    cmd->pText[255] = '\0';              // +0x10b force-terminate
    // The manager forwarders pass the pen position (a0/a1) and the four per-corner
    // colours (a2..a5); PushAepOtTextCmd stores the position in the float slots.
    cmd->flPosXf = (float)a0; // +0x10c
    cmd->flPosYf = (float)a1; // +0x110
    cmd->nColorTL = a2;       // +0x114
    cmd->nColorTR = a3;       // +0x118
    cmd->nColorBL = a4;       // +0x11c
    cmd->nColorBR = a5;       // +0x120
    if (colorVec != nullptr) {
        std::memcpy(cmd->pAClipVec, colorVec, 16); // +0x124 copy the 16-byte clip vector
    } else {
        cmd->pAClipVec[0] = 0;                           // default clip vector =
        cmd->pAClipVec[1] = 0;                           //   {0, 0, screenW, screenH}
        cmd->pAClipVec[2] = (int)(int16_t)ot->screenW(); // +0x12c (read as a short in the binary)
        cmd->pAClipVec[3] = (int)(int16_t)ot->screenH(); // +0x130
    }
}

// Ghidra: AepOrderingTable::drawAepOtLine (FUN_00010f98).
void AepOrderingTable::drawAepOtLine(int x0, int y0, int x1, int y1, int alpha, uint32_t color) {
    const float s = renderScale();
    neDrawLine(aepScale(x0, s),
               aepScale(y0, s),
               aepScale(x1, s),
               aepScale(y1, s),
               aepAlpha(alpha),
               aepColR(color),
               aepColG(color),
               aepColB(color));
}

// Ghidra: AepOrderingTable::drawAepOtRect (FUN_0001113c).
void AepOrderingTable::drawAepOtRect(int x0, int y0, int x1, int y1, int alpha, uint32_t color) {
    const float s = renderScale();
    neDrawRect(aepScale(x0, s),
               aepScale(y0, s),
               aepScale(x1, s),
               aepScale(y1, s),
               aepAlpha(alpha),
               aepColR(color),
               aepColG(color),
               aepColB(color));
}

// Ghidra: drawAepOtTriangle (FUN_00011054). Every coordinate is scaled by the
// render scale and the three input vertices are threaded in order.
// neDrawTriangle (FUN_00015188) takes exactly the three vertices — the earlier
// reconstruction appended a fabricated fourth x that the real, extern-"C"
// primitive silently discarded; removed for 1:1. (The exact VFP vertex
// permutation is register-allocator obscured.)
void AepOrderingTable::drawAepOtTriangle(
    int x0, int y0, int x1, int y1, int x2, int y2, int alpha, uint32_t color) {
    const float s = renderScale();
    neDrawTriangle(aepScale(x0, s),
                   aepScale(y0, s),
                   aepScale(x1, s),
                   aepScale(y1, s),
                   aepScale(x2, s),
                   aepScale(y2, s),
                   aepAlpha(alpha),
                   aepColR(color),
                   aepColG(color),
                   aepColB(color));
}

// Ghidra: drawAepOtQuad (FUN_000111f8). Four scaled corner vertices. neDrawQuad
// (FUN_000153e8) consumes exactly those four; the earlier reconstruction
// appended a fabricated fifth x (a discarded extern-"C" arg) — removed for 1:1.
void AepOrderingTable::drawAepOtQuad(
    int x0, int y0, int x1, int y1, int x2, int y2, int x3, int y3, int alpha, uint32_t color) {
    const float s = renderScale();
    neDrawQuad(aepScale(x0, s),
               aepScale(y0, s),
               aepScale(x1, s),
               aepScale(y1, s),
               aepScale(x2, s),
               aepScale(y2, s),
               aepScale(x3, s),
               aepScale(y3, s),
               aepAlpha(alpha),
               aepColR(color),
               aepColG(color),
               aepColB(color));
}

// Ghidra: drawAepOtText (FUN_00011310). Position and glyph size are scaled by
// the render scale; the colour vector is likewise scaled (VectorMultiply by
// scale) and forwarded.
void AepOrderingTable::drawAepOtText(const char *text,
                                     int p3,
                                     int x,
                                     int y,
                                     int size,
                                     int p7,
                                     int alpha,
                                     const void *colorVec,
                                     uint32_t color) {
    const float s = renderScale();
    const int scaledSize = aepScale(size, s);
    // Real signature: neDrawText(text, font, size, x, y, align, alpha, r, g, b,
    // clipRect). The binary passes p3 as the font arg (an int handle in the
    // pointer slot) and colorVec as the clip rect.
    neDrawText(text,
               reinterpret_cast<void *>(static_cast<uintptr_t>(static_cast<uint32_t>(p3))),
               scaledSize,
               aepScale(x, s),
               aepScale(y, s),
               p7,
               aepAlpha(alpha),
               aepColR(color),
               aepColG(color),
               aepColB(color),
               reinterpret_cast<const int *>(colorVec));
}

// Ghidra: drawAepSpriteClipped (FUN_00012020) — the clipped textured-quad
// immediate draw. Picks the active sub-frame from `frameTime` by walking the
// frame object's per-frame duration table, reduces the rotation to radians,
// sets the render-state slot for the sub-frame, and issues neDrawTexturedQuad
// through an optional (heap) clip rect. NOTE: `frameObj` is the renderer's
// animated-texture object; its sub-frame tables live at fixed offsets (+0x04
// count, +0x08 width table, +0x0c duration table, +0x14 the render-state slot
// array, stride 0x18), accessed by offset here as they are owned by the
// neGraphics reconstruction. The float/int split of the transform args is
// VFP-obscured; the recoverable control flow and the neDrawTexturedQuad call
// are reproduced faithfully.
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
                          int p19) {
    (void)renderScale;
    char *obj = reinterpret_cast<char *>(frameObj);

    // Blend mode: bit 0x400 forces mode 2, else (blend & 0x3ff) >> 9.
    const uint32_t mode = (blend & 0x400) ? 2u : ((blend & 0x3ff) >> 9);

    // Sub-frame selection: subtract each frame's duration until the remaining
    // time fits.
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

    // Rotation: reduce the angle to [0,360) (the binary's /360 reciprocal
    // multiply) and convert to radians for the renderer.
    int reduced = frameCol - (frameCol / 360) * 360;
    // Ghidra: the radian conversion uses the NEGATIVE pi literal (DAT_00012238 =
    // -pi, byte-verified) -> reduced * (-pi/180). With the downstream
    // matrixSetRotateZ(-rotation) this gives the correct net direction; the
    // decompiler dropped the pi literal's sign.
    const float rotation = (float)reduced * (float)(-M_PI / 180.0);

    // Source rect: the sub-frame's stored width bounds the u extent; v uses its
    // duration slot as the height. The clamped-fraction ratios are what
    // neDrawTexturedQuad wants.
    const int frameW = widths[frame];
    const int clampedU = (frameCol < frameW) ? frameCol : frameW;
    const float u1 = frameW ? ((float)clampedU / (float)frameW) : 0.0f;
    const float v1 = (float)frameTime;

    // Optional heap clip rect (the binary operator_new(0x10)s a scaled copy of
    // param_16).
    float *clipRect = nullptr;
    if (clip != nullptr) {
        clipRect = new float[4];
        const int16_t *src = reinterpret_cast<const int16_t *>(clip);
        for (int i = 0; i < 4; i++) {
            clipRect[i] = (float)src[i];
        }
    }

    // Render-state slot for this sub-frame: the neTextureRef record at
    // [frameObj + 0x14] + frame*0x18 (Ghidra 0x12154). Set slot 0/1 to the clip
    // flag (Ghidra 0x1215e/0x12180 -> neTextureRef::setRenderStateSlot).
    neTextureRef *slot = reinterpret_cast<neTextureRef *>(
        *reinterpret_cast<char *const *>(obj + 0x14) + frame * 0x18);
    slot->setRenderStateSlot(0, useClip != 0 ? 1 : 0);
    slot->setRenderStateSlot(1, useClip != 0 ? 1 : 0);

    // The slot record is the sprite object neDrawTexturedQuad blits (Ghidra
    // 0x121f8 -> FUN_00015fb8). The argument values line up positionally with the
    // real signature; p16 is a trailing flag the real entry point does not take.
    neDrawTexturedQuad(slot,
                       u0,
                       v0,
                       x,
                       y,
                       (float)u0 / (frameW ? frameW : 1),
                       (float)v0,
                       u1,
                       v1,
                       rotation,
                       (int)w,
                       (int)h,
                       aepAlpha((int)alpha),
                       aepColR(p19),
                       aepColG(p19),
                       aepColB(p19),
                       (int)mode,
                       clipRect);
    (void)sx;
    (void)sy;
    (void)p13;
    (void)p16;

    delete[] clipRect;
}

// Ghidra: drawAepOtSprite (FUN_00010c90) — resolve the slot's texture, gate on
// visibility (a fully-transparent, unrotated, unscaled sprite is culled) and
// forward to drawAepSpriteClipped with the sprite record's source rect and the
// scaled transform.
void AepOrderingTable::drawAepOtSprite(const int16_t *spriteRec,
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
                                       int slot) {
    const float s = renderScale();
    const int dstX = aepScale(x, s);
    const int dstY = aepScale(y, s);

    // Natural-scale flag (Ghidra's param_14==1 short-circuit): the binary clears
    // it when the sprite is at its natural 100% scale in both axes — scaled sx/sy
    // == 100.0 (DAT_00010e14) — with no blend bits set. Otherwise mask the alpha
    // by the sign of (p12<<0x1a).
    bool visible = (p14 != 0);
    if (p14 == 1 && aepScale(sx, s) == 100 && aepScale(sy, s) == 100 && (blend & 0xffff) == 0) {
        visible = false;
    }
    uint32_t maskedAlpha = alpha & (uint32_t)(((int)((uint32_t)p12 << 0x1a)) >> 0x1f);
    if (p9 == 0 && maskedAlpha == 100) {
        return; // fully-opaque untinted no-op: nothing to composite
    }

    void *tex = textureTable() ? textureTable()[slot] : nullptr;
    // spriteRec: +0 u, +2 v, +4 width, +6 height.
    // Disasm (drawAepOtSprite tail, four vdiv by DAT_00010e14=100.0): the
    // forwarded quad width/height are the TRIPLE product base * renderScale *
    // (sx|sy)/100 -- the /100 turns the sx/sy PERCENTAGE (100 = natural) into a
    // fraction. The reconstruction dropped the *sx/100 and *sy/100 factors, so
    // every non-100% sprite rendered at a fixed 100% size.
    drawAepSpriteClipped(s,
                         tex,
                         spriteRec[0],
                         spriteRec[1],
                         dstX,
                         dstY,
                         spriteRec[2],
                         spriteRec[3],
                         (float)aepScale(sx, s),
                         (float)aepScale(sy, s),
                         blend,
                         (float)p7 * s * (float)sx / 100.0f,
                         (float)p8 * s * (float)sy / 100.0f,
                         p9,
                         maskedAlpha,
                         p12,
                         clip,
                         visible ? 1 : 0,
                         p15);
}

// Ghidra: drawAepOtSpriteStretch (FUN_00010e18) — the stretched-sprite variant.
// Same gate and scaling as drawAepOtSprite but with an explicit end position
// (ex,ey), forwarded to drawAepSpriteClipped.
void AepOrderingTable::drawAepOtSpriteStretch(void *frameObj,
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
                                              int p19) {
    const float s = renderScale();

    // Natural-scale flag, same as drawAepOtSprite but keyed on the END position
    // (ex, ey): the binary clears it when scaled ex/ey == 100.0 (DAT_00010f94)
    // with no blend bits set.
    bool visible = (p18 != 0);
    if (p18 == 1 && aepScale(ex, s) == 100 && aepScale(ey, s) == 100 && (blend & 0xffff) == 0) {
        visible = false;
    }
    uint32_t maskedAlpha = alpha & (uint32_t)(((int)((uint32_t)p16 << 0x1a)) >> 0x1f);
    if (p13 == 0 && maskedAlpha == 100) {
        return;
    }

    // Disasm (drawAepOtSpriteStretch tail, vdiv by DAT_00010f94=100.0): quad
    // width/height are base * renderScale * (ex|ey)/100 -- the stretch variant
    // folds the END position ex/ey (not sx/sy) into the size. Same dropped */100
    // percentage factor as drawAepOtSprite.
    drawAepSpriteClipped(s,
                         frameObj,
                         frameCol,
                         frameTime,
                         aepScale(x, s),
                         aepScale(y, s),
                         ex,
                         ey,
                         (float)aepScale(sx, s),
                         (float)aepScale(sy, s),
                         blend,
                         (float)p11 * s * (float)ex / 100.0f,
                         (float)p12 * s * (float)ey / 100.0f,
                         p13,
                         maskedAlpha,
                         p16,
                         clip,
                         visible ? 1 : 0,
                         p19);
}
