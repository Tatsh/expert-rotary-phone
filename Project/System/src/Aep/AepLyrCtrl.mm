//
//  AepLyrCtrl.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. A drawable
//  Aep layer/sprite: ctor FUN_0002c7d8, init-with-texture FUN_0002c834. init
//  creates a texture through the render manager and links the layer into the
//  global layer list (Ghidra: DAT_00188490).
//

#include <cassert>
#include <cmath>
#include <cstdint>

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Intrusive doubly-linked list of all live layers (Ghidra: head @
// DAT_00188490).
static AepLyrCtrl *s_layerListHead = nullptr;

// Ghidra: AepLyrCtrl_ctor (FUN_0002c7d8). The field types/offsets are
// byte-verified from the updateAndDrawAepLayers (0x2c924) disassembly; see
// AepLyrCtrl.h. The whole struct is reached through its named members now (the
// file-static lc* offset helpers are gone).
AepLyrCtrl::AepLyrCtrl()
    : m_prev(nullptr), m_next(nullptr), m_texId(-1), m_owner(nullptr), m_order(0), m_x(0), m_y(0),
      m_scaleX(100), m_scaleY(100), m_rotation(0), m_pad2a(0), m_p9(0), m_p10(0), m_blend(0),
      m_lyr(0), m_frameCount(0), m_frame(0), m_alpha(1.0f), m_clipRect{0, 0, 0, 0}, m_playState(0),
      m_visible(false), m_pad5a{0, 0}, m_finished(0), m_pad5d{0, 0, 0} {
}

AepLyrCtrl::~AepLyrCtrl() {
    if (m_prev) {
        m_prev->m_next = m_next;
    }
    if (m_next) {
        m_next->m_prev = m_prev;
    }
    if (s_layerListHead == this) {
        s_layerListHead = m_next;
    }
}

// Ghidra: AepLyrCtrl_unlink @ 0x2ca9c — splice this layer out of the global
// active list without destroying it (the owner deletes it afterward). Standard
// doubly-linked removal: patch the neighbours, and if this was the head (m_prev
// == null) advance it.
void AepLyrCtrl::unlink() {
    if (m_next) {
        m_next->m_prev = m_prev;
    }
    if (m_prev == nullptr) {
        s_layerListHead = m_next;
    } else {
        m_prev->m_next = m_next;
    }
}

// Base layer draw: overridden by concrete sprite subclasses. vtable @ 0x2c82c.
void AepLyrCtrl::draw() {
}

// Ghidra: AepLyrCtrl_init (FUN_0002c834) — resolve the layer by (group, name)
// through the render manager and register in the active-layer list. The binary
// form takes two extra args: `owner` stored at +0x10 and `order` (the
// ordering-priority word threaded into drawLayer as p17) stored raw into the
// +0x14 slot.
void AepLyrCtrl::init(int group, const char *name, void *owner, int order) {
    assert(group >= 0); // AepLyrCtrl.mm:0x42
    assert(name != nullptr);
    AepManager &mgr = AepManager::shared();

    m_texId = group;
    m_owner = owner; // +0x10 owner/context
    m_order = order; // +0x14 order word
    m_x = 0;
    m_y = 0;
    m_scaleX = 100;
    m_scaleY = 100;
    m_rotation = 0;
    m_p9 = 0;
    m_p10 = 0;
    m_blend = 0x20;

    m_lyr = mgr.getLyrNo(group, name);         // Ghidra: AepManager_getLyrNo
    assert(m_lyr >= 0);                        // AepLyrCtrl.mm:0x56
    m_frameCount = mgr.layerFrameCount(m_lyr); // Ghidra: AepManager_layerFrameCount
    m_frame = 0;
    m_alpha = 1.0f;
    m_clipRect[0] = 0;
    m_clipRect[1] = 0;
    m_clipRect[2] = 0;
    m_clipRect[3] = 0; // +0x48..0x54 (vst1 q8,#0)
    m_playState = 0;
    m_visible = false;

    // Head-insert into the global layer list.
    m_prev = nullptr;
    m_next = s_layerListHead;
    if (s_layerListHead != nullptr) {
        s_layerListHead->m_prev = this;
    }
    s_layerListHead = this;
}

// Convenience 2-arg form used by scenes that pass neither owner nor order.
void AepLyrCtrl::init(int group, const char *name) {
    init(group, name, nullptr, 0);
}

// Ghidra: AepLyrCtrl_play (FUN_0002caf8) — enter play state. A fully-faded
// layer (alpha <= 0) jumps to its last frame; otherwise it restarts at frame 0.
void AepLyrCtrl::play() {
    m_playState = 2;
    if (m_alpha <= 0.0f) {
        m_frame = static_cast<float>(m_frameCount - 1); // seek to last frame
    } else {
        m_frame = 0.0f;
    }
}

// Ghidra: aepLyrCtrlStop (FUN_0002cb24) — enter the once-to-idle play state
// (3). Only when `keepVisible == 1` does it seek the play head (to the last
// frame for a reverse rate, otherwise to frame 0); any other value leaves the
// play head where it is.
void AepLyrCtrl::stop(int keepVisible) {
    m_playState = 3;
    if (keepVisible != 1) {
        return;
    }
    if (m_alpha <= 0.0f) {
        m_frame = static_cast<float>(m_frameCount - 1);
    } else {
        m_frame = 0.0f;
    }
}

// Ghidra: aepLyrCtrlReset (FUN_0002cb5c) — clear the play state (+0x58 = 0),
// stopping the layer's animation without unlinking it.
void AepLyrCtrl::reset() {
    m_playState = 0;
}

// Ghidra: FUN_0002cb64 — still-animating predicate. `(playState | 4) == 4` is
// true for the idle (0) and held (4) states; otherwise the float play head at
// +0x40 is compared against its travel: a reverse rate (+0x44 <= 0) animates
// while the head is > 0, a forward rate while the head is < the layer length
// (+0x3c).
bool AepLyrCtrl::isAnimating() const {
    if ((static_cast<unsigned>(m_playState) | 4u) == 4u) { // idle (0) or held (4)
        return false;
    }
    const int frame = static_cast<int>(m_frame); // vcvt.s32.f32: truncate to int
    if (m_alpha <= 0.0f) {                       // reverse rate
        return frame > 0;
    }
    return frame < m_frameCount;
}

// Ghidra: FUN_0002c924 (updateAndDrawAepLayers). Walk the global live-layer list
// and, for every layer whose play state (+0x58) is non-zero, draw it at its
// current frame through AepManager::drawLayer, then (unless drawOnly) step the
// frame by its signed rate (+0x44) and apply the per-play-mode end handling.
// The drawLayer argument threading and the state machine below are
// byte-verified from the disassembly at 0x2c958..0x2ca82.
void updateAndDrawAepLayers(int drawOnly) {
    AepManager &mgr = AepManager::shared(); // Ghidra: AepManager_shared (FUN_0000f1ec)

    for (AepLyrCtrl *l = s_layerListHead; l != nullptr; l = l->m_next) {
        const int playState = l->m_playState;
        if (playState == 0) {
            continue;
        }

        // Clip/root arg: the four-word clip rect (m_clipRect) is threaded only when
        // both gate words +0x50/+0x54 (m_clipRect[2]/[3]) are positive, else no
        // clip.
        int *root = nullptr;
        if (l->m_clipRect[2] >= 1 && l->m_clipRect[3] > 0) {
            root = l->m_clipRect;
        }

        // Frame index handed to drawLayer: the float play head truncated to int
        // (vcvt.s32.f32). Constants (byte-verified from the bl @ 0x2c9ce):
        // loopFlags=8, color=100, colorHi=0, p15=0xffffff, p19=1.
        const int frame = static_cast<int>(l->m_frame);
        mgr.drawLayer(l->m_lyr,
                      frame,
                      l->m_x,
                      l->m_y,
                      l->m_scaleX,
                      l->m_scaleY,
                      static_cast<int>(l->m_rotation),
                      8, // loopFlags (kDrawClampLast)
                      l->m_p9,
                      l->m_p10,
                      100,
                      0, // color / colorHi
                      static_cast<uint32_t>(static_cast<unsigned short>(l->m_blend)),
                      0x00ffffff, // p15
                      root,
                      l->m_owner,                        // context
                      static_cast<uint32_t>(l->m_order), // p17
                      1);                                // p19

        if (playState == 4 || drawOnly != 0) {
            continue; // held frame, or draw-only pass: do not advance
        }

        // Advance the play head by the signed rate and apply the end handling per
        // mode.
        const float rate = l->m_alpha;
        const float newFrame = l->m_frame + rate;
        l->m_frame = newFrame;
        const int frameCount = l->m_frameCount;

        if (rate > 0.0f) {                                  // forward
            if (static_cast<int>(newFrame) >= frameCount) { // reached the end
                if (playState == 3) {                       // once, stop to idle
                    l->m_frame = static_cast<float>(frameCount - 1);
                    l->m_playState = 0;
                    l->m_finished = 1;
                } else if (playState == 2) { // loop, wrap to start
                    l->m_frame = 0.0f;
                } else if (playState == 1) { // once, hold at last frame
                    l->m_frame = static_cast<float>(frameCount - 1);
                    l->m_playState = 4;
                    l->m_finished = 1;
                }
            }
        } else {                      // reverse (rate <= 0)
            if (newFrame <= 0.0f) {   // reached the start
                if (playState == 3) { // once, stop to idle
                    l->m_frame = 0.0f;
                    l->m_playState = 0;
                    l->m_finished = 1;
                } else if (playState == 2) { // loop, wrap to the end
                    l->m_frame = static_cast<float>(frameCount - 1);
                } else if (playState == 1) { // once, hold at frame 0
                    l->m_frame = 0.0f;
                    l->m_playState = 4;
                    l->m_finished = 1;
                }
            }
        }
    }
}
