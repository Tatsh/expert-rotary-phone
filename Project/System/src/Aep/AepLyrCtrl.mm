//
//  AepLyrCtrl.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. A drawable Aep
//  layer/sprite: ctor FUN_0002c7d8, init-with-texture FUN_0002c834. init creates
//  a texture through the render manager and links the layer into the global layer
//  list (Ghidra: DAT_00188490).
//

#include <cassert>
#include <cmath>

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Intrusive doubly-linked list of all live layers (Ghidra: head @ DAT_00188490).
static AepLyrCtrl *s_layerListHead = nullptr;

// Ghidra: AepLyrCtrl_ctor (FUN_0002c7d8).
AepLyrCtrl::AepLyrCtrl()
    : m_prev(nullptr), m_next(nullptr), m_texId(-1), m_field10(0),
      m_x(0), m_y(0), m_z(0), m_width(100), m_height(100),
      m_grpA{0, 0, 0}, m_blend(0), m_lyr(-1), m_frameCount(0), m_frame(0),
      m_alpha(1.0f), m_grpC{0, 0, 0, 0}, m_flag55(false), m_playState(0),
      m_visible(false) {}

AepLyrCtrl::~AepLyrCtrl() {
    if (m_prev) m_prev->m_next = m_next;
    if (m_next) m_next->m_prev = m_prev;
    if (s_layerListHead == this) s_layerListHead = m_next;
}

// Base layer draw: overridden by concrete sprite subclasses. vtable @ 0x2c82c.
void AepLyrCtrl::draw() {}

// Ghidra: AepLyrCtrl_init (FUN_0002c834) — resolve the layer by (group, name)
// through the render manager and register in the active-layer list.
void AepLyrCtrl::init(int group, const char *name) {
    assert(group >= 0);           // AepLyrCtrl.mm:0x42
    assert(name != nullptr);
    AepManager &mgr = AepManager::shared();

    m_texId = group;
    m_field10 = 0;
    m_x = 0; m_y = 0; m_z = 0;
    m_width = 100; m_height = 100;
    m_grpA[0] = 0; m_grpA[1] = 0; m_grpA[2] = 0;
    m_blend = 0x20;

    m_lyr = mgr.getLyrNo(group, name);   // Ghidra: AepManager_getLyrNo
    assert(m_lyr >= 0);                  // AepLyrCtrl.mm:0x56
    m_frameCount = mgr.layerFrameCount(m_lyr);   // Ghidra: AepManager_layerFrameCount
    m_frame = 0;
    m_alpha = 1.0f;
    m_flag55 = false;
    m_visible = false;

    // Head-insert into the global layer list.
    m_prev = nullptr;
    m_next = s_layerListHead;
    if (s_layerListHead != nullptr) {
        s_layerListHead->m_prev = this;
    }
    s_layerListHead = this;
}

// Ghidra: AepLyrCtrl_play (FUN_0002caf8) — enter play state. A fully-faded layer
// (alpha <= 0) jumps to its last frame; otherwise it restarts at frame 0.
void AepLyrCtrl::play() {
    m_playState = 2;
    if (m_alpha <= 0.0f) {
        m_frame = m_frameCount - 1;
    } else {
        m_frame = 0;
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
