//
//  AepOrderingTable.h
//  pop'n rhythmin
//
//  The z-sorted draw list of the Aep 2D scene: layers are drawn back-to-front in
//  ordering-table order. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (strings: drawLayer / get_aepOt).
//
//  ARCHITECTURE NOTE (correction): the binary's ordering table is NOT a persistent
//  list of layer objects — it is a PER-FRAME COMMAND BUFFER. get_aepOt (allocEntry,
//  FUN_00010be0) hands out up to OT_REGIST_MAX (2047) fixed entries of 0x134 bytes,
//  bucketed into OT_PRI_MAX (50) priority lists (bucket heads @ play-data +0x9a0dc).
//  Each frame: the buffer is reset, drawLayer/FUN_000113d0 fill entries (position,
//  uv, color, scale in the 0x50-byte payload at entry+0xc), and a batch flush walks
//  the buckets high->low priority issuing GL quads via neGLES_11. The vector model
//  below is a SIMPLIFICATION pending reconstruction of that command buffer + flush.
//

#pragma once

#include <vector>

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

private:
    std::vector<AepLyrCtrl *> m_layers;   // ordered (back-to-front) draw list
    int m_drawnCount = 0;                 // layers drawn on the last pass
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
