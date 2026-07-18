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
#include <cstdint>
#include <cstring>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "neDebugLog.h"
#import "neTextureForiOS.h"

// Ghidra: FUN_0000fa30 — resolve `name` in a group's open-addressing hash
// table. A rolling rotate-add hash (mod 2047) picks the start bucket, then
// linear-probe (wrapping) until the key matches (return its stored value) or an
// empty/looped slot is hit (return -1).
// @complete
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
            h = (h >> r) | (h << (0x20 - r)); // rotate-right by r
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
// @complete
AepManager &AepManager::shared() {
    static AepManager instance;
    return instance;
}

// Ghidra: readIndexFile (FUN_0000f770). Read the whole .idx into
// m_idxData[group]; the index proper begins 4 bytes in (the binary reads at
// +0x200, index at +0x204) and its first int16 is overwritten with the group
// id. Returns the index base.
// @complete
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
    uint8_t *indexBase = bytes + 4;                           // skip the 4-byte header
    *reinterpret_cast<int16_t *>(indexBase) = (int16_t)group; // stamp the group id
    return indexBase;
}

// Ghidra: loadAepData (FUN_0000f4b0, asserts n < MAX_FRAME_DATA at
// AepManager.mm:0x17a). Reads the index, relocates its header (building the name
// hash tables and resolving the frame-position / frame-entry pointers), uploads the
// group's texture, and copies the frame-position table.
// @complete
bool AepManager::loadAepData(int group, const char *dir, const char *name, bool single) {
    assert(name != nullptr);
    if (group < 0 || group >= kMaxAepGroups) {
        return false;
    }

    NSString *path = single ? [NSString stringWithFormat:@"%s/%s.idx", dir, name] :
                              [NSString stringWithFormat:@"%s/%s/%s.idx", dir, name, name];
    const uint8_t *indexBase = readIndexFile(group, path);
    if (indexBase == nullptr) {
        return false;
    }
    int groupId = *reinterpret_cast<const int16_t *>(indexBase);

    // Relocate the index header (Ghidra: loadAepData calls relocateAepData FUN_0000f824
    // @0xf572, right after readIndexFile): build the frame/layer/user name hash tables
    // and resolve the frame-position and frame-entry pointers (each sits past its name
    // table + the layer-ordinal array) into m_framePosData / m_groupFrameData. The index
    // buffer is a private mutable copy (readIndexFile already stamps the group id into it).
    relocateData(group, reinterpret_cast<const AepIndexHeader *>(indexBase), indexBase);

    // Replace the group's texture.
    delete m_groupTexture[group];
    m_groupTexture[group] = new neTextureForiOS();
    NSString *texDir = single ? nil : [NSString stringWithFormat:@"%s/%s", dir, name];
    // The tile loader reads "<texDir>/<name>_<i>.png" for each of the index's
    // tiles (Ghidra FUN_00011e18); it fills the sprite's tile/handle arrays.
    m_groupTexture[group]->loadFrames(texDir.UTF8String, name, indexBase);

    // group id -> slot maps (Ghidra: pAGroupBankTable[groupId] = nSlot @ +0x7c1748,
    // pABankGroupTable[nSlot] = groupId @ +0x7c1948). Both stores are needed:
    // getLyrNo packs m_groupSlot[group] into the lyr handle, and groupEntries reads
    // it back through m_groupIndex to reach this group's frame data.
    m_groupIndex[groupId] = (uint8_t)group;
    m_groupSlot[group] = (uint8_t)groupId;

    // Copy the frame-position table (8-byte records, terminated by a zero span),
    // bounded by MAX_FRAME_DATA. relocateAepData resolved its pointer (past the
    // frame-name table) into m_framePosData.
    const int16_t *pos = m_framePosData[group];
    int n = 0;
    while (pos != nullptr && pos[2] != 0) {
        assert(n < kMaxFrameData && "n < MAX_FRAME_DATA");
        m_framePos[group][n] = {pos[0], pos[1], pos[2], pos[3]};
        n++;
        pos += 4;
    }
    m_frameCount[group] = n;

    // The AepFrameEntry array the layer draw walks (Ghidra: +0x7f39c8, read from the
    // relocated header +0x10) was resolved into m_groupFrameData by relocateAepData.
    return true;
}

// Ghidra: FUN_0000f988 — drop the group's texture (its dtor releases the
// tiles).
// @complete
void AepManager::releaseAepTexture(int group) {
    if (group < 0 || group >= kMaxAepGroups) {
        return;
    }
    delete m_groupTexture[group];
    m_groupTexture[group] = nullptr;
}

// Ghidra: FUN_0000f758 — load a single-file group ("<baseDir>/<name>.idx") from
// the manager's base directory into `group`.
// @complete
void AepManager::loadAepDataDefaultPath(int group, const char *name) {
    loadAepData(group, baseDir(), name, true);
}

// Resolve the frame-entry array for the group encoded in `lyr`'s high 16 bits.
// Ghidra: a byte group-index table (this+0x7c1748) selects a slot into the
// per-group frame-data pointer table (this+0x7f39c8).
// @complete
const AepFrameEntry *AepManager::groupEntries(int lyr) const {
    unsigned slot = m_groupIndex[lyr >> 16];
    return m_groupFrameData[slot];
}

// Walk `entries`[layerNo]'s chain to its last entry and return its frameEnd —
// the layer's length. Ghidra: the shared loop in FUN_0000fd64 / FUN_0000fb8c
// (stride 0x24; scan forward while the entry's first field is non-negative).
// @complete
int AepManager::layerLength(const AepFrameEntry *entries, int layerNo) {
    const AepFrameEntry *e = &entries[layerNo];
    while (e->type >= 0) {
        ++e;
    }
    return e->frameEnd; // Ghidra: psVar2[5]
}

// Ghidra: getLyrNo FUN_0000fac8 — hash-resolve `name` in `group`'s table,
// assert it exists, and pack (group slot << 16) | layer index into the encoded
// lyr.
// @complete
int AepManager::getLyrNo(int group, const char *name) const {
    int idx = AepNameHashLookup(name, &m_groupNames[group]);
    assert(idx >= 0); // AepManager.mm:0x1d0 "0" (getLyrNo)
    return (m_groupSlot[group] << 16) | m_layerNumbers[group][idx];
}

// Ghidra: getFrmNo FUN_0000f9cc — hash-resolve `name` in `group`'s frame-name
// table
// (@ +0x640200), assert, and pack (group slot << 16) | the looked-up frame
// number.
// @complete
int AepManager::getFrameNo(int group, const char *name) const {
    int idx = AepNameHashLookup(name, &m_frameNames[group]);
    assert(idx >= 0); // AepManager.mm:0x1bb "getFrmNo"
    return idx | (m_groupSlot[group] << 16);
}

// Ghidra: getUsrNo FUN_0000fb40 — hash-resolve `name` in `group`'s user-name
// table
// (@ +0x6d6138), assert, and return the looked-up user number (no slot
// packing).
// @complete
int AepManager::getUserNo(int group, const char *name) const {
    int idx = AepNameHashLookup(name, &m_userNames[group]);
    assert(idx >= 0); // AepManager.mm:0x1e4 "getUsrNo"
    return idx;
}

// Ghidra: FUN_0000f498 / FUN_0000f4a4 — the cached screen-quad extents at
// +0x7f3afc / +0x7f3b00 (the same slots screenWidth()/screenHeight() read).
// @complete
int AepManager::transitionOverlayWidth() const {
    return m_transitionOverlay[2];
}
// @complete
int AepManager::transitionOverlayHeight() const {
    return m_transitionOverlay[3];
}

// Ghidra: FUN_0000fb8c — the layer's frame count (same walk as drawLayer).
// @complete
int AepManager::layerFrameCount(int lyr) const {
    return layerLength(groupEntries(lyr), lyr & 0xffff);
}

// Ghidra: FUN_0000fd64 — resolve the layer's frame-entry array, clamp/loop the
// requested frame to the layer's length, then fill it (AepDrawLayer /
// FUN_0000fe8c). The full 19-parameter form: `loopFlags` is param_13 (bit0 =
// loop, bit4 = clampLast); every other arg threads straight into the frame-tree
// fill. A null clipRect defaults to the full-screen rect cached at
// this+0x7f3af4.
// @complete
void AepManager::drawLayer(int lyr,
                           int frame,
                           int x,
                           int y,
                           int scaleX,
                           int scaleY,
                           int rotation,
                           int anchorX,
                           int anchorY,
                           int color,
                           int colorHi,
                           uint32_t loopFlags,
                           uint32_t blendFlags,
                           uint32_t colorRGB,
                           int *clipRect,
                           void *context,
                           uint32_t priority,
                           uint32_t visFlag) {
    assert(lyr >= 0); // AepManager.mm:0x26a "0 <= lyr"

    const unsigned slot = m_groupIndex[(unsigned)lyr >> 16]; // this+0x7c1748
    const AepFrameEntry *entries = m_groupFrameData[slot];   // this+slot*4+0x7f39c8
    const int layerNo = lyr & 0xffff;
    const int length = layerLength(entries, layerNo);
    if (length == 0 || frame < 0) {
        return;
    }

    if (loopFlags & kDrawLoop) {
        frame %= length; // Ghidra: ___modsi3
    } else if (frame >= length) {
        if ((loopFlags & kDrawClampLast) == 0) {
            return; // past the end and not clamping -> skip
        }
        frame = length - 1;
    }

    // Default clip rect = the cached full-screen quad {x, y, w, h} at
    // this+0x7f3af4.
    int *clip = clipRect ? clipRect : m_transitionOverlay;

    AepDrawLayer(this,
                 (int)slot,
                 layerNo,
                 frame,
                 x,
                 y,
                 scaleX,
                 scaleY,
                 anchorX,
                 anchorY,
                 color,
                 colorHi,
                 (uint32_t)rotation,
                 blendFlags,
                 colorRGB,
                 clip,
                 priority,
                 context,
                 visFlag);
}

// Compatibility overload for the transform-only callers (MenuMainTask /
// PlayTask / AepLyrCtrl). Maps the transform into the full form: colour = 100
// and colourHi = 100 give a fully-opaque, un-tinted quad (the >=100 alpha split
// turns alpha 100 into the 0x200 "opaque" blend bit); pivots and user words
// default to 0, no clip override, and the transform's priority becomes the
// ordering-table priority (binary param_18).
// @complete
void AepManager::drawLayer(int lyr, int frame, const AepTransform &root, uint32_t flags) {
    drawLayer(lyr,
              frame,
              static_cast<int>(root.x),
              static_cast<int>(root.y),
              static_cast<int>(root.sx),
              static_cast<int>(root.sy),
              static_cast<int>(root.rotation),
              /*anchorX*/ 0,
              /*anchorY*/ 0,
              /*color*/ 100,
              /*colorHi*/ 100,
              flags, // loopFlags (binary position 13, after colorHi)
              /*blendFlags*/ 0,
              /*colorRGB*/ 0,
              /*clipRect*/ nullptr,
              /*context*/ nullptr,
              /*priority*/ static_cast<uint32_t>(root.priority),
              /*visFlag*/ 0);
}

// Ghidra: FUN_0000f9b0 — install a per-group frame-tree draw callback + context
// (stored at this+slot*4+0x7f3a2c / +0x7f3a90). The callback is invoked by the
// type-3 dispatch in AepDrawLayer with the full per-frame draw args
// (AepGroupDrawFn); its last argument receives this stored context (the owning
// scene/task).
// @complete
void AepManager::setGroupDrawCallback(int slot, AepGroupDrawFn callback, void *context) {
    if (slot < 0 || slot >= kMaxAepGroups) {
        return;
    }
    m_groupCallback[slot] = callback;
    m_groupContext[slot] = context;
}

// Ghidra: FUN_000106dc — start a fade transition (mode 1 in / 2 out; 0 or >=3
// cancels). Length + total are set to `frames`; `color` is the fade colour
// (0x00RRGGBB) the overlay dips to (0 = black, as every boot-logo call passes).
// @complete
void AepManager::playTransition(int mode, int frames, int color) {
    if ((unsigned)mode < 3 && frames > 0) {
        m_transitionMode = mode;
        m_transitionFrames = frames;
        m_transitionTotal = frames;
        m_transitionColor = color;
    } else {
        m_transitionMode = 0;
        m_transitionFrames = 0;
    }
}

// Ghidra: FUN_00010698 — arm a transition with the fixed 30-frame duration (a
// fade to black). A valid mode (0..2) sets the mode, both frame counters to 30,
// and clears the colour; an invalid mode disables the transition. Distinct from
// playTransition, which takes an explicit frame count and colour.
// @complete
void AepManager::setAepTransitionMode(int mode) {
    if ((unsigned)mode < 3) {
        m_transitionMode = mode;
        m_transitionFrames = 0x1e;
        m_transitionTotal = 0x1e;
        m_transitionColor = 0;
        return;
    }
    m_transitionMode = 0;
    m_transitionFrames = 0;
}

// Ghidra: FUN_00010758 — clamp `frame` into [0, total] and store it as the
// current transition frame counter (the value draw() counts down and derives
// alpha from).
// @complete
void AepManager::setTransitionFrame(int frame) {
    if (frame < 0) {
        frame = 0;
    }
    if (frame > m_transitionTotal) {
        frame = m_transitionTotal;
    }
    m_transitionFrames = frame;
}

// Ghidra: FUN_00010730 — done when no frames remain, or no transition is
// active.
// @complete
bool AepManager::isTransitionDone() const {
    if (m_transitionFrames > 0) {
        return m_transitionMode == 0;
    }
    return true;
}

// Ghidra: FUN_0001058c — if a fade is active, draw its overlay quad at the
// current alpha (100% * frames/total, offset per mode) over the ordering table
// and count the frame down; then flush the OT and record the highest priority
// drawn.
// @complete
void AepManager::draw() {
    if (NE_DBG_FIRST(240)) {
        neDebugLog("AepManager::draw transMode=%d transFrames=%d transTotal=%d transColor=0x%x "
                   "screen=%dx%d renderScale=%.3f",
                   m_transitionMode,
                   m_transitionFrames,
                   m_transitionTotal,
                   m_transitionColor,
                   screenWidth(),
                   screenHeight(),
                   m_ot.renderScale());
    }
    if (m_transitionTotal > 0 && (m_transitionMode == 1 || m_transitionMode == 2)) {
        // Progress runs 100 -> 0 as the frames count down. The binary computes this
        // as INTEGER division ((frames*100)/total via ___divsi3 @ 0x105c6) and only
        // then converts to float (vcvt.f32.s32 @ 0x105d0), so a non-exact ratio
        // truncates toward zero before the fade math -- not a float divide.
        float progress = static_cast<float>((m_transitionFrames * 100) / m_transitionTotal);
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

// Ghidra: FUN_0001151c — queue the full-screen fade quad (geometry from
// m_transitionOverlay, opacity `alpha` 0..100, colour m_transitionColor). The
// fill writes the rect into nTexU/nTexV/nPosX/nPosY, the alpha into flPosXf and
// the colour into flPosYf; renderAepOrderingTable case 4 then hands those to
// drawAepOtRect(x, y, w, h, alpha, colour). AepManager::draw @0x1058c passes a
// constant priority 1 (disasm: mov r11,#1 -> strd at [sp,#0xc], the nPriority
// stack arg). The flush walks bucket 0x31 first down to 0 last, so bucket 1 draws
// after the scene (logos are 5+) and on top. The old kOtPriMax-1 (49) put the
// fade behind everything, so nothing saw it.
// @complete
void AepManager::drawTransitionOverlay(int alpha) {
    AepOtSpriteCmd *cmd = m_ot.allocEntry(1);
    if (cmd == nullptr) {
        return;
    }
    cmd->wFlags = 4; // -> renderAepOrderingTable case 4 = drawAepOtRect
    cmd->nBank = 0;
    cmd->nTexU = m_transitionOverlay[0]; // x
    cmd->nTexV = m_transitionOverlay[1]; // y
    cmd->nPosX = m_transitionOverlay[2]; // w
    cmd->nPosY = m_transitionOverlay[3]; // h
    cmd->flPosXf = alpha;                // drawAepOtRect nAlpha (0..100); +0x1c int slot
    cmd->flPosYf = m_transitionColor;    // drawAepOtRect nColor (0x00RRGGBB; 0 = black); +0x20 int
}

// ===========================================================================
// Resource-load name tables, engine init and the text / transition free
// functions.
// ===========================================================================

// Ghidra: buildAepNameHashTable (FUN_0001077c). Build an open-addressed
// name->index table (the same rotate-add hash, mod 2047, that AepNameHashLookup
// probes) from a NUL-separated string block starting at *cursor. Each name's
// start pointer is stored in its bucket's key slot and its ordinal in the value
// slot. On return *cursor is advanced past the block (8-byte aligned) and the
// number of names is returned (-1 on overflow).
// @complete
static int buildAepNameHashTable(const char **cursor, AepManager::NameHashTable *out) {
    std::memset(out, 0, sizeof(*out)); // 0x2ffc bytes
    const char *p = *cursor;
    int count = 0;
    while (*p != '\0') {
        // Rotate-add hash over the NUL-terminated name (identical to the lookup).
        unsigned h = 0;
        unsigned c = (unsigned char)*p;
        const char *q = p;
        do {
            ++q;
            unsigned r = (0x20 - (c & 0x1f)) & 0x1f;
            h = ((h + c) >> r) | ((h + c) << (0x20 - r)); // rotate-right by r
            c = (unsigned char)*q;
        } while (c != 0);

        const int start = (int)(h % 2047);
        int bucket = start;
        while (out->key[bucket] != nullptr) {
            bucket = (bucket + 1) % 2047;
            if (bucket == start) {
                return -1; // table full
            }
        }
        out->key[bucket] = p;
        out->value[bucket] = (uint16_t)count;

        while (*p != '\0') { // skip to this name's terminator
            ++p;
        }
        ++p;
        ++count;
    }
    // The producer 8-byte-aligns the cursor (by its address) after the block.
    const char *end = p + 1;
    uintptr_t misalign = (uintptr_t)end % 8;
    if ((int)misalign > 0) {
        end = p + (9 - (int)misalign);
    }
    *cursor = end;
    return count;
}

// Ghidra: aepManagerInit (FUN_0000f33c). `basePath` is the bundle path
// (this+0), copied alongside `dataPath` (the texture root at this+0x100 =
// baseDir). The binary memsets the per-group frame/sprite tables and seeds the
// transform-matrix stacks — here those are the members' zero-initialised state.
// It then hands the screen extents + render scale to the ordering table and
// seeds the transition defaults (total = 30 frames).
// @complete
void AepManager::init(
    const char *basePath, const char *dataPath, int screenW, int screenH, float scale) {
    (void)basePath; // the bundle-path buffer at this+0 is not separately modelled
    if (dataPath != nullptr) {
        std::strncpy(m_baseDir, dataPath, sizeof(m_baseDir) - 1);
        m_baseDir[sizeof(m_baseDir) - 1] = '\0';
    }

    // Screen extents + render scale -> ordering table; the per-slot texture
    // handle table is the group texture pointers (this+0x7c16e4 in the binary).
    aepOtSetScreenParams(orderingTable(), m_groupTexture, screenW, screenH, scale);

    // Cache the screen extents (the fade-quad w/h slots) and seed the transition
    // defaults.
    m_transitionOverlay[0] = 0;
    m_transitionOverlay[1] = 0;
    m_transitionOverlay[2] = screenW; // screenWidth()  (+0x7f3afc)
    m_transitionOverlay[3] = screenH; // screenHeight() (+0x7f3b00)
    m_transitionMode = 0;
    m_transitionFrames = 0;
    m_transitionTotal = 30; // 0x1e
    m_transitionColor = 0;
    m_maxPriority = 0;
}

// Ghidra: relocateAepData (FUN_0000f824). Build the group's frame / layer /
// user name hash tables from the index header's string-block offsets, rewriting
// each offset in place to the post-block cursor. For the layer block the `n`
// int16 layer ordinals that follow the names are copied into the per-group
// layer-number table (feeding getLyrNo).
// @complete
void AepManager::relocateData(int group, const AepIndexHeader *header, const uint8_t *idxBase) {
    if (group < 0 || group >= AepManager::kMaxAepGroups) {
        return;
    }
    // Frame-name block (+0x04): build the hash table; the cursor then points past it,
    // at the frame-position table. The 32-bit binary writes that pointer back into the
    // header's 4-byte slot in place; on the 64-bit rebuild an 8-byte pointer will not
    // fit, so store it in the manager instead.
    if (header->frameNamesOff != 0) {
        const char *cursor = reinterpret_cast<const char *>(idxBase + header->frameNamesOff);
        buildAepNameHashTable(&cursor, &m_frameNames[group]);
        m_framePosData[group] = reinterpret_cast<const int16_t *>(cursor);
    }
    // Layer-name block (+0x10), followed by the layer-ordinal array; the cursor past
    // both is the frame-entry array.
    if (header->layerNamesOff != 0) {
        const char *cursor = reinterpret_cast<const char *>(idxBase + header->layerNamesOff);
        int n = buildAepNameHashTable(&cursor, &m_groupNames[group]);
        const int16_t *ordinals = reinterpret_cast<const int16_t *>(cursor);
        if (n > 0) {
            for (int i = 0; i < n && i < 256; i++) {
                m_layerNumbers[group][i] = static_cast<uint16_t>(ordinals[i]);
            }
            ordinals += n;
        }
        if (n % 4 != 0) {
            ordinals += (4 - n % 4); // align to 4 int16s (8 bytes)
        }
        m_groupFrameData[group] = reinterpret_cast<const AepFrameEntry *>(ordinals);
    }
    // User-name block (+0x14).
    if (header->userNamesOff != 0) {
        const char *cursor = reinterpret_cast<const char *>(idxBase + header->userNamesOff);
        buildAepNameHashTable(&cursor, &m_userNames[group]);
    }
}

// Ghidra: getAepTransitionMode (FUN_00010724).
// @complete
int getAepTransitionMode(const AepManager *mgr) {
    return mgr->transitionMode();
}

// Ghidra: AepManager::DrawText (FUN_00010540; audit label "aepManagerReset_a" —
// a misnomer). Forward the string + the six positional / per-corner-colour words
// to the ordering table's text command with no clip rect.
// @complete
void AepManager::DrawText(
    const char *text, int x, int y, int cTL, int cTR, int cBL, int cBR, int priority) {
    pushAepOtTextCmd(orderingTable(), text, x, y, cTL, cTR, cBL, cBR, nullptr, priority);
}

// Ghidra: AepManager::DrawTextClipped (FUN_0001057c) — as DrawText but threads
// the caller-supplied clip rect straight through.
// @complete
void AepManager::DrawTextClipped(const char *text,
                                 int x,
                                 int y,
                                 int cTL,
                                 int cTR,
                                 int cBL,
                                 int cBR,
                                 const int *clip,
                                 int priority) {
    pushAepOtTextCmd(orderingTable(), text, x, y, cTL, cTR, cBL, cBR, clip, priority);
}

// Ghidra: drawAepTextMultiline (FUN_0002d8b0). Split `text` on '\n' and draw
// each line as a separate text command, vertically centred about `y` with
// `lineHeight` spacing. The per-line call forwards through AepManager::DrawText
// (the audit's aepManagerReset_a).
// @complete
void drawAepTextMultiline(
    const char *text, int a0, int y, int a3, int a4, int lineHeight, int a6, int a7, int a8) {
    // Count lines ('\n'-separated; a non-empty tail counts as a line).
    int lines = 0;
    for (const char *p = text; *p != '\0'; ++p) {
        if (*p == '\n') {
            ++lines;
        }
    }
    if (*text != '\0') {
        ++lines; // the final (unterminated) line
    }
    if (lines <= 0) {
        return;
    }

    // Vertically centre the block about `y`.
    int lineY = y - (lineHeight * (lines - 1)) / 2;

    AepManager &mgr = AepManager::shared();
    const char *cursor = text;
    for (int i = 0; i < lines; i++) {
        const char *nl = std::strchr(cursor, '\n');
        if (nl == nullptr) {
            nl = text + std::strlen(text); // last line runs to the end (Ghidra quirk: from `text`)
        }
        size_t len = (size_t)(nl - cursor);
        if (len > 0xfe) {
            len = 0xff;
        }
        char line[256];
        std::strncpy(line, cursor, len);
        line[len] = '\0';

        // Ghidra arg order: DrawText(mgr, line, a4, a0, lineY, a3, a8, a6, a7).
        mgr.DrawText(line, a4, a0, lineY, a3, a8, a6, a7);

        cursor = nl + 1;
        lineY += lineHeight;
    }
}
