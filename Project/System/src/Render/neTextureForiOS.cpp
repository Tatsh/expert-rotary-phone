//
//  neTextureForiOS.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. A drawable
//  sprite backed by the shared AepTexture cache; draws a textured quad into the
//  ordering table.
//

#include <cctype>
#include <cstring>
#include <string>

#include "AepOrderingTable.h"
#include "AepTexture.h"
#include "neTextureForiOS.h"

// Acquire (ref-counted) the cached AepTexture for a bundled image path, loading +
// uploading it on first use. Ghidra: FUN_0001bbf0 (the texture cache; head list
// DAT_00188464, see neEngineBridge). Distinct reconstruction unit — declared here.
extern AepTexture *AepTextureCacheAcquire(const char *path);

// Push the tile's decoded pixels to GL. Ghidra: FUN_000166ec (uploadGL wrapper).
extern void AepTextureUploadTiles(void *subRects);

// Ghidra: FUN_00011818 — vtable + null fields (a detached, unloaded sprite).
neTextureForiOS::neTextureForiOS() = default;

// Ghidra: FUN_00011a2c — resolve + cache-load `path`, then read its dimensions.
int neTextureForiOS::load(const char *path) {
    if (path == nullptr) {
        return -1;
    }

    // The cache key is the lowercased path (the original lower-cases in place).
    std::string key(path);
    for (char &c : key) {
        c = (char)std::tolower((unsigned char)c);
    }

    // One tile for the common (non-split) case; the split-texture path allocates
    // more. Ghidra: the +0x10/+0x14 heap arrays sized 1 here.
    m_tileCount = 1;
    m_tiles = new AepTexture *[1];
    m_tiles[0] = AepTextureCacheAcquire(key.c_str());
    if (m_tiles[0] == nullptr) {
        return -5;   // 0xfffffffb: the texture failed to load
    }

    m_width = m_tiles[0]->width();     // AepTexture +0x24
    m_height = m_tiles[0]->height();   // AepTexture +0x28
    AepTextureUploadTiles(m_subRects); // FUN_000166ec
    return 0;
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

// Release the cached tiles (the cache is ref-counted; drop our references).
neTextureForiOS::~neTextureForiOS() {
    delete[] m_tiles;
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
