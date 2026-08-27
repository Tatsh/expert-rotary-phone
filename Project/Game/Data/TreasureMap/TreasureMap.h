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

#import <Foundation/Foundation.h>

/**
 * @brief The parsed sugoroku (board-game) map: a table of board squares plus a few header fields,
 * loaded from a bundled "map_%03d.map" blob.
 */
class TreasureMap {
public:
    /**
     * @brief Zero-initialise the 0x60-byte object; the member initialisers reproduce the five
     * zeroed 16-byte stores.
     * @ghidraAddress 0xce2b0
     */
    TreasureMap() = default;
    /**
     * @brief Free the node and edge tables. Kept as a declared seam; the parser module owns the
     * definition. The pre-step is FUN_000ce2e4.
     * @ghidraAddress 0xce330
     */
    ~TreasureMap();

    /**
     * @brief Parse a bundled ".map" blob into the node table and header fields. The large binary
     * parser is kept as a declared seam.
     * @param path The ".map" file path.
     * @ghidraAddress 0xce340
     */
    void load(const char *path);

    /**
     * @brief The board-square kind, stored in Node::type (+0x06) and read straight from the ".map"
     * file.
     *
     * Ghidra-verified across the map loader (FUN_000ce340) and both draw passes (drawSquareText
     * FUN_000a1bb4, drawSquare FUN_000a4eb4). The loader rewrites every non-chosen bonus-treasure
     * candidate (kSquareBonusTreasure) to kSquareDeactivatedBonus and clears its text, so a
     * deactivated bonus then renders as an ordinary board-story message square.
     */
    enum SquareKind : int16_t {
        kSquareInvalid = -1,         /**< A corrupt square; load() asserts on it. */
        kSquareStart = 0,            /**< The board start square, recorded in *(+0x54). */
        kSquarePlayerStart = 1,      /**< The player spawn square. */
        kSquareDeactivatedBonus = 2, /**< A board-story message or deactivated bonus square. */
        kSquareBonus = 3,            /**< A bonus square; live at roulette 0x12 or HUD state 2. */
        kSquareTreasure = 4,       /**< A treasure square; live at roulette 0x12 or HUD state 3. */
        kSquareSubMapFlag = 5,     /**< A sub-map flag square, labelled from the HUD state. */
        kSquareWallpaperPiece = 6, /**< A wallpaper-piece square; unlock grid @ +0x748. */
        kSquareMusicPiece = 7,     /**< A music-piece square; unlock grid @ +0x6dc. */
        kSquareWarp = 8,           /**< A warp square, paired with another by slotId. */
        /** A goal-lock square, which shows its message once the goal clears at HUD state 4. */
        kSquareGoalLock = 9,
        kSquareBonusTreasure = 10, /**< An active bonus-treasure or friend-meet goal square. */
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
    /**
     * @brief One board square. The binary's Objective-C value-type name for this record is
     * "SquareStruct".
     */
    struct Node {
        int16_t id;   /**< +0x00 The sub-map id. */
        int16_t x;    /**< +0x02 The board column, in tile units. */
        int16_t y;    /**< +0x04 The board row, in tile units. */
        int16_t type; /**< +0x06 The square kind, a SquareKind. */
        /** +0x08 The per-square slot id, 0..14, from the file record. It doubles as the warp-pair
         * key and the wall/music piece-table index. */
        int16_t slotId;
        int16_t _pad0a;   /**< +0x0a Zeroed; the file's neighbour ids are not stored here. */
        Node *backLink;   /**< +0x0c The neighbour resolved from file record +0x0a. */
        Node *links[3];   /**< +0x10 The neighbours resolved from file record +0x0c, +0x0e and
                               +0x10. */
        char text[0x100]; /**< +0x1c The message, Shift-JIS decoded to UTF-8 with "<br>" turned
                               into a newline. */
        uint8_t _rest[4]; /**< +0x11c Padding out to the 0x120 stride. */
    };

    /**
     * @brief A resolved board edge between two squares.
     *
     * Built into the +0x58 array by load(); the binary boxes it in an NSValue with the Objective-C
     * type encoding "{ConnectStruct=^{SquareStruct}^{SquareStruct}B}" — 12 bytes: two Node* and a
     * BOOL.
     */
    struct ConnectStruct {
        Node *a;      /**< +0x00 One end of the edge. */
        Node *b;      /**< +0x04 The other end of the edge. */
        bool sameRow; /**< +0x08 Whether both ends share a board row. */
    };

    /**
     * @brief The number of board squares (binary field @ +0x02).
     * @return The node count.
     */
    int nodeCount() const {
        return m_count;
    }
    /**
     * @brief The board-square table (binary field @ +0x50).
     * @return The node array, or nullptr before load().
     */
    const Node *nodes() const {
        return m_nodes;
    }

    /**
     * @brief The node whose id matches @p subId, scanning the whole table.
     * @param subId The sub-map id to find.
     * @return The node, or nullptr when @p subId is out of range or the table is empty.
     * @ghidraAddress 0xce934
     */
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

    /**
     * @brief The board's start square id (binary field @ *(+0x54)).
     * @return The start sub-map id, or 0 when none is recorded.
     */
    int16_t startSubId() const {
        return m_startSubId ? *m_startSubId : 0;
    }
    // +0x58 is the malloc'd ConnectStruct edge array; +0x5c is its element count, and both are
    // copied into the arcade play data. The 32-bit binary held the array pointer in a 4-byte int
    // slot at +0x58; a 64-bit pointer does not fit, so the reconstruction stores a real
    // ConnectStruct* (m_edges), matching how m_nodes (+0x50) is already a real pointer.

    /**
     * @brief The resolved board-edge table.
     * @return The edge array, or nullptr before load().
     */
    const ConnectStruct *edges() const {
        return m_edges;
    }
    /**
     * @brief The number of board edges.
     * @return The edge count.
     */
    int edgeCount() const {
        return m_edgeCount;
    }

    /**
     * @brief The partner warp square sharing @p node 's slotId (its warp-pair id).
     * @param node The warp square; the call asserts its type is kSquareWarp.
     * @return The partner square, or nullptr when there is none.
     * @ghidraAddress 0xce96c
     */
    Node *getWarpSquare(Node *node);

    /**
     * @brief Pick a random "buttobi" (fly-to) destination square.
     *
     * The pick is a node that is not a warp, not a player-start, and not @p currentNode, walking
     * the links[0] chain when the first pick is unsuitable.
     * @param currentNode The square the player is on.
     * @return The destination square, falling back to the start node.
     * @ghidraAddress 0xce9d4
     */
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

// Cardinal search direction for findAdjacentSquareIndex. The geometry is fixed
// by the board's screen coordinates: a lower x is further left, a lower y is
// further up (Ghidra-verified in FUN_000ce114, whose case arms compare exactly
// these axes). The perpendicular axis must match for a link to qualify.
enum TreasureMapDirection : int {
    kTreasureDirLeft = 0,  // neighbour with link->x < node->x, same row (y)
    kTreasureDirRight = 1, // neighbour with link->x > node->x, same row (y)
    kTreasureDirUp = 2,    // neighbour with link->y < node->y, same column (x)
    kTreasureDirDown = 3,  // neighbour with link->y > node->y, same column (x)
};

// Ghidra: FUN_000ce114
// Searches node->links[0..2] for a neighbour that lies in the given cardinal
// direction relative to node (same-axis coordinate must match). Returns the
// slot index (0..2) of the matching link, or -1 if not found.
int findAdjacentSquareIndex(const TreasureMap::Node *node, TreasureMapDirection direction);

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

// code: language=Objective-C++ insertSpaces=true tabSize=4
// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
