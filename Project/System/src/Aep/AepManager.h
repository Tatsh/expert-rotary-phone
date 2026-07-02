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

#include "AepOrderingTable.h"

class AepManager {
public:
    // Load an .aep animation/scene resource. Ghidra: loadAepData.
    void loadAepData(NSString *name);

    // Per-frame render: advances the active screen transition (fade in/out over
    // a timer) then draws the ordering table. Ghidra: FUN_0001058c.
    void draw();

    AepOrderingTable *orderingTable() { return &m_ot; }  // Ghidra: get_aepOt

private:
    // The z-sorted draw list (Ghidra: @ this + 0x727538).
    AepOrderingTable m_ot;

    // Screen-transition (fade) state (Ghidra: @ this + 0x7f3af4..0x7f3b14).
    int m_transitionType = 0;         // 0 = none
    float m_transitionElapsed = 0;    // seconds into the current transition
    float m_transitionDuration = 0;   // total fade length
    AepLyrCtrl *m_transitionOverlay = nullptr;  // full-screen fade quad
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
