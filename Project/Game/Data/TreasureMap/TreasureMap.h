//
//  TreasureMap.h
//  pop'n rhythmin
//
//  The parsed sugoroku (board-game) map: a table of board squares
//  ("nodes"/areas) plus a few header fields, loaded from a bundled
//  "map_%03d.map" blob. The arcade task (AcMainTask::loadTreasureMap, Ghidra
//  charaSelectReloadData @ 0xa0b58) news one of these per goal, loads it, then
//  reads its node bounding box to place + clamp the scroll.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_000ce2b0 zeroes 0x60 bytes; parser FUN_000ce340; area lookup
//  FUN_000ce934; destructor FUN_000ce330). Only the offsets the arcade scene
//  reads are byte-verified and named; the rest of the 0x60-byte object is kept
//  as padding.
//

#pragma once

#include <cstdint>

class TreasureMap {
public:
    // Ghidra: FUN_000ce2b0 — zero-inits the 0x60-byte object (the member
    // initialisers below reproduce the five zeroed 16-byte stores).
    TreasureMap() = default;
    // Ghidra: FUN_000ce330 (+ pre-step FUN_000ce2e4); `delete` frees it. Kept as
    // a declared seam (the parser module owns the definition).
    ~TreasureMap();

    // Parse "<path>" (a bundled ".map" blob) into the node table + header fields.
    // Large binary parser kept as a declared seam. Ghidra: FUN_000ce340.
    void load(const char *path);

    // Board-square kind, stored in Node::type (+0x06) and read straight from the
    // ".map" file. Ghidra-verified across the map loader (FUN_000ce340) and both
    // draw passes (drawSquareText FUN_000a1bb4, drawSquare FUN_000a4eb4). The
    // loader rewrites every non-chosen bonus-treasure candidate
    // (kSquareBonusTreasure) to kSquareDeactivatedBonus and clears its text, so a
    // deactivated bonus then renders as an ordinary board-story message square.
    enum SquareKind : int16_t {
        kSquareInvalid = -1,         // corrupt square; load() asserts
        kSquareStart = 0,            // board start square (recorded in *(+0x54))
        kSquarePlayerStart = 1,      // player spawn square
        kSquareDeactivatedBonus = 2, // board-story message / deactivated bonus square
        kSquareBonus = 3,            // bonus square (live when roulette 0x12 or HUD state 2)
        kSquareTreasure = 4,         // treasure square (live when roulette 0x12 or HUD state 3)
        kSquareSubMapFlag = 5,       // sub-map flag square (label keyed to the HUD state)
        kSquareWallpaperPiece = 6,   // wallpaper-piece square (unlock grid @ +0x748)
        kSquareMusicPiece = 7,       // music-piece square (unlock grid @ +0x6dc)
        kSquareWarp = 8,             // warp square (paired with another by slotId)
        kSquareGoalLock = 9,         // goal-lock square (message once the goal clears, HUD state 4)
        kSquareBonusTreasure = 10,   // active bonus-treasure / friend-meet goal square
    };

    // One board square. id is the sub-map id; x / y are the board column / row in
    // tile units (the scene multiplies by the 0x1a == 26 px tile size). The
    // in-memory record is 0x120 bytes (stride verified in FUN_000ce934); the file
    // image packs the same square into 0xaa bytes (see load()). The parser
    // (FUN_000ce340) fills the leading five int16 fields verbatim from the file,
    // resolves the neighbour ids into real Node pointers, and decodes the message
    // text. The ObjC value-type name the binary uses for this record is
    // "SquareStruct".
    //
    // NOTE: pointer members below are 4 bytes on the game's 32-bit (ILP32)
    // target, which is what keeps the 0x120 stride exact — the same assumption
    // the enclosing class layout (m_nodes @ +0x50, m_startSubId @ +0x54, ...)
    // already relies on.
    struct Node {
        int16_t id;       // +0x00 sub-map id
        int16_t x;        // +0x02 board column (tile units)
        int16_t y;        // +0x04 board row (tile units)
        int16_t type;     // +0x06 square kind (SquareKind)
        int16_t slotId;   // +0x08 per-square slot id (0..14; from the file record). Doubles as the
                          // warp-pair key and the wall/music piece-table index.
        int16_t _pad0a;   // +0x0a (zeroed; file neighbour ids are not stored here)
        Node *backLink;   // +0x0c neighbour resolved from file record +0x0a
        Node *links[3];   // +0x10 neighbours resolved from file record +0x0c/0e/10
        char text[0x100]; // +0x1c ShiftJIS->UTF8 message ("<br>" -> newline)
        uint8_t _rest[4]; // +0x11c pad to the 0x120 stride
    };

    // A resolved board edge between two squares. Built into the +0x58 array by
    // load(); the binary boxes it in NSValue with the ObjC type encoding
    // "{ConnectStruct=^{SquareStruct}^{SquareStruct}B}" (12 bytes: two Node* + a
    // BOOL).
    struct ConnectStruct {
        Node *a;      // +0x00
        Node *b;      // +0x04
        bool sameRow; // +0x08 a->y == b->y
    };

    int nodeCount() const {
        return m_count;
    } // +0x02
    const Node *nodes() const {
        return m_nodes;
    } // +0x50

    // The node whose id matches subId, scanning the whole table, or null. Ghidra:
    // FUN_000ce934 (null when subId >= count or count < 1).
    const Node *findArea(int subId) const {
        if (!m_nodes) {
            return nullptr;
        }
        const int n = m_count;
        if (subId >= n || n < 1) {
            return nullptr; // FUN_000ce934: out of range / empty table
        }
        const Node *node = m_nodes;
        for (int i = 0; i < n; i++, node++) {
            if (static_cast<uint16_t>(node->id) == static_cast<uint16_t>(subId)) {
                return node;
            }
        }
        return nullptr;
    }

    int16_t startSubId() const {
        return m_startSubId ? *m_startSubId : 0;
    } // *(+0x54)
    // +0x58 is the malloc'd ConnectStruct edge array; +0x5c is its element count
    // (both copied into the arcade play data). The 32-bit binary held the array
    // pointer in a 4-byte int slot at +0x58; a 64-bit pointer does not fit, so the
    // reconstruction stores a real ConnectStruct* (m_edges), matching how m_nodes
    // (+0x50) is already a real pointer.
    const ConnectStruct *edges() const {
        return m_edges;
    }
    int edgeCount() const {
        return m_edgeCount;
    }

    // Ghidra: FUN_000ce96c (SugorokuMap::GetWarpSquare). Asserts node is a warp
    // square (kSquareWarp), then returns the partner warp square sharing its
    // slotId (warp-pair id), or null.
    Node *getWarpSquare(Node *node);

    // Ghidra: FUN_000ce9d4 (SugorokuMap::GetButtobiSquare). Picks a random
    // destination node that is not a warp, not a player-start, and not
    // currentNode, walking the links[0] chain if the first pick is unsuitable;
    // falls back to the start node.
    Node *getButtobiSquare(const Node *currentNode);

private:
    // Ghidra: FUN_000ce2e4 — free the owned node table (+0x50) and edge array
    // (+0x58), then zero the whole 0x60-byte object. Shared by load()
    // (clear-before-parse) and the destructor.
    void reset();

    // Linear id -> Node* lookup used by load()'s neighbour resolution (the inline
    // search in FUN_000ce340). Null for a negative / out-of-range id or an empty
    // table.
    Node *findNodeById(int id) const;

    // Byte-exact layout to alignment 4 (offsets verified in
    // FUN_000ce2b0/340/934).
    [[maybe_unused]] uint8_t m_head[2] =
        {};              // +0x00 file header bytes (memcpy target; unread by name)
    int16_t m_count = 0; // +0x02 node count
    [[maybe_unused]] uint8_t m_pad04[0x50 - 4] = {}; // +0x04 file header padding (memcpy target)
    Node *m_nodes = nullptr;                         // +0x50 node array base (stride 0x120)
    int16_t *m_startSubId = nullptr;                 // +0x54 default/start node id source
    ConnectStruct *m_edges = nullptr; // +0x58 malloc'd edge array (real ptr; was an int slot)
    int16_t m_edgeCount = 0;          // +0x5c edge count (was m_field5c)
    [[maybe_unused]] uint8_t m_tail[0x60 - 0x5e] = {}; // +0x5e tail padding
};

// ──────────────────────────────────────────────────────────────────────────────
// Free sugoroku-map C helpers (binary cluster ~0xce000, defined in
// TreasureMap.mm).
// ──────────────────────────────────────────────────────────────────────────────

// Ghidra: FUN_000ce0ec
// If checkBackLink != 0: returns 1 when node->backLink is non-null, else 0.
// If checkBackLink == 0: counts non-null slots in node->links[0..2] (stop at
// first null).
unsigned int countSquareLinks(const TreasureMap::Node *node, int checkBackLink);

// Ghidra: FUN_000ce114
// Searches node->links[0..2] for a neighbour that lies in the given cardinal
// direction relative to node (0=left, 1=right, 2=up, 3=down, same-axis
// coordinate must match). Returns the slot index (0..2) of the matching link,
// or -1 if not found.
int findAdjacentSquareIndex(const TreasureMap::Node *node, int direction);

// Ghidra: FUN_000ce180
// Indexes kTreasureMapTable[mainMapId][subMapId] (DAT_0012fac4, row stride
// 0xc). Returns the earned goal-star count for the given map/area pair.
int getTreasureMapTableEntry(int mainMapId, int subMapId);

// Ghidra: FUN_000ce198
// Returns kParentMapTable[mapId] (DAT_0012fb30) — parent main-map id, -1 for
// roots.
int getTreasureMapValue_fb30(int mapId);

// Ghidra: getCharacterAssetCount @ 0xce1a8 (address-sweep fix: 0xce1c8 was
// mid-body) Returns the number of character message strings for the given
// character id. characterId encodes: group = id/10 (valid: 6, 8), slot = id%10
// (valid: 0..2). Called by both getCharacterAssetName and
// charaSelectReloadData.
int getCharacterAssetCount(int characterId);

// Ghidra: FUN_000ce200
// Returns a UTF-8 character message string from the baked pool for the given
// (characterId, slotIndex). slotIndex must be in [0,
// getCharacterAssetCount(characterId)). Returns null for out-of-range or
// unrecognised ids.
const char *getCharacterAssetName(int characterId, int slotIndex);

// Ghidra: FUN_000cea50
// Returns kSubMapFlagTable[mapId] (DAT_0012fb54). The first argument is ignored
// by the binary (matches the undefined4 Ghidra type; preserved for ABI
// fidelity).
int getTreasureMapValue_fb54(int unused, int mapId);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
