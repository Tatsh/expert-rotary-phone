/** @file
 * A GL texture decoded from an image file, referenced by AepLyrCtrl layers and shared (refcounted,
 * keyed by path) through the engine's texture cache. On a GL context loss the name is freed and
 * re-uploaded on return to foreground. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (RTTI type ne::C_TEXTURE, type_info @ 0x12e308; vtable @ 0x13089c; constructor
 * FUN_000180c4, load FUN_00018218, upload FUN_000185a0, releaseGL FUN_00018884, reload
 * FUN_000188ac; cache FUN_0001bbf0).
 */

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#import <OpenGLES/ES1/gl.h>

namespace ne {

/**
 * @brief A refcounted GL texture decoded from a bundled image and shared through the engine's
 * path-keyed texture cache.
 */
class C_TEXTURE {
public:
    /**
     * @brief Construct an empty texture with no GL name and no path.
     * @ghidraAddress 0x180c4
     */
    C_TEXTURE();
    /**
     * @brief Free the GL name and the stored paths.
     */
    ~C_TEXTURE();

    /**
     * @brief Decode @p path (a bundled PNG, with an @2x fallback) and upload it as a GL texture.
     * @param path The bundle-relative image path; also becomes the shared-cache key.
     * @return true on success.
     * @ghidraAddress 0x18218
     */
    bool load(const char *path);

    /**
     * @brief Free the GL name, called when the GL context is lost on backgrounding.
     * @ghidraAddress 0x18884
     */
    void releaseGL();

    /**
     * @brief Re-decode and re-upload from the stored path, on return to foreground.
     * @return true on success.
     * @ghidraAddress 0x188ac
     */
    bool reload();

    /**
     * @brief The GL texture name (binary field @ +0x18).
     * @return The GL name, or 0 when nothing is uploaded.
     */
    GLuint name() const {
        return m_name;
    }
    /**
     * @brief The original bundle path (+0x10), used as the shared-cache key.
     *
     * The cache scan (FUN_0001bbf0) strcmp's this against the requested path.
     * @return The cache key.
     */
    const char *cacheKey() const {
        return m_path;
    }
    /**
     * @brief The source image width (binary field @ +0x24).
     * @return The width, in pixels.
     */
    int width() const {
        return m_width;
    }
    /**
     * @brief The source image height (binary field @ +0x28).
     * @return The height, in pixels.
     */
    int height() const {
        return m_height;
    }
    /**
     * @brief The padded power-of-two texture width (binary field @ +0x1c).
     * @return The texture width, in texels.
     */
    int textureWidth() const {
        return m_texWidth;
    }
    /**
     * @brief The padded power-of-two texture height (binary field @ +0x20).
     * @return The texture height, in texels.
     */
    int textureHeight() const {
        return m_texHeight;
    }

    // Setters used by the in-memory data path (neTextureSetDataParams / neTextureLoadFromData /
    // neTextureUpload) to fill the same fields load() populates from a decoded file.

    /**
     * @brief Record the source image dimensions (binary fields @ +0x24 and +0x28).
     * @param w Source width, in pixels.
     * @param h Source height, in pixels.
     */
    void setSourceSize(int w, int h) {
        m_width = w;
        m_height = h;
    }
    /**
     * @brief Record the uploaded pixel-buffer size (binary field @ +0x2c).
     * @param bytes The buffer size, in bytes.
     */
    void setBufferSize(int bytes) {
        m_bufferSize = bytes;
    }
    /**
     * @brief Record the asset scale (binary field @ +0x44).
     * @param s The scale; 2.0 for an @2x asset.
     */
    void setScale(float s) {
        m_scale = s;
    }
    /**
     * @brief Adopt an already-uploaded GL name and its padded size (binary fields @ +0x18, +0x1c
     * and +0x20).
     * @param n The GL texture name.
     * @param texW The padded texture width, in texels.
     * @param texH The padded texture height, in texels.
     */
    void adoptGLName(GLuint n, int texW, int texH) {
        m_name = n;
        m_texWidth = texW;
        m_texHeight = texH;
    }

    int refCount = 0;          /**< +0x04 Outstanding shared-cache references. */
    C_TEXTURE *next = nullptr; /**< +0x08 Next node in the shared cache list. */
    C_TEXTURE *prev = nullptr; /**< +0x0c Previous node in the shared cache list. */

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
    /**
     * @brief +0x30 Per-texture tex-param cache: the last value applied for each of the four
     * tex-param types {MAG, MIN, WRAP_S, WRAP_T}.
     *
     * neTextureUpload seeds it to the values it applies; setTexParamCached (C_RENDER.cpp) consults
     * it to skip redundant glTexParameteri calls.
     */
    int m_texParamCache[4] = {};
    /** +0x40 Upload format: 0 for RGBA, 2 for ALPHA. Read by neTextureRebind. */
    int m_format = 0;
    /**
     * @brief The upload format (binary field @ +0x40).
     * @return 0 for RGBA, 2 for ALPHA.
     */
    int format() const {
        return m_format;
    }

private:
    float m_scale = 1.0f; // +0x44 (2.0 for an @2x asset)
};

} // namespace ne

/**
 * @brief GPU texture-memory accounting: the total bytes of all live textures (Ghidra:
 * g_dwTextureMemTotal).
 */
extern int g_dwTextureMemTotal;

/**
 * @brief The single head of the shared, refcounted, path-keyed texture cache.
 *
 * The one global list head that AepTextureCacheAcquire links into and that both the background
 * (onDidEnterBackground) and foreground (notifyEnterForeground) GL handlers walk. Defined in
 * neEngineBridge.mm; the sentinel node is created lazily by AepTextureCacheSentinel(). It is null
 * until the first texture is cached.
 */
extern ne::C_TEXTURE *g_textureCacheList;

/**
 * @brief The shared cache list head, lazily building the self-linked sentinel node into
 * g_textureCacheList on the first call.
 *
 * The engine bootstrap (bootstrapB) calls this to create it eagerly; the acquire path calls it on
 * demand.
 * @return The sentinel node.
 */
ne::C_TEXTURE *AepTextureCacheSentinel(void);

/**
 * @brief Drop one shared-cache reference of a texture.
 *
 * On the last reference this frees the GL name, unlinks the texture from the cache list and
 * destroys it.
 * @param tex The ne::C_TEXTURE to release.
 * @ghidraAddress 0x18200
 */
void neTextureRelease(void *tex);

/**
 * @brief Record the source dimensions and byte size for an already-decoded RGBA image and upload
 * it as a single GL texture.
 * @param tex The texture to fill.
 * @param width Source width, in pixels.
 * @param height Source height, in pixels.
 * @param format The upload format: 0 for RGBA, 2 for ALPHA.
 * @param pixels The decoded pixel data.
 * @param texW The padded texture width, in texels.
 * @param texH The padded texture height, in texels.
 * @return 1.
 * @ghidraAddress 0x18644
 */
int neTextureSetDataParams(
    ne::C_TEXTURE *tex, int width, int height, int format, const void *pixels, int texW, int texH);

/**
 * @brief Decode an in-memory image via UIImage and upload it as a power-of-two GL texture.
 * @param tex The texture to fill.
 * @param nsData A bridged NSData* of PNG or other image bytes.
 * @return 1 on success, 0 on decode failure.
 * @ghidraAddress 0x18684
 */
int neTextureLoadFromData(ne::C_TEXTURE *tex, const void *nsData);

/**
 * @brief Re-bind and re-upload a texture through the current renderer; the context-restore path.
 * @param tex The texture to re-upload.
 * @param pixels The pixel data to re-upload.
 * @ghidraAddress 0x18828
 */
void neTextureRebind(ne::C_TEXTURE *tex, const void *pixels);

/**
 * @brief Allocate a ne::C_TEXTURE from raw pixel data, upload it and link it into the shared
 * cache.
 * @param width Source width, in pixels.
 * @param height Source height, in pixels.
 * @param format The upload format: 0 for RGBA, 2 for ALPHA.
 * @param pixels The decoded pixel data.
 * @param texW The padded texture width, in texels.
 * @param texH The padded texture height, in texels.
 * @return The new refcounted texture, or nullptr on failure.
 * @ghidraAddress 0x1bcfc
 */
ne::C_TEXTURE *
neCreateTextureFromData(int width, int height, int format, const void *pixels, int texW, int texH);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
