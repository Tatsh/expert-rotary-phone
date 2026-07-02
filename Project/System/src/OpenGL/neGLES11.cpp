//
//  neGLES11.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  OpenGL ES 1.1 backend. The enum<->GL mapping helpers below are decoded from
//  the binary; the remaining virtual wrappers follow the same
//  "validate against _MAX, then call the matching glXxx" pattern and are filled
//  in progressively.
//

#include <cassert>

#include <OpenGLES/ES1/gl.h>

#include "neGLES11.h"

namespace ne {

// Ghidra: RenderKindToGLRenderKind @ 0x12f64 (table @ DAT_0012e110).
static GLenum RenderKindToGLRenderKind(int kind) {
    assert(kind >= 0 && kind < neIGLES::RENDER_KIND_MAX);
    static const GLenum kTable[neIGLES::RENDER_KIND_MAX] = {
        GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN,  // TODO: confirm @ DAT_0012e110
    };
    return kTable[kind];
}

// Ghidra: TexParamTypeFuncToGLType @ 0x13864 (table @ DAT_0012e2d0).
static GLenum TexParamTypeFuncToGLType(int type) {
    assert(type >= 0 && type < neIGLES::TEX_PARAM_TYPE_MAX);
    static const GLenum kTable[neIGLES::TEX_PARAM_TYPE_MAX] = {
        GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER,
        GL_TEXTURE_WRAP_S, GL_TEXTURE_WRAP_T,
    };
    return kTable[type];
}

// Ghidra: TextureFormatToGLFormat @ ~0x13970 (format 1 -> GL_RGB, 2 -> GL_RGBA).
static GLenum TextureFormatToGLFormat(int format) {
    assert(format >= 0 && format < neIGLES::TEX_FORMAT_MAX);
    switch (format) {
        case neIGLES::TEX_FORMAT_ALPHA: return GL_ALPHA;
        case neIGLES::TEX_FORMAT_RGB:   return GL_RGB;
        case neIGLES::TEX_FORMAT_RGBA:  return GL_RGBA;
    }
    assert(0);
    return 0;
}

// Ghidra: GLValueToTexParamValue @ 0x138cc (reverse map of glGetTexParameteriv).
static neIGLES::TexParamValue GLValueToTexParamValue(GLint v) {
    switch (v) {
        case GL_NEAREST:                return neIGLES::TEX_PARAM_VALUE_NEAREST;
        case GL_LINEAR:                 return neIGLES::TEX_PARAM_VALUE_LINEAR;
        case GL_NEAREST_MIPMAP_NEAREST: return neIGLES::TEX_PARAM_VALUE_NEAREST_MIPMAP_NEAREST;
        case GL_LINEAR_MIPMAP_NEAREST:  return neIGLES::TEX_PARAM_VALUE_LINEAR_MIPMAP_NEAREST;
        case GL_NEAREST_MIPMAP_LINEAR:  return neIGLES::TEX_PARAM_VALUE_NEAREST_MIPMAP_LINEAR;
        case GL_LINEAR_MIPMAP_LINEAR:   return neIGLES::TEX_PARAM_VALUE_LINEAR_MIPMAP_LINEAR;
        case GL_CLAMP_TO_EDGE:          return neIGLES::TEX_PARAM_VALUE_CLAMP_TO_EDGE;
        case GL_REPEAT:                 return neIGLES::TEX_PARAM_VALUE_REPEAT;
    }
    assert(0);
    return neIGLES::TEX_PARAM_VALUE_NEAREST;
}

neGLES_11::neGLES_11() = default;
neGLES_11::~neGLES_11() = default;

// Ghidra: @ 0x13970 — upload a 2D texture (GL_TEXTURE_2D, level 0, UNSIGNED_BYTE).
void neGLES_11::texImage2D(TexFormat format, int width, int height, const void *pixels) {
    GLenum glFormat = TextureFormatToGLFormat(format);
    glTexImage2D(GL_TEXTURE_2D, 0, glFormat, width, height, 0,
                 glFormat, GL_UNSIGNED_BYTE, pixels);
}

// Ghidra: @ 0x138cc — read a texture parameter back as our enum.
neIGLES::TexParamValue neGLES_11::getTexParameter(TexParamType type) {
    GLint value = 0;
    glGetTexParameteriv(GL_TEXTURE_2D, TexParamTypeFuncToGLType(type), &value);
    return GLValueToTexParamValue(value);
}

// --- Remaining wrappers: validate then call the matching GL ES 1.1 entry point.
//     Pattern established above; bodies filled progressively.
void neGLES_11::enable(EnableState) {}
void neGLES_11::disable(EnableState) {}
void neGLES_11::enableClientState(ClientState) {}
void neGLES_11::disableClientState(ClientState) {}
void neGLES_11::setHint(Hint, int) {}
void neGLES_11::setFogMode(FogMode) {}
void neGLES_11::setCullFace(CullFace) {}
void neGLES_11::setFrontFace(FrontFace) {}
void neGLES_11::setBlendFunc(BlendSrcValue, BlendDestValue) {}
void neGLES_11::setDepthFunc(DepthTestFunc) {}
void neGLES_11::setAlphaFunc(AlphaTestFunc, float) {}

void neGLES_11::setTexParameter(TexParamType type, TexParamValue value) {
    // Forward map (TexParamValueToGLValue) is the inverse of GLValueToTexParamValue.
    glTexParameteri(GL_TEXTURE_2D, TexParamTypeFuncToGLType(type), value);  // TODO: map value->GL
}

void neGLES_11::draw(RenderKind kind, RenderType, int first, int count) {
    glDrawArrays(RenderKindToGLRenderKind(kind), first, count);
}

}  // namespace ne
