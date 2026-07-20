/** @file
 * The Aep ordering table: a per-frame sprite command buffer. Each frame the scene fills the
 * buffer with textured-quad draw commands (drawLayer -> allocEntry), bucketed by priority; the
 * flush then walks the buckets high-priority-first and emits a GL quad per command through
 * neGLES_11. OT_REGIST_MAX = 2047 entries, OT_PRI_MAX = 50 priorities.
 */

#pragma once

#include <cstdint>

class neTextureForiOS; // the sprite/frame-atlas object a sprite command references

/** @brief Maximum number of ordering-table entries reservable per frame (OT_REGIST_MAX). */
constexpr int kOtRegistMax = 2047;
/** @brief Maximum number of priority buckets the ordering table supports (OT_PRI_MAX). */
constexpr int kOtPriMax = 50;

/**
 * @brief The clip rectangle carried by a sprite command.
 *
 * Sixteen bytes of four ints. Defaults to the screen bounds when the fill supplies no explicit
 * rectangle.
 */
struct AepClipRect {
    int32_t nLeft;   /*!< Left edge (+0x00). */
    int32_t nTop;    /*!< Top edge (+0x04). */
    int32_t nRight;  /*!< Right edge (+0x08). */
    int32_t nBottom; /*!< Bottom edge (+0x0c). */
};

/**
 * @brief Command-type discriminator held in AepOtSpriteCmd::wFlags.
 *
 * Also overlays the AepTextCmd::nType slot at +0x04. The flush switches on it to select the
 * per-type draw handler. The underlying type is pinned to uint16_t so the field stays two bytes
 * at +0x04.
 */
enum AepOtCmdType : uint16_t {
    kAepOtCmdSprite = 0,        /*!< Textured sprite, dispatched to drawAepOtSprite. */
    kAepOtCmdSpriteStretch = 1, /*!< Stretched sprite, dispatched to drawAepOtSpriteStretch. */
    kAepOtCmdLine = 2,          /*!< Line, dispatched to drawAepOtLine. */
    kAepOtCmdTriangle = 3,      /*!< Triangle, dispatched to drawAepOtTriangle. */
    kAepOtCmdRect = 4,          /*!< Rectangle (the transition-fade overlay), to drawAepOtRect. */
    kAepOtCmdQuad = 5,          /*!< Quad, dispatched to drawAepOtQuad. */
    kAepOtCmdText = 6,          /*!< Text, dispatched to drawAepOtText. */
};

/**
 * @brief Bits of the AEP blend word threaded through the frame tree.
 *
 * These flags are stored in AepOtSpriteCmd::nVKey. The clipped-quad draw extracts the mode
 * selector `(flags & kAepBlendModeMask) >> kAepBlendModeShift`, or forces kAepBlendModeReverseSub
 * when kAepBlendReverseSubtract is set.
 */
enum AepBlendFlag : uint32_t {
    kAepBlendAlphaGateBit = 0x20,     /*!< Bit 5: gates the per-sprite alpha. */
    kAepBlendModeShift = 9,           /*!< The mode selector occupies bit 9. */
    kAepBlendModeMask = 0x3ff,        /*!< Bits 0..9 hold the mode selector. */
    kAepBlendAdditive = 0x200,        /*!< Bit 9: additive blend (clipped-quad mode 1). */
    kAepBlendReverseSubtract = 0x400, /*!< Forces reverse-subtract (mode 2). */
};

/**
 * @brief GL blend presets selected from the mode field of the blend word.
 *
 * The clipped-quad draw picks one of these from the mode field and hands it to neDrawTexturedQuad:
 * straight alpha, additive, or reverse-subtract.
 */
enum AepBlendMode : int {
    kAepBlendModeStraightAlpha = 0, /*!< GL_ONE, GL_ONE_MINUS_SRC_ALPHA. */
    kAepBlendModeAdd = 1,           /*!< GL_ONE, GL_ONE. */
    kAepBlendModeReverseSub = 2,    /*!< GL_FUNC_REVERSE_SUBTRACT_OES. */
};

/**
 * @brief One queued ordering-table draw command.
 *
 * The command block of a 0x134-byte pool entry. The first 0x50 bytes are the named payload the
 * fills (drawSprite, the transition overlay, and the sprite emitter) write; the tail is
 * per-command scratch. The fills spill an 8-byte source-rect word into the next entry, so the
 * whole entry stride (0x134) is reserved here. The wFlags field at +0x04 is the command-type
 * discriminator the flush switches on. Where a slot's role varies by command type the per-field
 * note gives the concrete meaning.
 */
struct AepOtSpriteCmd {
    AepOtSpriteCmd *pListNext; /*!< Priority-bucket link (+0x00). */
    AepOtCmdType wFlags;       /*!< Command-type discriminator (+0x04). */
    int16_t nPriority;         /*!< Bucket priority; bookkeeping, not traversal (+0x06). */
    int32_t nBank;             /*!< Texture bank / layer slot (+0x08). */
    /**
     * @brief Source origin, reinterpreted by command type (+0x0c/+0x10).
     *
     * Line, rectangle, quad, and text commands use nTexU/nTexV as plain ints; a type-0 sprite
     * instead packs its u/v/w/h source rectangle into the same eight bytes as four shorts
     * (srcRect), and a type-1 sprite uses nTexV as the frame column (its texture lives in
     * pTexObj). srcRect is exactly the two int slots, so the union adds no size and shifts no
     * offset.
     */
    union {
        struct {
            int32_t nTexU; /*!< Source U (plain-int commands). */
            int32_t nTexV; /*!< Source V, or the frame column for a stretched sprite. */
        };
        int16_t srcRect[4]; /*!< Type-0 sprite: packed {u, v, w, h}. */
    };
    int32_t nPosX, nPosY; /*!< Screen position (+0x14/+0x18). */
    /**
     * @brief Slot at +0x1c, read as int for cases 1-5 and as float for case 0.
     *
     * The +0x1c/+0x20 and +0x28/+0x2c slots are reused per command type with different encodings.
     * A single 32-bit pool slot is thus float for one command and int for another, so each is a
     * union of both views. Every command reads and writes the SAME member (no inactive-member
     * punning). This slot holds the base size, position, or alpha for cases 1-5, and the sprite X
     * scale for case 0.
     */
    union {
        int32_t flPosXf; /*!< Int view (cases 1-5: base size / position / alpha). */
        float flPosXfF;  /*!< Float view (case 0: sprite X scale). */
    };
    /**
     * @brief Slot at +0x20, read as int for cases 1-5 and as float for case 0.
     *
     * Holds the position or colour for cases 1-5, and the sprite Y scale for case 0.
     */
    union {
        int32_t flPosYf; /*!< Int view (cases 1-5: position / colour). */
        float flPosYfF;  /*!< Float view (case 0: sprite Y scale). */
    };
    int32_t nOfsX; /*!< Offset X, int slot (+0x24). */
    /**
     * @brief Slot at +0x28, read as int for cases 0, 3, and 5, and float for case 1.
     */
    union {
        int32_t nOfsY; /*!< Int view (cases 0, 3, 5: height / offset). */
        float nOfsYF;  /*!< Float view (case 1: stretched-sprite X scale). */
    };
    /**
     * @brief Slot at +0x2c, read as int for cases 0 and 5, and float for case 1.
     */
    union {
        int32_t nColorA; /*!< Int view (cases 0, 5: colour / alpha). */
        float nColorAF;  /*!< Float view (case 1: stretched-sprite Y scale). */
    };
    int32_t nColorMul;    /*!< Colour multiplier, int slot (+0x30). */
    int16_t nUKey, nVKey; /*!< UV keys; nVKey also carries the blend flags (+0x34/+0x36). */
    int32_t nBlendFlags;  /*!< Blend flags (+0x38). */
    int32_t nColorRGB;    /*!< Packed 0x00RRGGBB colour (+0x3c). */
    AepClipRect clipRect; /*!< Clip rectangle; defaults to screen bounds (+0x40..0x4f). */
    /**
     * @brief Per-command / clip-spill scratch tail (+0x50..+0x5f).
     *
     * The clip-spill (drawSprite) writes clipRect.nBottom plus the following 12 bytes into
     * +0x4c..+0x5b of this tail.
     */
    uint8_t scratch0[0x60 - 0x50];
    /**
     * @brief The sprite's source texture object; rebuild-only, +0x60.
     *
     * Not present in the 32-bit binary's layout: the binary packs this pointer into the 32-bit
     * nTexU slot. Storing it as a real typed pointer here avoids truncating a 64-bit pointer into
     * an int. Only sprite commands (wFlags 0 or 1) use it; it is the neTextureForiOS the flush
     * walks.
     */
    neTextureForiOS *pTexObj;
    uint8_t scratch1[0x134 - 0x60 - sizeof(void *)]; /*!< Remaining per-command state. */
};

/**
 * @brief A queued text draw command.
 *
 * The type-6 entry pushAepOtTextCmd fills; it reinterprets the same 0x134-byte pool slot as
 * AepOtSpriteCmd via nType. The string occupies the slot the sprite view uses for its
 * texture/source-rect words (+0x0c), and the glyph parameters follow it at +0x10c, which the
 * flush reaches as the fourth 80-byte AepOtSpriteCmd-sized block of the entry.
 */
struct AepTextCmd {
    AepOtSpriteCmd *pNext; /*!< Priority-bucket link (+0x00). */
    int16_t nType;         /*!< == kAepOtCmdText, same discriminator slot as wFlags (+0x04). */
    int16_t nPriority;     /*!< Bucket priority (+0x06). */
    int32_t nReserved8;    /*!< Reserved (+0x08). */
    char pText[256];       /*!< The glyph run, force-terminated at pText[255] (+0x0c..+0x10b). */
    int32_t nSize;         /*!< Glyph point size, scaled by the render scale (+0x10c). */
    int32_t nPosX;         /*!< Pen position x (+0x110). */
    int32_t nPosY;         /*!< Pen position y (+0x114). */
    int32_t nJustify;      /*!< Justify / alignment mode (+0x118). */
    int32_t nAlpha;        /*!< 0..100 alpha percentage (+0x11c). */
    int32_t nColorRGB;     /*!< 0x00RRGGBB glyph colour (+0x120). */
    int32_t pAClipVec[4];  /*!< Clip vector, or {0, 0, screenW, screenH} (+0x124..+0x133). */
};

/**
 * @brief The Aep ordering table: a per-frame priority-bucketed sprite command buffer.
 */
class AepOrderingTable {
public:
    /** @brief Construct an empty ordering table ready for a new frame. */
    AepOrderingTable();

    /** @brief Reset the buffer for a new frame: zero the count and clear the buckets. */
    void reset();

    /**
     * @brief Reserve a command entry at a priority and link it into that bucket.
     *
     * @param priority The priority bucket to head-insert the new entry into.
     * @return The reserved command entry, ready to fill.
     * @ghidraAddress 0x10be0
     */
    AepOtSpriteCmd *allocEntry(int priority);

    /**
     * @brief Fill a stretched-sprite command (wFlags=1) and link it at a priority.
     *
     * Forwards position, scale, colour, blend, and clip for the sprite. This is the fill
     * neTextureForiOS::draw drives; the flush later dispatches the command through
     * drawAepOtSpriteStretch.
     *
     * @param pTexture The source sprite/frame-atlas texture object.
     * @param nTexV The frame column.
     * @param nPosX Screen position x.
     * @param nPosY Screen position y.
     * @param flPosXf Base size (int view of the +0x1c slot).
     * @param flPosYf Position (int view of the +0x20 slot).
     * @param nOfsX Offset x.
     * @param nOfsY Stretched-sprite X scale (float view of the +0x28 slot).
     * @param nColorA Stretched-sprite Y scale (float view of the +0x2c slot).
     * @param nColorMul Colour multiplier.
     * @param nKeys Packed UV keys (low half is nUKey, high half is nVKey).
     * @param nBlendFlags Blend flags.
     * @param nColorRGB Packed 0x00RRGGBB colour.
     * @param clipLeftLo Low half of the packed clip-left word.
     * @param clipLeftHi High half of the packed clip-left word.
     * @param clipTop Clip rectangle top.
     * @param clipRight Clip rectangle right.
     * @param clipSpill The 16-byte clip block, or null to default to screen bounds.
     * @param nPriority The priority bucket to link the command into.
     * @return The filled command entry.
     * @ghidraAddress 0x11468
     */
    AepOtSpriteCmd *drawSprite(neTextureForiOS *pTexture,
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
                               int nPriority);

    /**
     * @brief Flush the buffer: walk the priority buckets high-to-low and dispatch each command by
     *        wFlags to its per-type draw handler.
     *
     * @ghidraAddress 0x115d0
     */
    void flush();

    /**
     * @brief Number of commands dispatched by the most recent flush.
     *
     * @return The dispatched command count.
     * @ghidraAddress 0x117dc
     */
    int drawnCount() const {
        return m_drawnCount;
    }

    /**
     * @brief Cache the screen extents, the per-slot texture table, and the device-pixel render
     *        scale on the ordering table.
     *
     * The immediate-mode primitive helpers transform their coordinates by the render scale and
     * resolve their texture from the per-slot table.
     *
     * @param textureTable The per-slot GL texture-handle table.
     * @param screenW Screen width.
     * @param screenH Screen height.
     * @param scale The device-pixel render scale.
     * @ghidraAddress 0x10bbc
     */
    void setScreenParams(neTextureForiOS **textureTable, int screenW, int screenH, float scale);
    /**
     * @brief Screen width.
     *
     * @return The cached screen width.
     */
    int screenW() const {
        return m_screenW;
    } // +0x04
    /**
     * @brief Screen height.
     *
     * @return The cached screen height.
     */
    int screenH() const {
        return m_screenH;
    } // +0x08
    /**
     * @brief The per-slot GL texture-handle table.
     *
     * @return The cached texture table.
     */
    neTextureForiOS **textureTable() const {
        return m_textureTable;
    } // +0x9a1a4
    /**
     * @brief The device-pixel render scale.
     *
     * @return The cached render scale.
     */
    float renderScale() const {
        return m_renderScale;
    } // +0x9a1a8
    /**
     * @brief Set the device-pixel render scale directly.
     *
     * BootLogoTask setup and finish write this to switch to native scale (1.0) for the branding
     * logos and to restore the saved UI half-scale on exit.
     *
     * @param scale The new render scale.
     */
    void setRenderScale(float scale) {
        m_renderScale = scale;
    }

private:
    // Per-type draw handlers the flush dispatches each command to. Only the flush
    // calls them in this title, so they are private. Each transforms its
    // coordinates by renderScale() and issues the matching neGraphics primitive.
    void drawAepOtSprite(const int16_t *spriteRec,
                         int x,
                         int y,
                         int sx,
                         int sy,
                         int nOfsX,
                         int nOfsY,
                         int nColorA,
                         uint32_t alpha,
                         int rotation,
                         int blend,
                         const void *clip,
                         int visFlag,
                         int colorRGB,
                         int slot,
                         int priority);
    void drawAepOtSpriteStretch(neTextureForiOS *pFrames,
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
                                uint32_t nColorRGB);
    void drawAepOtLine(int x0, int y0, int x1, int y1, int alpha, uint32_t color);
    void
    drawAepOtTriangle(int x0, int y0, int x1, int y1, int x2, int y2, int alpha, uint32_t color);
    void drawAepOtRect(int x0, int y0, int x1, int y1, int alpha, uint32_t color);
    void drawAepOtQuad(
        int x0, int y0, int x1, int y1, int x2, int y2, int x3, int y3, int alpha, uint32_t color);
    void drawAepOtText(const char *text,
                       const char *font,
                       int x,
                       int y,
                       int size,
                       int align,
                       int alpha,
                       const int *colorVec,
                       uint32_t color);

    int m_screenW = 0;                      // +0x04
    int m_screenH = 0;                      // +0x08
    AepOtSpriteCmd m_entries[kOtRegistMax]; // the frame's command pool
    AepOtSpriteCmd *m_buckets[kOtPriMax];   // per-priority list heads (both track the
                                            // newest entry per bucket)
    int m_count = 0;                        // m_OtCount
    int m_maxPriority = 0;                  // highest used priority
    int m_drawnCount = 0;
    neTextureForiOS **m_textureTable = nullptr; // +0x9a1a4  per-slot GL texture handles
    float m_renderScale = 1.0f;                 // +0x9a1a8  device-pixel scale
};

// ---------------------------------------------------------------------------
// The ordering table's immediate-mode primitive draw helpers. Each takes the OT
// (for the render scale + texture table), transforms its coordinates by
// OT::renderScale(), unpacks the packed colour (0xRRGGBB) and 0..100 alpha, and
// issues the corresponding neGraphics primitive. These are the type-dispatch
// handlers the flush runs per queued command; they are also called directly by
// the UI draws. The neDraw* renderer entries are reconstructed in parallel in
// the neGraphics unit (forward-declared in the .mm).
// ---------------------------------------------------------------------------

/**
 * @brief Set the ordering table's screen extents, per-slot texture table, and render scale.
 *
 * @param ot The ordering table to configure.
 * @param textureTable The per-slot GL texture-handle table.
 * @param screenW Screen width.
 * @param screenH Screen height.
 * @param scale The device-pixel render scale.
 * @ghidraAddress 0x10bbc
 */
void aepOtSetScreenParams(
    AepOrderingTable *ot, neTextureForiOS **textureTable, int screenW, int screenH, float scale);

/**
 * @brief Queue a text draw command (type 6) at a priority.
 *
 * The `colorVec` (16 bytes) overrides the per-glyph clip vector; when null it defaults to
 * {0, 0, screenW, screenH}. The first value is the size, not a position (see AepTextCmd).
 *
 * @param ot The ordering table to queue into.
 * @param text The glyph run to draw.
 * @param size The glyph point size.
 * @param x Pen position x.
 * @param y Pen position y.
 * @param justify The justify / alignment mode.
 * @param alpha Alpha percentage (0..100).
 * @param colorRGB Packed 0x00RRGGBB colour.
 * @param colorVec The 16-byte clip-vector override, or null for screen bounds.
 * @param priority The priority bucket to queue the command into.
 * @ghidraAddress 0x1154c
 */
void pushAepOtTextCmd(AepOrderingTable *ot,
                      const char *text,
                      int size,
                      int x,
                      int y,
                      int justify,
                      int alpha,
                      int colorRGB,
                      const int *colorVec,
                      int priority);

// The seven per-type draw handlers (drawAepOtSprite / …Stretch / …Line /
// …Triangle / …Rect / …Quad / …Text) are AepOrderingTable member functions
// declared in the class above; only the flush dispatches to them.

/**
 * @brief The clipped textured-quad immediate draw.
 *
 * `frameObj` is the animated texture object: it holds the sub-frame count, the per-frame width and
 * duration tables, and the render-state slots. It picks the active sub-frame from `frameTime`,
 * composes the source rectangle, sets the render state, and issues neDrawTexturedQuad, optionally
 * through a scaled clip rectangle.
 *
 * @param pFrames The animated texture object.
 * @param nWidth Source-rect origin x.
 * @param nFrameIn The frame time used to pick the active sub-frame.
 * @param nSrcV Source-rect span (mapped to U).
 * @param nSrcU Source-rect span (mapped to V).
 * @param flDstX Destination-rect x.
 * @param flDstY Destination-rect y.
 * @param flDstW Destination-rect width.
 * @param flDstH Destination-rect height.
 * @param nRawAngle Rotation in degrees (reduced mod 360).
 * @param flPivotX Pivot x.
 * @param flPivotY Pivot y.
 * @param nAlpha Alpha percentage (0..100).
 * @param flParam14 Unused.
 * @param nFlags Blend flags.
 * @param pClipRect The clip rectangle, or null.
 * @param nUseClip Non-zero to enable clipping.
 * @param nColor Packed 0x00RRGGBB colour.
 * @ghidraAddress 0x12020
 */
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
                          float flParam14,
                          uint32_t nFlags,
                          const int *pClipRect,
                          int nUseClip,
                          uint32_t nColor);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
