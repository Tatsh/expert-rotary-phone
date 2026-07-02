//
//  neTextureForiOS.h
//  pop'n rhythmin
//
//  A drawable sprite backed by a cached AepTexture. A bundled PNG is loaded
//  through the shared texture cache (large images may be split into GL-max-size
//  tiles), and the sprite is drawn straight into the ordering table as a textured
//  quad. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_00011818, load FUN_00011a2c, draw FUN_00011468).
//

#pragma once

class AepTexture;
class AepOrderingTable;

// Geometry + appearance of one sprite draw. Mirrors the fields FUN_00011468 fills
// into an AepSpriteCommand (offsets in comments). Zero-defaulted like a fresh quad.
struct neSpriteDrawParams {
    int u = 0, v = 0;         // +0x0c/+0x10 source origin
    int x = 0, y = 0;         // +0x14/+0x18 screen position
    int sx = 0, sy = 0;       // +0x1c/+0x20 scale
    int w = 100, h = 100;     // +0x24/+0x28 size (percent)
    int ex = 0, ey = 0;       // +0x2c/+0x30 extra / end position
    int color = 100;          // +0x34 colour/alpha
    int rotation = 0;         // +0x38 rotation
    short blend0 = 0x20;      // +0x40 blend mode
    short blend1 = 0;         // +0x42
    int colorMul = 0xffffff;  // +0x44 colour multiplier
    int extra = 0;            // +0x48
    const int *clip = nullptr; // +0x4c/+0x54 optional clip rect (else screen bounds)
    int priority = 0;         // allocEntry bucket
};

class neTextureForiOS {
public:
    neTextureForiOS();          // Ghidra: FUN_00011818
    ~neTextureForiOS();

    // Load `path` (lowercased) through the shared texture cache. Returns 0 on
    // success, -1 for a null path, -5 if the texture failed to load. Fills the
    // source width/height from the resolved AepTexture. Ghidra: FUN_00011a2c.
    int load(const char *path);

    int width() const { return m_width; }    // +0x08 (source width)
    int height() const { return m_height; }  // +0x0c (source height)

    // Emit one textured-quad command for this sprite into `ot`. Ghidra: FUN_00011468
    // (allocEntry FUN_00010be0 + field fill).
    void draw(AepOrderingTable *ot, const neSpriteDrawParams &p);

private:
    // Split-texture storage: an image wider/taller than the GL max is loaded as
    // several tiles. These parallel arrays hold the per-tile AepTexture handles and
    // sub-rects (Ghidra: heap arrays at +0x10 / +0x14, tile width/height at +0x08/+0x0c).
    AepTexture **m_tiles = nullptr;   // +0x10 cached AepTexture per tile
    void *m_subRects = nullptr;       // +0x14 per-tile sub-rect / UV records
    int m_width = 0;                  // +0x08 source width  (from AepTexture +0x24)
    int m_height = 0;                 // +0x0c source height (from AepTexture +0x28)
    int m_tileCount = 0;              // +0x04 number of tiles
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
