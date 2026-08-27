/** @file
 * The dynamic text and glyph subsystem: a singleton manager owning a cache of rendered glyphs and
 * a list of 256x256 grayscale atlas textures they are packed into, plus the string layout and draw
 * entry point neDrawText. Reconstructed from Ghidra project rb420, program PopnRhythmin (original
 * tree: .../Project/System/src/Render/neTextTexture.mm).
 */

#pragma once

#include <cstdint>
#include <memory>

#import <Foundation/Foundation.h>

/**
 * @brief One glyph atlas: a 256x256 GL_ALPHA texture (created via neCreateTextureFromData) plus
 * the CPU-side pixel buffer it was uploaded from.
 *
 * Ghidra: CreateNewTextTexture (FUN_00017b28) fills these.
 */
class neTextTexture {
public:
    /**
     * @brief Release the GL texture and free the pixel buffer.
     * @ghidraAddress 0x180a4
     */
    ~neTextTexture();

    int32_t index = 0;                 /**< +0x00 Atlas index: its slot in the manager's list. */
    void *texture = nullptr;           /**< +0x04 The ne::C_TEXTURE*, released on destroy. */
    int32_t penX = 0;                  /**< +0x08 Current pack cursor x. */
    int32_t penY = 0;                  /**< +0x0c Current pack cursor y. */
    int32_t rowHeight = 0;             /**< +0x10 Height of the tallest glyph in the current row. */
    std::unique_ptr<uint8_t[]> pixels; /**< +0x14 The CPU-side pixel buffer. */
    neTextTexture *next = nullptr;     /**< +0x18 Next node in the manager's atlas list. */
};

/** One cached glyph record; defined in neTextTexture.mm. */
struct neGlyph;

#ifdef __OBJC__
@class UILabel; // renderGlyphToAtlas rasterizes a glyph through a UILabel
#endif

/**
 * @brief The text-texture manager (Ghidra: the singleton at DAT_0018845c).
 *
 * Owns the glyph cache list (+0x04) and the atlas node list (+0x0c); +0x00 is the content-scale
 * shift applied to point sizes and +0x08 the atlas count. The members below are the class methods
 * Ghidra records — each was a free function taking this manager as its receiver.
 */
class neTextTextureMgr {
public:
    /**
     * @brief Free every cached glyph and destroy every atlas texture.
     *
     * The binary also invokes this explicitly to evict the atlas cache once it grows past four
     * textures, after which the emptied manager keeps being used.
     * @ghidraAddress 0x179a8
     */
    ~neTextTextureMgr();

    /**
     * @brief Linear search of the glyph cache for the first UTF-8 character of @p utf8 at
     * @p pointSize.
     * @param utf8 The string whose first character to look up.
     * @param pointSize The rendered point size.
     * @return The cached glyph, or nullptr when it is not cached.
     * @ghidraAddress 0x17ad4
     */
    neGlyph *findCachedGlyph(const char *utf8, int pointSize);

    /**
     * @brief Find the atlas whose index is @p atlasId.
     * @param atlasId The atlas index.
     * @return The atlas, or nullptr when there is no such index.
     * @ghidraAddress 0x17b10
     */
    neTextTexture *findTextTextureById(int atlasId);

    /**
     * @brief Allocate a fresh 256x256 GL_ALPHA atlas and link it into the manager's list.
     * @ghidraAddress 0x17b28
     */
    void createNewTextTexture();

    /**
     * @brief Reserve a @p w by @p h cell in the current atlas, wrapping to a new row or opening a
     * new atlas when the current one is full.
     * @param w Cell width, in texels.
     * @param h Cell height, in texels.
     * @param outX Receives the reserved cell's x origin.
     * @param outY Receives the reserved cell's y origin.
     * @return true when a cell was reserved.
     * @ghidraAddress 0x17bb4
     */
    bool allocGlyphAtlasSlot(int w, int h, int *outX, int *outY);

    /**
     * @brief Allocate a glyph record for the first UTF-8 character of @p utf8, rasterise it into
     * an atlas, and cache it.
     * @param utf8 The string whose first character to render.
     * @param fontName The font to render with.
     * @param pointSize The point size to render at.
     * @return The new cached glyph, or nullptr on failure.
     * @ghidraAddress 0x17ecc
     */
    neGlyph *createTextGlyphEntry(const char *utf8, const char *fontName, int pointSize);

#ifdef __OBJC__
    /**
     * @brief Rasterise @p utf8 through @p label into the reserved atlas cell and fill the glyph's
     * placement.
     * @param utf8 The string whose first character to rasterise.
     * @param label The label configured with the target font and point size.
     * @param glyph The glyph record to fill.
     * @return Non-zero on success.
     * @ghidraAddress 0x17c44
     */
    int renderGlyphToAtlas(const char *utf8, UILabel *label, neGlyph *glyph);
#endif

    int8_t scaleShift = 0; /**< +0x00 log2 of the content scale; glyph sizes shift left by it. */
    int8_t _pad[3] = {0, 0, 0}; /**< +0x01 Alignment padding. */
    /** +0x04 The rendered-glyph cache (data at +0x00, next at +0x08). */
    void *glyphList = nullptr;
    int32_t atlasCount = 0;           /**< +0x08 The number of live atlases. */
    neTextTexture *atlases = nullptr; /**< +0x0c Atlas list, linked via neTextTexture::next. */
};

/**
 * @brief The manager singleton (Ghidra: returns DAT_0018845c).
 * @return The text-texture manager.
 * @ghidraAddress 0x17998
 */
neTextTextureMgr *neGetTextTextureMgr(void);

/**
 * @brief The byte length of the UTF-8 sequence led by `*s`.
 * @param mgr The manager; the receiver in the binary, unused by the decode itself.
 * @param s The string to inspect.
 * @return 1..6 for a valid lead byte, -1 on an invalid lead byte, 0 on a stray continuation byte.
 * @ghidraAddress 0x17a84
 */
int utf8CharLen(neTextTextureMgr *mgr, const char *s);

/**
 * @brief Draw @p text at (@p x, @p y).
 *
 * Glyphs are laid out through the atlas cache and rendered as batched textured quads via the
 * current renderer.
 * @param text The string to draw.
 * @param font The font name.
 * @param size The point size.
 * @param x Draw origin x, in pixels.
 * @param y Draw origin y, in pixels.
 * @param align Picks left, centre or right alignment.
 * @param alpha Alpha, 0..255.
 * @param red Red, 0..255.
 * @param green Green, 0..255.
 * @param blue Blue, 0..255.
 * @param clipRect Clip-plane values, or nullptr to leave the text unclipped.
 * @ghidraAddress 0x1551c
 */
void neDrawText(const char *text,
                const char *font,
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
