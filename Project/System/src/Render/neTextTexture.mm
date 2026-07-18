//
//  neTextTexture.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The dynamic
//  text subsystem: a singleton manager that renders glyphs on demand, packs
//  them into 256x256 alpha atlases, and lays out + batches strings into
//  textured quads drawn through the current renderer. Original tree:
//  .../Project/System/src/Render/neTextTexture.mm.
//

#include <cstdint>
#include <cstring>
#include <vector>

#import <CoreText/CoreText.h> // CTFontManagerRegisterFontsForURL (bundled DynaFont)
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h> // CALayer renderInContext:
#import <UIKit/UIKit.h>           // UILabel / UIFont / UIColor / UIGraphics + CoreGraphics

#import "C_RENDER.h"
#import "C_TEXTURE.h" // neCreateTextureFromData / neTextureRelease (texture cache)
#import "neDebugLog.h"
#import "neTextTexture.h"

// The manager singleton (Ghidra: DAT_0018845c), created lazily by the engine
// bootstrap.
static neTextTextureMgr *g_pTextTextureMgr = nullptr;

// Shared index buffer for the glyph quad batches (Ghidra:
// g_pTextQuadIndexBuffer). Built once, on the first neDrawText, for 256 quads
// (0x400 vertices / 0x600 indices).
static unsigned g_pTextQuadIndexBuffer = 0;

// One cached glyph record (Ghidra: the 0x20-byte node allocated by
// createTextGlyphEntry and filled by renderGlyphToAtlas). Keyed by its UTF-8
// bytes + scaled point size.
struct neGlyph {
    char *key = nullptr;     // +0x00 UTF-8 bytes of the glyph (nul-terminated) — cache key
    int32_t pointSize = 0;   // +0x04 scaled point size — second half of the cache key
    neGlyph *next = nullptr; // +0x08 cache list link
    int32_t atlasId = 0;     // +0x0c atlas index the glyph packed into
    int32_t advance = 0;     // +0x10 glyph cell width / horizontal advance
    int32_t height = 0;      // +0x14 glyph cell height
    int32_t cellX = 0;       // +0x18 cell origin in the atlas
    int32_t cellY = 0;       // +0x1c
};

// Ghidra: FUN_00017998.
// @complete
neTextTextureMgr *neGetTextTextureMgr(void) {
    return g_pTextTextureMgr;
}

// @newCode
// The glyph path builds fonts with [UIFont fontWithName:@"DFMaruGothic-Bd-WIN-RKSJ-H"]
// (the DynaFont rounded gothic). The original binary neither bundled a registration
// call nor listed the font in UIAppFonts — it relied on that face being an
// OS-provided font on the iOS 8 Japanese SDK. Modern iOS no longer ships it, so
// fontWithName: would return nil and createTextGlyphEntry would return null (then
// neDrawText dereferences the null glyph). The app *does* bundle the face as the
// TrueType collection "prf02w07", so register it here, once, before any text draws.
static void registerBundledFonts() {
    NSString *path = [NSBundle.mainBundle pathForResource:@"prf02w07" ofType:nil];
    if (path == nil) {
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, nullptr);
}

namespace neEngine {
// Ghidra: neEngine::bootstrapC (FUN_0001796c) — lazily create the singleton
// glyph/text-texture manager. Idempotent: a second call is a no-op. `fixedShift`
// becomes the content-scale shift applied to point sizes. This lives in the same
// translation unit as `g_pTextTextureMgr` (as it does in the original), so the
// store actually reaches the static the whole text path reads through
// neGetTextTextureMgr; a stub in another unit would leave the manager null and
// every neDrawText would dereference it.
// @complete
void bootstrapC(int fixedShift) {
    if (g_pTextTextureMgr != nullptr) {
        return;
    }
    registerBundledFonts(); // @newCode — make the bundled DynaFont resolvable
    g_pTextTextureMgr = new neTextTextureMgr();
    g_pTextTextureMgr->scaleShift = static_cast<int8_t>(fixedShift);
    g_pTextTextureMgr->glyphList = nullptr;
    g_pTextTextureMgr->atlasCount = 0;
    g_pTextTextureMgr->atlases = nullptr;
}
} // namespace neEngine

// Ghidra: FUN_00017a84 — UTF-8 lead-byte length classifier.
// @complete
int utf8CharLen(neTextTextureMgr * /*mgr*/, const char *s) {
    unsigned c = static_cast<unsigned char>(*s);
    if ((c & 0x80) == 0) {
        return 1;
    }
    if ((c & 0x40) == 0) {
        return 0; // stray continuation byte
    }
    if ((c & 0x20) == 0) {
        return 2;
    }
    if ((c & 0x10) == 0) {
        return 3;
    }
    if ((c & 0x08) == 0) {
        return 4;
    }
    if ((c & 0x04) == 0) {
        return 5;
    }
    if ((c & 0x02) == 0) {
        return 6;
    }
    return -1; // invalid
}

// Ghidra: FUN_000180a4 — release the atlas's ne::C_TEXTURE reference and free its
// pixels (the unique_ptr buffer releases automatically).
// @complete
neTextTexture::~neTextTexture() {
    if (texture != nullptr) {
        neTextureRelease(texture);
    }
}

// Ghidra: FUN_000179a8 — free the whole glyph cache and destroy every atlas.
// @complete
neTextTextureMgr::~neTextTextureMgr() {
    // Glyph cache: singly-linked (data at +0x00, next at +0x08).
    struct GlyphNode {
        uint8_t *data;
        void *_rsv;
        GlyphNode *next;
    };
    GlyphNode *g = static_cast<GlyphNode *>(glyphList);
    while (g != nullptr) {
        GlyphNode *next = g->next;
        delete[] g->data;
        delete g;
        g = next;
    }
    glyphList = nullptr;

    // Atlas list: destroy + free each neTextTexture.
    neTextTexture *a = atlases;
    while (a != nullptr) {
        neTextTexture *next = a->next;
        delete a;
        a = next;
    }
    atlases = nullptr;
    atlasCount = 0;
}

// Ghidra: FUN_00017b28 — allocate a fresh 256x256 glyph atlas and link it in.
// The binary used GL_LUMINANCE_ALPHA (format 2), but that deprecated format is
// not sampled correctly by modern iOS's GLES 1.1, which garbled all text (the CPU
// glyph bitmap is correct; only text uses this format and only text was broken).
// Upload the atlas as GL_RGBA (format 1) instead and replicate the LA behaviour by
// writing the coverage into all four channels; this is a modern-iOS correctness
// fix, not an ENABLE_PATCHES change.
// @complete
void neTextTextureMgr::createNewTextTexture() {
    neTextTexture *atlas = new neTextTexture();
    atlas->pixels = std::make_unique<uint8_t[]>(0x40000); // 256x256 RGBA, zero-cleared
    void *tex =
        neCreateTextureFromData(0x100, 0x100, /*GL_RGBA*/ 1, atlas->pixels.get(), 0x100, 0x100);
    // assert(tex) — neTextTexture.mm:0xeb in the shipped binary.
    atlas->index = atlasCount;
    atlas->texture = tex;
    ++atlasCount;
    atlas->next = atlases;
    atlases = atlas;
}

// One textured glyph vertex (16 bytes): GL_FLOAT position, GL_SHORT UV, premult
// RGBA8. The backend specifies the position array as GL_FLOAT (0x1406, verified
// in FUN_0001342c), so the positions must be stored as floats — integer bytes
// would be reinterpreted as near-zero denormals and collapse every glyph quad.
struct neGlyphVertex {
    float x;
    float y;
    int16_t u;
    int16_t v;
    uint8_t rgba[4];
};

// @ 0x17ad4
// Ghidra: FUN_00017ad4 — linear search of the glyph cache for a record matching
// the first UTF-8 char of `utf8` at `pointSize`; returns null when not cached.
// @complete
neGlyph *neTextTextureMgr::findCachedGlyph(const char *utf8, int pointSize) {
    size_t len = utf8CharLen(this, utf8);
    for (neGlyph *g = static_cast<neGlyph *>(glyphList); g != nullptr; g = g->next) {
        if (g->pointSize == pointSize && std::strncmp(g->key, utf8, len) == 0) {
            return g;
        }
    }
    return nullptr;
}

// @ 0x17b10
// Ghidra: FUN_00017b10 — find the atlas with index `atlasId` in the manager's
// list.
// @complete
neTextTexture *neTextTextureMgr::findTextTextureById(int atlasId) {
    for (neTextTexture *a = atlases; a != nullptr; a = a->next) {
        if (a->index == atlasId) {
            return a;
        }
    }
    return nullptr;
}

// @ 0x17bb4
// Ghidra: FUN_00017bb4 — reserve a `w`x`h` cell in the current (head) atlas,
// packing along a row and wrapping/opening a new atlas (bounded to two spills)
// when full. Writes the cell origin to *outX/*outY. Returns false only when the
// glyph is larger than an atlas (in which case *outX/*outY are left as the
// caller set them).
// @complete
bool neTextTextureMgr::allocGlyphAtlasSlot(int w, int h, int *outX, int *outY) {
    int retries = 0;
    for (;;) {
        neTextTexture *atlas = atlases;
        if (atlas == nullptr) {
            createNewTextTexture();
            atlas = atlases;
        }
        ne::C_TEXTURE *tex = static_cast<ne::C_TEXTURE *>(atlas->texture);
        int atlasW = tex->textureWidth();  // ne::C_TEXTURE +0x1c
        int atlasH = tex->textureHeight(); // ne::C_TEXTURE +0x20

        // A glyph that is as wide/tall as an atlas can never be packed.
        if (w >= atlasW || h >= atlasH) {
            return false;
        }

        int col = atlas->rowHeight; // +0x10 horizontal pack cursor
        *outX = col;
        int colEnd = col + w;
        int row = atlas->penX; // +0x08 vertical cursor for the current row
        *outY = row;
        if (atlasW <= colEnd) { // current row exhausted -> wrap to the next
            *outX = 0;
            row = atlas->penY; // +0x0c next-row baseline
            *outY = row;
            colEnd = w;
        }

        int rowEnd = row + h;
        if (rowEnd < atlasH) { // fits vertically -> commit the cursors
            atlas->penX = row;
            atlas->rowHeight = colEnd;
            if (rowEnd >= atlas->penY) {
                atlas->penY = rowEnd;
            }
            return true;
        }

        // Atlas full: flush its CPU pixels to GL and open a fresh one.
        neTextureRebind(tex, atlas->pixels.get());
        createNewTextTexture();
        if (++retries > 1) {
            return true;
        }
    }
}

// @ 0x17c44
// Ghidra: FUN_00017c44 — render one glyph string into a device-gray
// CGBitmapContext via the label's CALayer, then copy it into the reserved atlas
// cell (two bytes per texel, the gray value duplicated into both luminance and
// alpha). Fills the glyph record's atlas placement. (ARC: the NSString and
// CGContexts are managed here; the CF color space / bitmap context are
// CoreFoundation and released explicitly.)
// @complete
int neTextTextureMgr::renderGlyphToAtlas(const char *utf8, UILabel *label, neGlyph *glyph) {
    NSString *str = [[NSString alloc] initWithUTF8String:utf8];
    UIFont *font = [label font];

    CGSize size = CGSizeZero;
    if (str != nil) {
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        size = [str sizeWithAttributes:@{NSFontAttributeName : font}];
#else
        size = [str sizeWithFont:font];
#endif
    }
    // The binary rounds the measured size to integer texels (FPToFixed, mode 3).
    int w = static_cast<int>(size.width);
    int h = static_cast<int>(size.height);

    int cellX = -1;
    int cellY = -1;
    const bool slotOk = allocGlyphAtlasSlot(w, h, &cellX, &cellY);

    neTextTexture *atlas = atlases;

    // Rasterize the glyph into a w*h, 1-byte/pixel device-gray bitmap. The binary
    // sizes this buffer from the FLOAT product (int)(width*height) (vmul.f32 +
    // vcvt.s32.f32 @ 0x17d04), not (int)width * (int)height; the CGBitmapContext
    // below still uses the truncated w/h for its dimensions and stride.
    std::vector<uint8_t> gray(static_cast<size_t>(static_cast<int>(size.width * size.height)));
    [label setFrame:CGRectMake(0, 0, size.width, size.height)];
    [label setText:str];

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(gray.data(), w, h, 8, w, cs, kCGImageAlphaNone);
    CGContextClearRect(ctx, CGRectMake(0, 0, size.width, size.height));
    UIGraphicsPushContext(ctx);
    CGContextTranslateCTM(ctx, 0, size.height); // flip to UIKit's top-left origin
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    [[label layer] renderInContext:ctx];
    UIGraphicsPopContext();
    CGColorSpaceRelease(cs);
    CGContextRelease(ctx);

    // Blit the gray bitmap into the atlas cell. The atlas is GL_RGBA (see
    // createNewTextTexture); replicate the binary's luminance-alpha by writing the
    // coverage into all four channels (RGB = A = gray), so a MODULATE by the glyph
    // vertex colour reproduces the original LA result.
    ne::C_TEXTURE *tex = static_cast<ne::C_TEXTURE *>(atlas->texture);
    int atlasW = tex->textureWidth();
    const int atlasH = tex->textureHeight();
    // allocGlyphAtlasSlot returns true even on its give-up path (2 failed
    // new-texture retries, matching the binary), leaving cellX/cellY at the
    // overflow cursor near or past the atlas edge. Blitting there writes past the
    // 256x256 atlas buffer and crashes on a wild address -- seen while rasterising
    // song titles, which produce far more new glyphs than the menu did. Only blit
    // when the reserved cell is fully in bounds; otherwise leave the glyph blank
    // (it still advances). The draw-time UV read is GL-clamped, so only the write
    // is unsafe.
    const bool cellInBounds =
        slotOk && cellX >= 0 && cellY >= 0 && cellX + w <= atlasW && cellY + h <= atlasH;
    if (cellInBounds) {
        // The packer advances cellX by the glyph WIDTH, so cellX is the COLUMN and
        // cellY (the shelf base, advanced by the height) is the ROW: byte =
        // (cellY + rrow) * atlasW + (cellX + col) (binary: mla shelf, atlasW, pen @
        // 0x17e40). Indexing the row by cellX instead overlapped consecutive glyph
        // cells and garbled text.
        for (int rrow = 0; rrow < h; ++rrow) {
            const uint8_t *src = gray.data() + rrow * w;
            uint8_t *dst = atlas->pixels.get() + ((cellY + rrow) * atlasW + cellX) * 4;
            for (int col = 0; col < w; ++col) {
                uint8_t g = src[col];
                dst[col * 4 + 0] = g;
                dst[col * 4 + 1] = g;
                dst[col * 4 + 2] = g;
                dst[col * 4 + 3] = g;
            }
        }
    } else {
        cellX = 0;
        cellY = 0; // keep the glyph's UV valid (samples the cleared top-left)
    }
    if (NE_DBG_FIRST(60)) {
        int nz = 0;
        int maxGray = 0;
        for (int p = 0; p < w * h; ++p) {
            if (gray[p]) {
                ++nz;
            }
            if (gray[p] > maxGray) {
                maxGray = gray[p];
            }
        }
        neDebugLog("glyphRaster '%s' font=%s size=(%.2f,%.2f) wh=(%d,%d) cell=(%d,%d) "
                   "atlasW=%d nonzero=%d/%d maxGray=%d",
                   utf8,
                   [[[label font] fontName] UTF8String],
                   size.width,
                   size.height,
                   w,
                   h,
                   cellX,
                   cellY,
                   atlasW,
                   nz,
                   w * h,
                   maxGray);
    }

    glyph->atlasId = atlas->index;
    glyph->advance = w;
    glyph->height = h;
    // cellX is the column (its u source) and cellY the row (its v source), matching
    // the blit above and the binary (glyph+0x18 = the pen @ 0x17eb0 -> neDrawText u,
    // glyph+0x1c = shelf @ 0x17eb4 -> v).
    glyph->cellX = cellX; // +0x18 -> u (column)
    glyph->cellY = cellY; // +0x1c -> v (row)
    return 1;
}

// @ 0x17ecc
// Ghidra: FUN_00017ecc — allocate a glyph record for the first UTF-8 char of
// `utf8` at `pointSize`, rasterize it into an atlas, re-upload that atlas, and
// push the record onto the manager's cache. `fontName` null => the bold system
// font. Returns null on an invalid lead byte or an unresolvable font.
neGlyph *
neTextTextureMgr::createTextGlyphEntry(const char *utf8, const char *fontName, int pointSize) {
    int len = utf8CharLen(this, utf8);
    if (len < 1) {
        return nullptr;
    }

    neGlyph *glyph = new neGlyph();
    glyph->pointSize = pointSize;
    glyph->key = new char[len + 1];
    std::strncpy(glyph->key, utf8, len);
    glyph->key[len] = '\0';

    // The binary converts the (fixed-point) point size to a float for UIFont.
    CGFloat sizePt = static_cast<CGFloat>(pointSize);
    UIFont *font;
    if (fontName == nullptr) {
        font = [UIFont boldSystemFontOfSize:sizePt];
    } else {
        NSString *name = [NSString stringWithUTF8String:fontName];
        font = [UIFont fontWithName:name size:sizePt];
    }
    if (font == nil) {
        delete[] glyph->key;
        delete glyph;
        return nullptr;
    }

    UILabel *label = [[UILabel alloc] init];
    [label setFont:font];
    [label setTextColor:[UIColor whiteColor]];
    [label setTextAlignment:NSTextAlignmentLeft];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setNumberOfLines:0];

    renderGlyphToAtlas(glyph->key, label, glyph);

    // Re-upload the atlas the glyph landed in so the new pixels reach GL.
    neTextTexture *atlas = atlases;
    if (atlas != nullptr) {
        neTextureRebind(static_cast<ne::C_TEXTURE *>(atlas->texture), atlas->pixels.get());
    }

    // Head-insert onto the glyph cache.
    glyph->next = static_cast<neGlyph *>(glyphList);
    glyphList = glyph;
    // (ARC releases `label`.)
    return glyph;
}

// Ghidra: FUN_0001551c — measure, lay out and batch-draw a string.
// @complete
void neDrawText(const char *text,
                const char *font,
                int size,
                int x,
                int y,
                int align,
                int alpha,
                int red,
                int green,
                int blue,
                const int *clipRect) {
    neTextTextureMgr *mgr = neGetTextTextureMgr();
    int shift = mgr->scaleShift;
    int len = static_cast<int>(std::strlen(text));

    // --- Measure: resolve each char to a cached glyph, accumulate total advance.
    // ---
    static constexpr int kMaxChars = 256;
    int glyphAtlas[kMaxChars];  // per-char atlas id (-1 => skip)
    neGlyph *glyphs[kMaxChars]; // per-char glyph record (0 => skip)
    int totalWidth = 0;
    int count = len < kMaxChars ? len : kMaxChars;
    for (int i = 0; i < count; ++i) {
        if (utf8CharLen(mgr, text + i) < 1) {
            glyphAtlas[i] = -1;
            glyphs[i] = nullptr;
            continue;
        }
        neGlyph *g = mgr->findCachedGlyph(text + i, size << shift);
        if (g == nullptr) {
            g = mgr->createTextGlyphEntry(text + i, font, size << shift);
        }
        glyphAtlas[i] = g->atlasId;
        glyphs[i] = g;
        totalWidth += g->advance;
    }

    ne::C_RENDER *r = neGetCurrentRenderer();

    // --- Shared quad index buffer (256 quads: 0,1,2, 2,1,3 per quad). ---
    if (g_pTextQuadIndexBuffer == 0) {
        r->genBuffer(g_pTextQuadIndexBuffer);
        r->bindElementBuffer(g_pTextQuadIndexBuffer);
        int16_t indices[0x600];
        for (int q = 0, base = 0; q < 256; ++q, base += 4) {
            int16_t *o = &indices[q * 6];
            o[0] = base;
            o[1] = base + 1;
            o[2] = base + 2;
            o[3] = base + 2;
            o[4] = base + 1;
            o[5] = base + 3;
        }
        r->bufferData(indices, sizeof(indices), 0);
    } else {
        r->bindElementBuffer(g_pTextQuadIndexBuffer);
    }

    // --- Base draw state: current viewport, model = translate(x,y), identity
    // pivot. ---
    neApplyViewport(r, neGetCurrentViewport());
    neMatrix4 model;
    matrixSetTranslate(model, static_cast<float>(x), static_cast<float>(y), 0.0f);
    neMatrix4 pivot;
    matrixSetTranslate(pivot, 0.0f, 0.0f,
                       0.0f); // Ghidra: translate(0x80000000,...) == -0
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

    // Straight-alpha blend + clear the remaining caps (same tail as the
    // primitives).
    r->setEnable(0, false);
    r->setEnable(1, true);
    r->setBlendFunc(1, 5);
    static constexpr int kCaps[] = {
        2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17,   18,
        19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 0x23,
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

    // Straight-alpha input, premultiplied for the (GL_ONE,
    // GL_ONE_MINUS_SRC_ALPHA) blend: each colour channel is scaled by alpha/255
    // (DAT_00015db0 == 255.0); alpha is stored straight.
    uint8_t aa = static_cast<uint8_t>(alpha);
    float premul = static_cast<float>(alpha) / 255.0f;
    uint8_t rr = static_cast<uint8_t>(static_cast<float>(red) * premul);
    uint8_t gg = static_cast<uint8_t>(static_cast<float>(green) * premul);
    uint8_t bb = static_cast<uint8_t>(static_cast<float>(blue) * premul);

    for (int i = 0; i < count; ++i) {
        int atlasId = glyphAtlas[i];
        if (atlasId < 0) {
            continue;
        }
        neTextTexture *atlas = mgr->findTextTextureById(atlasId);
        ne::C_TEXTURE *tex = static_cast<ne::C_TEXTURE *>(atlas->texture);
        float atlasW = static_cast<float>(tex->textureWidth());  // ne::C_TEXTURE +0x1c
        float atlasH = static_cast<float>(tex->textureHeight()); // ne::C_TEXTURE +0x20

        // Emit every glyph that belongs to this atlas into `quads`, advancing the
        // pen.
        int pen = alignOffset;
        int quadCount = 0;
        for (int j = 0; j < count; ++j) {
            neGlyph *g = glyphs[j];
            if (g == nullptr) {
                continue;
            }
            if (g->atlasId != atlasId) {
                pen += (g->advance >> 1); // still advance for glyphs on other atlases
                continue;
            }
            int w = g->advance; // cell width / horizontal advance
            int h = g->height;  // cell height
            float u0 = static_cast<float>(g->cellX) / atlasW;
            float u1 = u0 + static_cast<float>(w) / atlasW;
            float v0 = static_cast<float>(g->cellY) / atlasH;
            float v1 = v0 + static_cast<float>(h) / atlasH;
            neGlyphVertex *v = &quads[quadCount * 4];
            // Glyphs are rasterized at 2x and drawn at half size: the quad spans
            // (w/2) x (h/2).
            int px = pen, py = 0, halfW = w >> 1, halfH = h >> 1;
            for (int k = 0; k < 4; ++k) {
                v[k].x = px + ((k & 1) ? halfW : 0);
                v[k].y = py + ((k & 2) ? halfH : 0);
                v[k].u = static_cast<int16_t>((((k & 1) ? u1 : u0)) * 32767.0f);
                v[k].v = static_cast<int16_t>((((k & 2) ? v1 : v0)) * 32767.0f);
                v[k].rgba[0] = rr;
                v[k].rgba[1] = gg;
                v[k].rgba[2] = bb;
                v[k].rgba[3] = aa;
            }
            pen += (w >> 1);
            ++quadCount;
            glyphs[j] = nullptr; // consumed
        }

        r->setEnable(0x22, true);        // GL_TEXTURE_2D
        r->bindTexture(tex->name());     // ne::C_TEXTURE +0x18
        setTexParamCached(tex, r, 2, 7); // wrap S = REPEAT
        setTexParamCached(tex, r, 3, 7); // wrap T = REPEAT
        setTexParamCached(tex, r, 0, 0); // mag = NEAREST
        setTexParamCached(tex, r, 1, 0); // min = NEAREST

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
        r->drawElements(6, quadCount * 6, 0); // GL_TRIANGLES, indexed
    }

    // Evict the atlas cache when it has grown past 4 textures (Ghidra: > 4). The
    // binary calls the destructor explicitly here to clear the manager in place;
    // it stays alive and its lists are reset to empty.
    if (mgr->atlasCount > 4) {
        mgr->~neTextTextureMgr();
    }
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
