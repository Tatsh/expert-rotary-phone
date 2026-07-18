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
#include <memory>

#import <OpenGLES/ES1/gl.h>

#import "AepOrderingTable.h"
#import "C_RENDER.h"        // neDrawLine/Triangle/Rect/Quad/TexturedQuad
#import "C_SINGLE_SPRITE.h" // ne::C_SINGLE_SPRITE::setRenderStateSlot (FUN_00016710)
#import "neDebugLog.h"
#import "neTextTexture.h"   // neDrawText (FUN_0001551c)
#import "neTextureForiOS.h" // the sprite/frame-atlas object the flush walks

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// @complete
AepOrderingTable::AepOrderingTable() {
    reset();
}

// Reset for a new frame: no live commands, empty buckets.
// @complete
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
// @complete
AepOtSpriteCmd *AepOrderingTable::allocEntry(int priority) {
    assert(m_count < kOtRegistMax); // AepOrderingTable.mm:0x3d "m_OtCount < OT_REGIST_MAX"
    assert(priority < kOtPriMax);   // AepOrderingTable.mm:0x3e "pri < OT_PRI_MAX"

    AepOtSpriteCmd *cmd = &m_entries[m_count++];
    cmd->nPriority = static_cast<int16_t>(priority);
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
//
// The command's only float stores are cmd+0x28 and cmd+0x2c (the sole vstr pair in
// FUN_00011468; every other slot is a plain int str), which hold the stretched
// sprite's X/Y scale. They are the nOfsYF/nColorAF float views of the AepOtSpriteCmd
// union; flPosXf/flPosYf (+0x1c/+0x20) are the int views (str). The wrapper
// neTextureForiOS::draw (FUN_0000fbcc) already vcvt-converts exactly those two scale
// args to float and passes the positions as ints, so this fill mirrors the binary
// store-for-store.
// @complete
AepOtSpriteCmd *AepOrderingTable::drawSprite(neTextureForiOS *pTexture,
                                             int nTexV,
                                             int nPosX,
                                             int nPosY,
                                             int flPosXf,
                                             int flPosYf,
                                             int nOfsX,
                                             float nOfsY,
                                             float nColorA,
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
    cmd->nOfsYF = nOfsY;     // +0x28 float view (binary vstr): stretched-sprite X scale
    cmd->nColorAF = nColorA; // +0x2c float view (binary vstr): stretched-sprite Y scale
    cmd->nColorMul = nColorMul;
    cmd->nUKey = static_cast<int16_t>(nKeys);
    cmd->nVKey = static_cast<int16_t>(nKeys >> 16);
    cmd->nBlendFlags = nBlendFlags;
    cmd->nColorRGB = nColorRGB;
    // clipRect.nLeft carries two packed shorts; nTop / nRight follow.
    cmd->clipRect.nLeft =
        static_cast<int>(static_cast<uint16_t>(clipLeftLo) |
                         (static_cast<uint32_t>(static_cast<uint16_t>(clipLeftHi)) << 16));
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
        // No explicit clip: default to the full screen bounds, matching the binary
        // (it fills the spill tail from aEntries[0].pAHeader+4/+8 = screen w/h). The
        // flush reads &clipRect.nBottom as {left0, top0, right, bottom}; {0,0,W,H}
        // clips to the whole content area, i.e. a no-op. Zero-filling it (as before)
        // produced a {0,0,0,0} region that clipped every unclipped sprite away.
        int32_t *spill = &cmd->clipRect.nBottom;
        spill[0] = 0;
        spill[1] = 0;
        spill[2] = m_screenW;
        spill[3] = m_screenH;
    }
    return cmd;
}

// Ghidra: renderAepOrderingTable (FUN_000115d0) — walk the priority buckets from
// OT_PRI_MAX-1 (0x31) down to 0 (high priority drawn first = back-to-front) and
// dispatch each queued command by its wFlags tag to the matching per-type draw
// handler. Each handler receives the raw command fields in the exact order the
// binary passes them (the field slots are reinterpreted per type; the handler
// bodies follow their own FUN_* decompiles). Priority 0 draws last = frontmost.
// @complete
void AepOrderingTable::flush() {
    // Pure dispatch, exactly as FUN_000115d0: the per-frame 2D render state
    // (top-left ortho projection, identity model matrix and default blend) is
    // established through the renderer facade by the draw primitives themselves —
    // every neDraw* funnels through neApplyDefaultRenderState / neApplyViewport,
    // which load g_pCurrentViewport's ortho (built by MainViewController's
    // neCreateOrthoViewport) and reset the caps. No frame-begin setup happens here.
    if (NE_DBG_FIRST(240)) {
        int dbgTotal = 0, dbgType[8] = {0};
        for (int pri = kOtPriMax - 1; pri >= 0; pri--) {
            for (AepOtSpriteCmd *c = m_buckets[pri]; c != nullptr; c = c->pListNext) {
                ++dbgTotal;
                if ((unsigned)c->wFlags < 8) {
                    ++dbgType[c->wFlags];
                }
            }
        }
        neDebugLog(
            "flush m_count=%d queued=%d byType[sprite=%d stretch=%d t2=%d t6=%d] screen=%dx%d",
            m_count,
            dbgTotal,
            dbgType[0],
            dbgType[1],
            dbgType[2],
            dbgType[6],
            m_screenW,
            m_screenH);
    }

    m_drawnCount = 0;
    for (int pri = kOtPriMax - 1; pri >= 0; pri--) {
        for (AepOtSpriteCmd *cmd = m_buckets[pri]; cmd != nullptr; cmd = cmd->pListNext) {
            switch (cmd->wFlags) {
            case 0:                           // textured sprite -> drawAepOtSprite (FUN_00010c90)
                drawAepOtSprite(cmd->srcRect, // packed {u, v, w, h} source rect
                                cmd->nPosX,
                                cmd->nPosY,
                                static_cast<int>(cmd->flPosXfF), // +0x1c float view (vldr)
                                static_cast<int>(cmd->flPosYfF), // +0x20 float view (vldr)
                                cmd->nOfsX,
                                cmd->nOfsY,   // +0x28 int view (ldr): width/height
                                cmd->nColorA, // +0x2c int view (ldr): colour
                                static_cast<uint32_t>(cmd->nColorMul),
                                static_cast<int>(cmd->nUKey),
                                static_cast<uint32_t>(static_cast<uint16_t>(cmd->nVKey)),
                                &cmd->clipRect.nLeft,
                                cmd->nBlendFlags,
                                cmd->nColorRGB,
                                cmd->nBank);
                break;
            case 1: { // stretched sprite -> drawAepOtSpriteStretch (FUN_00010e18)
                // Exact command->handler field mapping per Ghidra FUN_000115d0
                // case-1. The scale percentages (nOfsY/nColorA slots) are read as
                // floats; the base size lives in nPosY/flPosXf, the position in
                // flPosYf/nOfsX.
                const int nColorA =
                    static_cast<uint16_t>(cmd->nUKey) | (static_cast<int>(cmd->nVKey) << 16);
                const uint32_t clipLeft = static_cast<uint32_t>(cmd->clipRect.nLeft);
                drawAepOtSpriteStretch(cmd->pTexObj,   // pFrames
                                       cmd->nTexV,     // nU
                                       cmd->nPosX,     // nV
                                       cmd->nPosY,     // nPosX (width)
                                       cmd->flPosXf,   // nPosY (height) +0x1c int view (ldr)
                                       cmd->flPosYf,   // nScaleX (screen X) +0x20 int view (ldr)
                                       cmd->nOfsX,     // nScaleY (screen Y)
                                       cmd->nOfsYF,    // nOfsX (X scale %) +0x28 float view (vldr)
                                       cmd->nColorAF,  // nOfsY (Y scale %) +0x2c float view (vldr)
                                       cmd->nColorMul, // nColorMul
                                       nColorA,        // nColorA
                                       cmd->nBlendFlags,       // nAlpha (colour %)
                                       cmd->nColorRGB,         // nColorFlags
                                       clipLeft & 0xffff,      // nColorA2
                                       clipLeft >> 16,         // nBlendMask
                                       &cmd->clipRect.nBottom, // pClipRect
                                       cmd->clipRect.nTop,     // nBlendFlag
                                       static_cast<uint32_t>(cmd->clipRect.nRight)); // nColorRGB
                break;
            }
            case 2: // line -> drawAepOtLine (FUN_00010f98)
                drawAepOtLine(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              static_cast<int>(cmd->flPosXf),
                              static_cast<uint32_t>(cmd->flPosYf));
                break;
            case 3: // triangle -> drawAepOtTriangle (FUN_00011054)
                drawAepOtTriangle(cmd->nTexU,
                                  cmd->nTexV,
                                  cmd->nPosX,
                                  cmd->nPosY,
                                  static_cast<int>(cmd->flPosXf),
                                  static_cast<int>(cmd->flPosYf),
                                  cmd->nOfsX,
                                  cmd->nOfsY); // +0x28 int view
                break;
            case 4: // rect (transition fade overlay) -> drawAepOtRect (FUN_0001113c)
                drawAepOtRect(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              static_cast<int>(cmd->flPosXf),
                              static_cast<uint32_t>(cmd->flPosYf));
                break;
            case 5: // quad -> drawAepOtQuad (FUN_000111f8)
                drawAepOtQuad(cmd->nTexU,
                              cmd->nTexV,
                              cmd->nPosX,
                              cmd->nPosY,
                              static_cast<int>(cmd->flPosXf),
                              static_cast<int>(cmd->flPosYf),
                              cmd->nOfsX,
                              cmd->nOfsY,                             // +0x28 int view
                              cmd->nColorA,                           // alpha (+0x2c int view)
                              static_cast<uint32_t>(cmd->nColorMul)); // colour (+0x30)
                break;
            case 6: { // text -> drawAepOtText (FUN_00011310)
                // The type-6 entry is an AepTextCmd overlaid on the same pool slot:
                // the string lives at +0x0c (the nTexU slot) and the glyph
                // parameters at +0x10c. (The binary reaches them as pCmd[3].* using
                // the 80-byte AepOtSpriteCmd view; the named overlay is equivalent.)
                const AepTextCmd *t = reinterpret_cast<const AepTextCmd *>(cmd);
                // The binary hard-codes the font-name pointer 0x1020bd, which in the
                // armv7 image is the C-string "DFMaruGothic-Bd-WIN-RKSJ-H" (Ghidra:
                // renderAepOrderingTable @0x117be references it as the font param).
                // That raw address is dead memory on the 64-bit rebuild, so pass the
                // real string it pointed at.
                drawAepOtText(t->pText,
                              "DFMaruGothic-Bd-WIN-RKSJ-H",
                              t->nPosX,
                              t->nPosY,
                              t->nColorTL,
                              t->nColorTR,
                              t->nColorBL,
                              t->pAClipVec,
                              static_cast<uint32_t>(t->nColorBR));
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
// @complete
void AepOrderingTable::setScreenParams(neTextureForiOS **textureTable,
                                       int screenW,
                                       int screenH,
                                       float scale) {
    m_screenW = screenW;           // +0x04
    m_screenH = screenH;           // +0x08
    m_textureTable = textureTable; // +0x9a1a4
    m_renderScale = scale;         // +0x9a1a8
}

void aepOtSetScreenParams(
    AepOrderingTable *ot, neTextureForiOS **textureTable, int screenW, int screenH, float scale) {
    ot->setScreenParams(textureTable, screenW, screenH, scale);
}

// Colour / alpha unpack shared by every primitive. The alpha is the
// byte-verified `v * 0xff / 100` reciprocal-multiply (`* 0x51eb851f >> 0x25`);
// the colour word is packed 0x00RRGGBB.
static inline int aepAlpha(int pct) {
    return ((pct * 0xff) / 100) & 0xff;
}
static inline int aepColR(uint32_t c) {
    return static_cast<int>((c & 0xffffff) >> 0x10);
}
static inline int aepColG(uint32_t c) {
    return static_cast<int>((c & 0xffff) >> 8);
}
static inline int aepColB(uint32_t c) {
    return static_cast<int>(c & 0xff);
}
// Transform a coordinate by the OT render scale. The binary converts the int to
// float, multiplies by the scale, and snaps back with vcvt.s32.f32 — the NEON
// float-to-int conversion, which always rounds toward zero — i.e. a plain (int)
// cast, not round-to-nearest. Verified in drawAepOtLine (0x10f98) and
// drawAepOtRect (0x1113c): vmul.f32 by the scale, then vcvt.s32.f32 with no bias.
static inline int aepScale(int c, float s) {
    return static_cast<int>(static_cast<float>(c) * s);
}

// Ghidra: pushAepOtTextCmd (FUN_0001154c) — queue a type-6 text command. The
// manager-level forwarders (FUN_00010540 / _1057c) reach it through
// AepManager::orderingTable(). nType=6 (+0x04, strh), nReserved8=0 (+0x08),
// strncpy(text, 256) into +0x0c with a forced NUL at +0x10b, the integer pen
// position at +0x10c/+0x110, the four corner colours at +0x114..+0x120, and the
// 16-byte clip vector at +0x124 (memcpy when supplied, else {0,0,screenW,screenH}
// with the extents read as int16 from ot+0x04/+0x08).
// @complete
void pushAepOtTextCmd(AepOrderingTable *ot,
                      const char *text,
                      int a0,
                      int a1,
                      int a2,
                      int a3,
                      int a4,
                      int a5,
                      const int *colorVec,
                      int priority) {
    AepTextCmd *cmd = reinterpret_cast<AepTextCmd *>(ot->allocEntry(priority));
    if (cmd == nullptr) {
        return;
    }
    cmd->nType = 6;                      // +0x04
    cmd->nReserved8 = 0;                 // +0x08
    std::strncpy(cmd->pText, text, 256); // +0x0c
    cmd->pText[255] = '\0';              // +0x10b force-terminate
    // The manager forwarders pass the integer pen position (a0/a1) and the four
    // per-corner colours (a2..a5); the binary stores the position as raw ints
    // (str, not vstr) — drawAepOtText converts them to float when it scales.
    cmd->nPosX = a0;    // +0x10c
    cmd->nPosY = a1;    // +0x110
    cmd->nColorTL = a2; // +0x114
    cmd->nColorTR = a3; // +0x118
    cmd->nColorBL = a4; // +0x11c
    cmd->nColorBR = a5; // +0x120
    if (colorVec != nullptr) {
        std::memcpy(cmd->pAClipVec, colorVec, 16); // +0x124 copy the 16-byte clip vector
    } else {
        cmd->pAClipVec[0] = 0; // default clip vector =
        cmd->pAClipVec[1] = 0; //   {0, 0, screenW, screenH}
        cmd->pAClipVec[2] =
            static_cast<int>(static_cast<int16_t>(ot->screenW())); // +0x12c (short in the binary)
        cmd->pAClipVec[3] = static_cast<int>(static_cast<int16_t>(ot->screenH())); // +0x130
    }
}

// Ghidra: AepOrderingTable::drawAepOtLine (FUN_00010f98).
// @complete
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
// @complete
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
// @complete
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
// @complete
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
// @complete
void AepOrderingTable::drawAepOtText(const char *text,
                                     const char *font,
                                     int x,
                                     int y,
                                     int size,
                                     int align,
                                     int alpha,
                                     const int *colorVec,
                                     uint32_t color) {
    const float s = renderScale();
    const int scaledSize = aepScale(size, s);
    // Real signature: neDrawText(text, font, size, x, y, align, alpha, r, g, b,
    // clipRect). The font is a C-string font name (a real 64-bit pointer — the
    // old int handle truncated it on arm64, producing a dead low address that
    // crashed strlen in neDrawText's font lookup) and colorVec is the clip rect.
    neDrawText(text,
               font,
               scaledSize,
               aepScale(x, s),
               aepScale(y, s),
               align,
               aepAlpha(alpha),
               aepColR(color),
               aepColG(color),
               aepColB(color),
               colorVec);
}

// Ghidra: drawAepSpriteClipped (FUN_00012020) — pick the active sub-frame, set
// its render state, and issue the clipped textured quad. The quad GEOMETRY is the
// destination rect (flDstX/Y/W/H); the colour comes from nColor (0x00RRGGBB) and
// the alpha from nAlpha (a 0..100 percentage); the UV is derived from the source
// rect (nSrcU/nSrcV/nWidth) against the sub-frame's width/height tables. The whole
// bl 0x15fb8 argument mapping was traced register-by-register from the
// disassembly (r0=&pTexRefArray[frameIdx], r1=flDstX->x, r2=flDstY->y,
// r3=flDstW->width, [sp]=flDstH->height, colour from nColor, alpha=nAlpha*255/100).
// @complete
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
                          float flPivotX,
                          float flPivotY,
                          int nAlpha,
                          float /*flParam14*/,
                          uint32_t nFlags,
                          const int *pClipRect,
                          int nUseClip,
                          uint32_t nColor) {
    // Sub-frame selection: walk the per-frame duration table (tileHeights),
    // subtracting each duration from the remaining time until it fits.
    int frameIdx = 0;
    int t = nFrameIn;
    const int frameCount = pFrames->tileCount();
    const int *durations = pFrames->tileHeights();
    const int *widths = pFrames->tileWidths();
    while (frameIdx < frameCount) {
        int d = durations[frameIdx];
        if (t <= d) {
            break;
        }
        t -= d;
        ++frameIdx;
    }

    // Rotation: reduce mod 360 and convert to radians with the negative-pi literal
    // (Ghidra: DAT_00012238 = -pi, /180). matrixSetRotateZ(-rotation) downstream
    // recovers the net direction.
    const int reduced = nRawAngle - (nRawAngle / 360) * 360;
    const float rotation = static_cast<float>(reduced) * static_cast<float>(-M_PI / 180.0);

    // Source rect -> normalized UV against the sub-frame's padded width/height. The
    // source origin is (nWidth, nFrameIn) and the span is (nSrcV x nSrcU); for a
    // full-image sprite these give u0=v0=0 and the span the fraction of the padded
    // atlas the image occupies (e.g. a 1536-wide image in a 2048 atlas -> 0.75).
    const int frameW = widths[frameIdx];
    const int frameH = durations[frameIdx];
    const float u0 = frameW ? static_cast<float>(nWidth) / static_cast<float>(frameW) : 0.0f;
    const float v0 = frameH ? static_cast<float>(nFrameIn) / static_cast<float>(frameH) : 0.0f;
    const float uSpan = frameW ? static_cast<float>(nSrcV) / static_cast<float>(frameW) : 1.0f;
    const float vSpan = frameH ? static_cast<float>(nSrcU) / static_cast<float>(frameH) : 1.0f;

    // Optional heap clip rect (Ghidra: operator new(0x10) of the fixed->float copy).
    // The rect is always non-null here: an explicitly-clipped sprite carries its own
    // rect, and an unclipped one carries the full screen bounds that drawSprite
    // defaults into the spill (matching the binary's aEntries[0].pAHeader screen
    // extents), so clipping to it is a whole-screen no-op.
    std::unique_ptr<float[]> clipRect;
    if (pClipRect != nullptr) {
        clipRect = std::make_unique<float[]>(4);
        for (int i = 0; i < 4; ++i) {
            clipRect[i] = static_cast<float>(pClipRect[i]);
        }
    }

    // Render-state slot for this sub-frame (slot 0/1 = clip enable). The tile
    // records are ne::C_SINGLE_SPRITE, which owns setRenderStateSlot directly.
    ne::C_SINGLE_SPRITE *slot = &pFrames->tileRects()[frameIdx];
    slot->setRenderStateSlot(0, nUseClip != 0 ? 1 : 0);
    slot->setRenderStateSlot(1, nUseClip != 0 ? 1 : 0);

    // Blend mode: bit 0x400 forces 2, else (nFlags & 0x3ff) >> 9.
    const int mode = (nFlags & 0x400) ? 2 : static_cast<int>((nFlags & 0x3ff) >> 9);

    // Colour: nColor is 0x00RRGGBB; alpha is the nAlpha percentage scaled to 0..255.
    const int red = static_cast<int>((nColor >> 16) & 0xff);
    const int green = static_cast<int>((nColor >> 8) & 0xff);
    const int blue = static_cast<int>(nColor & 0xff);
    const int alpha = nAlpha * 255 / 100;

    neDrawTexturedQuad(slot,
                       static_cast<int>(flDstX),
                       static_cast<int>(flDstY),
                       static_cast<int>(flDstW),
                       static_cast<int>(flDstH),
                       u0,
                       v0,
                       uSpan,
                       vSpan,
                       rotation,
                       static_cast<int>(flPivotX),
                       static_cast<int>(flPivotY),
                       alpha,
                       red,
                       green,
                       blue,
                       mode,
                       clipRect.get());
}

// Ghidra: drawAepOtSprite (FUN_00010c90) — resolve the slot's texture, gate on
// visibility (a fully-transparent, unrotated, unscaled sprite is culled) and
// forward to drawAepSpriteClipped with the sprite record's source rect and the
// scaled transform.
// @complete
void AepOrderingTable::drawAepOtSprite(const int16_t *spriteRec,
                                       int x,
                                       int y,
                                       int sx,
                                       int sy,
                                       int nOfsX,
                                       int nOfsY,
                                       int nColorA,
                                       uint32_t alpha,
                                       uint32_t blend,
                                       int modeFlags,
                                       const void *clip,
                                       int visFlag,
                                       int colorRGB,
                                       int slot) {
    const float s = renderScale();
    const int dstX = aepScale(x, s);
    const int dstY = aepScale(y, s);

    // Natural-scale flag (Ghidra's param_14==1 short-circuit): the binary clears
    // it when the sprite is at its natural 100% scale in both axes — scaled sx/sy
    // == 100.0 (DAT_00010e14) — with no blend bits set. Otherwise mask the alpha
    // by the sign of (modeFlags<<0x1a).
    bool visible = (visFlag != 0);
    if (visFlag == 1 && aepScale(sx, s) == 100 && aepScale(sy, s) == 100 && (blend & 0xffff) == 0) {
        visible = false;
    }
    uint32_t maskedAlpha =
        alpha &
        static_cast<uint32_t>((static_cast<int>(static_cast<uint32_t>(modeFlags) << 0x1a)) >> 0x1f);
    if (nColorA == 0 && maskedAlpha == 100) {
        return; // fully-opaque untinted no-op: nothing to composite
    }

    neTextureForiOS *frames = textureTable() ? textureTable()[slot] : nullptr;
    // spriteRec: +0 srcX, +2 srcY, +4 srcW, +6 srcH (the atlas source rect). The
    // quad geometry is the scaled destination rect; colour comes from colorRGB
    // and the tint level from nColorA. The tail of FUN_00010c90 emits four
    // `/DAT_00010e14 (=100.0)` divides, wired verbatim from the disassembly:
    //   flDstW = renderScale * sx * srcW / 100  (0x10dd4 vmul by srcW=spriteRec[2],
    //                                             0x10de8 vdiv) -> quad width
    //   flDstH = renderScale * sy * srcH / 100  (srcH=spriteRec[3], 0x10de4 vdiv)
    //   pivotX = renderScale * sx * nOfsX / 100  (0x10db8 vmul by nOfsX,
    //                                             0x10dc8 vdiv)
    //   pivotY = renderScale * sy * nOfsY / 100  (nOfsY, 0x10d86 vdiv)
    // The destination SIZE is the source-rect W/H (not nOfsX/nOfsY, which are the
    // pivot): a leaf sprite or drawAepFrame passes nOfsX=nOfsY=0, so sizing off
    // them would collapse the quad to zero and draw nothing.
    const float flDstW = static_cast<float>(spriteRec[2]) * s * static_cast<float>(sx) / 100.0f;
    const float flDstH = static_cast<float>(spriteRec[3]) * s * static_cast<float>(sy) / 100.0f;
    const float flPivotX = static_cast<float>(nOfsX) * s * static_cast<float>(sx) / 100.0f;
    const float flPivotY = static_cast<float>(nOfsY) * s * static_cast<float>(sy) / 100.0f;
    drawAepSpriteClipped(frames,
                         spriteRec[0],
                         spriteRec[1],
                         spriteRec[2],
                         spriteRec[3],
                         static_cast<float>(dstX),
                         static_cast<float>(dstY),
                         flDstW,
                         flDstH,
                         0,
                         flPivotX,
                         flPivotY,
                         nColorA,
                         static_cast<float>(maskedAlpha),
                         blend,
                         static_cast<const int *>(clip),
                         visible ? 1 : 0,
                         static_cast<uint32_t>(colorRGB));
}

// Ghidra: drawAepOtSpriteStretch (FUN_00010e18) — the stretched-sprite handler.
// Converts the fixed-point transform to float, scales by the half-screen device
// factor (hs = renderScale), computes the destination rect, and forwards to
// drawAepSpriteClipped. The parameter order matches the binary exactly: nScaleX/Y
// are the (int) screen position, nOfsX/Y the (float) scale percentages, nPosX/Y
// the base size, nAlpha the colour percentage and nColorRGB the 0x00RRGGBB colour.
// @complete
void AepOrderingTable::drawAepOtSpriteStretch(neTextureForiOS *pFrames,
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
                                              uint32_t nColorRGB) {
    (void)nColorA;
    const float hs = renderScale();
    const float ox = nOfsX * hs;
    const float oy = nOfsY * hs;

    // Visibility / clip gate: a plain (nBlendFlag==1) copy with zero scaled offsets
    // and an empty colour mask draws unclipped.
    int useClip = (nBlendFlag != 0) ? 1 : 0;
    if (nBlendFlag == 1 && ox == 0.0f && oy == 0.0f && (nColorA2 & 0xffff) == 0) {
        useClip = 0;
    }

    // bit5 of nBlendMask gates the colour-flags passthrough (100 = full multiply).
    const int colorFlags = (nBlendMask & 0x20) ? nColorFlags : 0;
    if (nAlpha == 0 && colorFlags == 100) {
        return;
    }

    // Destination rect: position scaled by hs; size = base * (scale%/100) * hs.
    const float flDstX = static_cast<float>(nScaleX) * hs;
    const float flDstY = static_cast<float>(nScaleY) * hs;
    const float flDstW = static_cast<float>(nPosX) * ox / 100.0f;
    const float flDstH = static_cast<float>(nPosY) * oy / 100.0f;

    NE_DBG(neDebugLog(
        "otStretch base=(%d,%d) scale=(%.2f,%.2f) hs=%.3f pos=(%d,%d) dst=(%.1f,%.1f,%.1f,%.1f) "
        "src=(u=%d v=%d) alpha=%d blendFlag=%d",
        nPosX,
        nPosY,
        static_cast<double>(nOfsX),
        static_cast<double>(nOfsY),
        static_cast<double>(hs),
        nScaleX,
        nScaleY,
        static_cast<double>(flDstX),
        static_cast<double>(flDstY),
        static_cast<double>(flDstW),
        static_cast<double>(flDstH),
        nU,
        nV,
        nAlpha,
        nBlendFlag));

    drawAepSpriteClipped(pFrames,
                         nU,
                         nV,
                         nPosX,
                         nPosY,
                         flDstX,
                         flDstY,
                         flDstW,
                         flDstH,
                         static_cast<int>(nColorA2),
                         flDstX,
                         flDstY,
                         nAlpha,
                         static_cast<float>(nColorMul),
                         nBlendMask,
                         pClipRect,
                         useClip,
                         nColorRGB);
}
