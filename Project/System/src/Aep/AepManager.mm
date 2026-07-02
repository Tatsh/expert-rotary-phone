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
#import "neTextureForiOS.h"

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

// Ghidra: readIndexFile (FUN_0000f770). Read the whole .idx into m_idxData[group];
// the index proper begins 4 bytes in (the binary reads at +0x200, index at +0x204)
// and its first int16 is overwritten with the group id. Returns the index base.
const uint8_t *AepManager::readIndexFile(int group, NSString *path) {
    if (group < 0 || group >= kMaxAepGroups) {
        return nullptr;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        return nullptr;
    }
    assert(data.length < 0x40000 && "fileSize < MAX_IDXBUFSIZE");
    m_idxData[group] = [data copy];
    uint8_t *bytes = (uint8_t *)m_idxData[group].bytes;
    uint8_t *indexBase = bytes + 4;              // skip the 4-byte header
    *reinterpret_cast<int16_t *>(indexBase) = (int16_t)group;  // stamp the group id
    return indexBase;
}

// Ghidra: loadAepData (FUN_0000f4b0, asserts n < MAX_FRAME_DATA at AepManager.mm:0x17a).
// Reads the index, uploads the group's texture, records the frame-position table and
// the frame-entry pointer. The .idx stores its internal tables as byte offsets from
// the index base (they are pre-relocated in the binary's fixed-buffer scheme; here
// they are resolved against m_idxData's bytes).
bool AepManager::loadAepData(int group, const char *dir, const char *name, bool single) {
    assert(name != nullptr);
    if (group < 0 || group >= kMaxAepGroups) {
        return false;
    }

    NSString *path = single
        ? [NSString stringWithFormat:@"%s/%s.idx", dir, name]
        : [NSString stringWithFormat:@"%s/%s/%s.idx", dir, name, name];
    const uint8_t *indexBase = readIndexFile(group, path);
    if (indexBase == nullptr) {
        return false;
    }
    int groupId = *reinterpret_cast<const int16_t *>(indexBase);

    // Replace the group's texture.
    delete m_groupTexture[group];
    m_groupTexture[group] = new neTextureForiOS();
    NSString *texDir = single ? nil : [NSString stringWithFormat:@"%s/%s", dir, name];
    // The tile loader reads "<texDir>/<name>_<i>.png" for each of the index's tiles
    // (Ghidra FUN_00011e18); it fills the sprite's tile/handle arrays.
    m_groupTexture[group]->loadFrames(texDir.UTF8String, name, indexBase);

    // group id -> slot maps (Ghidra: +0x7c1748 / +0x7c1948).
    m_groupIndex[groupId] = (uint8_t)group;

    // Copy the frame-position table (8-byte records, terminated by a zero span),
    // bounded by MAX_FRAME_DATA.
    uint32_t posOffset = *reinterpret_cast<const uint32_t *>(indexBase + 4);
    const int16_t *pos = reinterpret_cast<const int16_t *>(m_idxData[group].bytes) +
                         posOffset / 2;
    int n = 0;
    while (pos[2] != 0) {
        assert(n < kMaxFrameData && "n < MAX_FRAME_DATA");
        m_framePos[group][n] = { pos[0], pos[1], pos[2], pos[3] };
        n++;
        pos += 4;
    }
    m_frameCount[group] = n;

    // The AepFrameEntry array the layer draw walks (Ghidra: +0x7f39c8 = *(idx+8)).
    uint32_t entryOffset = *reinterpret_cast<const uint32_t *>(indexBase + 8);
    m_groupFrameData[group] = reinterpret_cast<const AepFrameEntry *>(
        reinterpret_cast<const uint8_t *>(m_idxData[group].bytes) + entryOffset);
    return true;
}

// Ghidra: FUN_0000f988 — drop the group's texture (its dtor releases the tiles).
void AepManager::unloadGroup(int group) {
    if (group < 0 || group >= kMaxAepGroups) {
        return;
    }
    delete m_groupTexture[group];
    m_groupTexture[group] = nullptr;
}

// Ghidra: FUN_0000f758 — load a single-file group ("<baseDir>/<name>.idx") into slot.
void AepLoadGroup(AepManager *aep, int slot, const char *name) {
    aep->loadAepData(slot, aep->baseDir(), name, true);
}

// Ghidra: FUN_0000f988.
void AepUnloadGroup(AepManager *aep, int slot) {
    aep->unloadGroup(slot);
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

// Ghidra: FUN_000106dc — start a fade transition (mode 1 in / 2 out; 0 or >=3
// cancels). Length + total are set to `frames`; the overlay is chosen by `flag`.
void AepManager::playTransition(int mode, int frames, int flag) {
    if ((unsigned)mode < 3 && frames > 0) {
        m_transitionMode = mode;
        m_transitionFrames = frames;
        m_transitionTotal = frames;
        m_transitionFlag = flag;
    } else {
        m_transitionMode = 0;
        m_transitionFrames = 0;
    }
}

// Ghidra: FUN_00010758 — clamp `frame` into [0, total] and store it as the current
// transition frame counter (the value draw() counts down and derives alpha from).
void AepManager::setTransitionFrame(int frame) {
    if (frame < 0) {
        frame = 0;
    }
    if (frame > m_transitionTotal) {
        frame = m_transitionTotal;
    }
    m_transitionFrames = frame;
}

// Ghidra: FUN_00010730 — done when no frames remain, or no transition is active.
bool AepManager::isTransitionDone() const {
    if (m_transitionFrames > 0) {
        return m_transitionMode == 0;
    }
    return true;
}

// Ghidra: FUN_0001058c — if a fade is active, draw its overlay quad at the current
// alpha (100% * frames/total, offset per mode) over the ordering table and count
// the frame down; then flush the OT and record the highest priority drawn.
void AepManager::draw() {
    if (m_transitionTotal > 0 && (m_transitionMode == 1 || m_transitionMode == 2)) {
        // Progress runs 100 -> 0 as the frames count down.
        float progress = (float)(m_transitionFrames * 100) / (float)m_transitionTotal;
        // Fade out rises 0 -> 100 opaque; fade in is the complement (mode-1 base is
        // ambiguous in the decompile, modelled as the mirror of fade out).
        float alpha = (m_transitionMode == 2) ? (100.0f - progress) : progress;
        if (alpha > 0.0f) {
            if (alpha > 100.0f) {
                alpha = 100.0f;
            }
            drawTransitionOverlay((int)alpha);
        }
        if (m_transitionFrames > 0) {
            m_transitionFrames--;
        }
    }

    // Flush the ordering table (filled this frame by drawLayer) highest priority
    // first, and record the count drawn (Ghidra: FUN_000115d0 / FUN_000117dc).
    m_ot.flush();
    m_maxPriority = m_ot.drawnCount();
}

// Ghidra: FUN_0001151c — queue the full-screen fade quad as a top-priority OT
// command: geometry from m_transitionOverlay, opacity `alpha` (0..100), overlay
// selector m_transitionFlag. (The exact colour packing is that unit's detail.)
void AepManager::drawTransitionOverlay(int alpha) {
    AepSpriteCommand *cmd = m_ot.allocEntry(kOtPriMax - 1);
    if (cmd == nullptr) {
        return;
    }
    cmd->x = m_transitionOverlay[0];
    cmd->y = m_transitionOverlay[1];
    cmd->w = m_transitionOverlay[2];
    cmd->h = m_transitionOverlay[3];
    cmd->color0 = (int16_t)alpha;
    cmd->textureId = m_transitionFlag;
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
