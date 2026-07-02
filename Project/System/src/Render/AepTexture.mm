//
//  AepTexture.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Decodes a
//  bundled PNG (with @2x fallback) into a power-of-two RGBA buffer via
//  UIImage/CoreGraphics and uploads it as a GL texture. The binary routes the GL
//  calls through neGLES_11's genTexture/bindTexture/setTexParameter/texImage2D
//  virtuals; those wrap exactly these ES 1.1 calls, used directly here.
//  Ghidra: load FUN_00018218, upload FUN_000185a0, release FUN_00018884.
//

#include <cstdlib>
#include <cstring>

#import <UIKit/UIKit.h>

#import "AepTexture.h"

AepTexture::AepTexture() = default;   // Ghidra: FUN_000180c4

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
    m_path = strdup(path);       // +0x10 cache key
    return decodeAndUpload(path);
}

// Ghidra: FUN_00018884 — free the GL name (the GL context is gone on background).
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

    NSString *resolved = [bundle pathForResource:base ofType:ext];
    UIImage *image = resolved ? [[UIImage alloc] initWithContentsOfFile:resolved] : nil;
    if (image != nil) {
        if ([image respondsToSelector:@selector(scale)]) {
            m_scale = (float)image.scale;
        }
    } else {
        // @2x variant, then the raw path.
        NSString *at2x = [NSString stringWithFormat:@"%@@2x", base];
        resolved = [bundle pathForResource:at2x ofType:ext];
        image = resolved ? [[UIImage alloc] initWithContentsOfFile:resolved] : nil;
        if (image != nil) {
            m_scale = 2.0f;
        } else {
            resolved = [bundle pathForResource:base ofType:ext];
            image = resolved ? [[UIImage alloc] initWithContentsOfFile:resolved] : nil;
            if (image == nil) {
                resolved = full;
                image = [[UIImage alloc] initWithContentsOfFile:full];
            }
            if (image == nil) {
                return false;
            }
        }
    }

    free(m_filePath);
    m_filePath = strdup(resolved.UTF8String);   // +0x14 resolved path (for reload)

    CGImageRef cg = image.CGImage;
    m_width = (int)CGImageGetWidth(cg);
    m_height = (int)CGImageGetHeight(cg);

    int tw = 1; while (tw < m_width) tw <<= 1;   // pad to power of two
    int th = 1; while (th < m_height) th <<= 1;
    m_bufferSize = tw * 4 * th;

    void *pixels = calloc(1, m_bufferSize);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels, tw, th, 8, tw * 4, space,
                                             kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, m_height);   // flip to GL's bottom-left origin
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
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texWidth, texHeight, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}
