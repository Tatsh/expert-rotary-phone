/**
 * @file
 * The parsed sugoroku (board-game) map.
 *
 * A table of board squares (nodes, or areas) plus a few header fields, loaded from a bundled
 * "map_%03d.map" blob. The arcade task (AcMainTask::loadTreasureMap, Ghidra charaSelectReloadData
 * @ 0xa0b58) news one of these per goal, loads it, then reads its node bounding box to place and
 * clamp the scroll.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor FUN_000ce2b0 zeroes 0x60
 * bytes; parser FUN_000ce340; area lookup FUN_000ce934; destructor FUN_000ce330). Only the
 * offsets the arcade scene reads are byte-verified and named; the rest of the 0x60-byte object is
 * kept as padding.
 */

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

/**
 * The parsed sugoroku (board-game) map: a table of board squares plus a few header fields,
 * loaded from a bundled "map_%03d.map" blob.
 */
class TreasureMap {
public:
    /**
     * Zero-initialise the 0x60-byte object; the member initialisers reproduce the five
     * zeroed 16-byte stores.
     * @ghidraAddress 0xce2b0
     */
    TreasureMap() = default;
    /**
     * Free the node and edge tables. Kept as a declared seam; the parser module owns the
     * definition. The pre-step is FUN_000ce2e4.
     * @ghidraAddress 0xce330
     */
    ~TreasureMap();

    /**
     * Parse a bundled ".map" blob into the node table and header fields. The large binary
     * parser is kept as a declared seam.
     * @param path The ".map" file path.
     * @ghidraAddress 0xce340
     */
    void load(const char *path);

    /**
     * The board-square kind, stored in Node::type (+0x06) and read straight from the ".map"
     * file.
     *
     * Ghidra-verified across the map loader (FUN_000ce340) and both draw passes (drawSquareText
     * FUN_000a1bb4, drawSquare FUN_000a4eb4). The loader rewrites every non-chosen bonus-treasure
     * candidate (kSquareBonusTreasure) to kSquareDeactivatedBonus and clears its text, so a
     * deactivated bonus then renders as an ordinary board-story message square.
     */
    enum SquareKind : int16_t {
        kSquareInvalid = -1,         /**< A corrupt square; load() asserts on it. */
        kSquareStart = 0,            /**< The board start square, recorded at +0x54. */
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
    // the enclosing class layout (m_nodes @ +0x50, m_startNode @ +0x54, ...)
    // already relies on.
    /**
     * One board square. The binary's Objective-C value-type name for this record is
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
     * A resolved board edge between two squares.
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
     * The number of board squares (binary field @ +0x02).
     * @return The node count.
     */
    int nodeCount() const {
        return m_count;
    }
    /**
     * The board-square table (binary field @ +0x50).
     * @return The node array, or nullptr before load().
     */
    const Node *nodes() const {
        return m_nodes;
    }

    /**
     * The node whose id matches @p subId, scanning the whole table.
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
     * The board's start square (binary field @ +0x54).
     * @return The kSquareStart node, or nullptr when the map records none.
     */
    Node *startNode() const {
        return m_startNode;
    }

    /**
     * The board's start square id.
     * @return The start sub-map id, or 0 when none is recorded.
     */
    int16_t startSubId() const {
        return m_startNode ? m_startNode->id : 0;
    }
    // +0x58 is the malloc'd ConnectStruct edge array; +0x5c is its element count, and both are
    // copied into the arcade play data. The 32-bit binary held the array pointer in a 4-byte int
    // slot at +0x58; a 64-bit pointer does not fit, so the reconstruction stores a real
    // ConnectStruct* (m_edges), matching how m_nodes (+0x50) is already a real pointer.

    /**
     * The resolved board-edge table.
     * @return The edge array, or nullptr before load().
     */
    const ConnectStruct *edges() const {
        return m_edges;
    }
    /**
     * The number of board edges.
     * @return The edge count.
     */
    int edgeCount() const {
        return m_edgeCount;
    }

    /**
     * The partner warp square sharing @p node 's slotId (its warp-pair id).
     * @param node The warp square; the call asserts its type is kSquareWarp.
     * @return The partner square, or nullptr when there is none.
     * @ghidraAddress 0xce96c
     */
    Node *getWarpSquare(Node *node);

    /**
     * Pick a random "buttobi" (fly-to) destination square.
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
    // +0x54 the kSquareStart node. load() stores &m_nodes[i].id here, and Node::id is the
    // record's first field, so the stored address is the node itself. The arcade task's
    // roulette mode 7 reads this slot with a word ldr at 0x9d04c and uses the result directly
    // as a Node pointer, so it is one rather than a pointer to the id.
    Node *m_startNode = nullptr;
    ConnectStruct *m_edges = nullptr; // +0x58 malloc'd edge array (real ptr; was an int slot)
    int16_t m_edgeCount = 0;          // +0x5c edge count (was m_field5c)
    [[maybe_unused]] uint8_t m_tail[0x60 - 0x5e] = {}; // +0x5e tail padding
};

// ──────────────────────────────────────────────────────────────────────────────
// Free sugoroku-map C helpers (binary cluster ~0xce000, defined in
// TreasureMap.mm).
// ──────────────────────────────────────────────────────────────────────────────

/**
 * Count a board node's links.
 *
 * @param node The node to inspect.
 * @param checkBackLink When non-zero, return 1 if node->backLink is non-null and 0 otherwise;
 * when zero, count the non-null slots in node->links[0..2], stopping at the first null.
 * @return The count described above.
 * @ghidraAddress 0xce0ec
 */
unsigned int countSquareLinks(const TreasureMap::Node *node, int checkBackLink);

/**
 * The cardinal search direction for findAdjacentSquareIndex.
 *
 * The geometry is fixed by the board's screen coordinates: a lower x is further left and a lower y
 * is further up, verified in Ghidra's FUN_000ce114, whose case arms compare exactly these axes.
 * The perpendicular axis must match for a link to qualify.
 */
enum TreasureMapDirection : int {
    kTreasureDirLeft = 0,  /**< A neighbour with link->x below node->x, in the same row. */
    kTreasureDirRight = 1, /**< A neighbour with link->x above node->x, in the same row. */
    kTreasureDirUp = 2,    /**< A neighbour with link->y below node->y, in the same column. */
    kTreasureDirDown = 3,  /**< A neighbour with link->y above node->y, in the same column. */
};

/**
 * Find the link slot holding the neighbour in a given cardinal direction.
 *
 * It searches node->links[0..2] for a neighbour lying in that direction relative to node; the
 * same-axis coordinate must match.
 *
 * @param node The node to search from.
 * @param direction The cardinal direction to search in.
 * @return The slot index, 0 to 2, of the matching link, or -1 when there is none.
 * @ghidraAddress 0xce114
 */
int findAdjacentSquareIndex(const TreasureMap::Node *node, TreasureMapDirection direction);

/**
 * The earned goal-star count for one map and area pair.
 *
 * It indexes kTreasureMapTable[mainMapId][subMapId] (DAT_0012fac4, row stride 0xc).
 *
 * @param mainMapId The main map id.
 * @param subMapId The area id within that map.
 * @return The earned goal-star count.
 * @ghidraAddress 0xce180
 */
int getTreasureMapTableEntry(int mainMapId, int subMapId);

/**
 * The parent main-map id of a map, from kParentMapTable (DAT_0012fb30).
 * @param mapId The map id.
 * @return The parent main-map id, or -1 for a root.
 * @ghidraAddress 0xce198
 */
int getTreasureMapValue_fb30(int mapId);

/**
 * The number of character message strings for a character id.
 *
 * The id encodes a group as `id / 10`, valid for 6 and 8, and a slot as `id % 10`, valid for 0 to
 * 2. Both getCharacterAssetName and charaSelectReloadData call it. The address is an
 * address-sweep fix: 0xce1c8 was mid-body.
 *
 * @param characterId The encoded character id.
 * @return The number of message strings.
 * @ghidraAddress 0xce1a8
 */
int getCharacterAssetCount(int characterId);

/**
 * A UTF-8 character message string from the baked pool.
 *
 * @param characterId The encoded character id.
 * @param slotIndex The message slot, which must lie in [0, getCharacterAssetCount(characterId)).
 * @return The string, or null for an out-of-range or unrecognised id.
 * @ghidraAddress 0xce200
 */
const char *getCharacterAssetName(int characterId, int slotIndex);

/**
 * The sub-map flag for a map, from kSubMapFlagTable (DAT_0012fb54).
 *
 * @param unused Ignored by the binary; it matches the undefined4 Ghidra type and is preserved for
 * ABI fidelity.
 * @param mapId The map id.
 * @return The table entry.
 * @ghidraAddress 0xcea50
 */
int getTreasureMapValue_fb54(int unused, int mapId);

// code: language=Objective-C++ insertSpaces=true tabSize=4
// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
