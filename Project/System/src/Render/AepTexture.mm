//
//  AepTexture.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Decodes a
//  bundled PNG (with @2x fallback) into a power-of-two RGBA buffer via
//  UIImage/CoreGraphics and uploads it as a GL texture. Every GL call routes
//  through the current renderer's neGLES_11 facade — genTexture (+0xb4),
//  deleteTexture (+0xb8), bindTexture (+0xc0), applyTexParameter (+0xc4) and
//  uploadTexture (+0xcc) — exactly as the binary does, so the backend's bound-
//  texture cache stays coherent. Ghidra: load FUN_00018218, upload FUN_000185a0,
//  release FUN_00018884, dtor FUN_000180f8, release-ref FUN_00018200.
//

#include <cstdlib>
#include <cstring>

#import <UIKit/UIKit.h>

#import "AepTexture.h"
#import "neDebugLog.h"
#import "neRenderer.h"      // current renderer for neTextureRebind
#import "neTextureForiOS.h" // AepTile + the cache/bind free functions declared here

// GPU texture-memory accounting (Ghidra: g_dwTextureMemTotal).
int g_dwTextureMemTotal = 0;

// The single GL-upload routine (Ghidra: FUN_000185a0); defined below, forward-
// declared here for decodeAndUpload.
static int neTextureUpload(AepTexture *tex, int texW, int texH, int format, const void *pixels);

// Ghidra: FUN_000180cc — the ctor installs the vtable and sets m_scale = 1.0f
// (+0x44); every other field is zero (the disasm zero-fills +0x04..+0x33 with
// three vst1 stores and writes +0x40 = 0). The in-class member initializers
// reproduce this exactly.
// @complete
AepTexture::AepTexture() = default;

// Ghidra: FUN_000180f8 — the destructor owns teardown: unlink from the shared
// cache ring (+0x08 next / +0x0c prev), free both path strings (+0x10/+0x14),
// delete the GL name through the renderer's deleteTexture vtable slot (+0xb8)
// guarded on the name ALONE (unlike releaseGL, which also guards m_filePath),
// and debit g_dwTextureMemTotal by m_bufferSize (+0x2c). FUN_00018160 is the
// compiler-emitted deleting-destructor thunk (this dtor + operator delete under
// an SjLj cleanup frame); neTextureRelease dispatches through it on the last
// reference.
// @complete
AepTexture::~AepTexture() {
    if (next != nullptr && prev != nullptr) { // unlink from the cache ring
        next->prev = prev;
        prev->next = next;
    }
    free(m_path);     // +0x10
    free(m_filePath); // +0x14
    if (m_name != 0) {
        neGetCurrentRenderer()->deleteTexture(m_name); // +0xb8
    }
    g_dwTextureMemTotal -= m_bufferSize; // +0x2c
}

bool AepTexture::load(const char *path) {
    if (path == nullptr) {
        return false;
    }
    free(m_path);
    m_path = strdup(path); // +0x10 cache key
    return decodeAndUpload(path);
}

// Ghidra: FUN_00018884 — free the GL name on context loss (the GL context is
// gone on background). Guards on BOTH the resolved path (+0x14) and the name
// (+0x18), and routes the delete through the renderer's deleteTexture vtable slot
// (+0xb8) so the backend's bound-texture cache is cleared too — a raw
// glDeleteTextures would leave a stale cache entry for a later reused name.
// @complete
void AepTexture::releaseGL() {
    if (m_filePath != nullptr && m_name != 0) {
        neGetCurrentRenderer()->deleteTexture(m_name); // +0xb8
        m_name = 0;
    }
}

// Ghidra: FUN_000188ac — re-decode the stored RESOLVED file (+0x14) and re-upload
// on return to foreground (the GL context was dropped on background). Unlike the
// initial decode this does NOT re-resolve the bundle path, re-read m_scale,
// re-record m_bufferSize or touch g_dwTextureMemTotal — it reuses the existing
// padded buffer size (+0x2c) for the CoreGraphics context and re-uploads through
// the same neTextureUpload path. Returns true when there is nothing to reload
// (no resolved path) or the re-upload succeeds, false only on a decode failure.
// @complete
bool AepTexture::reload() {
    if (m_filePath == nullptr) {
        return true;
    }
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:@(m_filePath)];
    if (image == nil) {
        return false;
    }
    CGImageRef cg = image.CGImage;
    m_width = (int)CGImageGetWidth(cg);   // +0x24
    m_height = (int)CGImageGetHeight(cg); // +0x28

    int tw = 1;
    while (tw < m_width) {
        tw <<= 1; // pad to power of two
    }
    int th = 1;
    while (th < m_height) {
        th <<= 1;
    }

    void *pixels = calloc(1, m_bufferSize); // reuse the recorded padded size (+0x2c)
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx =
        CGBitmapContextCreate(pixels, tw, th, 8, tw * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, m_height); // flip to GL's bottom-left origin
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextDrawImage(ctx, CGRectMake(0, 0, m_width, m_height), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);

    neTextureUpload(this, tw, th, /*TEX_FORMAT_RGBA*/ 1, pixels);
    free(pixels);
    return true;
}

// Ghidra: FUN_00018218 — resolve the bundle path, decode, and upload. Together
// with load() (its m_path-recording entry) this reconstructs the single shipped
// function: bundle lookup order (base+ext, then raw-path fallback, then @2x, then
// base+ext), m_bufferSize = tw*4*th, g_dwTextureMemTotal += m_bufferSize, and the
// format-1 upload through neTextureUpload are all disassembly-verified.
// @complete
bool AepTexture::decodeAndUpload(const char *path) {
    NSString *full = @(path);
    NSString *ext = full.pathExtension;
    NSString *base = [full substringToIndex:full.length - 1 - ext.length];
    NSBundle *bundle = NSBundle.mainBundle;

    // Resolve base+ext in the bundle; if that misses, fall back to the raw path
    // string and attempt to load THAT as the primary image. Only if this first
    // load fails do we try the
    // "@2x" variant, then a final bundle lookup of base+ext (faithful to the
    // binary's order).
    NSString *resolved = [bundle pathForResource:base ofType:ext];
    if (resolved == nil) {
        resolved = full; // raw path fallback
    }
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:resolved];
    if (image != nil) {
        if ([image respondsToSelector:@selector(scale)]) {
            m_scale = (float)image.scale;
        }
    } else {
        // @2x variant, then the plain base+ext lookup.
        NSString *at2x = [NSString stringWithFormat:@"%@@2x", base];
        resolved = [bundle pathForResource:at2x ofType:ext];
        image = [[UIImage alloc] initWithContentsOfFile:resolved];
        if (image != nil) {
            m_scale = 2.0f;
        } else {
            resolved = [bundle pathForResource:base ofType:ext];
            image = [[UIImage alloc] initWithContentsOfFile:resolved];
            if (image == nil) {
                return false;
            }
        }
    }

    free(m_filePath);
    m_filePath = strdup(resolved.UTF8String); // +0x14 resolved path (for reload)

    CGImageRef cg = image.CGImage;
    m_width = (int)CGImageGetWidth(cg);
    m_height = (int)CGImageGetHeight(cg);

    int tw = 1;
    while (tw < m_width) {
        tw <<= 1; // pad to power of two
    }
    int th = 1;
    while (th < m_height) {
        th <<= 1;
    }
    m_bufferSize = tw * 4 * th;
    g_dwTextureMemTotal += m_bufferSize; // GPU memory accounting (FUN_00018218)

    void *pixels = calloc(1, m_bufferSize);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx =
        CGBitmapContextCreate(pixels, tw, th, 8, tw * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, m_height); // flip to GL's bottom-left origin
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextDrawImage(ctx, CGRectMake(0, 0, m_width, m_height), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);

    // File textures are RGBA (format ordinal 1); upload through the one shared
    // GL-upload routine (the binary calls FUN_000185a0 here, not a distinct
    // file-only uploader).
    neTextureUpload(this, tw, th, /*TEX_FORMAT_RGBA*/ 1, pixels);
    free(pixels);
    return true;
}

// Head of the shared texture cache. Ghidra: DAT_00188464 is a circular,
// sentinel-terminated doubly-linked list of AepTexture nodes (links at
// next/+0x08, prev/+0x0c; refcount at +0x04). NEEngine_bootstrapB
// (FUN_0001ba60) builds the sentinel — an empty AepTexture whose next/prev
// point back at itself. It is created lazily into the shared g_textureCacheList
// head so the acquire path and the background/foreground GL handlers
// (onDidEnterBackground / notifyEnterForeground, which read the very same global)
// all walk ONE list. The self-linked empty-node structure is confirmed by the
// list walk/splice in AepTextureCacheAcquire (FUN_0001bbf0).
// @complete
AepTexture *AepTextureCacheSentinel() {
    if (g_textureCacheList == nullptr) {
        AepTexture *s = new AepTexture(); // operator new(0x48) + ctor FUN_000180c4
        s->next = s;
        s->prev = s;
        g_textureCacheList = s;
    }
    return g_textureCacheList;
}

// Ghidra: FUN_0001bbf0 — resolve a bundled image path through the shared cache.
// Returns the existing entry (with its refcount bumped) when the path is
// already cached, else loads a fresh AepTexture, links it to the front of the
// list, and returns it. Returns null when the image fails to load (the binary,
// like this, leaves the failed allocation without an explicit delete). The
// neDebugLog calls are RHYDBG diagnostics that compile out in the shipped config.
// @complete
AepTexture *AepTextureCacheAcquire(const char *path) {
    AepTexture *sentinel = AepTextureCacheSentinel();

    for (AepTexture *node = sentinel->next; node != sentinel; node = node->next) {
        if (node->cacheKey() != nullptr && std::strcmp(node->cacheKey(), path) == 0) {
            ++node->refCount; // +0x04
            return node;
        }
    }

    AepTexture *tex = new AepTexture(); // operator new(0x48) + ctor FUN_000180c4
    if (!tex->load(path)) {             // FUN_00018218 (returns 1 on success)
        neDebugLog("AepTextureCacheAcquire LOAD-FAILED path='%s'", path ? path : "(null)");
        return nullptr;
    }
    neDebugLog("AepTextureCacheAcquire loaded path='%s' glName=%u w=%d h=%d",
               path ? path : "(null)",
               tex->name(),
               tex->textureWidth(),
               tex->textureHeight());
    ++tex->refCount; // +0x04

    // push_front: splice the new node in between the sentinel and the current
    // first.
    AepTexture *first = sentinel->next;
    first->prev = tex;
    tex->next = first;
    tex->prev = sentinel;
    sentinel->next = tex;
    return tex;
}

// Ghidra: FUN_000166ec — release the tile's previously-bound texture
// (FUN_00018200), then retain and bind the new one. The 2nd argument is a real
// incoming AepTexture* (verified in the disassembly) that the decompiler drops
// at the call site. The tile's texture is at tile+0x4; its refcount at +0x04.
// @complete
void AepTextureUploadTiles(AepTile *tile, AepTexture *tex) {
    // Release whatever texture the tile currently holds — unconditionally, the
    // binary does NOT skip the release when the incoming texture is the same one
    // — then retain and store the new one. The release routes through
    // neTextureRelease (drops one reference; on the last one it frees the GL
    // name, unlinks from the shared cache list and destroys it).
    if (tile->uploaded != nullptr) {
        neTextureRelease(tile->uploaded);
        tile->uploaded = nullptr;
    }
    if (tex != nullptr) {
        ++tex->refCount; // +0x04 retain
        tile->uploaded = tex;
    }
}

// Ghidra: FUN_000185a0 — the one shared GL upload every decode path funnels
// through. Records the format (+0x40), generates and binds a fresh texture name
// through the renderer facade, sets the four tex-params (WRAP_S/T = REPEAT,
// MAG/MIN = NEAREST) via applyTexParameter (+0xc4), seeds the texture's own
// tex-param cache (+0x30 = {MAG,MIN,WRAP_S,WRAP_T} = {0,0,7,7}) so
// setTexParamCached will not redundantly re-issue those, then uploads the pixels
// through uploadTexture (+0xcc, which maps the engine format ordinal to its GL
// enum — RGBA(1) or LUMINANCE_ALPHA(2)). Returns 1. No old name is released: a
// fresh load has none, and a foreground reload's old names died with the GL
// context.
// @complete
static int neTextureUpload(AepTexture *tex, int texW, int texH, int format, const void *pixels) {
    tex->m_format = format; // +0x40
    neRenderer *r = neGetCurrentRenderer();
    unsigned name = 0;
    r->genTexture(name);         // +0xb4 glGenTextures
    r->bindTexture(name);        // +0xc0
    r->applyTexParameter(2, 7);  // +0xc4  WRAP_S = REPEAT
    r->applyTexParameter(3, 7);  //        WRAP_T = REPEAT
    r->applyTexParameter(0, 0);  //        MAG    = NEAREST
    r->applyTexParameter(1, 0);  //        MIN    = NEAREST
    tex->m_texParamCache[0] = 0; // seed the per-texture tex-param cache (+0x30)
    tex->m_texParamCache[1] = 0;
    tex->m_texParamCache[2] = 7;
    tex->m_texParamCache[3] = 7;
    r->uploadTexture(format, texW, texH, pixels); // +0xcc glTexImage2D (maps the format)
    NE_DBG(GLenum glErr = glGetError();
           neDebugLog("neTextureUpload glName=%u %dx%d fmt=%d pixels=%p glErr=0x%x",
                      name,
                      texW,
                      texH,
                      format,
                      pixels,
                      (unsigned)glErr));
    // Publish the name + padded size back onto the texture (AepTexture
    // +0x18/+0x1c/+0x20).
    tex->adoptGLName(name, texW, texH);
    return 1;
}

// Ghidra: FUN_00018644 — record dims + byte size for pre-decoded pixels and
// upload. The byte size is width*height*4 (source dims, not the padded texW*texH),
// added to g_dwTextureMemTotal; returns 1. Disassembly-verified.
// @complete
int neTextureSetDataParams(
    AepTexture *tex, int width, int height, int format, const void *pixels, int texW, int texH) {
    tex->setSourceSize(texW, texH); // +0x24/+0x28
    int bytes = width * height * 4;
    tex->setBufferSize(bytes); // +0x2c
    g_dwTextureMemTotal += bytes;
    neTextureUpload(tex, width, height, format, pixels);
    return 1;
}

// Ghidra: FUN_00018684 — decode an in-memory image (bridged NSData*) and upload
// it as a power-of-two GL texture. bytes = tw*4*th, added to g_dwTextureMemTotal;
// format-1 upload; returns 1 on success, 0 on decode failure. Disassembly-verified.
// @complete
int neTextureLoadFromData(AepTexture *tex, const void *nsData) {
    UIImage *image = [[UIImage alloc] initWithData:(__bridge NSData *)nsData];
    if (image == nil) {
        return 0;
    }
    if ([image respondsToSelector:@selector(scale)]) {
        tex->setScale((float)image.scale);
    }
    CGImageRef cg = image.CGImage;
    int w = (int)CGImageGetWidth(cg);
    int h = (int)CGImageGetHeight(cg);
    tex->setSourceSize(w, h);

    int tw = 1;
    while (tw < w) {
        tw <<= 1; // pad to power of two
    }
    int th = 1;
    while (th < h) {
        th <<= 1;
    }
    int bytes = tw * 4 * th;
    tex->setBufferSize(bytes);
    g_dwTextureMemTotal += bytes;

    void *pixels = calloc(1, bytes);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx =
        CGBitmapContextCreate(pixels, tw, th, 8, tw * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, h); // flip to GL's bottom-left origin
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);

    neTextureUpload(tex, tw, th, /*TEX_FORMAT_RGBA*/ 1, pixels);
    free(pixels);
    return 1;
}

// Ghidra: FUN_00018828 — re-bind + re-upload through the current renderer.
// bindTexture(name) (+0xc0) then uploadTexture(format, texWidth, texHeight, pixels)
// (+0xcc). Disassembly-verified.
// @complete
void neTextureRebind(AepTexture *tex, const void *pixels) {
    neRenderer *r = neGetCurrentRenderer();
    r->bindTexture(tex->name()); // +0xc0
    r->uploadTexture(tex->format(), tex->textureWidth(), tex->textureHeight(),
                     pixels); // +0xcc
}

// Ghidra: FUN_0001bcfc — build a cached AepTexture from raw pixel data.
// @complete
AepTexture *
neCreateTextureFromData(int width, int height, int format, const void *pixels, int texW, int texH) {
    AepTexture *tex = new AepTexture(); // operator new(0x48) + ctor FUN_000180cc
    if (neTextureSetDataParams(tex, width, height, format, pixels, texW, texH) != 1) {
        // Unreachable in practice (neTextureSetDataParams always returns 1); the
        // binary simply returns null here without destroying the allocation.
        return nullptr;
    }
    ++tex->refCount; // +0x04

    // push_front onto the shared cache list.
    AepTexture *sentinel = AepTextureCacheSentinel();
    AepTexture *first = sentinel->next;
    first->prev = tex;
    tex->next = first;
    tex->prev = sentinel;
    sentinel->next = tex;
    return tex;
}

// The foreground-reload walk (Ghidra FUN_0001be20) is reconstructed once, as
// neEngineBridge's notifyEnterForeground (the function AppDelegate actually wires
// on applicationDidBecomeActive), walking this same g_textureCacheList. The
// earlier duplicate here was dead (no caller) and has been removed.

// Ghidra: FUN_00018200 — drop one shared-cache reference; on the last one, hand
// the node to `delete` (its deleting-destructor vtable slot +0x04). The unlink,
// GL-name delete and memory-accounting all live in the destructor (FUN_000180f8),
// so this is just the refcount gate — it does NOT unlink or release GL itself.
// @complete
void neTextureRelease(void *tex) {
    AepTexture *t = static_cast<AepTexture *>(tex);
    if (--t->refCount != 0) { // destroy only when the count hits exactly zero
        return;
    }
    delete t;
}
