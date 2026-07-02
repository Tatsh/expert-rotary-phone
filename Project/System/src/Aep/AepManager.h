//
//  AepManager.h
//  pop'n rhythmin
//
//  The Aep 2D scene manager: owns the ordering table, drives screen-transition
//  fades, and is the sprite/texture factory the graphics manager creates through.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NOTE: the concrete object is very large — it embeds the ordering table
//  (@ +0x727538) and the full set of texture/sprite slots, so it behaves as the
//  global scene. Only the public surface is modeled here; the storage arrays are
//  reconstructed progressively.
//

#pragma once

#import <Foundation/Foundation.h>

#include "AepFrameDraw.h"
#include "AepOrderingTable.h"

class AepManager {
public:
    // The engine keeps one global scene manager (Ghidra: DAT @ PTR_DAT_00130484,
    // operator_new(0x7f3b18) ~8 MB with the ordering table at +0x727538). Reached
    // through a lazy accessor. Ghidra: FUN_0000f1ec (init FUN_00010b88).
    static AepManager &shared();

    // Load an .aep animation/scene resource into group slot `group`. `single` picks
    // "<dir>/<name>.idx" (true) vs "<dir>/<sub>/<name>.idx" (false, `sub` = name).
    // Reads the index, uploads the texture, and copies the frame tables in.
    // Ghidra: loadAepData (FUN_0000f4b0). Returns true on success.
    bool loadAepData(int group, const char *dir, const char *name, bool single);

    // Per-frame render: advances the active screen transition (fade in/out over
    // a timer) then draws the ordering table. Ghidra: FUN_0001058c.
    void draw();

    // Frame-clamp flags passed in `lyr`'s high-level draw call (Ghidra: param_13).
    enum DrawFlags {
        kDrawLoop      = 0x01,   // wrap the frame index modulo the layer length
        kDrawClampLast = 0x10,   // clamp past-the-end to the last frame (else skip)
    };

    // Resolve a layer *name* within `group` to the encoded `lyr` value drawLayer
    // consumes (group slot in the high 16 bits, layer index in the low 16). Asserts
    // the name exists. Ghidra: getLyrNo FUN_0000fac8 (asserts at AepManager.mm:0x1d0).
    int getLyrNo(int group, const char *name) const;

    // The number of frames in the layer `lyr` (its entry chain's frameEnd).
    // Ghidra: FUN_0000fb8c.
    int layerFrameCount(int lyr) const;

    // Start a screen transition (fade). `mode` 1 = fade in, 2 = fade out (0 or >=3
    // clears it); `frames` is its length in frames; `flag` selects the overlay.
    // Ghidra: FUN_000106dc.
    void playTransition(int mode, int frames, int flag);

    // Whether the active transition has finished (no frames left, or none active).
    // Ghidra: FUN_00010730.
    bool isTransitionDone() const;

    // Draw one animated layer: `lyr` encodes the resource group in its high 16 bits
    // and the layer index in its low 16 bits; `frame` is clamped/looped to the
    // layer's length; `root` is the root transform threaded into the fill. Ghidra:
    // drawLayer FUN_0000fd64 -> AepDrawLayer (FUN_0000fe8c).
    void drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags);

    AepOrderingTable *orderingTable() { return &m_ot; }  // Ghidra: get_aepOt

    // Base resource directory the single-file loaders resolve against (Ghidra: the
    // char buffer @ this + 0x100).
    const char *baseDir() const { return m_baseDir; }

    // Drop a group's loaded texture (Ghidra: FUN_0000f988).
    void unloadGroup(int group);

private:
    // Resolve the frame-entry array for the group encoded in `lyr` (Ghidra: a byte
    // group-index table @ this+0x7c1748 selecting a per-group pointer @ +0x7f39c8).
    const AepFrameEntry *groupEntries(int lyr) const;

    // Walk `entries`[layerNo]'s chain (stride 0x24) to its last entry and return
    // its frameEnd (the layer's length). Ghidra: the shared loop in FUN_0000fd64 /
    // FUN_0000fb8c.
    static int layerLength(const AepFrameEntry *entries, int layerNo);

    // Queue the full-screen fade quad at the given opacity. Ghidra: FUN_0001151c.
    void drawTransitionOverlay(int alpha);

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
    uint8_t m_groupIndex[256] = {};                      // +0x7c1748 (group id -> slot)
    const AepFrameEntry *m_groupFrameData[kMaxAepGroups] = {};  // +0x7f39c8

    // Raw .idx file bytes per group (holds the frame tables the pointers above
    // reference). Ghidra: this + group*0x40000 + 0x200 (readIndexFile @ FUN_0000f770).
    NSData *m_idxData[kMaxAepGroups] = {};
    // The sprite/texture object each group's frames draw from (neTextureForiOS).
    // Ghidra: this + group*4 + 0x7c16e4.
    neTextureForiOS *m_groupTexture[kMaxAepGroups] = {};
    // 8-byte frame-position records copied out of the idx (Ghidra: @ 0x7c1962,
    // stride 8, bounded by MAX_FRAME_DATA). x / y / span / h.
    struct AepFramePos { int16_t x, y, span, h; };
    AepFramePos m_framePos[kMaxAepGroups][kMaxFrameData] = {};
    int m_frameCount[kMaxAepGroups] = {};                // +0x7f3964 per group

    // Read "<path>" into m_idxData[group]; returns the parsed index base (the bytes
    // after the 4-byte header) or nil. Ghidra: readIndexFile (FUN_0000f770).
    const uint8_t *readIndexFile(int group, NSString *path);

    // Layer-name -> index open-addressing hash table, one per group (Ghidra: the
    // 0x2ffc-byte-strided region @ this+0x68b19c). Ghidra: FUN_0000fa30 probes it.
    struct NameHashTable {
        uint16_t value[2048];    // +0x0000 layer index stored per bucket
        const char *key[2047];   // +0x1000 name per bucket (null = empty slot)
    };
    const NameHashTable *m_groupNames = nullptr;         // +0x68b19c (per-group)
    const uint8_t *m_groupSlot = nullptr;                // +0x7c1948 (per-group high byte)
    const uint16_t *m_layerNumbers = nullptr;            // +0x7210d4 (per-group, 256 stride)

    // Screen-transition (fade) state (Ghidra: @ this + 0x7f3af4..0x7f3b14).
    int m_transitionOverlay[4] = {};  // +0x7f3af4..0x7f3b00 overlay quad params
    int m_transitionMode = 0;         // +0x7f3b04  0 none, 1 fade in, 2 fade out
    int m_transitionFrames = 0;       // +0x7f3b08  frames remaining (counts down)
    int m_transitionTotal = 0;        // +0x7f3b0c  total frames of the transition
    int m_transitionFlag = 0;         // +0x7f3b10  overlay selector
    int m_maxPriority = 0;            // +0x7f3b14  highest OT priority drawn last flush
};

// Load / unload a named Aep resource group into a manager slot (the title/menu/play
// scenes swap their layer groups this way). Ghidra: FUN_0000f758 / FUN_0000f988.
void AepLoadGroup(AepManager *aep, int slot, const char *name);
void AepUnloadGroup(AepManager *aep, int slot);

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
