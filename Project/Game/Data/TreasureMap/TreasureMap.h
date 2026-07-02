//
//  TreasureMap.h
//  pop'n rhythmin
//
//  The parsed sugoroku (board-game) map: a table of board squares ("nodes"/areas)
//  plus a few header fields, loaded from a bundled "map_%03d.map" blob. The arcade
//  task (AcMainTask::loadTreasureMap, Ghidra FUN_000a0b58) news one of these per
//  goal, loads it, then reads its node bounding box to place + clamp the scroll.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_000ce2b0 zeroes 0x60 bytes; parser FUN_000ce340; area lookup
//  FUN_000ce934; destructor FUN_000ce330). Only the offsets the arcade scene reads
//  are byte-verified and named; the rest of the 0x60-byte object is kept as padding.
//

#pragma once

#include <cstdint>

class TreasureMap {
public:
    // Ghidra: FUN_000ce2b0 — zero-inits the 0x60-byte object (the member
    // initialisers below reproduce the five zeroed 16-byte stores).
    TreasureMap() = default;
    // Ghidra: FUN_000ce330 (+ pre-step FUN_000ce2e4); `delete` frees it. Kept as a
    // declared seam (the parser module owns the definition).
    ~TreasureMap();

    // Parse "<path>" (a bundled ".map" blob) into the node table + header fields.
    // Large binary parser kept as a declared seam. Ghidra: FUN_000ce340.
    void load(const char *path);

    // One board square. id is the sub-map id; x / y are the board column / row in
    // tile units (the scene multiplies by the 0x1a == 26 px tile size). The record
    // is 0x120 bytes in the file image (stride verified in FUN_000ce934); only the
    // leading id/x/y are read by the arcade scene.
    struct Node {
        int16_t id;                 // +0x00
        int16_t x;                  // +0x02
        int16_t y;                  // +0x04
        uint8_t _rest[0x120 - 6];   // +0x06.. (unread board metadata)
    };

    int nodeCount() const { return m_count; }        // +0x02
    const Node *nodes() const { return m_nodes; }     // +0x50

    // The node whose id matches subId, scanning the whole table, or null. Ghidra:
    // FUN_000ce934 (null when subId >= count or count < 1).
    const Node *findArea(int subId) const {
        if (!m_nodes) {
            return nullptr;
        }
        const int n = m_count;
        if (subId >= n || n < 1) {
            return nullptr;   // FUN_000ce934: out of range / empty table
        }
        const Node *node = m_nodes;
        for (int i = 0; i < n; i++, node++) {
            if ((uint16_t)node->id == (uint16_t)subId) {
                return node;
            }
        }
        return nullptr;
    }

    int16_t startSubId() const { return m_startSubId ? *m_startSubId : 0; } // *(+0x54)
    int     field58()    const { return m_field58; }  // +0x58 (copied to play data +0x4b8)
    int16_t field5c()    const { return m_field5c; }  // +0x5c (copied to play data +0x4c6)

private:
    // Byte-exact layout to alignment 4 (offsets verified in FUN_000ce2b0/340/934).
    uint8_t  m_head[2]       = {};       // +0x00
    int16_t  m_count         = 0;        // +0x02 node count
    uint8_t  m_pad04[0x50-4] = {};       // +0x04
    Node    *m_nodes         = nullptr;  // +0x50 node array base (stride 0x120)
    int16_t *m_startSubId    = nullptr;  // +0x54 default/start node id source
    int      m_field58       = 0;        // +0x58
    int16_t  m_field5c       = 0;        // +0x5c
    uint8_t  m_tail[0x60-0x5e] = {};     // +0x5e
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
