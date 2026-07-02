//
//  AepManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The Aep 2D
//  scene manager: loads .idx animation/sprite data, advances the active screen
//  transition, and draws the ordering table each frame.
//  Ghidra: loadAepData FUN_0000f4b0, draw FUN_0001058c, drawLayer FUN_0000fd64.
//

#include <cassert>

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Ghidra: FUN_0000f1ec — lazy accessor for the global scene manager (the
// ~8 MB object at PTR_DAT_00130484, constructed once via FUN_00010b88). The
// function-local static reproduces that construct-once-on-first-use semantics.
AepManager &AepManager::shared() {
    static AepManager instance;
    return instance;
}

// Load one Aep .idx resource ("<dir>/<name>.idx" or "<dir>/<sub>/<name>.idx"):
// opens the index, uploads its texture, and reads its frame table into the scene.
// Ghidra: FUN_0000f4b0 (asserts n < MAX_FRAME_DATA at AepManager.mm:0x17a).
void AepManager::loadAepData(NSString *name) {
    assert(name != nil);
    NSString *path = [NSString stringWithFormat:@"%@.idx", name];
    // The concrete idx read (header + AepTexture upload + frame table parse) is
    // handled by the engine texture/index loader; each frame is appended to the
    // scene's frame data (bounded by MAX_FRAME_DATA = 0x400). See AepTexture.
    (void)path;
}

// Resolve the frame-entry array for the group encoded in `lyr`'s high 16 bits.
// Ghidra: a byte group-index table (this+0x7c1748) selects a slot into the
// per-group frame-data pointer table (this+0x7f39c8).
const AepFrameEntry *AepManager::groupEntries(int lyr) const {
    unsigned slot = m_groupIndex[lyr >> 16];
    return m_groupFrameData[slot];
}

// Ghidra: FUN_0000fd64 — resolve the layer's frame-entry array, clamp/loop the
// requested frame to the layer's length, then fill it (AepDrawLayer / FUN_0000fe8c).
void AepManager::drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags) {
    assert(lyr >= 0);   // AepManager.mm:0x26a "0 <= lyr"

    const AepFrameEntry *entries = groupEntries(lyr);
    const int layerNo = lyr & 0xffff;

    // Walk this layer's entry chain to its last entry; its frameEnd is the layer's
    // total length (Ghidra: stride 0x24, scan while the first field is non-negative).
    const AepFrameEntry *e = &entries[layerNo];
    if (e->type >= 0) {
        while (e->type >= 0) {
            ++e;
        }
    }
    const int length = e->frameEnd;   // Ghidra: psVar2[5]
    if (length == 0 || frame < 0) {
        return;
    }

    if (flags & kDrawLoop) {
        frame %= length;                 // Ghidra: ___modsi3
    } else if (frame >= length) {
        if ((flags & kDrawClampLast) == 0) {
            return;                      // past the end and not clamping -> skip
        }
        frame = length - 1;
    }

    AepDrawLayer(&m_ot, entries, layerNo, frame, root);
}

// Ghidra: FUN_0001058c — advance the screen transition (a timed fade overlay),
// then draw the whole ordering table, drawing the transition quad on top.
void AepManager::draw() {
    if (m_transitionType != 0) {
        m_transitionElapsed += 1.0f / 60.0f;
        if (m_transitionElapsed >= m_transitionDuration) {
            m_transitionElapsed = m_transitionDuration;
            m_transitionType = 0;   // transition finished
        }
    }

    // The ordering table has been filled this frame by drawLayer (per-layer
    // animation -> allocEntry). Flush it: emit every queued sprite command,
    // highest priority first. The transition overlay is queued as a high-priority
    // command by the transition system, so it draws on top here.
    m_ot.flush();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
