//
//  AepFrameDraw.mm
//  pop'n rhythmin
//
//  TRUE 1:1 reconstruction of the Aep animated frame-tree renderer from Ghidra
//  project rb420, program PopnRhythmin. The core is FUN_0000fe8c
//  (AepDrawLayer): it walks a layer's frame-entry chain and, for every entry
//  active on the current frame, interpolates each keyframe channel in the
//  engine's integer fixed point, composes the parent transform + colour/alpha +
//  rotation + blend flags, clips to the active clip rect and emits.
//
//  Fixed-point notes (byte-verified):
//    * `x * 0x51eb851f >> 0x20` (and the `>> 0x25` variant) is a /100
//    reciprocal
//      multiply; reproduced here as C integer `/ 100` (both truncate toward
//      zero).
//    * rotation uses `x * 0x80008001 >> 47` (spelled `* -0x7fff7fff + (x<<32)
//    >> 32`
//      then `>>15`) which normalises by 0xffff, i.e. cos/sin are fixed with 1.0
//      == 0xffff. Reproduced faithfully in aepRotNorm().
//

#import "AepFrameDraw.h"
#import "AepManager.h"
#import "AepOrderingTable.h"
#import "neDebugLog.h"

#include <cmath>
#include <cstring>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Ghidra: FUN_0001234c (cos) / FUN_0001228c (sin). The originals reduce the
// angle to [0,360) at 1/3-degree granularity (index = angle*3 mod 0x438) and
// fold a quarter- wave lookup table @ DAT_0012ded2 whose entries are
// ~round(sin*0xffff) (byte-verified: table[1] == 0x017d == round(sin(1/3
// deg)*0xffff)). The LUT itself is a data seam; the same value is produced here
// at the identical 1.0 == 0xffff fixed scale.
// @complete
static int aepSin(int deg) {
    return (int)std::lround(std::sin((double)deg * (M_PI / 180.0)) * 65535.0);
}
// @complete
static int aepCos(int deg) {
    return (int)std::lround(std::cos((double)deg * (M_PI / 180.0)) * 65535.0);
}

// Normalise a fixed-point product back to pixels. Ghidra: the exact sequence is
//   m  = (int)((long long)v * -0x7fff7fff + ((u64)(u32)v << 32) >> 32);   // v
//   * 0x80008001 >> 32 r  = (m >> 15) - (m >> 31); // /0x8000, round toward
//   zero
// whose net effect is v / 0xffff (matching cos/sin's 1.0 == 0xffff scale).
// @complete
static inline int aepRotNorm(int v) {
    long long prod =
        (long long)v * (long long)(-0x7fff7fffLL) + ((unsigned long long)(unsigned)v << 32);
    int m = (int)(prod >> 32);
    return (m >> 15) - (m >> 31);
}

// Walk a keyframe channel to the pair bracketing `frame`. Each keyframe is
// `stride` int16s wide; the list is terminated by frame == -1. Returns prev
// (last keyframe with frame <= target, or the first) and cur (the following
// keyframe / terminator), reproducing FUN_0000fe8c's per-channel bracket
// search.
// @complete
static void
aepBracket(const int16_t *keys, int stride, int frame, const int16_t **prev, const int16_t **cur) {
    const int16_t *p = keys;
    const int16_t *c = keys;
    while (c[0] != -1 && c[0] <= frame) {
        p = c;
        c += stride;
    }
    *prev = p;
    *cur = c;
}

// Ghidra: FUN_00010850 — build the child's clip rectangle {x, y, w, h}
// (out[0..3]) from the group's screen extents (this+0x7f3afc / +0x7f3b00), the
// entry's anchor (entry+0x10 / +0x12), the composed scale and the rotation.
// Axis-aligned when the rotation is zero; otherwise the min/max of the four
// rotated corners.
// @complete
static void aepComputeChildClip(AepManager *mgr,
                                const AepFrameEntry *e,
                                int x,
                                int y,
                                int scaleX,
                                int scaleY,
                                int rotation,
                                int *out) {
    const int anchorX = e->anchorX;
    const int anchorY = e->anchorY;
    int screenW = mgr->screenWidth();  // this+0x7f3afc
    int screenH = mgr->screenHeight(); // this+0x7f3b00

    if ((rotation & 0xffff) == 0) {
        // Axis-aligned. The screen span grows when the (anchor-relative) origin is
        // negative; a negative scale mirrors the quad, shifting its origin left/up.
        int py = y - (anchorY * scaleY) / 100;
        int px = x - (anchorX * scaleX) / 100;
        if (py < 0) {
            screenH -= py;
        }
        if (px < 0) {
            screenW -= px;
        }

        int16_t clipX = (int16_t)px;
        if (scaleX < 0) {
            int w = (screenW * -scaleX) / 100;
            out[2] = w;
            clipX = (int16_t)(clipX - w);
        } else {
            out[2] = (screenW * scaleX) / 100;
        }
        out[0] = clipX;

        if (scaleY < 0) {
            int h = (screenH * -scaleY) / 100;
            py -= h;
            out[3] = h;
        } else {
            out[3] = (screenH * scaleY) / 100;
        }
        out[1] = (int16_t)py;
        return;
    }

    // Rotated: transform the four corners and take their bounding box. The two
    // edge extents are the anchor-relative left/top and right/bottom, each grown
    // for a negative-scale mirror exactly as the binary does.
    int left = (-anchorX * scaleX) / 100;
    int right = screenW - anchorX;
    if (-anchorX * scaleX < -99) {
        right -= left;
    }
    right = (right * scaleX) / 100;

    int top = (-anchorY * scaleY) / 100;
    int bottom = screenH - anchorY;
    if (-anchorY * scaleY < -99) {
        bottom -= top;
    }
    bottom = (bottom * scaleY) / 100;

    const int C = aepCos(rotation);
    const int S = aepSin(rotation);
    const int cornerX[4] = {left, left, right, right};
    const int cornerY[4] = {top, bottom, top, bottom};

    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (int i = 0; i < 4; i++) {
        int rx = aepRotNorm(cornerX[i] * C - cornerY[i] * S);
        int ry = aepRotNorm(cornerX[i] * S + cornerY[i] * C);
        if (i == 0 || rx < minX) {
            minX = rx;
        }
        if (i == 0 || rx > maxX) {
            maxX = rx;
        }
        if (i == 0 || ry < minY) {
            minY = ry;
        }
        if (i == 0 || ry > maxY) {
            maxY = ry;
        }
    }
    out[0] = x + minX;
    out[1] = y + minY;
    out[2] = (maxX - minX) + 1;
    out[3] = (maxY - minY) + 1;
}

// Ghidra: FUN_000113d0 (-> allocEntry FUN_00010be0) — reserve an ordering-table
// command at `priority` and fill the textured-quad payload. Field offsets are
// the binary's; the AepOtSpriteCmd slots at +0x2c..+0x3c carry colour/alpha,
// the packed rotation/blend words and the two user words, so they are written
// by their offset meaning (the field names carry the sprite-command roles).
// @complete
static void aepEmitSprite(AepManager *mgr,
                          int groupSlot,
                          int child,
                          int x,
                          int y,
                          int scaleX,
                          int scaleY,
                          int w,
                          int h,
                          int color,
                          int alpha,
                          int rotation,
                          uint32_t blend,
                          int *clipRect,
                          uint32_t priority,
                          uint32_t colorRGB,
                          uint32_t visFlag) {
    AepOrderingTable *ot = mgr->orderingTable();                      // this+0x727538
    AepOtSpriteCmd *cmd = ot->allocEntry(static_cast<int>(priority)); // FUN_00010be0
    if (cmd == nullptr) {
        return;
    }
    const int16_t *rec = mgr->spriteRecord(groupSlot, child); // this+slot*0x2000+child*8+0x7c1962

    NE_DBG(neDebugLog("aepEmit slot=%d child=%d scale=(%d,%d) wh=(%d,%d) pos=(%d,%d) "
                      "color=%d alpha=%d rec=(%d,%d,%d,%d)",
                      groupSlot,
                      child,
                      scaleX,
                      scaleY,
                      w,
                      h,
                      x,
                      y,
                      color,
                      alpha,
                      rec[0],
                      rec[1],
                      rec[2],
                      rec[3]));

    cmd->wFlags = 0;        // +0x04  type 0 = textured sprite
    cmd->nBank = groupSlot; // +0x08  (flush case 0 forwards this as the texture slot)
    // The binary copies the 8-byte sprite record verbatim into the nTexU/nTexV
    // slots; the flush reads them back as the u/v/w/h source-rect shorts (srcRect).
    std::memcpy(cmd->srcRect, rec, 8); // +0x0c..+0x13
    cmd->nPosX = x;                    // +0x14
    cmd->nPosY = y;                    // +0x18
    // The binary converts the integer scale to float (FixedToFP, 16.16) here; the
    // flush reads (int)flPosXf back out as the percentage scale.
    cmd->flPosXfF = static_cast<float>(scaleX); // +0x1c float view (case-0 vldr)
    cmd->flPosYfF = static_cast<float>(scaleY); // +0x20 float view (case-0 vldr)
    cmd->nOfsX = w;                             // +0x24  (entry anchorX doubles as width)
    cmd->nOfsY = h;                             // +0x28  int view (entry anchorY doubles as height)
    cmd->nColorA = color;                       // +0x2c  int view: colour (brightness) 0..100
    cmd->nColorMul = alpha;                     // +0x30  alpha 0..100 (see the >=100 split)
    cmd->nUKey = static_cast<int16_t>(rotation);  // +0x34  packed rotation word
    cmd->nVKey = static_cast<int16_t>(blend);     // +0x36  packed blend word
    cmd->nBlendFlags = static_cast<int>(visFlag); // +0x38  visibility/natural-scale flag (param_19)
    cmd->nColorRGB = static_cast<int>(colorRGB);  // +0x3c  packed 0x00RRGGBB colour (param_15)
    if (clipRect != nullptr) {
        cmd->clipRect.nLeft = clipRect[0];
        cmd->clipRect.nTop = clipRect[1];
        cmd->clipRect.nRight = clipRect[2];
        cmd->clipRect.nBottom = clipRect[3];
    } else {
        // Default: the full screen quad (the binary reads the OT's cached bounds at
        // its +0x4/+0x8; here the manager's screen extents give the same rect).
        cmd->clipRect.nLeft = 0;
        cmd->clipRect.nTop = 0;
        cmd->clipRect.nRight = mgr->screenWidth();
        cmd->clipRect.nBottom = mgr->screenHeight();
    }
}

// Ghidra: FUN_0000fcd0 — the note-quad wrapper. It resolves the sprite's group
// slot from the handle's high 16 bits (the byte group table @ +0x7c1748) and
// its record from the low 16 bits, then hands both to the sprite-command fill
// FUN_000113d0. Here the record lookup is folded into aepEmitSprite(slot,
// child); `anchorX`/`anchorY` become the quad width/height (the entry anchor
// doubles as size for a leaf), `colorMul` rides the colorRGB slot. Exact
// float-vs-int arg positions in the original are VFP-ABI obscured; the
// call-site value threading is reproduced.
// @complete
void AepDrawSpriteHandle(AepManager *mgr,
                         int handle,
                         int x,
                         int y,
                         int scaleX,
                         int scaleY,
                         int rotation,
                         int anchorX,
                         int anchorY,
                         int color,
                         int alpha,
                         uint32_t blend,
                         uint32_t colorMul,
                         int *clipRect,
                         int priority,
                         uint32_t visFlag) {
    const int groupSlot = mgr->groupSlotForHandle(handle); // (handle >> 16) -> slot byte
    const int child = handle & 0xffff;                     // low 16 bits = record index
    aepEmitSprite(mgr,
                  groupSlot,
                  child,
                  x,
                  y,
                  scaleX,
                  scaleY,
                  anchorX,
                  anchorY,
                  color,
                  alpha,
                  rotation,
                  blend,
                  clipRect,
                  static_cast<uint32_t>(priority),
                  colorMul,
                  visFlag);
}

// Ghidra: FUN_0000fe8c. The 19-argument frame-tree fill.
// @complete
void AepDrawLayer(AepManager *mgr,
                  int groupSlot,
                  int layerNo,
                  int frame,
                  int x,
                  int y,
                  int scaleX,
                  int scaleY,
                  int anchorX,
                  int anchorY,
                  int color,
                  int colorHi,
                  uint32_t rotation,
                  uint32_t blendFlags,
                  uint32_t colorRGB,
                  int *clipRect,
                  uint32_t priority,
                  void *context,
                  uint32_t visFlag) {
    const AepFrameEntry *entries = mgr->frameEntries(groupSlot); // this+slot*4+0x7f39c8
    if (entries == nullptr || entries[layerNo].type < 0) {
        return;
    }
    NE_DBG(neDebugLog("aepLayer slot=%d layerNo=%d frame=%d scale=(%d,%d) pos=(%d,%d) "
                      "type0=%d scaleCh=%d",
                      groupSlot,
                      layerNo,
                      frame,
                      scaleX,
                      scaleY,
                      x,
                      y,
                      entries[layerNo].type,
                      entries[layerNo].scaleChannel));
    const uint8_t *chBase = mgr->channelBase(groupSlot); // this+slot*4+0x7274d4

    // Anchor-relative base translation, pre-scaled (Ghidra: iVar6 / iVar5).
    const int baseX = -(scaleX * anchorX) / 100;
    const int baseY = -(scaleY * anchorY) / 100;
    const int16_t combinedHi = (int16_t)(colorHi + color); // sVar4

    for (const AepFrameEntry *e = &entries[layerNo]; e->type >= 0; e++) {
        if (frame < e->frameStart || frame >= e->frameEnd) {
            continue; // entry not active on this frame
        }

        // --- Position channel (entry+0x14, keyframe stride 4 int16: frame,x,y,_)
        // ---
        int posX = baseX;
        int posY = baseY;
        if (e->posChannel != 0) {
            const int16_t *keys = (const int16_t *)(chBase + e->posChannel);
            const int16_t *prev, *cur;
            aepBracket(keys, 4, frame, &prev, &cur);
            if (prev[0] != -1) {
                if (cur == prev || cur[0] == -1) { // hold prev
                    posX = baseX + (scaleX * prev[1]) / 100;
                    posY = baseY + (scaleY * prev[2]) / 100;
                } else { // lerp prev..cur
                    int denom = cur[0] - prev[0];
                    int dx = (frame - prev[0]) * (cur[1] - prev[1]) / denom;
                    int dy = (frame - prev[0]) * (cur[2] - prev[2]) / denom;
                    posX = baseX + (scaleX * (dx + prev[1])) / 100;
                    posY = baseY + (scaleY * (dy + prev[2])) / 100;
                }
            }
        }

        // --- Rotation of the composed offset by the incoming base rotation ---
        int px = posX;
        int py = posY;
        if ((rotation & 0xffff) != 0) {
            int C = aepCos((int)rotation);
            int S = aepSin((int)rotation);
            px = aepRotNorm(posX * C - posY * S);
            py = aepRotNorm(posX * S + posY * C);
        }

        // --- Rotation channel (entry+0x20, DOUBLE-indirect; stride 2: frame,angle)
        // --- childRotation accumulates the incoming rotation plus this entry's
        // animated angle, sign-flipped once per mirrored (negative) scale axis.
        uint32_t childRotation = rotation;
        if (e->rotChannel != 0) {
            int inner = *(const int32_t *)(chBase + e->rotChannel);
            if (inner != 0) {
                const int16_t *keys = (const int16_t *)(chBase + inner);
                const int16_t *prev, *cur;
                aepBracket(keys, 2, frame, &prev, &cur);
                if (prev[0] >= 0) {
                    int a;
                    if (cur == prev || cur[0] < 0) {
                        a = (uint16_t)prev[1];
                    } else {
                        a = (int)(short)prev[1] +
                            (frame - prev[0]) * (cur[1] - prev[1]) / (cur[0] - prev[0]);
                    }
                    if ((unsigned)scaleX > 0x7fffffff) {
                        a = -(a & 0xffff);
                    }
                    if ((unsigned)scaleY > 0x7fffffff) {
                        a = -(a & 0xffff);
                    }
                    childRotation = (rotation & 0xffff) + (a & 0xffff);
                }
            }
        }

        // --- Scale channel (entry+0x18, stride 4 int16: frame,sx,sy,_) ---
        int outSx = scaleX;
        int outSy = scaleY;
        if (e->scaleChannel != 0) {
            const int16_t *keys = (const int16_t *)(chBase + e->scaleChannel);
            const int16_t *prev, *cur;
            aepBracket(keys, 4, frame, &prev, &cur);
            int16_t sx, sy;
            if (prev[0] < 0) {
                sx = 100;
                sy = 100;
            } else if (cur == prev) {
                sx = prev[1];
                sy = prev[2];
            } else if (cur[0] < 0) { // hold prev
                sx = prev[1];
                sy = prev[2];
            } else { // lerp
                int denom = cur[0] - prev[0];
                sx = (int16_t)(prev[1] + (frame - prev[0]) * (cur[1] - prev[1]) / denom);
                sy = (int16_t)(prev[2] + (frame - prev[0]) * (cur[2] - prev[2]) / denom);
            }
            outSx = (scaleX * (int)sx) / 100;
            outSy = (scaleY * (int)sy) / 100;
        }

        // --- Colour / alpha channel (entry+0x1c, stride 2: frame,
        // packed[lo=colour, hi=alpha]) ---
        int colorVal = color;     // low channel (brightness)
        int highVal = combinedHi; // high channel (colour+alpha accumulator)
        if (e->colorChannel != 0) {
            const int16_t *keys = (const int16_t *)(chBase + e->colorChannel);
            const int16_t *prev, *cur;
            aepBracket(keys, 2, frame, &prev, &cur);
            if (prev[0] >= 0) {
                int pLo = (int8_t)(prev[1] & 0xff);
                int pHi = (int8_t)((prev[1] >> 8) & 0xff);
                int v0, v1; // v0 = colour, v1 = colour+alpha
                if (cur == prev || cur[0] < 0) {
                    v0 = pLo;
                    v1 = pLo + pHi;
                } else {
                    int cLo = (int8_t)(cur[1] & 0xff);
                    int cHi = (int8_t)((cur[1] >> 8) & 0xff);
                    int denom = cur[0] - prev[0];
                    int pSum = pLo + pHi;
                    v0 = pLo + (frame - prev[0]) * (cLo - pLo) / denom;
                    v1 = pSum + (frame - prev[0]) * ((cLo + cHi) - pSum) / denom;
                }
                colorVal = (color * v0) / 100;
                if (colorHi + color <= 100) {
                    highVal = (int16_t)((combinedHi * v1) / 100);
                } else {
                    highVal = colorHi + colorVal;
                }
            }
        }

        // --- Compose translation, blend flags and the >=100 alpha split ---
        int drawX = px + x;
        int drawY = py + y;
        int finalSx = (int16_t)outSx;
        int finalSy = (int16_t)outSy;
        int alpha = highVal - colorVal;

        uint32_t entryBlend = (uint16_t)e->blendFlags; // entry+0x04
        uint32_t bf = blendFlags;
        if (colorVal != 100 || highVal != 100) {
            bf = (entryBlend & 0x30) | blendFlags;
        }
        uint32_t blend = (bf | (entryBlend & 0x400)) ^ (entryBlend & 0xc0);
        if (alpha >= 100) { // byte-verified: cmp #0x64, sub.ge, orr.ge #0x200
            alpha -= 100;
            blend |= 0x200;
        }

        const int childRotArg = (int)(int16_t)childRotation;

        if (e->type == 2 || e->type == 3) {
            // Group / nested layer: build and intersect the child clip rect, and only
            // recurse/dispatch when something remains visible.
            int childClip[4];
            aepComputeChildClip(mgr, e, drawX, drawY, finalSx, finalSy, childRotArg, childClip);

            int cx = clipRect[0];
            if (childClip[0] < cx) {
                childClip[2] += (childClip[0] - cx);
                childClip[0] = cx;
            }
            if (cx + clipRect[2] < childClip[2] + childClip[0]) {
                childClip[2] = (int16_t)((cx + clipRect[2]) - childClip[0]);
            }
            int cy = clipRect[1];
            if (childClip[1] < cy) {
                childClip[3] += (childClip[1] - cy);
                childClip[1] = cy;
            }
            if (cy + clipRect[3] < childClip[3] + childClip[1]) {
                childClip[3] = (int16_t)((cy + clipRect[3]) - childClip[1]);
            }
            int vis = childClip[2];
            if (childClip[2] > 0) {
                vis = childClip[3];
            }
            if (vis > 0) {
                int childFrame = (frame - e->frameStart) + e->loopOffset;
                if (e->frameSpeed > 0) {
                    childFrame = childFrame * 100 / e->frameSpeed;
                }
                if (e->type == 2) {
                    AepDrawLayer(mgr,
                                 groupSlot,
                                 e->child,
                                 childFrame,
                                 drawX,
                                 drawY,
                                 finalSx,
                                 finalSy,
                                 e->anchorX,
                                 e->anchorY,
                                 colorVal,
                                 alpha,
                                 childRotation,
                                 blend,
                                 colorRGB,
                                 childClip,
                                 priority,
                                 context,
                                 visFlag);
                } else {
                    AepGroupDrawFn cb = mgr->groupCallback(groupSlot); // this+slot*4+0x7f3a2c
                    if (cb != nullptr) {
                        void *ctx = context;
                        if (ctx == nullptr) {
                            ctx = mgr->groupContext(groupSlot); // this+slot*4+0x7f3a90
                        }
                        cb(e->child,
                           childFrame,
                           drawX,
                           drawY,
                           finalSx,
                           finalSy,
                           e->anchorX,
                           e->anchorY,
                           colorVal,
                           alpha,
                           childRotArg,
                           blend,
                           childClip,
                           priority,
                           ctx);
                    }
                }
            }
        } else if (e->type == 0) {
            // Leaf sprite command.
            aepEmitSprite(mgr,
                          groupSlot,
                          e->child,
                          drawX,
                          drawY,
                          finalSx,
                          finalSy,
                          e->anchorX,
                          e->anchorY,
                          colorVal,
                          alpha,
                          childRotArg,
                          blend,
                          clipRect,
                          priority,
                          colorRGB,
                          visFlag);
        }
        // type 1 (and any other): no emission (matches FUN_0000fe8c).
    }
}

// Ghidra: drawAepFrame (FUN_0000fc58). Resolve the handle's group slot (the
// byte group table @ +0x7c1748) and its sprite record (low 16 bits), then queue
// a full-scale, opaque sprite command. The binary passes 100.0f scale, colour
// 100, alpha 0, no rotation and the full-screen clip sentinel; those map onto
// aepEmitSprite's integer-percentage form.
// @complete
void drawAepFrame(AepManager *mgr, int id, int x, int y, uint32_t blend, uint32_t priority) {
    const int groupSlot = mgr->groupSlotForHandle(id); // (id >> 16) -> slot byte
    const int child = id & 0xffff;                     // low 16 bits = record index
    aepEmitSprite(mgr,
                  groupSlot,
                  child,
                  x,
                  y,
                  /*scaleX*/ 100,
                  /*scaleY*/ 100,
                  /*w*/ 0,
                  /*h*/ 0,
                  /*color*/ 100,
                  /*alpha*/ 0,
                  /*rotation*/ 0,
                  blend,
                  /*clipRect*/ nullptr,
                  priority,
                  /*colorRGB*/ 0,
                  /*visFlag*/ 0);
}
