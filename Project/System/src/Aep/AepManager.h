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

    // Load an .aep animation/scene resource. Ghidra: loadAepData.
    void loadAepData(NSString *name);

    // Per-frame render: advances the active screen transition (fade in/out over
    // a timer) then draws the ordering table. Ghidra: FUN_0001058c.
    void draw();

    // Frame-clamp flags passed in `lyr`'s high-level draw call (Ghidra: param_13).
    enum DrawFlags {
        kDrawLoop      = 0x01,   // wrap the frame index modulo the layer length
        kDrawClampLast = 0x10,   // clamp past-the-end to the last frame (else skip)
    };

    // Draw one animated layer: `lyr` encodes the resource group in its high 16 bits
    // and the layer index in its low 16 bits; `frame` is clamped/looped to the
    // layer's length; `root` is the root transform threaded into the fill. Ghidra:
    // drawLayer FUN_0000fd64 -> AepDrawLayer (FUN_0000fe8c).
    void drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags);

    AepOrderingTable *orderingTable() { return &m_ot; }  // Ghidra: get_aepOt

private:
    // Resolve the frame-entry array for the group encoded in `lyr` (Ghidra: a byte
    // group-index table @ this+0x7c1748 selecting a per-group pointer @ +0x7f39c8).
    const AepFrameEntry *groupEntries(int lyr) const;

    // The z-sorted draw list (Ghidra: @ this + 0x727538).
    AepOrderingTable m_ot;

    // Loaded-resource tables (Ghidra: @ this + 0x7c1748 / +0x7f39c8). The byte
    // table maps a group id (lyr >> 16) to a slot; the pointer table gives that
    // slot's frame-entry array. Populated by loadAepData as resources load.
    const uint8_t *m_groupIndex = nullptr;               // +0x7c1748
    const AepFrameEntry *const *m_groupFrameData = nullptr;  // +0x7f39c8

    // Screen-transition (fade) state (Ghidra: @ this + 0x7f3af4..0x7f3b14).
    int m_transitionType = 0;         // 0 = none
    float m_transitionElapsed = 0;    // seconds into the current transition
    float m_transitionDuration = 0;   // total fade length
    AepLyrCtrl *m_transitionOverlay = nullptr;  // full-screen fade quad
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
