//
//  AepOrderingTable.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The z-sorted
//  draw list of the Aep 2D scene: layers are held back-to-front and drawn in
//  order each frame. Ghidra: draw FUN_000115d0, drawnCount FUN_000117dc.
//

#include <algorithm>

#import "AepLyrCtrl.h"
#import "AepOrderingTable.h"

AepOrderingTable::AepOrderingTable() = default;
AepOrderingTable::~AepOrderingTable() = default;

// Insert a layer keeping the list sorted back-to-front by z.
// Modeled: no dedicated Ghidra function — in the binary a layer self-registers
// into the global intrusive list (DAT_00188490) from AepLyrCtrl::init (0x2c834).
void AepOrderingTable::addLayer(AepLyrCtrl *layer) {
    auto pos = std::lower_bound(m_layers.begin(), m_layers.end(), layer,
                                [](AepLyrCtrl *a, AepLyrCtrl *b) { return a->z() < b->z(); });
    m_layers.insert(pos, layer);
}

// Ghidra: FUN_000115d0 — draw every visible layer in order.
void AepOrderingTable::draw() {
    m_drawnCount = 0;
    for (auto *layer : m_layers) {
        if (layer->isVisible()) {
            layer->draw();
            m_drawnCount++;
        }
    }
}

// Ghidra: FUN_000117dc.
int AepOrderingTable::drawnCount() {
    return m_drawnCount;
}

// Draw a single layer (the transition overlay). Modeled helper; the binary's
// per-layer draw is AepManager::drawLayer (FUN_0000fd64) -> FUN_0000fe8c.
void AepOrderingTable::drawLayer(AepLyrCtrl *layer) {
    if (layer != nullptr && layer->isVisible()) {
        layer->draw();
    }
}

// Modeled: no dedicated Ghidra function (resets the reconstructed layer list).
void AepOrderingTable::clear() {
    m_layers.clear();
    m_drawnCount = 0;
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
