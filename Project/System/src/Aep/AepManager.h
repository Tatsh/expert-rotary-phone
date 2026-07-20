/** @file
 * The Aep 2D scene manager: owns the ordering table, drives screen-transition fades, and is the
 * sprite/texture factory the graphics manager creates through. Reconstructed from Ghidra project
 * rb420, program PopnRhythmin. The concrete object is very large: it embeds the ordering table and
 * the full set of texture/sprite slots, so it behaves as the global scene. Only the public surface
 * is modelled here; the storage arrays are reconstructed progressively.
 */

#pragma once

#import <Foundation/Foundation.h>

#include "AepFrameDraw.h"
#include "AepOrderingTable.h"

class neTextureForiOS; // Render/neTextureForiOS.h; only pointers held here (see
                       // m_groupTexture)

/**
 * @brief The .idx index-file header, stamped and relocated by the loader.
 * @details Stamped by readIndexFile and relocated by relocateAepData: the loader walks it from the
 *          index base. The name-block words are byte offsets from the index base on disk;
 *          relocateAepData resolves each to a live pointer (advanced past its name table and the
 *          layer-ordinal array). Modelled as real fields rather than raw `base + N` casts. All
 *          slots are the on-disk 4-byte offset width; the resolved pointers live in AepManager
 *          members (m_framePosData / m_groupFrameData) because a 64-bit pointer cannot be written
 *          back into a 4-byte slot.
 */
struct AepIndexHeader {
    int16_t groupId;       /*!< Group id stamped in by readIndexFile (+0x00). */
    int16_t reserved02;    /*!< Reserved (+0x02). */
    int32_t frameNamesOff; /*!< Frame-name block offset; relocated to the frame-position table
                                (+0x04). */
    int32_t reserved08;    /*!< Reserved (+0x08). */
    int32_t reserved0c;    /*!< Reserved (+0x0c). */
    int32_t layerNamesOff; /*!< Layer-name block plus ordinals; relocated to the frame entries
                                (+0x10). */
    int32_t userNamesOff;  /*!< User-name block offset (+0x14). */
};

class AepManager {
public:
    /**
     * @brief Access the single global scene manager.
     * @details The engine keeps one global scene manager (an ~8 MB object with the ordering table
     *          embedded), reached through this lazy accessor that constructs it once on first use.
     * @return Reference to the shared manager.
     * @ghidraAddress 0xf1ec
     */
    static AepManager &shared();

    /**
     * @brief Load an .aep animation/scene resource into a group slot.
     * @details Reads the index, uploads the texture, and copies the frame tables in. `single` picks
     *          the "<dir>/<name>.idx" layout (true) versus "<dir>/<name>/<name>.idx" (false,
     *          subdirectory named after the resource).
     * @param group Destination group slot.
     * @param dir Base directory to resolve the resource against.
     * @param name Resource base name.
     * @param single True for the single-file layout, false for the subdirectory layout.
     * @return True on success.
     * @ghidraAddress 0xf4b0
     */
    bool loadAepData(int group, const char *dir, const char *name, bool single);

    /**
     * @brief Load an .aep resource group from the manager's base directory.
     * @details Convenience form of loadAepData using baseDir() and the single-file
     *          "<baseDir>/<name>.idx" layout.
     * @param group Destination group slot.
     * @param name Resource base name (e.g. "title").
     * @ghidraAddress 0xf758
     */
    void loadAepDataDefaultPath(int group, const char *name);

    /**
     * @brief Render one frame.
     * @details Advances the active screen transition (a fade in or out over a timer), then draws
     *          the ordering table.
     * @ghidraAddress 0x1058c
     */
    void draw();

    /** @brief Frame-clamp flags passed in a layer's high-level draw call. */
    enum DrawFlags {
        kDrawLoop = 0x01,      /*!< Wrap the frame index modulo the layer length. */
        kDrawClampLast = 0x10, /*!< Clamp past-the-end to the last frame (else skip). */
    };

    /**
     * @brief Resolve a layer name within a group to an encoded `lyr` value.
     * @details Produces the value drawLayer consumes: the group slot in the high 16 bits and the
     *          layer index in the low 16 bits. Asserts the name exists.
     * @param group Group slot to search.
     * @param name Layer name to resolve.
     * @return The encoded `lyr` value.
     * @ghidraAddress 0xfac8
     */
    int getLyrNo(int group, const char *name) const;

    /**
     * @brief The number of frames in a layer.
     * @details Returns the layer's entry-chain frameEnd (its length).
     * @param lyr Encoded layer handle.
     * @return The frame count.
     * @ghidraAddress 0xfb8c
     */
    int layerFrameCount(int lyr) const;

    /**
     * @brief Resolve a frame resource name within a group to an encoded handle.
     * @details The result carries the frame index in the low 16 bits and the slot byte in bits
     *          16..23. Asserts the name exists.
     * @param group Group slot to search.
     * @param name Frame name to resolve.
     * @return The encoded frame handle.
     * @ghidraAddress 0xf9cc
     */
    int getFrameNo(int group, const char *name) const;

    /**
     * @brief Resolve a user/sprite resource name within a group to its index.
     * @details Looks the name up in the group's user-frame table. Asserts the name exists.
     * @param group Group slot to search.
     * @param name User resource name to resolve.
     * @return The index into the group's user-frame table.
     * @ghidraAddress 0xfb40
     */
    int getUserNo(int group, const char *name) const;

    /**
     * @brief Start a screen transition (fade).
     * @details The fade colour is the overlay colour the screen dips to.
     * @param mode 1 = fade in, 2 = fade out; 0 or >=3 clears the transition.
     * @param frames The transition length in frames.
     * @param color The fade colour (0x00RRGGBB; 0 = black).
     * @ghidraAddress 0x106dc
     */
    void playTransition(int mode, int frames, int color);

    /**
     * @brief Arm a screen transition with the standard fixed 30-frame duration.
     * @details A fixed-length counterpart to playTransition used by most scenes: a valid mode
     *          (0..2) sets the mode, resets both frame counters to 30, and clears the fade colour
     *          to black; an invalid mode (>=3) disables the transition (mode and frames set to 0).
     * @param mode 0 = none, 1 = fade in, 2 = fade out; >=3 disables.
     * @ghidraAddress 0x10698
     */
    void setAepTransitionMode(int mode);

    /**
     * @brief Scrub the current transition frame counter.
     * @details Sets the counter to `frame`, clamped to [0, total]. This does not change the mode or
     *          total set by playTransition; it just moves the fade to a given point (e.g. frame 0
     *          is fully-faded for a fade-out, since draw() derives alpha from frames/total).
     * @param frame The frame to scrub to.
     * @ghidraAddress 0x10758
     */
    void setTransitionFrame(int frame);

    /**
     * @brief Whether the active transition has finished.
     * @details True when no frames remain, or no transition is active.
     * @return True if the transition is done.
     * @ghidraAddress 0x10730
     */
    bool isTransitionDone() const;

    /**
     * @brief The active transition mode word.
     * @details Scenes poll it to gate input during a fade.
     * @return 0 for none, 1 for fade in, or 2 for fade out.
     */
    int transitionMode() const {
        return m_transitionMode;
    }

    /**
     * @brief Draw one animated layer (the full form).
     * @details `frame` is clamped or looped to the layer's length by `loopFlags` (bit 0 = loop,
     *          bit 4 = clampLast); the remaining arguments are the root transform, colour, alpha,
     *          rotation, blend, and clip threaded into the frame-tree fill. The argument order
     *          matches the binary's drawLayer stack layout exactly: loopFlags sits at position 13,
     *          after colorHi, not right after rotation.
     * @param lyr Encoded layer handle (group slot in the high 16 bits, layer index in the low 16
     *            bits).
     * @param frame Frame index within the layer.
     * @param x Root x position.
     * @param y Root y position.
     * @param scaleX Horizontal scale.
     * @param scaleY Vertical scale.
     * @param rotation Rotation.
     * @param anchorX Anchor x.
     * @param anchorY Anchor y.
     * @param color Colour multiply.
     * @param colorHi Alpha (drives the blend split).
     * @param loopFlags Loop/clamp flags (bit 0 = loop, bit 4 = clampLast).
     * @param blendFlags Blend flags.
     * @param colorRGB Tint colour (0x00RRGGBB).
     * @param clipRect Clip rectangle, or null for the full-screen default.
     * @param context Frame-tree fill context.
     * @param priority Ordering-table draw priority.
     * @param visFlag Visibility flag.
     * @ghidraAddress 0xfd64
     */
    void drawLayer(int lyr,
                   int frame,
                   int x,
                   int y,
                   int scaleX,
                   int scaleY,
                   int rotation,
                   int anchorX,
                   int anchorY,
                   int color,
                   int colorHi,
                   uint32_t loopFlags,
                   uint32_t blendFlags,
                   uint32_t colorRGB,
                   int *clipRect,
                   void *context,
                   uint32_t priority,
                   uint32_t visFlag);

    /**
     * @brief Compatibility overload driving a layer from a resolved transform.
     * @details The scenes (MenuMainTask, PlayTask, and AepLyrCtrl) drive layers with just a
     *          resolved transform and the loop flags. It maps the transform's x, y, sx, sy,
     *          rotation, and priority into the full form (colour and alpha fully opaque, no clip
     *          override) and forwards.
     * @param lyr Encoded layer handle.
     * @param frame Frame index within the layer.
     * @param root Resolved root transform.
     * @param flags Loop/clamp flags.
     */
    void drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags);

    /**
     * @brief Queue a single-line text draw through the ordering table.
     * @details Forwards the string and the six glyph-run words to the ordering table's text command
     *          (type 6) with no clip rect. The first word is the glyph point size, not a position;
     *          drawAepOtText reads them back as neDrawText(pointSize, posX, posY).
     * @param text Null-terminated string to draw.
     * @param size Glyph point size (scaled by the render scale).
     * @param x Pen x position.
     * @param y Pen y position.
     * @param justify Justify / alignment mode.
     * @param alpha Alpha percentage (0..100).
     * @param colorRGB Glyph colour (0x00RRGGBB).
     * @param priority Ordering-table draw priority.
     * @ghidraAddress 0x10540
     */
    void DrawText(const char *text,
                  int size,
                  int x,
                  int y,
                  int justify,
                  int alpha,
                  int colorRGB,
                  int priority);

    /**
     * @brief Queue a single-line text draw with an explicit clip rectangle.
     * @details As DrawText, but threads the caller-supplied clip rect straight through to the
     *          ordering-table text command.
     * @param text Null-terminated string to draw.
     * @param size Glyph point size (scaled by the render scale).
     * @param x Pen x position.
     * @param y Pen y position.
     * @param justify Justify / alignment mode.
     * @param alpha Alpha percentage (0..100).
     * @param colorRGB Glyph colour (0x00RRGGBB).
     * @param clip Clip rectangle (16-byte vector), or null for none.
     * @param priority Ordering-table draw priority.
     * @ghidraAddress 0x1057c
     */
    void DrawTextClipped(const char *text,
                         int size,
                         int x,
                         int y,
                         int justify,
                         int alpha,
                         int colorRGB,
                         const int *clip,
                         int priority);

    /**
     * @brief The ordering table (z-sorted draw list).
     * @return Pointer to the ordering table.
     */
    AepOrderingTable *orderingTable() {
        return &m_ot;
    }

    /**
     * @brief The frame-entry array for a resolved group slot.
     * @details Used by AepDrawLayer to reach the per-group storage by slot.
     * @param slot Resolved group slot.
     * @return Pointer to the group's frame-entry array.
     */
    const AepFrameEntry *frameEntries(int slot) const {
        return m_groupFrameData[slot];
    } // +0x7f39c8

    /**
     * @brief The keyframe-channel base pointer for a resolved group slot.
     * @details The keyframe-channel offsets stored in each AepFrameEntry are relative to idxBase,
     *          the index proper at file + 4 (readIndexFile skips the 4-byte header). The binary
     *          adds the channel offsets to that idxBase pointer; returning the bare file start
     *          would shift every keyframe read by two int16s, so a static "sx = 100" scale reads
     *          back as 0.
     * @param slot Resolved group slot.
     * @return Pointer to the group's keyframe-channel base.
     */
    const uint8_t *channelBase(int slot) const {
        return (const uint8_t *)m_idxData[slot].bytes + 4;
    } // +0x7274d4

    /**
     * @brief A frame-position sprite record within a group slot.
     * @param slot Resolved group slot.
     * @param idx Sprite record index.
     * @return Pointer to the record's first int16 (stride 8).
     */
    const int16_t *spriteRecord(int slot, int idx) const {
        return &m_framePos[slot][idx].x;
    } // +0x7c1962 (stride 8)

    /**
     * @brief The cached screen width (fade-quad width slot).
     * @return The screen width in pixels.
     */
    int screenWidth() const {
        return m_transitionOverlay[2];
    } // +0x7f3afc

    /**
     * @brief The cached screen height (fade-quad height slot).
     * @return The screen height in pixels.
     */
    int screenHeight() const {
        return m_transitionOverlay[3];
    } // +0x7f3b00

    /**
     * @brief The per-frame draw callback registered for a group slot.
     * @param slot Group slot.
     * @return The group's draw callback.
     */
    AepGroupDrawFn groupCallback(int slot) const {
        return m_groupCallback[slot];
    } // +0x7f3a2c

    /**
     * @brief The context registered alongside a group's draw callback.
     * @param slot Group slot.
     * @return The group's callback context.
     */
    void *groupContext(int slot) const {
        return m_groupContext[slot];
    } // +0x7f3a90

    /**
     * @brief Resolve the group slot a sprite/layer handle addresses.
     * @details The high 16 bits index the byte group table.
     * @param handle Sprite/layer handle.
     * @return The group slot.
     */
    int groupSlotForHandle(int handle) const {
        return m_groupIndex[(handle >> 16) & 0xff];
    }

    /**
     * @brief The base resource directory the single-file loaders resolve against.
     * @return The base directory path.
     */
    const char *baseDir() const {
        return m_baseDir;
    }

    /**
     * @brief Release a group's loaded texture.
     * @details The texture's destructor drops the tiles.
     * @param group Group slot to free.
     * @ghidraAddress 0xf988
     */
    void releaseAepTexture(int group);

    /**
     * @brief The cached fade-quad width extent.
     * @details One of the two screen-quad extents cached from the transition-overlay region. The
     *          play scene reads them into its play data at build.
     * @return The fade quad's width.
     * @ghidraAddress 0xf498
     */
    int transitionOverlayWidth() const;

    /**
     * @brief The cached fade-quad height extent.
     * @details One of the two screen-quad extents cached from the transition-overlay region. The
     *          play scene reads them into its play data at build.
     * @return The fade quad's height.
     * @ghidraAddress 0xf4a4
     */
    int transitionOverlayHeight() const;

    /**
     * @brief Register a per-frame draw callback for a group.
     * @details The play scene installs its note-field render pass here at build time; the manager
     *          invokes it (with the stored context) while drawing.
     * @param slot Group slot.
     * @param callback Per-frame draw callback.
     * @param context Context passed to the callback.
     * @ghidraAddress 0xf9b0
     */
    void setGroupDrawCallback(int slot, AepGroupDrawFn callback, void *context);

private:
    // Resolve the frame-entry array for the group encoded in `lyr` (a byte
    // group-index table selecting a per-group pointer).
    const AepFrameEntry *groupEntries(int lyr) const;

    // Walk `entries`[layerNo]'s chain (stride 0x24) to its last entry and return
    // its frameEnd (the layer's length).
    static int layerLength(const AepFrameEntry *entries, int layerNo);

    // Base resource directory (char buffer at this + 0x100).
    char m_baseDir[256] = {};

    // The z-sorted draw list (at this + 0x727538).
    AepOrderingTable m_ot;

    // Per-group loaded-resource storage. In the binary these are fixed-offset
    // regions of the ~8 MB manager object; here they are modelled as per-group
    // arrays. loadAepData() populates them; drawLayer()/getLyrNo() read them.
    static const int kMaxAepGroups = 32;    // MAX_IDXBUFSIZE slots (0x40000 each)
    static const int kMaxFrameData = 0x400; // MAX_FRAME_DATA per group

    // Loaded-resource tables. The byte table maps a group id (lyr >> 16) to a
    // slot; the pointer table gives that slot's frame-entry array. Populated by
    // loadAepData as resources load.
    uint8_t m_groupIndex[256] = {};                            // +0x7c1748 (group id -> slot)
    const AepFrameEntry *m_groupFrameData[kMaxAepGroups] = {}; // +0x7f39c8
    // Rebuild-only: the relocated frame-position table pointer per group. The 32-bit
    // binary rewrites the .idx header's 4-byte offset slot in place with the pointer;
    // on the 64-bit rebuild an 8-byte pointer cannot fit that slot, so relocateAepData
    // stores it here instead (see AepIndexHeader below).
    const int16_t *m_framePosData[kMaxAepGroups] = {};

    // Raw .idx file bytes per group (holds the frame tables the pointers above
    // reference).
    NSData *m_idxData[kMaxAepGroups] = {};
    // The sprite/texture object each group's frames draw from (neTextureForiOS).
    neTextureForiOS *m_groupTexture[kMaxAepGroups] = {};
    // 8-byte frame-position records copied out of the idx (stride 8, bounded by
    // MAX_FRAME_DATA). x / y / span / h.
    struct AepFramePos {
        int16_t x, y, span, h;
    };
    AepFramePos m_framePos[kMaxAepGroups][kMaxFrameData] = {};
    int m_frameCount[kMaxAepGroups] = {}; // +0x7f3964 per group

    // Per-group frame-tree draw callback + context. setGroupDrawCallback installs
    // them; AepDrawLayer invokes the callback for type-3 frame entries.
    AepGroupDrawFn m_groupCallback[kMaxAepGroups] = {}; // +0x7f3a2c
    void *m_groupContext[kMaxAepGroups] = {};           // +0x7f3a90

    // Read "<path>" into m_idxData[group]; returns the parsed index base (the
    // bytes after the 4-byte header) or nil.
    const uint8_t *readIndexFile(int group, NSString *path);

    // Layer-name -> index open-addressing hash table, one per group (the
    // 0x2ffc-byte-strided region). The probe helper is file-static in
    // AepManager.mm. Public type (the file-static build/probe helpers name it);
    // the per-group table instances below stay private.
public:
    /**
     * @brief Queue the full-screen fade quad at the given opacity.
     * @param alpha The overlay opacity (0..100).
     * @ghidraAddress 0x1151c
     */
    void drawTransitionOverlay(int alpha);

    /**
     * @brief Initialise the manager against its resource paths and screen surface.
     * @details Copies the base and data paths, seeds the identity transforms, and hands the screen
     *          extents and device scale to the ordering table. Called once from
     *          MainViewController -loadView.
     * @param basePath The bundle path.
     * @param dataPath The texture-root data path (baseDir).
     * @param screenW The screen width in pixels.
     * @param screenH The screen height in pixels.
     * @param scale The device render scale.
     * @ghidraAddress 0xf33c
     */
    void init(const char *basePath, const char *dataPath, int screenW, int screenH, float scale);

    /**
     * @brief Per-group open-addressing name-to-index hash table.
     * @details Filled by the loader and probed by the name resolvers.
     */
    struct NameHashTable {
        uint16_t value[2048];  /*!< Layer index stored per bucket (+0x0000). */
        const char *key[2047]; /*!< Name per bucket (null marks an empty slot) (+0x1000). */
    };

private:
    // Per-group name->index hash tables, filled by relocateAepData when a group
    // loads and probed by getLyrNo / getFrameNo / getUserNo. In the binary these
    // are three separate fixed-offset regions of the manager object (frame names
    // @ +0x640200, layer names @ +0x68b19c, user names @ +0x6d6138); here they
    // are the modelled per-group arrays.
    NameHashTable m_frameNames[kMaxAepGroups] = {};   // +0x640200
    NameHashTable m_groupNames[kMaxAepGroups] = {};   // +0x68b19c (layer names)
    NameHashTable m_userNames[kMaxAepGroups] = {};    // +0x6d6138
    uint8_t m_groupSlot[kMaxAepGroups] = {};          // +0x7c1948 (per-group high byte)
    uint16_t m_layerNumbers[kMaxAepGroups][256] = {}; // +0x7210d4 (per-group layer ordinals)

    // Screen-transition (fade) state.
    int m_transitionOverlay[4] = {}; // +0x7f3af4..0x7f3b00 overlay quad params
    int m_transitionMode = 0;        // +0x7f3b04  0 none, 1 fade in, 2 fade out
    int m_transitionFrames = 0;      // +0x7f3b08  frames remaining (counts down)
    int m_transitionTotal = 0;       // +0x7f3b0c  total frames of the transition
    int m_transitionColor = 0;       // +0x7f3b10  fade colour (0x00RRGGBB; 0 = black)
    int m_maxPriority = 0;           // +0x7f3b14  highest OT priority drawn last flush

    // Fix up (relocate) a freshly-loaded group's .idx name tables into the
    // per-group hash tables above; called from loadAepData.
    void relocateData(int group, const AepIndexHeader *header, const uint8_t *idxBase);
};

/**
 * @brief The active transition mode (free-function form of transitionMode()).
 * @param mgr The manager to query.
 * @return 0 for none, 1 for fade in, or 2 for fade out.
 * @ghidraAddress 0x10724
 */
int getAepTransitionMode(const AepManager *mgr);

/**
 * @brief Draw a multi-line ('\n'-separated) string vertically centred about `y`.
 * @details Emits one text command per line, spaced `lineHeight` apart.
 * @param text Null-terminated, newline-separated string to draw.
 * @param a0 Pen x position forwarded to each line.
 * @param y Vertical centre of the text block.
 * @param a3 Justify / alignment mode forwarded to each line.
 * @param a4 Glyph point size forwarded to each line.
 * @param lineHeight Vertical spacing between lines.
 * @param a6 Glyph colour word forwarded to each line.
 * @param a7 Priority word forwarded to each line.
 * @param a8 Alpha word forwarded to each line.
 * @ghidraAddress 0x2d8b0
 */
void drawAepTextMultiline(
    const char *text, int a0, int y, int a3, int a4, int lineHeight, int a6, int a7, int a8);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
