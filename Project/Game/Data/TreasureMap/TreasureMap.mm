//
//  TreasureMap.mm
//  pop'n rhythmin
//
//  The sugoroku (board-game) map-file parser. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin:
//    * TreasureMap::load        — FUN_000ce340 (parse "map_%03d.map")
//    * TreasureMap::reset        — FUN_000ce2e4 (free table + edge array, zero
//    object)
//    * TreasureMap::~TreasureMap — FUN_000ce330 (calls reset())
//
//  The original source file was Project/Game/Data/TreasureMap/SugorokuMap.mm
//  (the path survives in the load() assert at line 0x215).
//
//  Map-file binary format (little-endian, byte-verified against FUN_000ce340):
//    Header (first 0x50 bytes, memcpy'd verbatim into the object):
//      +0x00  uint8[2]   head
//      +0x02  int16      node/square count
//      +0x04..0x50       unused by the parser (the object's +0x50.. are runtime
//      ptrs)
//    Node records follow at file +0x50, each 0xaa (170) bytes:
//      +0x00  int16      id (sub-map id)
//      +0x02  int16      x  (board column, tile units)
//      +0x04  int16      y  (board row, tile units)
//      +0x06  int16      type  (-1 invalid/assert, 0 start, 10 bonus candidate)
//      +0x08  int16      field8
//      +0x0a  int16      neighbour id -> Node.backLink
//      +0x0c  int16      neighbour id -> Node.links[0]
//      +0x0e  int16      neighbour id -> Node.links[1]
//      +0x10  int16      neighbour id -> Node.links[2]
//      +0x12  char[0x98] ShiftJIS message text ("<br>" replaced with a newline)
//

#import "TreasureMap.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>

#import <Foundation/Foundation.h>

#import "TreasureTmpData.h"
#import "UserSettingData.h"

// Ghidra dtor FUN_000ce330 -> FUN_000ce2e4. `delete` (invoked by the arcade
// task in loadTreasureMap, FUN_000a0b58) frees the object storage itself.
// @complete
TreasureMap::~TreasureMap() {
    reset();
}

// Ghidra FUN_000ce2e4. Free the two owned heap buffers (the node table at +0x50
// and the edge array at +0x58 — m_startSubId at +0x54 is only a pointer into
// the table, not separately owned) and zero the whole 0x60-byte object back to
// its constructed state, exactly as the binary does with its 16-byte NEON
// stores. (The binary's six overlapping vst1.16 stores clear bytes 0x00..0x5d;
// the memset of 0x60 clears the whole object identically.)
// @complete
void TreasureMap::reset() {
    if (m_nodes) {
        std::free(m_nodes);
    }
    if (m_field58) {
        std::free(reinterpret_cast<void *>((intptr_t)m_field58));
    }
    std::memset(this, 0, 0x60);
}

// Ghidra FUN_000ce340. Node stride 0x120 (r0*9<<5), file record stride 0xaa,
// header memcpy 0x50, text at node+0x1c (strncpy 0x100), corrupt-square assert
// at SugorokuMap.mm:0x215 — all byte-verified against the disassembly.
// @complete
void TreasureMap::load(const char *path) {
    // Snapshot the pending-treasure record; bonusSquareIndex (Ghidra field15_0x46) records
    // which bonus square is this session's treasure and is (re)generated +
    // persisted below.
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Clear any previously loaded map first.
    reset();

    std::FILE *fp = std::fopen(path, "rb");
    if (!fp) {
        return;
    }

    std::fseek(fp, 0, SEEK_END);
    const long size = std::ftell(fp);
    std::fseek(fp, 0, SEEK_SET);
    void *raw = std::malloc((size_t)size);
    if (!raw) {
        std::fclose(fp);
        return;
    }
    const size_t got = std::fread(raw, (size_t)size, 1, fp);
    std::fclose(fp);
    if (got != 1) {
        std::free(raw);
        return;
    }

    // Header: first 0x50 bytes verbatim (fills m_head, m_count @ +0x02, m_pad04).
    std::memcpy(this, raw, 0x50);
    if (m_count <= 0) {
        std::free(raw);
        return;
    }

    // Allocate + zero the in-memory node table (stride sizeof(Node) == 0x120).
    const size_t tableBytes = (size_t)m_count * sizeof(Node);
    Node *nodes = static_cast<Node *>(std::malloc(tableBytes));
    m_nodes = nodes;
    if (!nodes) {
        std::free(raw); // the binary leaves m_nodes set but frees the file buffer
        return;
    }
    std::memset(nodes, 0, tableBytes);

    const uint8_t *fileBase = static_cast<const uint8_t *>(raw) + 0x50;
    int bonusCount = 0; // Ghidra local_134: number of kSquareBonusTreasure candidates

    // --- Pass 1: fill each square from its 0xaa-byte file record.
    for (int i = 0; i < m_count; i++) {
        const uint8_t *rec = fileBase + (size_t)i * 0xaa;
        Node &node = nodes[i];

        // Leading five int16 fields (id, x, y, type, field8) copied verbatim.
        std::memcpy(&node, rec, 10);

        // Message text: 0x98 ShiftJIS bytes at file +0x12, "<br>" -> newline, into
        // the 0x100-byte text buffer.
        char sjis[0x99];
        std::memset(sjis, 0, sizeof(sjis));
        std::memcpy(sjis, rec + 0x12, 0x98);
        if (sjis[0] != '\0') {
            NSData *data = [NSData dataWithBytes:sjis length:std::strlen(sjis)];
            NSString *s = [[NSString alloc] initWithData:data
                                                encoding:NSShiftJISStringEncoding]; // 8
            s = [s stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
            std::strncpy(m_nodes[i].text, [s UTF8String], 0x100);
        }

        // type gate (Ghidra: node+0x6). A -1 square is corrupt and the original
        // aborts.
        const int16_t type = m_nodes[i].type;
        if (type == TreasureMap::kSquareInvalid) {
            // Original aborts on a corrupt (-1) square. Ghidra: ___assert_rtn @
            // SugorokuMap.mm:0x215.
            assert(0);
        } else if (type == TreasureMap::kSquareBonusTreasure) {
            bonusCount++;
        } else if (type == TreasureMap::kSquareStart) {
            m_startSubId = &m_nodes[i].id; // *(+0x54): the start square
        }
    }

    // --- Bonus-treasure selection. Exactly one of the bonusCount
    // kSquareBonusTreasure squares stays the active treasure; the persisted
    // 1-based index bonusSquareIndex picks it (generated once and saved so it is
    // stable across launches). Every other candidate is deactivated
    // (type -> kSquareDeactivatedBonus, text cleared).
    if (bonusCount > 0) {
        if ((int8_t)tmp.bonusSquareIndex < 1) {
            std::srand((unsigned)std::time(nullptr));
            tmp.bonusSquareIndex = (uint8_t)((std::rand() % bonusCount) + 1);
            [UserSettingData saveTreasureTmp:tmp];
        }
        const int target = (int)tmp.bonusSquareIndex; // 1-based chosen index
        int seen = 0;
        for (int i = 0; i < m_count; i++) {
            Node &node = m_nodes[i];
            if (node.type == TreasureMap::kSquareBonusTreasure) {
                seen++;               // 1-based ordinal of this candidate
                if (target != seen) { // not the chosen one -> deactivate
                    node.type = TreasureMap::kSquareDeactivatedBonus;
                    std::memset(node.text, 0, 0x101); // Ghidra clears 0x101 bytes
                }
            }
        }
    }

    // --- Pass 2: resolve neighbour ids into Node pointers and build the
    // deduplicated edge list. Neighbour ids are read straight from the file
    // records (they are not stored in the node struct); each resolves to the
    // square whose id matches.
    NSMutableArray *edgeValues = [[NSMutableArray alloc] init];
    for (int i = 0; i < m_count; i++) {
        const uint8_t *rec = fileBase + (size_t)i * 0xaa;
        Node &node = m_nodes[i];

        // Back link (file +0x0a): a negative id means "no neighbour".
        const int16_t backId = *reinterpret_cast<const int16_t *>(rec + 0x0a);
        node.backLink = findNodeById(backId);

        // Three forward links (file +0x0c/0x0e/0x10) -> node.links[0..2].
        for (int k = 0; k < 3; k++) {
            const int16_t cid = *reinterpret_cast<const int16_t *>(rec + 0x0c + k * 2);
            Node *link = findNodeById(cid);
            node.links[k] = link;
            if (!link) {
                continue;
            }

            // Skip if the reverse edge (link -> node) is already recorded.
            bool duplicate = false;
            const NSUInteger count = edgeValues.count;
            for (NSUInteger e = 0; e < count; e++) {
                ConnectStruct existing;
                [[edgeValues objectAtIndex:e] getValue:&existing];
                if (existing.a == link && existing.b == &node) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) {
                continue;
            }

            ConnectStruct edge;
            edge.a = &node;
            edge.b = link;
            edge.sameRow = (node.y == link->y);
            NSValue *boxed = [NSValue value:&edge
                               withObjCType:"{ConnectStruct=^{SquareStruct}^{SquareStruct}B}"];
            [edgeValues addObject:boxed];
        }
    }

    // --- Flatten the edge list into the owned +0x58 array (+0x5c = element
    // count).
    const int16_t edgeCount = (int16_t)edgeValues.count;
    m_field5c = edgeCount;
    if (edgeCount > 0) {
        ConnectStruct *edges =
            static_cast<ConnectStruct *>(std::malloc((size_t)edgeCount * sizeof(ConnectStruct)));
        m_field58 = (int)(intptr_t)edges;
        for (int i = 0; i < edgeCount; i++) {
            [[edgeValues objectAtIndex:i] getValue:&edges[i]];
        }
    }

    std::free(raw);
}

// Linear id lookup shared by both neighbour resolutions in load(). Mirrors the
// inline search in FUN_000ce340 (and findArea / FUN_000ce934): null for a
// negative id, an id that is out of range, or an empty table.
// @complete
TreasureMap::Node *TreasureMap::findNodeById(int id) const {
    if (id < 0 || !m_nodes) {
        return nullptr;
    }
    const int n = m_count;
    if (id >= n || n < 1) {
        return nullptr;
    }
    for (int i = 0; i < n; i++) {
        if (m_nodes[i].id == id) {
            return &m_nodes[i];
        }
    }
    return nullptr;
}

// ──────────────────────────────────────────────────────────────────────────────
// Free sugoroku-map C helpers  (Ghidra cluster ~0xce000)
// ──────────────────────────────────────────────────────────────────────────────

// ── Small const lookup tables baked from the binary data section ─────────────

// Ghidra: DAT_0012fac4.  Goal-star counts indexed [mainMapId][subMapId].
// Row stride 0xc (3 × int32_t), column stride 4.  9 maps × 3 sub-map slots.
// Source: read_memory(0x12fac4, 108).
static const int32_t kTreasureMapTable[9][3] = {
    // DAT_0012fac4
    {1, 1, 2}, // mainMapId 0
    {4, 3, 4}, // mainMapId 1
    {3, 3, 4}, // mainMapId 2
    {5, 5, 5}, // mainMapId 3
    {5, 5, 5}, // mainMapId 4
    {2, 2, 2}, // mainMapId 5
    {2, 2, 2}, // mainMapId 6
    {5, 5, 5}, // mainMapId 7
    {5, 5, 5}, // mainMapId 8
};

// Ghidra: DAT_0012fb30.  Parent map id for each main map; -1 = root (no
// parent). The same table is used verbatim in TreasureData.m as kParentMapId[].
// Element stride 4 (int32_t).  Source: read_memory(0x12fb30, 36).
static const int32_t kParentMapTable[9] = { // DAT_0012fb30
    5,
    2,
    3,
    4,
    -1,
    1,
    7,
    -1,
    -1};

// Ghidra: DAT_0012fb54.  Sub-map type flags per main map.
// Element stride 4 (int32_t).  0x12fb54 == 0x12fb30 + 9 * sizeof(int32_t).
// Source: read_memory(0x12fb30, 72), bytes [36..71].
static const int32_t kSubMapFlagTable[9] = { // DAT_0012fb54
    0,
    1,
    0,
    1,
    0,
    1,
    0,
    1,
    2};

// Ghidra: DAT_0012fb90 / DAT_0012fb9c.  Per-slot character message counts.
// Source: read_memory(0x12fb90, 24) — 6 int32_t values, two groups of three.
static const int32_t kAssetCountsGroup6[3] = {41, 35, 47}; // DAT_0012fb90
static const int32_t kAssetCountsGroup8[3] = {64, 72, 71}; // DAT_0012fb9c

// ── Character message string pools (Ghidra pointer tables @ 0x1335c8 …
// 0x1339d4) ──
//
// In the binary these are six static `const char *` tables of ~330 UTF-8
// Japanese board-dialogue strings (~66 KB). That dialogue is copyrighted game
// content and is NOT present in this source tree. Instead the CMake configure
// step runs tools/extract_sugoroku_dialogue.py against an owned copy of the app
// binary (set -DPOPNRHYTHMIN_BINARY=...) to generate the six tables into the
// build directory, and this TU #includes them — reproducing the binary's exact
// static-table mechanism with the content supplied from your own binary. When
// no binary is configured the generated header defines empty tables and
// getCharacterAssetName returns nullptr (board messages blank).
//   kCharGroup6Slot0 — 41 entries  @ 0x1335c8      kCharGroup8Slot0 — 64  @
//   0x1337b4 kCharGroup6Slot1 — 35 entries  @ 0x13366c      kCharGroup8Slot1 —
//   72  @ 0x1338b4 (TOMOSUKE) kCharGroup6Slot2 — 47 entries  @ 0x1336f8 (wac)
//   kCharGroup8Slot2 — 71  @ 0x1339d4
#include "sugoroku_chara_msg.generated.inc"

// ── Function definitions
// ──────────────────────────────────────────────────────

// Ghidra: FUN_000ce0ec
// @complete
unsigned int countSquareLinks(const TreasureMap::Node *node, int checkBackLink) {
    if (checkBackLink != 0) {
        return node->backLink != nullptr ? 1u : 0u;
    }
    unsigned int count = 0;
    do {
        if (node->links[count] == nullptr) {
            return count;
        }
        count++;
    } while ((int)count < 3);
    return count;
}

// Ghidra: FUN_000ce114
// direction 0 — link to the left  (link.x < node.x, same y)
// direction 1 — link to the right (link.x > node.x, same y)
// direction 2 — link above        (link.y < node.y, same x)
// direction 3 — link below        (link.y > node.y, same x)
// @complete
int findAdjacentSquareIndex(const TreasureMap::Node *node, int direction) {
    for (int i = 0; i <= 2; i++) {
        const TreasureMap::Node *link = node->links[i];
        if (link == nullptr) {
            return -1;
        }
        int16_t sVar1, sVar2;
        switch (direction) {
        case 0:
            sVar1 = node->x;
            sVar2 = link->x;
            break;
        case 1:
            sVar1 = link->x;
            sVar2 = node->x;
            break;
        case 2:
            sVar1 = node->y;
            sVar2 = link->y;
            goto LAB_ce162;
        case 3:
            sVar1 = link->y;
            sVar2 = node->y;
        LAB_ce162:
            if (sVar2 < sVar1) {
                sVar2 = node->x;
                sVar1 = link->x;
                goto LAB_ce16c;
            }
            continue; // switchD default: advance to next link
        default:
            continue;
        }
        // Cases 0 and 1 land here.
        if (sVar2 < sVar1) {
            sVar2 = node->y;
            sVar1 = link->y;
        LAB_ce16c:
            if (sVar1 == sVar2) {
                return i;
            }
        }
    }
    return -1;
}

// Ghidra: FUN_000ce180
// @complete
int getTreasureMapTableEntry(int mainMapId, int subMapId) {
    return kTreasureMapTable[mainMapId][subMapId];
}

// Ghidra: FUN_000ce198
// @complete
int getTreasureMapValue_fb30(int mapId) {
    return kParentMapTable[mapId];
}

// Ghidra: getCharacterAssetCount @ 0xce1a8 (0xce1c8 in the file header cited a
// mid-body address; the function entry — the div-by-10 magic multiply — is
// 0xce1a8, confirmed by the bl target in getCharacterAssetName @ 0xce208).
// @complete
int getCharacterAssetCount(int characterId) {
    short group = (short)(characterId / 10);
    short slot = (short)(characterId - group * 10); // == characterId % 10
    if ((characterId / 10 & 0xffffu) == 8) {
        if ((unsigned int)(int)slot < 3u) {
            return kAssetCountsGroup8[slot];
        }
    } else if (group == 6 && (unsigned int)(int)slot < 3u) {
        return kAssetCountsGroup6[slot];
    }
    return 0;
}

// Ghidra: FUN_000ce200
// @complete
const char *getCharacterAssetName(int characterId, int slotIndex) {
    const int count = getCharacterAssetCount(characterId);
    if (slotIndex < 0) {
        return nullptr;
    }
    // Signed comparison: proceed only when 0 <= slotIndex < count.
    if (!(slotIndex < count)) {
        return nullptr;
    }

    unsigned int slot = (unsigned int)(characterId % 10);
    short group = (short)(characterId / 10);
    const char *const *strings = nullptr;

    if ((characterId / 10 & 0xffffu) == 8) {
        if (slot == 2) {
            strings = kCharGroup8Slot2;
        } else if (slot == 1) {
            strings = kCharGroup8Slot1;
        } else if (slot == 0) {
            strings = kCharGroup8Slot0;
        } else {
            return nullptr;
        }
    } else if (group == 6) {
        if (slot == 2) {
            strings = kCharGroup6Slot2;
        } else if (slot == 1) {
            strings = kCharGroup6Slot1;
        } else if (slot == 0) {
            strings = kCharGroup6Slot0;
        } else {
            return nullptr;
        }
    } else {
        return nullptr;
    }

    return strings[slotIndex];
}

// Ghidra: FUN_000ce96c  (SugorokuMap::GetWarpSquare)
// Asserts node is a warp square (type 8), then scans all nodes in map for the
// partner warp square: different id, same type 8, same field8 (warp-pair id).
// @complete
TreasureMap::Node *GetWarpSquare(TreasureMap *map, TreasureMap::Node *node) {
    if (node->type != TreasureMap::kSquareWarp) {
        assert(0);
    }
    const int n = map->m_count;
    if (n > 0) {
        TreasureMap::Node *cur = map->m_nodes;
        for (int i = 0; i < n; i++, cur++) {
            if (cur->id != node->id && cur->type == TreasureMap::kSquareWarp &&
                cur->field8 == node->field8) {
                return cur;
            }
        }
    }
    return nullptr;
}

// Ghidra: FUN_000ce9d4  (SugorokuMap::GetButtobiSquare)
// Picks a random non-warp, non-reserved, non-current destination node.
// The random node is chosen by index; if unsuitable, the links[0] chain from
// that node is walked until a valid node is found. Falls back to the start
// node. Node types skipped: kSquareWarp (8) and kSquarePlayerStart (1).
// @complete
TreasureMap::Node *getButtobiSquare(TreasureMap *map, const TreasureMap::Node *currentNode) {
    const int16_t count = map->m_count;
    if (count < 1) {
        assert(0);
    }
    const int randIdx = std::rand() % (int)count;
    TreasureMap::Node *node = map->m_nodes + randIdx;
    if (node->type != TreasureMap::kSquarePlayerStart && node->type != TreasureMap::kSquareWarp &&
        node != currentNode) {
        return node;
    }
    // Walk the links[0] chain from the same random starting node.
    TreasureMap::Node *follow = map->m_nodes + randIdx;
    while ((follow = follow->links[0]) != nullptr) {
        if (follow->type != TreasureMap::kSquareWarp) {
            if (follow->type == TreasureMap::kSquarePlayerStart) {
                break;
            }
            if (follow != currentNode) {
                return follow;
            }
        }
    }
    // Fallback: return the start node (m_startSubId points to Node.id at offset
    // 0).
    return reinterpret_cast<TreasureMap::Node *>(map->m_startSubId);
}

// Ghidra: FUN_000cea50
// param_1 (first argument) is ignored by the binary (undefined4 in Ghidra);
// preserved here for ABI fidelity.
// @complete
int getTreasureMapValue_fb54(int /*unused*/, int mapId) {
    return kSubMapFlagTable[mapId];
}
