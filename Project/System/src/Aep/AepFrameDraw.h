//
//  AepFrameDraw.h
//  pop'n rhythmin
//
//  The Aep animated frame-tree renderer. For the current frame it walks a layer's
//  frame-entry chain, interpolates every keyframe channel (position, scale, colour/
//  alpha, rotation) in the engine's integer fixed-point form, composes the parent
//  transform + blend flags, clips against the active clip rect, and then per entry
//  type emits a sprite command into the ordering table, recurses into a child layer,
//  or invokes the group draw callback.
//
//  TRUE 1:1 reconstruction from Ghidra project rb420, program PopnRhythmin:
//    drawFrameData / AepDrawLayer  FUN_0000fe8c  (the core)
//    drawLayer                     FUN_0000fd64  (frame clamp/loop + dispatch)
//    child clip-rect builder       FUN_00010850
//    cos / sin                     FUN_0001234c / FUN_0001228c (1/3-degree LUT @ DAT_0012ded2)
//    sprite command fill           FUN_000113d0  (-> allocEntry FUN_00010be0)
//

#pragma once

#include <cstdint>

class AepManager;

// The per-frame group draw callback the play/result/sugoroku scenes install
// (Ghidra: called through this+slot*4+0x7f3a2c inside FUN_0000fe8c). Its real ABI
// takes the fully-composed child transform. Scenes that only need the context still
// install a `void(*)(void*)`; AepManager stores it as this wider type and the two
// forms share the same first (or, via the context slot, only) argument.
using AepGroupDrawFn = void (*)(int child, int frame, int x, int y, int scaleX, int scaleY,
                                int anchorX, int anchorY, int color, int alpha, int rotation,
                                uint32_t blend, int *clipRect, uint32_t p17, void *context);

// One 36-byte frame-data entry (Ghidra: stride 0x24). Each entry animates one child
// over the frame range [frameStart, frameEnd); `type` selects how it emits. The four
// channel fields hold BYTE OFFSETS into the group's idx buffer (0 = channel absent);
// AepDrawLayer resolves them against AepManager::channelBase() (Ghidra: the pointer
// at this+groupSlot*4+0x7274d4).
struct AepFrameEntry {
    int16_t type;         // +0x00  0 = leaf sprite, 2 = nested layer, 3 = group callback
    int16_t child;        // +0x02  sprite record / sub-layer index
    int16_t blendFlags;   // +0x04  per-entry blend bits (0x30 / 0xc0 / 0x400 composed at draw)
    int16_t frameSpeed;   // +0x06  child frame remap divisor (>0 => childFrame = local*100/frameSpeed)
    int16_t frameStart;   // +0x08
    int16_t frameEnd;     // +0x0a
    int16_t loopOffset;   // +0x0c  added to the child's local frame
    int16_t reserved0e;   // +0x0e
    int16_t anchorX;      // +0x10  pivot X (child arg9); doubles as the sprite width for a leaf
    int16_t anchorY;      // +0x12  pivot Y (child arg10); doubles as the sprite height for a leaf
    int32_t posChannel;   // +0x14  x/y keyframes (offset into the idx buffer, 0 = none)
    int32_t scaleChannel; // +0x18  sx/sy keyframes
    int32_t colorChannel; // +0x1c  colour/alpha keyframes
    int32_t rotChannel;   // +0x20  rotation keyframes (double-indirect: *(int*)(base+rotChannel) + base)
};

// A resolved 2D transform threaded into the compatibility drawLayer overload.
struct AepTransform {
    float x = 0, y = 0;       // translation
    float sx = 100, sy = 100; // scale (percent)
    float rotation = 0;       // degrees
    int priority = 0;         // ordering-table priority
};

// Draw one already-resolved sprite handle (a note / effect / digit atlas quad) straight
// into the ordering table. `handle` encodes the resource group in bits 16.. (indexing
// AepManager::groupSlotForHandle) and the 8-byte sprite record in bits 0..15. The
// remaining args are the composed transform / anchor / colour / alpha / rotation / blend
// / clip the play + result per-frame draw passes thread in per sprite. Ghidra: the
// note-quad wrapper FUN_0000fcd0 (-> the sprite-command fill FUN_000113d0). Arg order
// follows the call sites; the leading duplicate scale word the VFP ABI emits is dropped.
void AepDrawSpriteHandle(AepManager *mgr, int handle, int x, int y, int scaleX, int scaleY,
                         int rotation, int anchorX, int anchorY, int color, int alpha,
                         uint32_t blend, uint32_t colorMul, int *clipRect, int priority,
                         uint32_t p19);

// Draw a single sprite-atlas frame by its packed handle with a default (100%, opaque,
// unrotated, un-clipped) transform straight into the ordering table. `id` encodes the
// resource group in bits 16.. and the 8-byte sprite record in bits 0..15; `x`/`y` are the
// screen position, `blend` the blend word and `priority` the ordering-table priority. This
// is the simplified sibling of AepDrawSpriteHandle used by the difficulty-frame / badge UI
// draws. Ghidra: drawAepFrame (FUN_0000fc58 -> the sprite-command fill FUN_000113d0).
void drawAepFrame(AepManager *mgr, int id, int x, int y, uint32_t blend, uint32_t priority);

// The faithful full-signature core (Ghidra: FUN_0000fe8c). `mgr`/`groupSlot` locate
// the frame-entry array, channel buffer, sprite records, ordering table, group
// callback and screen extents; the remaining args are the composed parent transform,
// colour/alpha, rotation, blend flags and clip rect threaded down the frame tree.
// (Arg order matches the binary's 19-parameter call exactly.)
void AepDrawLayer(AepManager *mgr, int groupSlot, int layerNo, int frame,
                  int x, int y, int scaleX, int scaleY, int p9, int p10,
                  int color, int colorHi, uint32_t rotation, uint32_t blendFlags,
                  uint32_t p15, int *clipRect, uint32_t p17, void *context, uint32_t p19);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
