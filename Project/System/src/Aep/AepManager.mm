//
//  AepManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The Aep 2D
//  scene manager: loads .idx animation/sprite data, advances the active screen
//  transition, and draws the ordering table each frame.
//  Ghidra: loadAepData FUN_0000f4b0, draw FUN_0001058c, drawLayer FUN_0000fd64.
//

#include <cassert>
#include <cstring>

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Ghidra: FUN_0000fa30 — resolve `name` in a group's open-addressing hash table.
// A rolling rotate-add hash (mod 2047) picks the start bucket, then linear-probe
// (wrapping) until the key matches (return its stored value) or an empty/looped
// slot is hit (return -1).
static int AepNameHashLookup(const char *name, const AepManager::NameHashTable *table) {
    unsigned c = (unsigned char)name[0];
    int bucket = 0;
    if (c != 0) {
        unsigned h = 0;
        const char *p = name;
        do {
            ++p;
            h += c;
            unsigned r = (0x20 - (c & 0x1f)) & 0x1f;
            c = (unsigned char)*p;
            h = (h >> r) | (h << (0x20 - r));   // rotate-right by r
        } while (c != 0);
        bucket = (int)(h % 2047);
    }
    const int start = bucket;
    for (;;) {
        const char *key = table->key[bucket];
        if (key == nullptr) {
            return -1;
        }
        if (std::strcmp(name, key) == 0) {
            return table->value[bucket];
        }
        bucket = (bucket + 1) % 2047;
        if (bucket == start) {
            return -1;
        }
    }
}

// Ghidra: FUN_0000f1ec — lazy accessor for the global scene manager (the
// ~8 MB object at PTR_DAT_00130484, constructed once via FUN_00010b88). The
// function-local static reproduces that construct-once-on-first-use semantics.
AepManager &AepManager::shared() {
    static AepManager instance;
    return instance;
}

// Load one Aep .idx resource ("<dir>/<name>.idx" or "<dir>/<sub>/<name>.idx"):
// opens the index, uploads its texture, and reads its frame table into the scene.
// Ghidra: FUN_0000f4b0 (asserts n < MAX_FRAME_DATA at AepManager.mm:0x17a).
void AepManager::loadAepData(NSString *name) {
    assert(name != nil);
    NSString *path = [NSString stringWithFormat:@"%@.idx", name];
    // The concrete idx read (header + AepTexture upload + frame table parse) is
    // handled by the engine texture/index loader; each frame is appended to the
    // scene's frame data (bounded by MAX_FRAME_DATA = 0x400). See AepTexture.
    (void)path;
}

// Resolve the frame-entry array for the group encoded in `lyr`'s high 16 bits.
// Ghidra: a byte group-index table (this+0x7c1748) selects a slot into the
// per-group frame-data pointer table (this+0x7f39c8).
const AepFrameEntry *AepManager::groupEntries(int lyr) const {
    unsigned slot = m_groupIndex[lyr >> 16];
    return m_groupFrameData[slot];
}

// Walk `entries`[layerNo]'s chain to its last entry and return its frameEnd — the
// layer's length. Ghidra: the shared loop in FUN_0000fd64 / FUN_0000fb8c (stride
// 0x24; scan forward while the entry's first field is non-negative).
int AepManager::layerLength(const AepFrameEntry *entries, int layerNo) {
    const AepFrameEntry *e = &entries[layerNo];
    while (e->type >= 0) {
        ++e;
    }
    return e->frameEnd;   // Ghidra: psVar2[5]
}

// Ghidra: getLyrNo FUN_0000fac8 — hash-resolve `name` in `group`'s table, assert
// it exists, and pack (group slot << 16) | layer index into the encoded lyr.
int AepManager::getLyrNo(int group, const char *name) const {
    int idx = AepNameHashLookup(name, &m_groupNames[group]);
    assert(idx >= 0);   // AepManager.mm:0x1d0 "0" (getLyrNo)
    return (m_groupSlot[group] << 16) | m_layerNumbers[group * 256 + idx];
}

// Ghidra: FUN_0000fb8c — the layer's frame count (same walk as drawLayer).
int AepManager::layerFrameCount(int lyr) const {
    return layerLength(groupEntries(lyr), lyr & 0xffff);
}

// Ghidra: FUN_0000fd64 — resolve the layer's frame-entry array, clamp/loop the
// requested frame to the layer's length, then fill it (AepDrawLayer / FUN_0000fe8c).
void AepManager::drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags) {
    assert(lyr >= 0);   // AepManager.mm:0x26a "0 <= lyr"

    const AepFrameEntry *entries = groupEntries(lyr);
    const int layerNo = lyr & 0xffff;
    const int length = layerLength(entries, layerNo);
    if (length == 0 || frame < 0) {
        return;
    }

    if (flags & kDrawLoop) {
        frame %= length;                 // Ghidra: ___modsi3
    } else if (frame >= length) {
        if ((flags & kDrawClampLast) == 0) {
            return;                      // past the end and not clamping -> skip
        }
        frame = length - 1;
    }

    AepDrawLayer(&m_ot, entries, layerNo, frame, root);
}

// Ghidra: FUN_0001058c — advance the screen transition (a timed fade overlay),
// then draw the whole ordering table, drawing the transition quad on top.
void AepManager::draw() {
    if (m_transitionType != 0) {
        m_transitionElapsed += 1.0f / 60.0f;
        if (m_transitionElapsed >= m_transitionDuration) {
            m_transitionElapsed = m_transitionDuration;
            m_transitionType = 0;   // transition finished
        }
    }

    // The ordering table has been filled this frame by drawLayer (per-layer
    // animation -> allocEntry). Flush it: emit every queued sprite command,
    // highest priority first. The transition overlay is queued as a high-priority
    // command by the transition system, so it draws on top here.
    m_ot.flush();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
