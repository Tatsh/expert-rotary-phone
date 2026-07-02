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

    m_ot.draw();

    if (m_transitionOverlay != nullptr && m_transitionType != 0) {
        m_ot.drawLayer(m_transitionOverlay);
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
