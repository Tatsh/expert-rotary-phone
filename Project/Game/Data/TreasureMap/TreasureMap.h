//
//  TreasureMap.h
//  pop'n rhythmin
//
//  The parsed sugoroku (board-game) map: a table of board squares ("nodes"/areas)
//  plus a few header fields, loaded from a bundled "map_%03d.map" blob. The arcade
//  task (AcMainTask::loadTreasureMap, Ghidra charaSelectReloadData @ 0xa0b58) news one of these per
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
    // tile units (the scene multiplies by the 0x1a == 26 px tile size). The in-memory
    // record is 0x120 bytes (stride verified in FUN_000ce934); the file image packs
    // the same square into 0xaa bytes (see load()). The parser (FUN_000ce340) fills
    // the leading five int16 fields verbatim from the file, resolves the neighbour ids
    // into real Node pointers, and decodes the message text. The ObjC value-type name
    // the binary uses for this record is "SquareStruct".
    //
    // NOTE: pointer members below are 4 bytes on the game's 32-bit (ILP32) target,
    // which is what keeps the 0x120 stride exact — the same assumption the enclosing
    // class layout (m_nodes @ +0x50, m_startSubId @ +0x54, ...) already relies on.
    struct Node {
        int16_t id;          // +0x00 sub-map id
        int16_t x;           // +0x02 board column (tile units)
        int16_t y;           // +0x04 board row (tile units)
        int16_t type;        // +0x06 square kind: -1 invalid (asserts), 0 start,
                             //        2 deactivated bonus, 10 active bonus treasure
        int16_t field8;      // +0x08 copied verbatim from the file record
        int16_t _pad0a;      // +0x0a (zeroed; file neighbour ids are not stored here)
        Node   *backLink;    // +0x0c neighbour resolved from file record +0x0a
        Node   *links[3];    // +0x10 neighbours resolved from file record +0x0c/0e/10
        char    text[0x100]; // +0x1c ShiftJIS->UTF8 message ("<br>" -> newline)
        uint8_t _rest[4];    // +0x11c pad to the 0x120 stride
    };

    // A resolved board edge between two squares. Built into the +0x58 array by load();
    // the binary boxes it in NSValue with the ObjC type encoding
    // "{ConnectStruct=^{SquareStruct}^{SquareStruct}B}" (12 bytes: two Node* + a BOOL).
    struct ConnectStruct {
        Node *a;        // +0x00
        Node *b;        // +0x04
        bool  sameRow;  // +0x08 a->y == b->y
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
    // +0x58 is the malloc'd ConnectStruct edge array (its raw pointer bits are what the
    // arcade scene copies into play data +0x4b8); +0x5c is that array's element count
    // (copied to play data +0x4c6). Kept as int/int16_t to match the fields the scene
    // reads; edges()/edgeCount() re-expose them with their real meaning.
    int     field58()    const { return m_field58; }  // +0x58
    int16_t field5c()    const { return m_field5c; }  // +0x5c
    const ConnectStruct *edges() const {
        return reinterpret_cast<const ConnectStruct *>((intptr_t)m_field58);
    }
    int edgeCount() const { return m_field5c; }

private:
    // Ghidra: FUN_000ce2e4 — free the owned node table (+0x50) and edge array (+0x58),
    // then zero the whole 0x60-byte object. Shared by load() (clear-before-parse) and
    // the destructor.
    void reset();

    // Linear id -> Node* lookup used by load()'s neighbour resolution (the inline
    // search in FUN_000ce340). Null for a negative / out-of-range id or an empty table.
    Node *findNodeById(int id) const;

    // Free helpers in TreasureMap.mm that need private member access (m_nodes,
    // m_count, m_startSubId). Ghidra: FUN_000ce96c, FUN_000ce9d4.
    friend Node *GetWarpSquare(TreasureMap *map, Node *node);
    friend Node *getButtobiSquare(TreasureMap *map, const Node *currentNode);

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

// ──────────────────────────────────────────────────────────────────────────────
// Free sugoroku-map C helpers (binary cluster ~0xce000, defined in TreasureMap.mm).
// ──────────────────────────────────────────────────────────────────────────────

// Ghidra: FUN_000ce0ec
// If checkBackLink != 0: returns 1 when node->backLink is non-null, else 0.
// If checkBackLink == 0: counts non-null slots in node->links[0..2] (stop at first null).
unsigned int countSquareLinks(const TreasureMap::Node *node, int checkBackLink);

// Ghidra: FUN_000ce114
// Searches node->links[0..2] for a neighbour that lies in the given cardinal direction
// relative to node (0=left, 1=right, 2=up, 3=down, same-axis coordinate must match).
// Returns the slot index (0..2) of the matching link, or -1 if not found.
int findAdjacentSquareIndex(const TreasureMap::Node *node, int direction);

// Ghidra: FUN_000ce180
// Indexes kTreasureMapTable[mainMapId][subMapId] (DAT_0012fac4, row stride 0xc).
// Returns the earned goal-star count for the given map/area pair.
int getTreasureMapTableEntry(int mainMapId, int subMapId);

// Ghidra: FUN_000ce198
// Returns kParentMapTable[mapId] (DAT_0012fb30) — parent main-map id, -1 for roots.
int getTreasureMapValue_fb30(int mapId);

// Ghidra: getCharacterAssetCount @ 0xce1a8 (address-sweep fix: 0xce1c8 was mid-body)
// Returns the number of character message strings for the given character id.
// characterId encodes: group = id/10 (valid: 6, 8), slot = id%10 (valid: 0..2).
// Called by both getCharacterAssetName and charaSelectReloadData.
int getCharacterAssetCount(int characterId);

// Ghidra: FUN_000ce200
// Returns a UTF-8 character message string from the baked pool for the given
// (characterId, slotIndex). slotIndex must be in [0, getCharacterAssetCount(characterId)).
// Returns null for out-of-range or unrecognised ids.
const char *getCharacterAssetName(int characterId, int slotIndex);

// Ghidra: FUN_000ce96c  (SugorokuMap::GetWarpSquare)
// Asserts node->type == 8 (warp square), then returns the OTHER warp square in map
// that shares the same field8 (warp-pair id). Returns null if none found.
TreasureMap::Node *GetWarpSquare(TreasureMap *map, TreasureMap::Node *node);

// Ghidra: FUN_000ce9d4  (SugorokuMap::GetButtobiSquare)
// Picks a random destination node in map that is not a warp (type 8), not a
// start-reserved (type 1), and not currentNode. Falls back to the start node.
TreasureMap::Node *getButtobiSquare(TreasureMap *map, const TreasureMap::Node *currentNode);

// Ghidra: FUN_000cea50
// Returns kSubMapFlagTable[mapId] (DAT_0012fb54). The first argument is ignored
// by the binary (matches the undefined4 Ghidra type; preserved for ABI fidelity).
int getTreasureMapValue_fb54(int unused, int mapId);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
