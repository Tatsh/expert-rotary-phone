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
#include "neDebugLog.h"
#include "neTextureForiOS.h"

// Ghidra: FUN_00015eb4 — clears the two reserved words and defaults the tile
// span to 7x7; the vtable pointer is written by the compiler-generated
// prologue.
// @complete
AepTile::AepTile() = default;

// Ghidra: FUN_00015edc (~AepTile / ~neTextureRef) — NOT a defaulted destructor:
// it drops the reference the upload path retained on the tile's bound texture
// (+0x04) via neTextureRelease (FUN_00018200), then leaves the compiler-emitted
// operator-delete thunk to free the storage.
// @complete
AepTile::~AepTile() {
    if (uploaded != nullptr) {
        neTextureRelease(uploaded);
        uploaded = nullptr;
    }
}

// Ghidra: FUN_00011818 — vtable + null fields (a detached, unloaded sprite).
// @complete
neTextureForiOS::neTextureForiOS() = default;

// Ghidra: FUN_00011a2c — resolve + cache-load `path`, then read its dimensions.
// @complete
int neTextureForiOS::load(const char *path) {
    if (path == nullptr) {
        return -1;
    }

    // The binary builds a lowercased copy of the path (in-place tolower over a
    // scratch std::string), but the cache acquire below is called with the
    // ORIGINAL path (FUN_00011a2c: the lowercased buffer is left unused; r0 =
    // param_2 at the bl).
    std::string key(path);
    for (char &c : key) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    (void)key;

    // One tile for the common (non-split) case; the split-texture path
    // (loadFrames) allocates more. Ghidra: the +0x08/+0x0c/+0x10/+0x14 heap
    // arrays sized 1 here.
    m_tileCount = 1;
    m_tiles = new AepTexture *[1];
    m_tileRects = new AepTile[1]; // 0x18-byte record (ctor FUN_00015eb4)
    m_tileWidths = new int[1];
    m_tileHeights = new int[1];

    m_tiles[0] =
        AepTextureCacheAcquire(path); // FUN_0001bbf0 (original path, not the lowercased key)
    if (m_tiles[0] == nullptr) {
        neDebugLog("neTextureForiOS::load FAILED path='%s' (acquire returned null)", path);
        return -5; // 0xfffffffb: the texture failed to load
    }

    m_tileWidths[0] = m_tiles[0]->textureWidth();       // AepTexture +0x1c
    m_tileHeights[0] = m_tiles[0]->textureHeight();     // AepTexture +0x20
    AepTextureUploadTiles(&m_tileRects[0], m_tiles[0]); // FUN_000166ec
    neDebugLog("neTextureForiOS::load OK path='%s' tex=%p glName=%u w=%d h=%d tile.uploaded=%p",
               path,
               static_cast<void *>(m_tiles[0]),
               m_tiles[0]->name(),
               m_tileWidths[0],
               m_tileHeights[0],
               static_cast<void *>(m_tileRects[0].uploaded));
    return 0;
}

// Ghidra: FUN_00011e18 — index-driven tile load. The tile count is a uint16 at
// indexBase+2; each tile i is acquired from the shared cache under the path
// "<dir>/<name>_<i>.png" (or "<name>_<i>.png" when dir is null), its padded
// texture size is recorded, and its upload record is bound. Bails early on a
// null argument
// (-1 in the binary) or a tile that fails to load (-5); the return code is
// discarded by the sole caller (AepManager), so this reconstruction is void.
// @complete
void neTextureForiOS::loadFrames(const char *dir, const char *name, const uint8_t *indexBase) {
    if (name == nullptr || indexBase == nullptr) {
        return; // 0xffffffff in FUN_00011e18
    }

    // Tile count: uint16 at indexBase+2. Ghidra: *(ushort *)(param_4 + 2).
    const int tileCount = *reinterpret_cast<const uint16_t *>(indexBase + 2);

    // Parallel per-tile arrays: handles (+0x10), upload records (+0x14), and
    // padded width/height (+0x08/+0x0c). Ghidra: operator new[] for each, count
    // at +0x04.
    m_tiles = new AepTexture *[tileCount];
    m_tileRects = new AepTile[tileCount]; // 0x18-byte records (ctor FUN_00015eb4)
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

        AepTexture *tex = AepTextureCacheAcquire(path); // FUN_0001bbf0
        m_tiles[i] = tex;
        if (tex == nullptr) {
            return; // 0xfffffffb in FUN_00011e18
        }

        m_tileWidths[i] = tex->textureWidth();       // AepTexture +0x1c
        m_tileHeights[i] = tex->textureHeight();     // AepTexture +0x20
        AepTextureUploadTiles(&m_tileRects[i], tex); // FUN_000166ec
    }
}

// Ghidra: neTextureForiOS_draw (FUN_0000fbcc) is the wrapper that emits this
// sprite into the ordering table via AepOrderingTable_drawSprite (FUN_00011468:
// allocEntry FUN_00010be0 + the field fill inlined below). A null clip defaults
// to screen bounds.
// @complete
void neTextureForiOS::draw(AepOrderingTable *ot, const neSpriteDrawParams &p) {
    // Fill a stretched-sprite command (wFlags=1) through the real fill
    // AepOrderingTable::drawSprite (FUN_00011468). The sprite's texture is THIS
    // object: it is stored verbatim in the command's nTexU slot and the flush's
    // case-1 dispatch reinterprets it as the neTextureFrames* that
    // drawAepOtSpriteStretch -> drawAepSpriteClipped -> neDrawTexturedQuad walk
    // (this class carries the frame tables the chain reads: tile count @+0x04,
    // width/height tables @+0x08/+0x0c, per-tile render-state records @+0x14). No
    // GL-name bridge is needed any more.
    //
    // The neSpriteDrawParams fields map onto the command slots by the offsets the
    // binary's neTextureForiOS::draw (FUN_0000fbcc) forwards them into. That wrapper
    // vcvt.f32.s32-converts exactly its 9th and 10th args (the scale values) to float
    // (0x0fbf4/0x0fc0c) and passes every other arg as a plain int, so the base size /
    // position go to the int slots +0x1c/+0x20 (flPosXf/flPosYf) and the scale % go to
    // the FLOAT slots +0x28/+0x2c (nOfsYF/nColorAF). A null clip leaves the flush to
    // default it to the screen bounds.
    // Field mapping is exact per Ghidra FUN_0000fbcc: the source origin (u) goes to
    // nTexV; the base size (w,h) into nPosY/flPosXf; the position (x,y) into
    // flPosYf/nOfsX; the scale (sx,sy) into the float nOfsY/nColorA slots; and the
    // colour percentage / secondary colour word / rotation / blend / layer /
    // colour-multiply into the remaining slots. The flush's case-1 dispatch
    // (renderAepOrderingTable) reads them back in this order.
    ot->drawSprite(this,                             // pTexObj: the source neTextureForiOS*
                   p.u,                              // nTexV
                   p.v,                              // nPosX
                   p.w,                              // nPosY (base width)
                   p.h,                              // flPosXf (base height; int slot +0x1c)
                   p.x,                              // flPosYf (screen X; int slot +0x20)
                   p.y,                              // nOfsX   (screen Y)
                   static_cast<float>(p.sx),         // nOfsY   (X scale %; float slot +0x28)
                   static_cast<float>(p.sy),         // nColorA (Y scale %; float slot +0x2c)
                   p.ex,                             // nColorMul
                   p.ey,                             // nUKey | nVKey<<16
                   p.color,                          // nBlendFlags (colour % -> quad alpha)
                   p.alpha,                          // nColorRGB (secondary colour-flags word)
                   static_cast<int16_t>(p.rotation), // clipRect.nLeft low half
                   static_cast<int16_t>(p.blend0),   // clipRect.nLeft high half (blend mode)
                   p.layer,                          // clipRect.nTop
                   p.colorMul,                       // clipRect.nRight (RGB -> quad colour)
                   p.clip,                           // clip-spill block -> command +0x4c
                   p.priority);
}

// neTextureForiOS_draw (FUN_0000fbcc), the flat-argument sprite-draw wrapper,
// is defined in neEngineBridge.mm — it needs AepManager (whose header pulls
// Foundation) which cannot be included into this pure-C++ .cpp.

// Ghidra: FUN_00011838 — release the cached tiles (the cache is ref-counted) and
// free the parallel per-tile arrays allocated by load()/loadFrames(). Each tile
// texture carries two references: one the acquire path retained in m_tiles[i]
// (dropped here by the loop) and one the upload path retained in
// m_tileRects[i].uploaded (dropped by delete[] m_tileRects running ~AepTile). The
// free order matches the binary: release loop, then m_tileRects, then the widths /
// heights / handles arrays.
// @complete
neTextureForiOS::~neTextureForiOS() {
    for (int i = 0; i < m_tileCount; ++i) {
        if (m_tiles[i] != nullptr) {
            neTextureRelease(m_tiles[i]); // FUN_00018200: drop the acquire reference
        }
    }
    delete[] m_tileRects; // runs ~AepTile per element -> drops the upload reference
    delete[] m_tileWidths;
    delete[] m_tileHeights;
    delete[] m_tiles;
}
