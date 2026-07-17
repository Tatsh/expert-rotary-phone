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

// Geometry + appearance of one sprite draw. Mirrors the fields FUN_00011468
// fills into an AepSpriteCommand (offsets in comments). Zero-defaulted like a
// fresh quad.
struct neSpriteDrawParams {
    int u = 0, v = 0;          // +0x0c/+0x10 source origin
    int x = 0, y = 0;          // +0x14/+0x18 screen position
    int sx = 0, sy = 0;        // +0x1c/+0x20 scale
    int w = 100, h = 100;      // +0x24/+0x28 size (percent)
    int ex = 0, ey = 0;        // +0x2c/+0x30 extra / end position
    int color = 100;           // +0x34 colour percentage (-> quad alpha)
    int alpha = 0;             // secondary colour-flags word (the draw's 15th arg)
    int rotation = 0;          // +0x38 rotation
    short blend0 = 0x20;       // +0x40 blend mode
    short blend1 = 0;          // +0x42
    int colorMul = 0xffffff;   // +0x44 colour multiplier (-> quad RGB)
    int extra = 0;             // +0x48
    int layer = 0;             // draw layer (the draw's 20th arg)
    const int *clip = nullptr; // +0x4c/+0x54 optional clip rect (else screen bounds)
    int priority = 0;          // allocEntry bucket
};

class neTextureForiOS {
public:
    neTextureForiOS(); // Ghidra: FUN_00011818
    ~neTextureForiOS();

    // Load `path` (lowercased) through the shared texture cache. Returns 0 on
    // success, -1 for a null path, -5 if the texture failed to load. Fills the
    // source width/height from the resolved ne::C_TEXTURE. Ghidra: FUN_00011a2c.
    int load(const char *path);

    // Upload an already-decoded, in-memory image (a bridged NSData* of PNG bytes)
    // as a single-tile texture. Used for artwork / name images the song record
    // carries in memory rather than as a bundled file. Returns 0 on success, -1
    // for null data, -5 on upload failure. Ghidra: FUN_00011cbc (->
    // FUN_0001bb0c).
    int loadFromImageData(const void *imageData);

    // Load an index-driven set of tiles. `indexBase` is a bundled .idx blob whose
    // tile count is a uint16 at +2; each tile i loads "<dir>/<name>_<i>.png" (or
    // "<name>_<i>.png" when `dir` is null) through the shared texture cache,
    // records its size and binds it for upload. A null `name`/`indexBase`, or a
    // tile that fails to load, aborts the load early. Ghidra: FUN_00011e18.
    void loadFrames(const char *dir, const char *name, const uint8_t *indexBase);

#ifdef __OBJC__
    // Decode a single PNG (bridged NSData) into one padded power-of-two RGBA GL
    // texture and return the created texture (or nullptr if the image fails to
    // decode). The source is drawn Y-flipped into a POT RGBA8 bitmap, then handed
    // to neCreateTextureFromData (its ne::C_TEXTURE is the binary's C_TEXTURE).
    // objc-dispatched class helper the in-memory image path uses. Ghidra:
    // neTextureForiOS LoadTexture: @ 0x1acac. Defined in neEngineBridge.mm (needs
    // UIKit/CoreGraphics).
    static ne::C_TEXTURE *LoadTexture(NSData *data);
#endif

    int width() const {
        return m_tileWidths ? m_tileWidths[0] : 0;
    } // +0x08 tile-0 width
    int height() const {
        return m_tileHeights ? m_tileHeights[0] : 0;
    } // +0x0c tile-0 height

    // Emit one textured-quad command for this sprite into `ot`. Ghidra: the
    // wrapper neTextureForiOS_draw (FUN_0000fbcc) -> AepOrderingTable_drawSprite
    // (FUN_00011468).
    void draw(AepOrderingTable *ot, const neSpriteDrawParams &p);

    // Tile-table accessors for the ordering-table flush. drawAepSpriteClipped walks
    // these members rather than raw byte offsets, so the field positions and the
    // ne::C_SINGLE_SPRITE element stride stay correct on the 64-bit rebuild. The
    // per-tile records double as the render-state slots (they are ne::C_SINGLE_SPRITE,
    // the same 0x18-byte record). These accessors have no binary counterpart (the
    // binary inlines the field reads); they exist only to avoid the offset math.
    /** @newCode */
    int tileCount() const {
        return m_tileCount;
    }
    /** @newCode */
    const int *tileWidths() const {
        return m_tileWidths.get();
    }
    /** @newCode */
    const int *tileHeights() const {
        return m_tileHeights.get();
    }
    /** @newCode */
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
