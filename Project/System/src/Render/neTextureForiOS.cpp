//
//  neTextureForiOS.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. A drawable
//  sprite backed by the shared AepTexture cache; draws a textured quad into the
//  ordering table.
//

#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "AepOrderingTable.h"
#include "AepTexture.h"
#include "neTextureForiOS.h"

// Ghidra: FUN_00015eb4 — clears the two reserved words and defaults the tile span to
// 7x7; the vtable pointer is written by the compiler-generated prologue.
AepTile::AepTile() = default;
AepTile::~AepTile() = default;

// Ghidra: FUN_00011818 — vtable + null fields (a detached, unloaded sprite).
neTextureForiOS::neTextureForiOS() = default;

// Ghidra: FUN_00011a2c — resolve + cache-load `path`, then read its dimensions.
int neTextureForiOS::load(const char *path) {
    if (path == nullptr) {
        return -1;
    }

    // The binary builds a lowercased copy of the path (in-place tolower over a scratch
    // std::string), but the cache acquire below is called with the ORIGINAL path
    // (FUN_00011a2c: the lowercased buffer is left unused; r0 = param_2 at the bl).
    std::string key(path);
    for (char &c : key) {
        c = (char)std::tolower((unsigned char)c);
    }
    (void)key;

    // One tile for the common (non-split) case; the split-texture path (loadFrames)
    // allocates more. Ghidra: the +0x08/+0x0c/+0x10/+0x14 heap arrays sized 1 here.
    m_tileCount = 1;
    m_tiles = new AepTexture *[1];
    m_tileRects = new AepTile[1];      // 0x18-byte record (ctor FUN_00015eb4)
    m_tileWidths = new int[1];
    m_tileHeights = new int[1];

    m_tiles[0] = AepTextureCacheAcquire(path);  // FUN_0001bbf0 (original path, not the lowercased key)
    if (m_tiles[0] == nullptr) {
        return -5;   // 0xfffffffb: the texture failed to load
    }

    m_tileWidths[0] = m_tiles[0]->textureWidth();    // AepTexture +0x1c
    m_tileHeights[0] = m_tiles[0]->textureHeight();  // AepTexture +0x20
    AepTextureUploadTiles(&m_tileRects[0], m_tiles[0]);   // FUN_000166ec
    return 0;
}

// Ghidra: FUN_00011e18 — index-driven tile load. The tile count is a uint16 at
// indexBase+2; each tile i is acquired from the shared cache under the path
// "<dir>/<name>_<i>.png" (or "<name>_<i>.png" when dir is null), its padded texture
// size is recorded, and its upload record is bound. Bails early on a null argument
// (-1 in the binary) or a tile that fails to load (-5); the return code is discarded
// by the sole caller (AepManager), so this reconstruction is void.
void neTextureForiOS::loadFrames(const char *dir, const char *name,
                                 const uint8_t *indexBase) {
    if (name == nullptr || indexBase == nullptr) {
        return;   // 0xffffffff in FUN_00011e18
    }

    // Tile count: uint16 at indexBase+2. Ghidra: *(ushort *)(param_4 + 2).
    const int tileCount = *reinterpret_cast<const uint16_t *>(indexBase + 2);

    // Parallel per-tile arrays: handles (+0x10), upload records (+0x14), and padded
    // width/height (+0x08/+0x0c). Ghidra: operator new[] for each, count at +0x04.
    m_tiles = new AepTexture *[tileCount];
    m_tileRects = new AepTile[tileCount];   // 0x18-byte records (ctor FUN_00015eb4)
    m_tileWidths = new int[tileCount];
    m_tileHeights = new int[tileCount];
    m_tileCount = tileCount;

    for (int i = 0; i < tileCount; ++i) {
        // Build the bundled PNG path. Ghidra: sprintf "%s_%d.png" / "%s/%s_%d.png".
        char path[320];
        if (dir == nullptr) {
            std::snprintf(path, sizeof(path), "%s_%d.png", name, i);
        } else {
            std::snprintf(path, sizeof(path), "%s/%s_%d.png", dir, name, i);
        }

        AepTexture *tex = AepTextureCacheAcquire(path);  // FUN_0001bbf0
        m_tiles[i] = tex;
        if (tex == nullptr) {
            return;   // 0xfffffffb in FUN_00011e18
        }

        m_tileWidths[i] = tex->textureWidth();    // AepTexture +0x1c
        m_tileHeights[i] = tex->textureHeight();  // AepTexture +0x20
        AepTextureUploadTiles(&m_tileRects[i], tex);   // FUN_000166ec
    }
}

// Ghidra: neTextureForiOS_draw (FUN_0000fbcc) is the wrapper that emits this sprite
// into the ordering table via AepOrderingTable_drawSprite (FUN_00011468: allocEntry
// FUN_00010be0 + the field fill inlined below). A null clip defaults to screen bounds.
void neTextureForiOS::draw(AepOrderingTable *ot, const neSpriteDrawParams &p) {
    AepSpriteCommand *cmd = ot->allocEntry(p.priority);
    if (cmd == nullptr) {
        return;
    }
    cmd->priority = 1;               // +0x04 (live command marker)
    cmd->textureId = 0;              // +0x08
    cmd->u = p.u;   cmd->v = p.v;    // +0x0c/+0x10
    cmd->x = p.x;   cmd->y = p.y;    // +0x14/+0x18
    cmd->sx = p.sx; cmd->sy = p.sy;  // +0x1c/+0x20
    cmd->w = p.w;   cmd->h = p.h;    // +0x24/+0x28
    cmd->ex = p.ex; cmd->ey = p.ey;  // +0x2c/+0x30
    cmd->color0 = (short)p.color;    // +0x34
    cmd->rotation = p.rotation;      // +0x38
    cmd->blend = p.blend0;           // +0x3c
    cmd->clip[0] = p.blend1;         // +0x40 (blend sub-mode)
    // +0x44 colour-mul, +0x48 extra, +0x4c.. clip rect are carried in the command's
    // opaque tail; when no explicit clip is given the flush defaults it to the
    // screen bounds (Ghidra: reads *(param_1+4)/*(param_1+8) at iVar1+0x54/0x58).
    (void)p.clip;
}

// neTextureForiOS_draw (FUN_0000fbcc), the flat-argument sprite-draw wrapper, is defined in
// neEngineBridge.mm — it needs AepManager (whose header pulls Foundation) which cannot be
// included into this pure-C++ .cpp.

// Release the cached tiles (the cache is ref-counted; drop our references) and the
// parallel per-tile arrays allocated by load()/loadFrames().
neTextureForiOS::~neTextureForiOS() {
    delete[] m_tiles;
    delete[] m_tileRects;
    delete[] m_tileWidths;
    delete[] m_tileHeights;
}
