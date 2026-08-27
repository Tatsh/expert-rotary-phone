//
//  neTextureForiOS.h
//  pop'n rhythmin
//
//  A drawable sprite backed by a cached ne::C_TEXTURE. A bundled PNG is loaded
//  through the shared texture cache (large images may be split into GL-max-size
//  tiles), and the sprite is drawn straight into the ordering table as a
//  textured quad. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_00011818, load FUN_00011a2c, draw FUN_00011468).
//

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#include <cstdint>
#include <memory>

#include "C_SINGLE_SPRITE.h" // one ne::C_SINGLE_SPRITE per GPU upload tile (m_tileRects)

#ifdef __OBJC__
@class NSData; // the in-memory image path (LoadTexture:) takes a bridged NSData*
#endif

namespace ne {
class C_TEXTURE;
}
class AepOrderingTable;
class AepManager;

// Acquire (ref-counted) the cached ne::C_TEXTURE for a bundled image path, loading
// + uploading it on first use; returns null on load failure. Ghidra:
// FUN_0001bbf0 (the shared texture cache, head list DAT_00188464). Implemented
// in C_TEXTURE.mm.
ne::C_TEXTURE *AepTextureCacheAcquire(const char *path);

// Rebind a tile to a texture: release the tile's previously-bound texture and
// retain the new one. Ghidra: FUN_000166ec (the decompiler drops the 2nd arg at
// the call site, but it is a real incoming ne::C_TEXTURE* — verified in
// disassembly).
void AepTextureUploadTiles(ne::C_SINGLE_SPRITE *tile, ne::C_TEXTURE *tex);

/**
 * @brief The geometry and appearance of one sprite draw.
 *
 * Mirrors the fields FUN_00011468 fills into an AepSpriteCommand (offsets noted per field), and is
 * zero-defaulted like a fresh quad.
 */
struct neSpriteDrawParams {
    int u = 0;                 /**< +0x0c Source origin u. */
    int v = 0;                 /**< +0x10 Source origin v. */
    int x = 0;                 /**< +0x14 Screen position x. */
    int y = 0;                 /**< +0x18 Screen position y. */
    int sx = 0;                /**< +0x1c Scale x. */
    int sy = 0;                /**< +0x20 Scale y. */
    int w = 100;               /**< +0x24 Width, as a percentage. */
    int h = 100;               /**< +0x28 Height, as a percentage. */
    int ex = 0;                /**< +0x2c Extra / end position x. */
    int ey = 0;                /**< +0x30 Extra / end position y. */
    int color = 100;           /**< +0x34 Colour percentage, becoming the quad alpha. */
    int alpha = 0;             /**< Secondary colour-flags word; the draw's 15th argument. */
    int rotation = 0;          /**< +0x38 Rotation. */
    short blend0 = 0x20;       /**< +0x40 Blend mode. */
    short blend1 = 0;          /**< +0x42 Secondary blend word. */
    int colorMul = 0xffffff;   /**< +0x44 Colour multiplier, becoming the quad RGB. */
    int extra = 0;             /**< +0x48 Spare word. */
    int layer = 0;             /**< Draw layer; the draw's 20th argument. */
    const int *clip = nullptr; /**< +0x4c Optional clip rect; screen bounds when nullptr. */
    int priority = 0;          /**< The allocEntry bucket. */
};

/**
 * @brief An iOS sprite texture: one or more cache-shared GL tiles plus the draw call that emits
 * them into an ordering table.
 */
class neTextureForiOS {
public:
    /**
     * @brief Construct an empty sprite with no tiles.
     * @ghidraAddress 0x11818
     */
    neTextureForiOS();
    /**
     * @brief Cache-release every tile.
     */
    ~neTextureForiOS();

    /**
     * @brief Load @p path (lowercased) through the shared texture cache.
     *
     * Fills the source width and height from the resolved ne::C_TEXTURE.
     * @param path The bundle-relative image path.
     * @return 0 on success, -1 for a null path, -5 if the texture failed to load.
     * @ghidraAddress 0x11a2c
     */
    int load(const char *path);

    /**
     * @brief Upload an already-decoded, in-memory image as a single-tile texture.
     *
     * Used for artwork and name images the song record carries in memory rather than as a bundled
     * file.
     * @param imageData A bridged NSData* of PNG bytes.
     * @return 0 on success, -1 for null data, -5 on upload failure.
     * @ghidraAddress 0x11cbc
     */
    int loadFromImageData(const void *imageData);

    /**
     * @brief Load an index-driven set of tiles.
     *
     * @p indexBase is a bundled .idx blob whose tile count is a uint16 at +2; each tile i loads
     * "<dir>/<name>_<i>.png" (or "<name>_<i>.png" when @p dir is null) through the shared texture
     * cache, records its size and binds it for upload. A null @p name or @p indexBase, or a tile
     * that fails to load, aborts the load early.
     * @param dir The bundle directory, or nullptr for the bundle root.
     * @param name The tile base name.
     * @param indexBase The .idx blob.
     * @ghidraAddress 0x11e18
     */
    void loadFrames(const char *dir, const char *name, const uint8_t *indexBase);

#ifdef __OBJC__
    /**
     * @brief Decode a single PNG into one padded power-of-two RGBA GL texture.
     *
     * The source is drawn Y-flipped into a power-of-two RGBA8 bitmap, then handed to
     * neCreateTextureFromData(). This is the Objective-C-dispatched class helper the in-memory
     * image path uses; it is defined in neEngineBridge.mm because it needs UIKit and CoreGraphics.
     * @param data The PNG bytes.
     * @return The created texture, or nullptr if the image fails to decode.
     * @ghidraAddress 0x1acac
     */
    static ne::C_TEXTURE *LoadTexture(NSData *data);
#endif

    /**
     * @brief The first tile's padded width (binary field @ +0x08).
     * @return The width in texels, or 0 when no tile is loaded.
     */
    int width() const {
        return m_tileWidths ? m_tileWidths[0] : 0;
    }
    /**
     * @brief The first tile's padded height (binary field @ +0x0c).
     * @return The height in texels, or 0 when no tile is loaded.
     */
    int height() const {
        return m_tileHeights ? m_tileHeights[0] : 0;
    }

    /**
     * @brief Emit one textured-quad command for this sprite into @p ot.
     *
     * Ghidra: the wrapper neTextureForiOS_draw (FUN_0000fbcc) calls
     * AepOrderingTable_drawSprite (FUN_00011468).
     * @param ot The ordering table to append the command to.
     * @param p The draw geometry and appearance.
     */
    void draw(AepOrderingTable *ot, const neSpriteDrawParams &p);

    // Tile-table accessors for the ordering-table flush. drawAepSpriteClipped walks these members
    // rather than raw byte offsets, so the field positions and the ne::C_SINGLE_SPRITE element
    // stride stay correct on the 64-bit rebuild. The per-tile records double as the render-state
    // slots (they are ne::C_SINGLE_SPRITE, the same 0x18-byte record). The binary inlines these
    // field reads; the accessors exist only to avoid the offset arithmetic.

    /**
     * @brief The number of loaded tiles.
     * @return The tile count.
     * @newCode
     */
    int tileCount() const {
        return m_tileCount;
    }
    /**
     * @brief The per-tile padded widths.
     * @return An array tileCount() long, or nullptr when no tile is loaded.
     * @newCode
     */
    const int *tileWidths() const {
        return m_tileWidths.get();
    }
    /**
     * @brief The per-tile padded heights.
     * @return An array tileCount() long, or nullptr when no tile is loaded.
     * @newCode
     */
    const int *tileHeights() const {
        return m_tileHeights.get();
    }
    /**
     * @brief The per-tile sprite records, which double as the render-state slots.
     * @return An array tileCount() long, or nullptr when no tile is loaded.
     * @newCode
     */
    ne::C_SINGLE_SPRITE *tileRects() const {
        return m_tileRects.get();
    }

private:
    // Split-texture storage: an image wider/taller than the GL max is loaded as
    // several tiles. These parallel heap arrays are all m_tileCount long. The
    // width and height arrays hold the padded GL texture size of each tile, read
    // from the resolved ne::C_TEXTURE (+0x1c / +0x20). Ghidra: operator new[]
    // results stored at +0x08 / +0x0c / +0x10 / +0x14.
    int m_tileCount = 0;                  // +0x04 number of tiles
    std::unique_ptr<int[]> m_tileWidths;  // +0x08 per-tile texture width  (ne::C_TEXTURE +0x1c)
    std::unique_ptr<int[]> m_tileHeights; // +0x0c per-tile texture height (ne::C_TEXTURE +0x20)
    std::unique_ptr<ne::C_TEXTURE *[]> m_tiles;         // +0x10 cached ne::C_TEXTURE per tile
    std::unique_ptr<ne::C_SINGLE_SPRITE[]> m_tileRects; // +0x14 per-tile upload records
};

// Flat-argument sprite-draw wrapper the task draw passes call (Ghidra:
// FUN_0000fbcc). Packs the args into a neSpriteDrawParams and emits `tex` into
// aep's ordering table via tex->draw().
void neTextureForiOS_draw(AepManager *aep,
                          neTextureForiOS *tex,
                          int u,
                          int v,
                          int w,
                          int h,
                          int x,
                          int y,
                          int sx,
                          int sy,
                          int rotation,
                          int ex,
                          int ey,
                          int color,
                          int alpha,
                          int blend0,
                          int colorMul,
                          const int *extra,
                          int priority,
                          int layer);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
