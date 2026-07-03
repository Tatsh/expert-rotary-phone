//
//  neTextTexture.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The dynamic text
//  subsystem: a singleton manager that renders glyphs on demand, packs them into
//  256x256 alpha atlases, and lays out + batches strings into textured quads drawn
//  through the current renderer. Original tree:
//  .../Project/System/src/Render/neTextTexture.mm.
//

#include <cstdint>
#include <cstring>

#import <OpenGLES/ES1/gl.h>

#import "AepTexture.h"        // neCreateTextureFromData / neTextureRelease (texture cache)
#import "neRenderer.h"
#import "neTextTexture.h"

// The manager singleton (Ghidra: DAT_0018845c), created lazily by the engine bootstrap.
static neTextTextureMgr *g_pTextTextureMgr = nullptr;

// Shared index buffer for the glyph quad batches (Ghidra: g_pTextQuadIndexBuffer). Built
// once, on the first neDrawText, for 256 quads (0x400 vertices / 0x600 indices).
static unsigned g_pTextQuadIndexBuffer = 0;

// Glyph-cache + atlas helpers reconstructed alongside this file (same original .mm).
// TODO(dep): full bodies tracked separately; declared here so neDrawText reads faithfully.
extern int findCachedGlyph(neTextTextureMgr *mgr, const char *utf8, int pointSize);   // FUN_000175xx
extern int createTextGlyphEntry(neTextTextureMgr *mgr, const char *utf8, void *font,  // FUN_000176xx
                                int pointSize);
extern neTextTexture *findTextTextureById(neTextTextureMgr *mgr, int atlasId);        // FUN_000177xx

// One cached glyph record (fields the layout reads): atlas id (+0x0c), advance (+0x10),
// packed cell origin (+0x18/+0x1c) and size (+0x10 hi). Ghidra: the entry created by
// createTextGlyphEntry / CreateNewTextTexture.
struct neGlyph {
    int32_t _rsv00[3];
    int32_t atlasId;   // +0x0c
    int32_t advance;   // +0x10
    int32_t _rsv14;
    int32_t cellX;     // +0x18 origin in the atlas
    int32_t cellY;     // +0x1c
};

// Ghidra: FUN_00017998.
neTextTextureMgr *neGetTextTextureMgr(void) { return g_pTextTextureMgr; }

// Ghidra: FUN_00017a84 — UTF-8 lead-byte length classifier.
int utf8CharLen(neTextTextureMgr * /*mgr*/, const char *s) {
    unsigned c = static_cast<unsigned char>(*s);
    if ((c & 0x80) == 0) return 1;
    if ((c & 0x40) == 0) return 0;          // stray continuation byte
    if ((c & 0x20) == 0) return 2;
    if ((c & 0x10) == 0) return 3;
    if ((c & 0x08) == 0) return 4;
    if ((c & 0x04) == 0) return 5;
    if ((c & 0x02) == 0) return 6;
    return -1;                              // invalid
}

// Ghidra: FUN_000180a4 — release the atlas's AepTexture reference and free its pixels.
neTextTexture::~neTextTexture() {
    delete[] pixels;
    if (texture != nullptr) {
        neTextureRelease(texture);
    }
}

// Ghidra: FUN_000179a8 — free the whole glyph cache and destroy every atlas.
void neTextTextureMgr_dtor(neTextTextureMgr *mgr) {
    // Glyph cache: singly-linked (data at +0x00, next at +0x08).
    struct GlyphNode { uint8_t *data; void *_rsv; GlyphNode *next; };
    GlyphNode *g = static_cast<GlyphNode *>(mgr->glyphList);
    while (g != nullptr) {
        GlyphNode *next = g->next;
        delete[] g->data;
        delete g;
        g = next;
    }
    mgr->glyphList = nullptr;

    // Atlas list: destroy + free each neTextTexture.
    neTextTexture *a = mgr->atlases;
    while (a != nullptr) {
        neTextTexture *next = a->next;
        delete a;
        a = next;
    }
    mgr->atlases = nullptr;
    mgr->atlasCount = 0;
}

// Ghidra: FUN_00017b28 — allocate a fresh 256x256 GL_ALPHA atlas and link it in.
static void CreateNewTextTexture(neTextTextureMgr *mgr) {
    uint8_t *pixels = new uint8_t[0x20000]();   // 256x256 zero-cleared cell buffer
    void *tex = neCreateTextureFromData(0x100, 0x100, /*GL_ALPHA*/ 2, pixels, 0x100, 0x100);
    // assert(tex) — neTextTexture.mm:0xeb in the shipped binary.
    neTextTexture *atlas = new neTextTexture();
    atlas->index = mgr->atlasCount;
    atlas->texture = tex;
    atlas->pixels = pixels;
    ++mgr->atlasCount;
    atlas->next = mgr->atlases;
    mgr->atlases = atlas;
}

// One textured glyph vertex (16 bytes): position, GL_SHORT UV, premult RGBA8.
struct neGlyphVertex {
    int32_t x;
    int32_t y;
    int16_t u;
    int16_t v;
    uint8_t rgba[4];
};

// Ghidra: FUN_0001551c — measure, lay out and batch-draw a string.
void neDrawText(const char *text, void *font, int size, int x, int y, int align,
                int alpha, int red, int green, int blue,
                const int *clipRect) {
    neTextTextureMgr *mgr = neGetTextTextureMgr();
    int shift = mgr->scaleShift;
    int len = static_cast<int>(std::strlen(text));

    // --- Measure: resolve each char to a cached glyph, accumulate total advance. ---
    static const int kMaxChars = 256;
    int glyphAtlas[kMaxChars];   // per-char atlas id (-1 => skip)
    neGlyph *glyphs[kMaxChars];  // per-char glyph record (0 => skip)
    int totalWidth = 0;
    int count = len < kMaxChars ? len : kMaxChars;
    for (int i = 0; i < count; ++i) {
        if (utf8CharLen(mgr, text + i) < 1) {
            glyphAtlas[i] = -1;
            glyphs[i] = nullptr;
            continue;
        }
        int entry = findCachedGlyph(mgr, text + i, size << shift);
        if (entry == 0) {
            entry = createTextGlyphEntry(mgr, text + i, font, size << shift);
        }
        neGlyph *g = reinterpret_cast<neGlyph *>(entry);
        glyphAtlas[i] = g->atlasId;
        glyphs[i] = g;
        totalWidth += g->advance;
    }

    neRenderer *r = neGetCurrentRenderer();

    // --- Shared quad index buffer (256 quads: 0,1,2, 2,1,3 per quad). ---
    if (g_pTextQuadIndexBuffer == 0) {
        r->genBuffer(g_pTextQuadIndexBuffer);
        r->bindElementBuffer(g_pTextQuadIndexBuffer);
        int16_t indices[0x600];
        for (int q = 0, base = 0; q < 256; ++q, base += 4) {
            int16_t *o = &indices[q * 6];
            o[0] = base;     o[1] = base + 1; o[2] = base + 2;
            o[3] = base + 2; o[4] = base + 1; o[5] = base + 3;
        }
        r->bufferData(indices, sizeof(indices), 0);
    } else {
        r->bindElementBuffer(g_pTextQuadIndexBuffer);
    }

    // --- Base draw state: current viewport, model = translate(x,y), identity pivot. ---
    neApplyViewport(r, neGetCurrentViewport());
    neMatrix4 model;
    matrixSetTranslate(model, static_cast<float>(x), static_cast<float>(y), 0.0f);
    neMatrix4 pivot;
    matrixSetTranslate(pivot, 0.0f, 0.0f, 0.0f);   // Ghidra: translate(0x80000000,...) == -0
    matrix4Multiply(model, pivot);
    r->loadMatrix(0, model);

    neGlyphVertex quads[kMaxChars * 4];
    r->setClientArray(5, true);
    r->vertexPointer(&quads[0].x, 2, sizeof(neGlyphVertex));
    r->setClientArray(2, false);
    r->setClientArray(4, true);
    r->texCoordPointer(&quads[0].u, sizeof(neGlyphVertex));
    r->setClientArray(0, true);
    r->colorPointer(&quads[0].rgba, sizeof(neGlyphVertex));

    // Straight-alpha blend + clear the remaining caps (same tail as the primitives).
    r->setEnable(0, false);
    r->setEnable(1, true);
    r->setBlendFunc(1, 5);
    static const int kCaps[] = {
        2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 0x23,
    };
    for (int cap : kCaps) {
        r->setEnable(cap, false);
    }

    // --- Batch by atlas: emit one quad per glyph and drawElements. ---
    int alignOffset;
    if (align == 2) {
        alignOffset = -(totalWidth >> shift);
    } else if (align == 1) {
        alignOffset = -((totalWidth >> shift) / 2);
    } else {
        alignOffset = 0;
    }

    uint8_t rr = static_cast<uint8_t>(red);
    uint8_t gg = static_cast<uint8_t>(green);
    uint8_t bb = static_cast<uint8_t>(blue);
    uint8_t aa = static_cast<uint8_t>(alpha);

    for (int i = 0; i < count; ++i) {
        int atlasId = glyphAtlas[i];
        if (atlasId < 0) {
            continue;
        }
        neTextTexture *atlas = findTextTextureById(mgr, atlasId);
        AepTexture *tex = static_cast<AepTexture *>(atlas->texture);
        float atlasW = static_cast<float>(tex->textureWidth());    // AepTexture +0x1c
        float atlasH = static_cast<float>(tex->textureHeight());   // AepTexture +0x20

        // Emit every glyph that belongs to this atlas into `quads`, advancing the pen.
        int pen = alignOffset;
        int quadCount = 0;
        for (int j = 0; j < count; ++j) {
            neGlyph *g = glyphs[j];
            if (g == nullptr) {
                continue;
            }
            if (g->atlasId != atlasId) {
                pen += (g->advance >> 1);   // still advance for glyphs on other atlases
                continue;
            }
            int w = g->advance;
            float u0 = static_cast<float>(g->cellX) / atlasW;
            float u1 = u0 + static_cast<float>(w) / atlasW;
            float v0 = static_cast<float>(g->cellY) / atlasH;
            float v1 = v0 + static_cast<float>(w) / atlasH;
            neGlyphVertex *v = &quads[quadCount * 4];
            int px = pen, py = 0, ph = w;
            for (int k = 0; k < 4; ++k) {
                v[k].x = px + ((k & 1) ? ph : 0);
                v[k].y = py + ((k & 2) ? ph : 0);
                v[k].u = static_cast<int16_t>((((k & 1) ? u1 : u0)) * 32767.0f);
                v[k].v = static_cast<int16_t>((((k & 2) ? v1 : v0)) * 32767.0f);
                v[k].rgba[0] = rr; v[k].rgba[1] = gg; v[k].rgba[2] = bb; v[k].rgba[3] = aa;
            }
            pen += (w >> 1);
            ++quadCount;
            glyphs[j] = nullptr;   // consumed
        }

        r->setEnable(0x22, true);                              // GL_TEXTURE_2D
        r->bindTexture(tex->name());                           // AepTexture +0x18
        setTexParamCached(tex, r, 2, 7);   // wrap S = REPEAT
        setTexParamCached(tex, r, 3, 7);   // wrap T = REPEAT
        setTexParamCached(tex, r, 0, 0);   // mag = NEAREST
        setTexParamCached(tex, r, 1, 0);   // min = NEAREST

        if (clipRect == nullptr) {
            r->setEnable(3, false);
            r->setEnable(4, false);
            r->setEnable(5, false);
            r->setEnable(6, false);
        } else {
            float left = static_cast<float>(clipRect[0] - x);
            float top = static_cast<float>(clipRect[1] - y);
            float right = left + static_cast<float>(clipRect[2]);
            float bottom = top + static_cast<float>(clipRect[3]);
            GLfloat pL[4] = {1.0f, 0.0f, 0.0f, -left};
            GLfloat pT[4] = {0.0f, -1.0f, 0.0f, bottom};
            GLfloat pR[4] = {-1.0f, 0.0f, 0.0f, right};
            GLfloat pB[4] = {0.0f, 1.0f, 0.0f, -top};
            glClipPlanef(GL_CLIP_PLANE0, pL);
            glClipPlanef(GL_CLIP_PLANE1, pT);
            glClipPlanef(GL_CLIP_PLANE2, pR);
            glClipPlanef(GL_CLIP_PLANE3, pB);
            r->setEnable(3, true);
            r->setEnable(4, true);
            r->setEnable(5, true);
            r->setEnable(6, true);
        }
        r->setEnable(7, false);
        r->setEnable(8, false);
        r->drawElements(6, quadCount * 6, 0);   // GL_TRIANGLES, indexed
    }

    // Evict the atlas cache when it has grown past 4 textures (Ghidra: > 4).
    if (mgr->atlasCount > 4) {
        neTextTextureMgr_dtor(mgr);
    }
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
