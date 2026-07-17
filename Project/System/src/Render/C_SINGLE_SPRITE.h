//
//  C_SINGLE_SPRITE.h
//  pop'n rhythmin
//
//  ne::C_SINGLE_SPRITE — a single sprite / texture tile: a refcounted bound
//  texture plus four metadata ints (the two per-frame render-state slots and the
//  tile's default 7x7 span). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (RTTI N2ne15C_SINGLE_SPRITEE; vtable @0x130884, ctor
//  FUN_00015eb4, dtor FUN_00015edc, deleting dtor FUN_00015f00). neTextureFrames
//  stores these contiguously as its per-frame records, and a neTextureForiOS
//  keeps one per split-image tile.
//

#pragma once

#include <cstdint>
#include <memory>

class AepTexture;

namespace ne {

// ne::C_SINGLE_SPRITE (RTTI N2ne15C_SINGLE_SPRITEE). A polymorphic single-sprite
// record filling a 0x18-byte slot: +0x04 the bound texture (a refcounted
// C_TEXTURE, released on destroy) and +0x08..+0x17 four metadata ints —
// meta[0]/meta[1] are the per-frame render-state slots the draw path sets,
// meta[2]/meta[3] the tile span (ctor default {0, 0, 7, 7}).
class C_SINGLE_SPRITE {
public:
    C_SINGLE_SPRITE();          // Ghidra: FUN_00015eb4
    virtual ~C_SINGLE_SPRITE(); // Ghidra: FUN_00015edc (+ deleting dtor FUN_00015f00)

    // Set a per-frame render-state slot (0 = blend/opaque select, 1 = clipped
    // flag) to `value`; stored in meta[slot]. Ghidra: FUN_00016710, called from
    // the AepSprite draw path (drawAepSpriteClipped) on each frame's sprite.
    void setRenderStateSlot(int slot, int value); // @ 0x16710

    AepTexture *texture = nullptr;  // +0x04 bound texture (refcounted C_TEXTURE)
    int32_t meta[4] = {0, 0, 7, 7}; // +0x08..+0x17 render-state slots / tile span
};

} // namespace ne

// A set of animation frames: parallel heap arrays (all `frameCount` long) of
// per-frame padded texture size, the cached AepTexture handles and the
// C_SINGLE_SPRITE records. Each array is owned (RAII); the handles are
// additionally cache-released in the destructor. Ghidra: dtor FUN_00011838.
class neTextureFrames {
public:
    virtual ~neTextureFrames(); // Ghidra: FUN_00011838 (+ compiler-emitted
                                // deleting dtor FUN_0001198c)

    int32_t frameCount = 0;                        // +0x04
    std::unique_ptr<int32_t[]> frameWidths;        // +0x08
    std::unique_ptr<int32_t[]> frameHeights;       // +0x0c
    std::unique_ptr<void *[]> handles;             // +0x10 AepTexture*[] (each cache-released)
    std::unique_ptr<ne::C_SINGLE_SPRITE[]> frames; // +0x14
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
