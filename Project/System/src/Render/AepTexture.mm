//
//  AepTexture.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Decodes a
//  bundled PNG (with @2x fallback) into a power-of-two RGBA buffer via
//  UIImage/CoreGraphics and uploads it as a GL texture. The binary routes the
//  GL calls through neGLES_11's
//  genTexture/bindTexture/setTexParameter/texImage2D virtuals; those wrap
//  exactly these ES 1.1 calls, used directly here. Ghidra: load FUN_00018218,
//  upload FUN_000185a0, release FUN_00018884.
//

#include <cstdlib>
#include <cstring>

#import <UIKit/UIKit.h>

#import "AepTexture.h"
#import "neRenderer.h"      // current renderer for neTextureRebind
#import "neTextureForiOS.h" // AepTile + the cache/bind free functions declared here

// GPU texture-memory accounting (Ghidra: g_dwTextureMemTotal).
int g_dwTextureMemTotal = 0;

AepTexture::AepTexture() = default; // Ghidra: FUN_000180cc (ctor sets vtable + m_scale=1.0)

// NOTE: the shipped destructor neTextureForiOS_dtor (Ghidra: FUN_000180f8)
// additionally unlinks the texture from the shared cache list (+0x08/+0x0c),
// decrements g_dwTextureMemTotal by m_bufferSize, and routes the GL delete
// through the current renderer's deleteTexture vtable slot (+0xb8) rather than
// glDeleteTextures directly. neTextureForiOS_delete (FUN_00018160) is its
// compiler-emitted deleting-destructor thunk (dtor + operator delete under an
// SjLj cleanup frame). The unlink/accounting here is performed by
// neTextureRelease / AepTextureUploadTiles on the release path.
AepTexture::~AepTexture() {
    releaseGL();
    free(m_path);
    free(m_filePath);
}

bool AepTexture::load(const char *path) {
    if (path == nullptr) {
        return false;
    }
    free(m_path);
    m_path = strdup(path); // +0x10 cache key
    return decodeAndUpload(path);
}

// Ghidra: FUN_00018884 — free the GL name (the GL context is gone on
// background).
void AepTexture::releaseGL() {
    if (m_name != 0) {
        glDeleteTextures(1, &m_name);
        m_name = 0;
    }
}

// Ghidra: FUN_000188ac — re-decode + re-upload from the stored path.
bool AepTexture::reload() {
    return m_path != nullptr && decodeAndUpload(m_path);
}

// Ghidra: FUN_00018218 — resolve the bundle path, decode, and upload.
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

    uploadGL(tw, th, pixels);
    free(pixels);
    return true;
}

// Ghidra: FUN_000185a0 — GL upload (WRAP_S/T = REPEAT, MAG/MIN = NEAREST).
void AepTexture::uploadGL(int texWidth, int texHeight, const void *pixels) {
    m_texWidth = texWidth;
    m_texHeight = texHeight;
    releaseGL();

    glGenTextures(1, &m_name);
    glBindTexture(GL_TEXTURE_2D, m_name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexImage2D(
        GL_TEXTURE_2D, 0, GL_RGBA, texWidth, texHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}

// Head of the shared texture cache. Ghidra: DAT_00188464 points at a circular,
// sentinel-terminated doubly-linked list of AepTexture nodes (links at
// next/+0x08, prev/+0x0c; refcount at +0x04). NEEngine_bootstrapB
// (FUN_0001ba60) builds the sentinel — an empty AepTexture whose next/prev
// point back at itself. It is created lazily here so the cache works regardless
// of which unit reaches it first.
static AepTexture *AepTextureCacheSentinel() {
    static AepTexture *sentinel = [] {
        AepTexture *s = new AepTexture(); // operator new(0x48) + ctor FUN_000180c4
        s->next = s;
        s->prev = s;
        return s;
    }();
    return sentinel;
}

// Ghidra: FUN_0001bbf0 — resolve a bundled image path through the shared cache.
// Returns the existing entry (with its refcount bumped) when the path is
// already cached, else loads a fresh AepTexture, links it to the front of the
// list, and returns it. Returns null when the image fails to load.
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
        return nullptr;
    }
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
// at the call site.
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

// Map the engine texture-format ordinal to its GL enum. The atlas path uses a
// 2-byte LUMINANCE_ALPHA format; artwork uses RGBA.
static GLenum TexDataFormatToGL(int format) {
    switch (format) {
    case 0:
        return GL_ALPHA;
    case 1:
        return GL_LUMINANCE_ALPHA;
    default:
        return GL_RGBA; // 2
    }
}

// GL upload shared by the data paths (Ghidra: neTextureUpload). Stores the
// padded texture size + format, (re)creates the GL name and uploads the pixels.
static void neTextureUpload(AepTexture *tex, int texW, int texH, int format, const void *pixels) {
    tex->m_format = format; // +0x40
    tex->releaseGL();
    GLuint name = 0;
    glGenTextures(1, &name);
    glBindTexture(GL_TEXTURE_2D, name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    GLenum gl = TexDataFormatToGL(format);
    glTexImage2D(GL_TEXTURE_2D, 0, gl, texW, texH, 0, gl, GL_UNSIGNED_BYTE, pixels);
    // Publish the name + padded size back onto the texture (AepTexture
    // +0x18/+0x1c/+0x20).
    tex->adoptGLName(name, texW, texH);
}

// Ghidra: FUN_00018644 — record dims + byte size for pre-decoded pixels and
// upload.
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
// it as a power-of-two GL texture.
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

    neTextureUpload(tex, tw, th, /*RGBA*/ 2, pixels);
    free(pixels);
    return 1;
}

// Ghidra: FUN_00018828 — re-bind + re-upload through the current renderer.
void neTextureRebind(AepTexture *tex, const void *pixels) {
    neRenderer *r = neGetCurrentRenderer();
    r->bindTexture(tex->name()); // +0xc0
    r->uploadTexture(tex->format(), tex->textureWidth(), tex->textureHeight(),
                     pixels); // +0xcc
}

// Ghidra: FUN_0001bcfc — build a cached AepTexture from raw pixel data.
AepTexture *
neCreateTextureFromData(int width, int height, int format, const void *pixels, int texW, int texH) {
    AepTexture *tex = new AepTexture(); // operator new(0x48) + ctor FUN_000180cc
    if (neTextureSetDataParams(tex, width, height, format, pixels, texW, texH) != 1) {
        delete tex;
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

// Ghidra: FUN_0001be20 — walk the cache list and re-upload each texture's GL
// name after a foreground return (NEEngine_notifyForegroundObserver per node).
void neNotifyTexturesForeground(void) {
    AepTexture *sentinel = AepTextureCacheSentinel();
    for (AepTexture *node = sentinel->next; node != sentinel; node = node->next) {
        node->reload();
    }
}

// Ghidra: FUN_00018200 — drop one shared-cache reference; on the last, free the
// GL name, unlink from the cache list and destroy.
void neTextureRelease(void *tex) {
    AepTexture *t = static_cast<AepTexture *>(tex);
    if (--t->refCount != 0) { // destroy only when the count hits exactly zero
        return;
    }
    t->releaseGL();
    t->prev->next = t->next;
    t->next->prev = t->prev;
    delete t;
}
