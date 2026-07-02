//
//  AepOrderingTable.h
//  pop'n rhythmin
//
//  The z-sorted draw list of the Aep 2D scene: layers are drawn back-to-front in
//  ordering-table order. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (strings: drawLayer / get_aepOt).
//

#pragma once

class AepLyrCtrl;

class AepOrderingTable {
public:
    AepOrderingTable();
    ~AepOrderingTable();

    // Insert a layer at its ordering slot.
    void addLayer(AepLyrCtrl *layer);

    // Draw every layer in order (issues the GL draw calls via neGLES_11).
    // Ghidra: FUN_000115d0
    void draw();

    // Number of layers drawn on the last pass. Ghidra: FUN_000117dc
    int drawnCount();

    // Draw a single layer (used by AepManager for the transition overlay).
    void drawLayer(AepLyrCtrl *layer);

    void clear();
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
