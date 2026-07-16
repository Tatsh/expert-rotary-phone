//
//  neTextTexture.h
//  pop'n rhythmin
//
//  The dynamic text/glyph subsystem: a singleton manager owning a cache of
//  rendered glyphs and a list of 256x256 grayscale atlas textures they are
//  packed into, plus the string layout + draw entry point neDrawText.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (original
//  tree:
//  .../Project/System/src/Render/neTextTexture.mm).
//

#pragma once

#include <cstdint>

// One glyph atlas: a 256x256 GL_ALPHA texture (created via
// neCreateTextureFromData) plus the CPU-side pixel buffer it was uploaded from.
// Ghidra: CreateNewTextTexture (FUN_00017b28) fills these; the destructor is
// FUN_000180a4.
class neTextTexture {
public:
    ~neTextTexture(); // Ghidra: FUN_000180a4

    int32_t index = 0;             // +0x00 atlas index (its slot in the manager's list)
    void *texture = nullptr;       // +0x04 AepTexture* (released on destroy)
    int32_t penX = 0;              // +0x08 current pack cursor X
    int32_t penY = 0;              // +0x0c current pack cursor Y
    int32_t rowHeight = 0;         // +0x10 tallest glyph in the current row
    uint8_t *pixels = nullptr;     // +0x14 CPU pixel buffer (delete[] on destroy)
    neTextTexture *next = nullptr; // +0x18 manager list link
};

// One cached glyph record (defined in neTextTexture.mm).
struct neGlyph;

#ifdef __OBJC__
@class UILabel; // renderGlyphToAtlas rasterizes a glyph through a UILabel
#endif

// The text-texture manager (Ghidra: the singleton at DAT_0018845c). Owns the
// glyph cache list (+0x04) and the atlas node list (+0x0c); +0x00 is the
// content-scale shift applied to point sizes, +0x08 the atlas count. The members
// below are the class methods Ghidra records — each was a free function taking
// this manager as its receiver.
class neTextTextureMgr {
public:
    // Free every cached glyph and destroy every atlas texture. Ghidra:
    // FUN_000179a8. The binary also invokes it explicitly to evict the atlas cache
    // once it grows past 4 textures, after which the emptied manager keeps being
    // used.
    ~neTextTextureMgr();

    // Linear search of the glyph cache for the first UTF-8 char of `utf8` at
    // `pointSize`; null when not cached. Ghidra: FUN_00017ad4.
    neGlyph *findCachedGlyph(const char *utf8, int pointSize);

    // Find the atlas whose index is `atlasId`. Ghidra: FUN_00017b10.
    neTextTexture *findTextTextureById(int atlasId);

    // Allocate a fresh 256x256 GL_ALPHA atlas and link it in. Ghidra: FUN_00017b28.
    void createNewTextTexture();

    // Reserve a `w`x`h` cell in the current atlas, wrapping/opening a new atlas
    // when full. Ghidra: FUN_00017bb4.
    bool allocGlyphAtlasSlot(int w, int h, int *outX, int *outY);

    // Allocate a glyph record for the first UTF-8 char of `utf8`, rasterize it into
    // an atlas, and cache it. Ghidra: FUN_00017ecc.
    neGlyph *createTextGlyphEntry(const char *utf8, const char *fontName, int pointSize);

#ifdef __OBJC__
    // Rasterize `utf8` through `label` into the reserved atlas cell and fill the
    // glyph's placement. Ghidra: FUN_00017c44.
    int renderGlyphToAtlas(const char *utf8, UILabel *label, neGlyph *glyph);
#endif

    int8_t scaleShift = 0;            // +0x00 log2 content scale (glyph sizes << by this)
    int8_t _pad[3] = {0, 0, 0};       // +0x01
    void *glyphList = nullptr;        // +0x04 rendered-glyph cache (data +0x00, next +0x08)
    int32_t atlasCount = 0;           // +0x08
    neTextTexture *atlases = nullptr; // +0x0c atlas list (linked via neTextTexture::next)
};

// The manager singleton. Ghidra: FUN_00017998 returns DAT_0018845c.
neTextTextureMgr *neGetTextTextureMgr(void);

// Byte length (1..6) of the UTF-8 sequence led by *s, or -1 on an invalid lead
// byte, 0 on a stray continuation byte. Ghidra: FUN_00017a84.
int utf8CharLen(neTextTextureMgr *mgr, const char *s);

// Draw `text` at (x,y). `size` is the point size, `align` picks
// left/center/right, and (alpha,red,green,blue) tint the glyphs; `clipRect` (or
// null) installs clip planes. Glyphs are laid out through the atlas cache and
// rendered as batched textured quads via the current renderer. Ghidra:
// FUN_0001551c.
void neDrawText(const char *text,
                void *font,
                int size,
                int x,
                int y,
                int align,
                int alpha,
                int red,
                int green,
                int blue,
                const int *clipRect);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
