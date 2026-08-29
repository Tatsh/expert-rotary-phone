/**
 * @file
 * @brief ne::C_SINGLE_SPRITE, a single sprite or texture tile.
 *
 * It is a refcounted bound texture plus four metadata ints (the two per-frame render-state slots
 * and the tile's default 7x7 span).
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (RTTI N2ne15C_SINGLE_SPRITEE;
 * vtable @ 0x130884, constructor FUN_00015eb4, destructor FUN_00015edc, deleting destructor
 * FUN_00015f00). neTextureFrames stores these contiguously as its per-frame records, and a
 * neTextureForiOS keeps one per split-image tile.
 */

#pragma once

#include <cstdint>
#include <memory>

namespace ne {
class C_TEXTURE;
}

namespace ne {

/**
 * @brief A polymorphic single-sprite record filling a 0x18-byte slot.
 *
 * +0x04 is the bound texture (a refcounted C_TEXTURE, released on destroy) and +0x08..+0x17 are
 * four metadata ints: meta[0] and meta[1] are the per-frame render-state slots the draw path sets,
 * meta[2] and meta[3] the tile span (the constructor defaults them to {0, 0, 7, 7}). RTTI
 * N2ne15C_SINGLE_SPRITEE.
 */
class C_SINGLE_SPRITE {
public:
    /**
     * @brief Construct an unbound sprite with the default {0, 0, 7, 7} metadata.
     * @ghidraAddress 0x15eb4
     */
    C_SINGLE_SPRITE();
    /**
     * @brief Release the bound texture. The deleting destructor is FUN_00015f00.
     * @ghidraAddress 0x15edc
     */
    virtual ~C_SINGLE_SPRITE();

    /**
     * @brief Set a per-frame render-state slot, stored in meta[slot].
     *
     * Called from the AepSprite draw path (drawAepSpriteClipped) on each frame's sprite.
     * @param slot 0 for the blend/opaque select, 1 for the clipped flag.
     * @param value The value to store.
     * @ghidraAddress 0x16710
     */
    void setRenderStateSlot(int slot, int value);

    /** +0x04 The bound texture, a refcounted ne::C_TEXTURE. */
    ne::C_TEXTURE *texture = nullptr;
    /** +0x08..+0x17 Render-state slots (0, 1) and tile span (2, 3). */
    int32_t meta[4] = {0, 0, 7, 7};
};

} // namespace ne

/**
 * @brief A set of animation frames: parallel heap arrays, all frameCount long, of the per-frame
 * padded texture size, the cached ne::C_TEXTURE handles and the ne::C_SINGLE_SPRITE records.
 *
 * Each array is owned (RAII); the handles are additionally cache-released in the destructor.
 */
class neTextureFrames {
public:
    /**
     * @brief Cache-release every texture handle and free the parallel arrays. The
     * compiler-emitted deleting destructor is FUN_0001198c.
     * @ghidraAddress 0x11838
     */
    virtual ~neTextureFrames();

    int32_t frameCount = 0;                  /**< +0x04 The number of frames in each array. */
    std::unique_ptr<int32_t[]> frameWidths;  /**< +0x08 Per-frame padded texture width. */
    std::unique_ptr<int32_t[]> frameHeights; /**< +0x0c Per-frame padded texture height. */
    /** +0x10 Per-frame ne::C_TEXTURE*, each cache-released on destroy. */
    std::unique_ptr<void *[]> handles;
    /** +0x14 Per-frame sprite records. */
    std::unique_ptr<ne::C_SINGLE_SPRITE[]> frames;
};
