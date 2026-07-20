//
//  C_TEXTURE.h
//  pop'n rhythmin
//
//  A GL texture decoded from an image file, referenced by AepLyrCtrl layers and
//  shared (refcounted, keyed by path) through the engine's texture cache. On a
//  GL context loss the name is freed and re-uploaded on return to foreground.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (RTTI type
//  ne::C_TEXTURE, type_info @0x12e308; vtable @0x13089c; ctor FUN_000180c4, load
//  FUN_00018218, upload FUN_000185a0, releaseGL FUN_00018884, reload FUN_000188ac;
//  cache FUN_0001bbf0).
//

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#import <OpenGLES/ES1/gl.h>

namespace ne {

class C_TEXTURE {
public:
    C_TEXTURE();
    ~C_TEXTURE();

    // Decode `path` (a bundled PNG, with @2x fallback) and upload it as a GL
    // texture. Returns true on success. Ghidra: FUN_00018218.
    bool load(const char *path);

    // Free the GL name (called when the GL context is lost on background).
    // Ghidra: FUN_00018884.
    void releaseGL();

    // Re-decode + re-upload from the stored path (on return to foreground).
    // Ghidra: FUN_000188ac.
    bool reload();

    GLuint name() const {
        return m_name;
    } // +0x18 GL texture name
    // Original bundle path (+0x10), used as the shared-cache key. Ghidra:
    // FUN_0001bbf0 strcmp's this against the requested path when scanning the
    // cache list.
    const char *cacheKey() const {
        return m_path;
    }
    int width() const {
        return m_width;
    } // +0x24 source width
    int height() const {
        return m_height;
    } // +0x28 source height
    int textureWidth() const {
        return m_texWidth;
    } // +0x1c padded (pow2) width
    int textureHeight() const {
        return m_texHeight;
    } // +0x20 padded (pow2) height

    // Setters used by the in-memory data path (neTextureSetDataParams /
    // neTextureLoadFromData / neTextureUpload) to fill the same fields load()
    // populates from a decoded file.
    void setSourceSize(int w, int h) {
        m_width = w;
        m_height = h;
    } // +0x24/+0x28
    void setBufferSize(int bytes) {
        m_bufferSize = bytes;
    } // +0x2c
    void setScale(float s) {
        m_scale = s;
    } // +0x44
    void adoptGLName(GLuint n, int texW, int texH) { // +0x18/+0x1c/+0x20
        m_name = n;
        m_texWidth = texW;
        m_texHeight = texH;
    }

    // Intrusive cache-list links (Ghidra: refcount +0x04, next +0x08, prev
    // +0x0c).
    int refCount = 0;
    C_TEXTURE *next = nullptr;
    C_TEXTURE *prev = nullptr;

private:
    // Decode `path` into a power-of-two RGBA buffer and upload it as a GL texture
    // through neTextureUpload (Ghidra: FUN_000185a0).
    bool decodeAndUpload(const char *path);

    char *m_path = nullptr;     // +0x10 original path (cache key)
    char *m_filePath = nullptr; // +0x14 resolved bundle path (for reload)
    GLuint m_name = 0;          // +0x18 GL texture name (0 = not uploaded)
    int m_texWidth = 0;         // +0x1c padded width
    int m_texHeight = 0;        // +0x20 padded height
    int m_width = 0;            // +0x24 source width
    int m_height = 0;           // +0x28 source height
    int m_bufferSize = 0;       // +0x2c
public:
    // Per-texture tex-param cache (Ghidra: tex+0x30): the last value applied for
    // each of the 4 tex-param types {MAG,MIN,WRAP_S,WRAP_T}. neTextureUpload seeds
    // it to the values it applies; setTexParamCached (C_RENDER.cpp) consults it
    // to skip redundant glTexParameteri calls.
    int m_texParamCache[4] = {}; // +0x30
    int m_format = 0;            // +0x40 upload format (0=RGBA, 2=ALPHA); read by neTextureRebind
    int format() const {
        return m_format;
    }

private:
    float m_scale = 1.0f; // +0x44 (2.0 for an @2x asset)
};

} // namespace ne

// GPU texture-memory accounting: total bytes of all live textures. Ghidra:
// g_dwTextureMemTotal.
extern int g_dwTextureMemTotal;

// The single head of the shared, refcounted, path-keyed texture cache (Ghidra:
// the one global list head that AepTextureCacheAcquire links into and both the
// background (onDidEnterBackground) and foreground (notifyEnterForeground) GL
// handlers walk). Defined in neEngineBridge.mm; the sentinel node is created
// lazily by AepTextureCacheSentinel(). null until the first texture is cached.
extern ne::C_TEXTURE *g_textureCacheList;

// Return the shared cache list head, lazily building the self-linked sentinel node
// into g_textureCacheList on first call. The engine bootstrap (bootstrapB) calls
// this to create it eagerly; the acquire path calls it on demand.
ne::C_TEXTURE *AepTextureCacheSentinel(void);

// Drop one shared-cache reference of `tex` (a C_TEXTURE); on the last
// reference it frees the GL name, unlinks from the cache list and destroys it.
// Ghidra: FUN_00018200.
void neTextureRelease(void *tex);

// Record source dimensions + byte size for an already-decoded RGBA image and
// upload it as a single GL texture (`texW`x`texH` padded size). Returns 1.
// Ghidra: FUN_00018644.
int neTextureSetDataParams(
    ne::C_TEXTURE *tex, int width, int height, int format, const void *pixels, int texW, int texH);

// Decode an in-memory image (a bridged NSData* of PNG/other bytes) via UIImage
// and upload it as a power-of-two GL texture. Returns 1 on success, 0 on decode
// failure. Ghidra: FUN_00018684.
int neTextureLoadFromData(ne::C_TEXTURE *tex, const void *nsData);

// Re-bind + re-upload this texture through the current renderer (context
// restore path). Ghidra: FUN_00018828.
void neTextureRebind(ne::C_TEXTURE *tex, const void *pixels);

// Allocate a C_TEXTURE from raw pixel data, upload it and link it into the
// shared cache. Returns the new texture (refcounted) or null on failure.
// Ghidra: FUN_0001bcfc.
ne::C_TEXTURE *
neCreateTextureFromData(int width, int height, int format, const void *pixels, int texW, int texH);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
