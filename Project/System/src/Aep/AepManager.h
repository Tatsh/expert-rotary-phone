//
//  AepManager.h
//  pop'n rhythmin
//
//  The Aep 2D scene manager: owns the ordering table, drives screen-transition
//  fades, and is the sprite/texture factory the graphics manager creates
//  through. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NOTE: the concrete object is very large — it embeds the ordering table
//  (@ +0x727538) and the full set of texture/sprite slots, so it behaves as the
//  global scene. Only the public surface is modeled here; the storage arrays
//  are reconstructed progressively.
//

#pragma once

#import <Foundation/Foundation.h>

#include "AepFrameDraw.h"
#include "AepOrderingTable.h"

class neTextureForiOS; // Render/neTextureForiOS.h; only pointers held here (see
                       // m_groupTexture)

// The .idx index-file header, stamped and relocated by readIndexFile /
// relocateAepData (Ghidra: the header the loader walks from the index base). The
// name-block words are byte offsets from the index base on disk; relocateAepData
// resolves each to a live pointer (advanced past its name table + the layer-ordinal
// array). Modelled as real fields rather than raw `base + N` casts. All slots are the
// on-disk 4-byte offset width; the resolved pointers live in AepManager members
// (m_framePosData / m_groupFrameData) because a 64-bit pointer cannot be written back
// into a 4-byte slot.
struct AepIndexHeader {
    int16_t groupId;       // +0x00 stamped by readIndexFile
    int16_t reserved02;    // +0x02
    int32_t frameNamesOff; // +0x04 frame-name block -> (relocated) frame-position table
    int32_t reserved08;    // +0x08
    int32_t reserved0c;    // +0x0c
    int32_t layerNamesOff; // +0x10 layer-name block + ordinals -> (relocated) frame entries
    int32_t userNamesOff;  // +0x14 user-name block
};

class AepManager {
public:
    // The engine keeps one global scene manager (Ghidra: DAT @ PTR_DAT_00130484,
    // operator_new(0x7f3b18) ~8 MB with the ordering table at +0x727538). Reached
    // through a lazy accessor. Ghidra: FUN_0000f1ec (init FUN_00010b88).
    static AepManager &shared();

    // Load an .aep animation/scene resource into group slot `group`. `single`
    // picks
    // "<dir>/<name>.idx" (true) vs "<dir>/<sub>/<name>.idx" (false, `sub` =
    // name). Reads the index, uploads the texture, and copies the frame tables
    // in. Ghidra: loadAepData (FUN_0000f4b0). Returns true on success.
    bool loadAepData(int group, const char *dir, const char *name, bool single);

    /// @brief Load an .aep resource group from the manager's base directory.
    /// @details Convenience form of loadAepData using baseDir() and the single-file
    ///          "<baseDir>/<name>.idx" layout.
    /// @param group Destination group slot.
    /// @param name Resource base name (e.g. "title").
    /// @note Ghidra: AepManager::loadAepDataDefaultPath (FUN_0000f758).
    void loadAepDataDefaultPath(int group, const char *name);

    // Per-frame render: advances the active screen transition (fade in/out over
    // a timer) then draws the ordering table. Ghidra: FUN_0001058c.
    void draw();

    // Frame-clamp flags passed in `lyr`'s high-level draw call (Ghidra:
    // param_13).
    enum DrawFlags {
        kDrawLoop = 0x01,      // wrap the frame index modulo the layer length
        kDrawClampLast = 0x10, // clamp past-the-end to the last frame (else skip)
    };

    // Resolve a layer *name* within `group` to the encoded `lyr` value drawLayer
    // consumes (group slot in the high 16 bits, layer index in the low 16).
    // Asserts the name exists. Ghidra: getLyrNo FUN_0000fac8 (asserts at
    // AepManager.mm:0x1d0).
    int getLyrNo(int group, const char *name) const;

    // The number of frames in the layer `lyr` (its entry chain's frameEnd).
    // Ghidra: FUN_0000fb8c.
    int layerFrameCount(int lyr) const;

    // Resolve a *frame* resource name within `group` to its encoded handle (frame
    // index in the low 16 bits | slot byte in bits 16..23). Asserts the name
    // exists
    // ("getFrmNo", AepManager.mm:0x1bb). Ghidra: FUN_0000f9cc.
    int getFrameNo(int group, const char *name) const;

    // Resolve a *user*/sprite resource name within `group` to its index in the
    // group's user-frame table. Asserts the name exists ("getUsrNo",
    // AepManager.mm:0x1e4). Ghidra: FUN_0000fb40.
    int getUserNo(int group, const char *name) const;

    // Start a screen transition (fade). `mode` 1 = fade in, 2 = fade out (0 or
    // >=3 clears it); `frames` is its length in frames; `color` is the fade colour
    // (0x00RRGGBB; 0 = black) the overlay dips to. Ghidra: FUN_000106dc.
    void playTransition(int mode, int frames, int color);

    /// @brief Arm a screen transition with the standard fixed 30-frame duration.
    /// @details A fixed-length counterpart to playTransition used by most scenes:
    ///          a valid mode (0..2) sets the mode, resets both frame counters to 30,
    ///          and clears the fade colour to black; an invalid mode (>=3) disables
    ///          the transition (mode and frames set to 0).
    /// @param mode 0 = none, 1 = fade in, 2 = fade out; >=3 disables.
    /// @note Ghidra: AepManager::setAepTransitionMode (FUN_00010698).
    void setAepTransitionMode(int mode);

    // Scrub the *current* transition frame counter to `frame`, clamped to
    // [0, total]. This does not change the mode or total set by playTransition;
    // it just moves the fade to a given point (e.g. frame 0 == fully-faded for a
    // fade-out, since draw() derives alpha from frames/total). Ghidra:
    // FUN_00010758.
    void setTransitionFrame(int frame);

    // Whether the active transition has finished (no frames left, or none
    // active). Ghidra: FUN_00010730.
    bool isTransitionDone() const;

    // The active transition mode word (0 none, 1 fade in, 2 fade out) at
    // +0x7f3b04. Ghidra: getAepTransitionMode (FUN_00010724). Scenes poll it to
    // gate input during a fade.
    int transitionMode() const {
        return m_transitionMode;
    }

    // Draw one animated layer (the full FUN_0000fd64 signature). `lyr` encodes
    // the resource group in its high 16 bits and the layer index in its low 16
    // bits; `frame` is clamped/looped to the layer's length by `loopFlags` (bit0
    // = loop, bit4 = clampLast); the remaining args are the root transform /
    // colour / alpha / rotation / blend / clip threaded into the frame-tree fill.
    // Ghidra: FUN_0000fd64
    // -> AepDrawLayer (FUN_0000fe8c).
    // Argument order matches the binary's drawLayer (FUN_0000fd64) stack layout
    // exactly: loopFlags is at position 13 (read from [r7+0x28] for the loop/clamp
    // bit test), AFTER colorHi -- not right after rotation.
    void drawLayer(int lyr,
                   int frame,
                   int x,
                   int y,
                   int scaleX,
                   int scaleY,
                   int rotation,
                   int p9,
                   int p10,
                   int color,
                   int colorHi,
                   uint32_t loopFlags,
                   uint32_t blendFlags,
                   uint32_t p15,
                   int *clipRect,
                   void *context,
                   uint32_t p17,
                   uint32_t p19);

    // Compatibility overload: the scenes (MenuMainTask / PlayTask / AepLyrCtrl)
    // drive layers with just a resolved transform and the loop flags. It maps the
    // transform's x / y / sx / sy / rotation / priority into the full form
    // (colour/alpha = fully opaque, no clip override) and forwards.
    void drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags);

    /// @brief Queue a single-line text draw through the manager's ordering table.
    /// @details Forwards the string and the six positional / per-corner-colour
    ///          words to the OT text command (type 6) with no clip rect. x/y are
    ///          integer positions (Ghidra's `float` typing is a soft-float
    ///          artifact — the callers pass integer pen coordinates).
    /// @param text Null-terminated string to draw.
    /// @param x Pen x position.
    /// @param y Pen y position.
    /// @param cTL Top-left corner colour word.
    /// @param cTR Top-right corner colour word.
    /// @param cBL Bottom-left corner colour word.
    /// @param cBR Bottom-right corner colour word.
    /// @param priority Ordering-table draw priority.
    /// @note Ghidra: AepManager::DrawText (FUN_00010540).
    void DrawText(const char *text, int x, int y, int cTL, int cTR, int cBL, int cBR, int priority);

    /// @brief Queue a single-line text draw with an explicit clip rectangle.
    /// @details As DrawText, but threads the caller-supplied clip rect straight
    ///          through to the ordering-table text command.
    /// @param text Null-terminated string to draw.
    /// @param x Pen x position.
    /// @param y Pen y position.
    /// @param cTL Top-left corner colour word.
    /// @param cTR Top-right corner colour word.
    /// @param cBL Bottom-left corner colour word.
    /// @param cBR Bottom-right corner colour word.
    /// @param clip Clip rectangle (16-byte vector), or null for none.
    /// @param priority Ordering-table draw priority.
    /// @note Ghidra: AepManager::DrawTextClipped (FUN_0001057c).
    void DrawTextClipped(const char *text,
                         int x,
                         int y,
                         int cTL,
                         int cTR,
                         int cBL,
                         int cBR,
                         const void *clip,
                         int priority);

    AepOrderingTable *orderingTable() {
        return &m_ot;
    } // Ghidra: get_aepOt

    // Frame-tree fill accessors used by AepDrawLayer (FUN_0000fe8c) to reach the
    // per-group storage by resolved slot. Offsets are the manager object's.
    const AepFrameEntry *frameEntries(int slot) const {
        return m_groupFrameData[slot];
    } // +0x7f39c8
    const uint8_t *channelBase(int slot) const {
        // The keyframe-channel offsets stored in each AepFrameEntry are relative to
        // idxBase, i.e. the index proper at file + 4 (readIndexFile FUN_0000f770 skips
        // the 4-byte header: it returns bytes + 0x204 from a buffer based at +0x200).
        // The binary stores that idxBase pointer at +0x7274d4 and adds the channel
        // offsets to it; returning the bare file start (bytes + 0) shifts every
        // keyframe read by two int16s, so a static "sx = 100" scale reads back as 0.
        return (const uint8_t *)m_idxData[slot].bytes + 4;
    } // +0x7274d4
    const int16_t *spriteRecord(int slot, int idx) const {
        return &m_framePos[slot][idx].x;
    } // +0x7c1962 (stride 8)
    int screenWidth() const {
        return m_transitionOverlay[2];
    } // +0x7f3afc
    int screenHeight() const {
        return m_transitionOverlay[3];
    } // +0x7f3b00
    AepGroupDrawFn groupCallback(int slot) const {
        return m_groupCallback[slot];
    } // +0x7f3a2c
    void *groupContext(int slot) const {
        return m_groupContext[slot];
    } // +0x7f3a90

    // Resolve the group slot a sprite/layer handle addresses: the high 16 bits
    // index the byte group table @ this+0x7c1748. Ghidra: the lookup in the
    // note-quad draw FUN_0000fcd0 (`*(byte *)(this + (handle >> 0x10) +
    // 0x7c1748)`).
    int groupSlotForHandle(int handle) const {
        return m_groupIndex[(handle >> 16) & 0xff];
    }

    // Base resource directory the single-file loaders resolve against (Ghidra:
    // the char buffer @ this + 0x100).
    const char *baseDir() const {
        return m_baseDir;
    }

    /// @brief Release a group's loaded texture (its destructor drops the tiles).
    /// @param group Group slot to free.
    /// @note Ghidra: AepManager::releaseAepTexture (FUN_0000f988).
    void releaseAepTexture(int group);

    // The two screen-quad extents cached from the transition-overlay region (the
    // fade quad's width/height at this+0x7f3afc / +0x7f3b00). The play scene
    // reads them into its play data at build. Ghidra: FUN_0000f498 /
    // FUN_0000f4a4.
    int transitionOverlayWidth() const;
    int transitionOverlayHeight() const;

    // Register a per-frame draw callback for group `slot`: the play scene
    // installs its note-field render pass here at build time; the manager invokes
    // it (with the stored `context`) while drawing. Ghidra: FUN_0000f9b0 (stores
    // the callback at this + slot*4 + 0x7f3a2c and its context at + 0x7f3a90).
    void setGroupDrawCallback(int slot, AepGroupDrawFn callback, void *context);

private:
    // Resolve the frame-entry array for the group encoded in `lyr` (Ghidra: a
    // byte group-index table @ this+0x7c1748 selecting a per-group pointer @
    // +0x7f39c8).
    const AepFrameEntry *groupEntries(int lyr) const;

    // Walk `entries`[layerNo]'s chain (stride 0x24) to its last entry and return
    // its frameEnd (the layer's length). Ghidra: the shared loop in FUN_0000fd64
    // / FUN_0000fb8c.
    static int layerLength(const AepFrameEntry *entries, int layerNo);

    // Base resource directory (Ghidra: char buffer @ this + 0x100).
    char m_baseDir[256] = {};

    // The z-sorted draw list (Ghidra: @ this + 0x727538).
    AepOrderingTable m_ot;

    // Per-group loaded-resource storage. In the binary these are fixed-offset
    // regions of the ~8 MB manager object; here they are modelled as per-group
    // arrays. loadAepData() populates them; drawLayer()/getLyrNo() read them.
    static const int kMaxAepGroups = 32;    // MAX_IDXBUFSIZE slots (0x40000 each)
    static const int kMaxFrameData = 0x400; // MAX_FRAME_DATA per group

    // Loaded-resource tables (Ghidra: @ this + 0x7c1748 / +0x7f39c8). The byte
    // table maps a group id (lyr >> 16) to a slot; the pointer table gives that
    // slot's frame-entry array. Populated by loadAepData as resources load.
    uint8_t m_groupIndex[256] = {};                            // +0x7c1748 (group id -> slot)
    const AepFrameEntry *m_groupFrameData[kMaxAepGroups] = {}; // +0x7f39c8
    // Rebuild-only: the relocated frame-position table pointer per group. The 32-bit
    // binary rewrites the .idx header's 4-byte offset slot in place with the pointer;
    // on the 64-bit rebuild an 8-byte pointer cannot fit that slot, so relocateAepData
    // stores it here instead (see AepIndexHeader below).
    const int16_t *m_framePosData[kMaxAepGroups] = {};

    // Raw .idx file bytes per group (holds the frame tables the pointers above
    // reference). Ghidra: this + group*0x40000 + 0x200 (readIndexFile @
    // FUN_0000f770).
    NSData *m_idxData[kMaxAepGroups] = {};
    // The sprite/texture object each group's frames draw from (neTextureForiOS).
    // Ghidra: this + group*4 + 0x7c16e4.
    neTextureForiOS *m_groupTexture[kMaxAepGroups] = {};
    // 8-byte frame-position records copied out of the idx (Ghidra: @ 0x7c1962,
    // stride 8, bounded by MAX_FRAME_DATA). x / y / span / h.
    struct AepFramePos {
        int16_t x, y, span, h;
    };
    AepFramePos m_framePos[kMaxAepGroups][kMaxFrameData] = {};
    int m_frameCount[kMaxAepGroups] = {}; // +0x7f3964 per group

    // Per-group frame-tree draw callback + context (Ghidra: this+slot*4+0x7f3a2c
    // and this+slot*4+0x7f3a90). setGroupDrawCallback installs them; AepDrawLayer
    // invokes the callback for type-3 frame entries.
    AepGroupDrawFn m_groupCallback[kMaxAepGroups] = {}; // +0x7f3a2c
    void *m_groupContext[kMaxAepGroups] = {};           // +0x7f3a90

    // Read "<path>" into m_idxData[group]; returns the parsed index base (the
    // bytes after the 4-byte header) or nil. Ghidra: readIndexFile
    // (FUN_0000f770).
    const uint8_t *readIndexFile(int group, NSString *path);

    // Layer-name -> index open-addressing hash table, one per group (Ghidra: the
    // 0x2ffc-byte-strided region @ this+0x68b19c). Ghidra: FUN_0000fa30 probes
    // it. Public type (the file-static build/probe helpers in AepManager.mm name
    // it); the per-group table instances below stay private.
public:
    // Queue the full-screen fade quad at the given opacity (Ghidra FUN_0001151c;
    // the former free drawAepTransitionOverlay wrapper FUN_00010530 just forwarded
    // here, so it is folded into this direct call).
    void drawTransitionOverlay(int alpha);

    // Initialise the manager against its resource paths and screen surface (copies
    // the base + data paths, seeds the identity transforms, hands the screen
    // extents + device scale to the ordering table). Ghidra: aepManagerInit
    // (FUN_0000f33c). Called once from MainViewController -loadView.
    void init(const char *basePath, const char *dataPath, int screenW, int screenH, float scale);

    struct NameHashTable {
        uint16_t value[2048];  // +0x0000 layer index stored per bucket
        const char *key[2047]; // +0x1000 name per bucket (null = empty slot)
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

    // Screen-transition (fade) state (Ghidra: @ this + 0x7f3af4..0x7f3b14).
    int m_transitionOverlay[4] = {}; // +0x7f3af4..0x7f3b00 overlay quad params
    int m_transitionMode = 0;        // +0x7f3b04  0 none, 1 fade in, 2 fade out
    int m_transitionFrames = 0;      // +0x7f3b08  frames remaining (counts down)
    int m_transitionTotal = 0;       // +0x7f3b0c  total frames of the transition
    int m_transitionColor = 0;       // +0x7f3b10  fade colour (0x00RRGGBB; 0 = black)
    int m_maxPriority = 0;           // +0x7f3b14  highest OT priority drawn last flush

    // Fix up (relocate) a freshly-loaded group's .idx name tables into the
    // per-group hash tables above. Ghidra: relocateAepData (FUN_0000f824); called
    // from loadAepData.
    void relocateData(int group, AepIndexHeader *header, const uint8_t *idxBase);
};

// The active transition mode (free-function form of
// AepManager::transitionMode()). Ghidra: getAepTransitionMode (FUN_00010724).
int getAepTransitionMode(const AepManager *mgr);

// Draw a multi-line ('\n'-separated) string vertically centred about `y`, one
// text command per line spaced `lineHeight` apart. Ghidra: drawAepTextMultiline
// (FUN_0002d8b0).
void drawAepTextMultiline(
    const char *text, int a0, int y, int a3, int a4, int lineHeight, int a6, int a7, int a8);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
