//
//  AepTexture.h
//  pop'n rhythmin
//
//  A GL texture decoded from an image file, referenced by AepLyrCtrl layers and
//  shared (refcounted, keyed by path) through the engine's texture cache. On a GL
//  context loss the name is freed and re-uploaded on return to foreground.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_000180c4, load FUN_00018218, upload FUN_000185a0,
//  releaseGL FUN_00018884, reload FUN_000188ac; cache FUN_0001bbf0).
//

#pragma once

#import <OpenGLES/ES1/gl.h>

class AepTexture {
public:
    AepTexture();
    ~AepTexture();

    // Decode `path` (a bundled PNG, with @2x fallback) and upload it as a GL
    // texture. Returns true on success. Ghidra: FUN_00018218.
    bool load(const char *path);

    // Free the GL name (called when the GL context is lost on background).
    // Ghidra: FUN_00018884.
    void releaseGL();

    // Re-decode + re-upload from the stored path (on return to foreground).
    // Ghidra: FUN_000188ac.
    bool reload();

    GLuint name() const { return m_name; }            // +0x18 GL texture name
    // Original bundle path (+0x10), used as the shared-cache key. Ghidra: FUN_0001bbf0
    // strcmp's this against the requested path when scanning the cache list.
    const char *cacheKey() const { return m_path; }
    int width() const { return m_width; }             // +0x24 source width
    int height() const { return m_height; }           // +0x28 source height
    int textureWidth() const { return m_texWidth; }   // +0x1c padded (pow2) width
    int textureHeight() const { return m_texHeight; } // +0x20 padded (pow2) height

    // Intrusive cache-list links (Ghidra: refcount +0x04, next +0x08, prev +0x0c).
    int refCount = 0;
    AepTexture *next = nullptr;
    AepTexture *prev = nullptr;

private:
    // Decode `path` into a power-of-two RGBA buffer and hand it to uploadGL.
    bool decodeAndUpload(const char *path);
    void uploadGL(int texWidth, int texHeight, const void *pixels);   // FUN_000185a0

    char *m_path = nullptr;      // +0x10 original path (cache key)
    char *m_filePath = nullptr;  // +0x14 resolved bundle path (for reload)
    GLuint m_name = 0;           // +0x18 GL texture name (0 = not uploaded)
    int m_texWidth = 0;          // +0x1c padded width
    int m_texHeight = 0;         // +0x20 padded height
    int m_width = 0;             // +0x24 source width
    int m_height = 0;            // +0x28 source height
    int m_bufferSize = 0;        // +0x2c
    float m_scale = 1.0f;        // +0x44 (2.0 for an @2x asset)
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
