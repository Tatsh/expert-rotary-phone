//
//  TreasureMap.mm
//  pop'n rhythmin
//
//  The sugoroku (board-game) map-file parser. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin:
//    * TreasureMap::load        — FUN_000ce340 (parse "map_%03d.map")
//    * TreasureMap::reset        — FUN_000ce2e4 (free table + edge array, zero object)
//    * TreasureMap::~TreasureMap — FUN_000ce330 (calls reset())
//
//  The original source file was Project/Game/Data/TreasureMap/SugorokuMap.mm (the
//  path survives in the load() assert at line 0x215).
//
//  Map-file binary format (little-endian, byte-verified against FUN_000ce340):
//    Header (first 0x50 bytes, memcpy'd verbatim into the object):
//      +0x00  uint8[2]   head
//      +0x02  int16      node/square count
//      +0x04..0x50       unused by the parser (the object's +0x50.. are runtime ptrs)
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

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <ctime>
#include <cassert>

#import <Foundation/Foundation.h>

#import "TreasureTmpData.h"
#import "UserSettingData.h"

// Ghidra dtor FUN_000ce330 -> FUN_000ce2e4. `delete` (invoked by the arcade task in
// loadTreasureMap, FUN_000a0b58) frees the object storage itself.
TreasureMap::~TreasureMap() {
    reset();
}

// Ghidra FUN_000ce2e4. Free the two owned heap buffers (the node table at +0x50 and
// the edge array at +0x58 — m_startSubId at +0x54 is only a pointer into the table,
// not separately owned) and zero the whole 0x60-byte object back to its constructed
// state, exactly as the binary does with its 16-byte NEON stores.
void TreasureMap::reset() {
    if (m_nodes) {
        std::free(m_nodes);
    }
    if (m_field58) {
        std::free(reinterpret_cast<void *>((intptr_t)m_field58));
    }
    std::memset(this, 0, 0x60);
}

// Ghidra FUN_000ce340.
void TreasureMap::load(const char *path) {
    // Snapshot the pending-treasure record; raw0x46 (Ghidra field15_0x46) records which
    // bonus square is this session's treasure and is (re)generated + persisted below.
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
        std::free(raw);   // the binary leaves m_nodes set but frees the file buffer
        return;
    }
    std::memset(nodes, 0, tableBytes);

    const uint8_t *fileBase = static_cast<const uint8_t *>(raw) + 0x50;
    int bonusCount = 0;   // Ghidra local_134: number of type == 10 bonus candidates

    // --- Pass 1: fill each square from its 0xaa-byte file record.
    for (int i = 0; i < m_count; i++) {
        const uint8_t *rec = fileBase + (size_t)i * 0xaa;
        Node &node = nodes[i];

        // Leading five int16 fields (id, x, y, type, field8) copied verbatim.
        std::memcpy(&node, rec, 10);

        // Message text: 0x98 ShiftJIS bytes at file +0x12, "<br>" -> newline, into the
        // 0x100-byte text buffer.
        char sjis[0x99];
        std::memset(sjis, 0, sizeof(sjis));
        std::memcpy(sjis, rec + 0x12, 0x98);
        if (sjis[0] != '\0') {
            NSData *data = [NSData dataWithBytes:sjis length:std::strlen(sjis)];
            NSString *s = [[NSString alloc] initWithData:data
                                                encoding:NSShiftJISStringEncoding];   // 8
            s = [s stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
            std::strncpy(m_nodes[i].text, [s UTF8String], 0x100);
        }

        // type gate (Ghidra: node+0x6). A -1 square is corrupt and the original aborts.
        const int16_t type = m_nodes[i].type;
        if (type == -1) {
            // Ghidra: ___assert_rtn("Init", ".../SugorokuMap.mm", 0x215, "0").
            __assert_rtn("Init",
                         "/Users/usr10013727/Documents/Project/Rhythmin/branches/v203/"
                         "Project/Game/Data/TreasureMap/SugorokuMap.mm",
                         0x215, "0");
        } else if (type == 10) {
            bonusCount++;
        } else if (type == 0) {
            m_startSubId = &m_nodes[i].id;   // *(+0x54): the start square
        }
    }

    // --- Bonus-treasure selection. Exactly one of the bonusCount type==10 squares stays
    // the active treasure; the persisted 1-based index raw0x46 picks it (generated once
    // and saved so it is stable across launches). Every other candidate is deactivated
    // (type -> 2, text cleared).
    if (bonusCount > 0) {
        if ((int8_t)tmp.raw0x46 < 1) {
            std::srand((unsigned)std::time(nullptr));
            tmp.raw0x46 = (uint8_t)((std::rand() % bonusCount) + 1);
            [UserSettingData saveTreasureTmp:tmp];
        }
        const int target = (int)tmp.raw0x46;   // 1-based chosen index
        int seen = 0;
        for (int i = 0; i < m_count; i++) {
            Node &node = m_nodes[i];
            if (node.type == 10) {
                seen++;                       // 1-based ordinal of this candidate
                if (target != seen) {         // not the chosen one -> deactivate
                    node.type = 2;
                    std::memset(node.text, 0, 0x101);   // Ghidra clears 0x101 bytes
                }
            }
        }
    }

    // --- Pass 2: resolve neighbour ids into Node pointers and build the deduplicated
    // edge list. Neighbour ids are read straight from the file records (they are not
    // stored in the node struct); each resolves to the square whose id matches.
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
            NSValue *boxed =
                [NSValue value:&edge
                  withObjCType:"{ConnectStruct=^{SquareStruct}^{SquareStruct}B}"];
            [edgeValues addObject:boxed];
        }
    }

    // --- Flatten the edge list into the owned +0x58 array (+0x5c = element count).
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

// Linear id lookup shared by both neighbour resolutions in load(). Mirrors the inline
// search in FUN_000ce340 (and findArea / FUN_000ce934): null for a negative id, an id
// that is out of range, or an empty table.
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

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
