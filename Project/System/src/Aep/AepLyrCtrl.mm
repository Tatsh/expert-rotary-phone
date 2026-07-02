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

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Render-manager hooks: the global AepManager singleton owns the texture slots.
// Cited by Ghidra address; reconstructed alongside AepManager.
AepManager *neRenderManagerShared();                                // FUN_0000f1ec
int neRenderCreateTexture(AepManager *mgr, int group, const char *name);  // FUN_0000fac8
int neRenderNextLayerId(AepManager *mgr);                           // FUN_0000fb8c

// Intrusive doubly-linked list of all live layers (Ghidra: head @ DAT_00188490).
static AepLyrCtrl *s_layerListHead = nullptr;

// Ghidra: FUN_0002c7d8.
AepLyrCtrl::AepLyrCtrl()
    : m_prev(nullptr), m_next(nullptr), m_texId(-1), m_field10(0),
      m_x(0), m_y(0), m_z(0), m_width(100), m_height(100),
      m_grpA{0, 0, 0}, m_grpB{0, 0, 0}, m_alpha(1.0f),
      m_grpC{0, 0, 0, 0}, m_flag55(false), m_visible(false) {}

AepLyrCtrl::~AepLyrCtrl() {
    if (m_prev) m_prev->m_next = m_next;
    if (m_next) m_next->m_prev = m_prev;
    if (s_layerListHead == this) s_layerListHead = m_next;
}

// Base layer draw: overridden by concrete sprite subclasses. vtable @ 0x2c82c.
void AepLyrCtrl::draw() {}

// Ghidra: FUN_0002c834 — bind a texture (group + resource name) and register.
void AepLyrCtrl::init(int group, const char *name) {
    assert(group >= 0);           // AepLyrCtrl.mm:0x42
    assert(name != nullptr);
    AepManager *mgr = neRenderManagerShared();

    m_texId = group;
    m_field10 = 0;
    m_x = 0; m_y = 0; m_z = 0;
    m_width = 100; m_height = 100;
    m_grpA[0] = 0; m_grpA[1] = 0; m_grpA[2] = 0;

    int tex = neRenderCreateTexture(mgr, group, name);
    assert(tex >= 0);             // AepLyrCtrl.mm:0x56
    (void)neRenderNextLayerId(mgr);
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

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
