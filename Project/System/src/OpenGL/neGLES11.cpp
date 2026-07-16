//
//  neGLES11.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  OpenGL ES 1.1 backend. Every enum<->GL mapping table below is decoded
//  byte-for-byte from the binary's __const region (addresses cited per table);
//  the wrapper bodies follow the decompiled "validate against _MAX, index the
//  table, call the matching glXxx" pattern (mapper functions cited per method).
//

#include <cassert>
#include <cstdint>
#include <cstring>

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>

#include "neGLES11.h"

namespace ne {

// Ghidra: RenderKindToGLRenderKind @ FUN_00012f64 (table @ DAT_0012e110): the
// GL ES OES framebuffer attachment points.
// @complete
static GLenum RenderKindToGL(int kind) {
    assert(kind >= 0 && kind < neIGLES::RENDER_KIND_MAX);
    static const GLenum kTable[neIGLES::RENDER_KIND_MAX] = {
        GL_COLOR_ATTACHMENT0_OES,  // 0x8ce0
        GL_DEPTH_ATTACHMENT_OES,   // 0x8d00
        GL_STENCIL_ATTACHMENT_OES, // 0x8d20
    };
    return kTable[kind];
}

// Renderbuffer storage format per RenderType (pairs 1:1 with RenderKind; no
// separate DAT table — the attach path is inlined).
// @complete
static GLenum RenderTypeToGLFormat(int type) {
    assert(type >= 0 && type < neIGLES::RENDER_TYPE_MAX);
    static const GLenum kTable[neIGLES::RENDER_TYPE_MAX] = {
        GL_RGBA8_OES,
        GL_DEPTH_COMPONENT16_OES,
        GL_STENCIL_INDEX8_OES,
    };
    return kTable[type];
}

// Ghidra: setMatrixMode @ FUN_00013110 (table @ DAT_0012e11c). Index 0 is the
// GL_MODELVIEW out-of-range default; 1..3 index the table.
// @complete
static GLenum MatrixModeToGL(int mode) {
    assert(mode >= 0 && mode < neIGLES::MATRIX_MODE_MAX);
    if (mode - 1U < 3U) {
        static const GLenum kTable[3] = {
            GL_PROJECTION,         // 0x1701
            GL_TEXTURE,            // 0x1702
            GL_MATRIX_PALETTE_OES, // 0x8840
        };
        return kTable[mode - 1];
    }
    return GL_MODELVIEW; // 0x1700
}

// glHint targets. Ghidra: table @ DAT_0012e290 (5 entries).
// @complete
static GLenum HintTargetToGL(int target) {
    assert(target >= 0 && target < neIGLES::HINT_MAX);
    static const GLenum kTable[neIGLES::HINT_MAX] = {
        GL_FOG_HINT,                    // 0x0c54
        GL_GENERATE_MIPMAP_HINT,        // 0x8192
        GL_LINE_SMOOTH_HINT,            // 0x0c52
        GL_PERSPECTIVE_CORRECTION_HINT, // 0x0c50
        GL_POINT_SMOOTH_HINT,           // 0x0c51
    };
    return kTable[target];
}

// glFog(GL_FOG_MODE) modes. Ghidra: table @ DAT_0012e27c (3 entries).
// @complete
static GLenum FogModeToGL(int mode) {
    assert(mode >= 0 && mode < neIGLES::FOG_MODE_MAX);
    static const GLenum kTable[neIGLES::FOG_MODE_MAX] = {
        GL_LINEAR, // 0x2601
        GL_EXP,    // 0x0800
        GL_EXP2,   // 0x0801
    };
    return kTable[mode];
}

// glEnableClientState array targets. Ghidra: table @ DAT_0012e25c (8 entries).
// @complete
static GLenum ClientStateToGL(int state) {
    assert(state >= 0 && state < neIGLES::CS_MAX);
    static const GLenum kTable[neIGLES::CS_MAX] = {
        GL_MATRIX_PALETTE_OES,     // 0x8840
        GL_COLOR_ARRAY,            // 0x8076
        GL_MATRIX_INDEX_ARRAY_OES, // 0x8844
        GL_NORMAL_ARRAY,           // 0x8075
        GL_POINT_SIZE_ARRAY_OES,   // 0x8b9c
        GL_TEXTURE_COORD_ARRAY,    // 0x8078
        GL_VERTEX_ARRAY,           // 0x8074
        GL_WEIGHT_ARRAY_OES,       // 0x86ad
    };
    return kTable[state];
}

// glEnable / glDisable capabilities. Ghidra: table @ DAT_0012e1d0 (35 entries).
// @complete
static GLenum EnableStateToGL(int state) {
    assert(state >= 0 && state < neIGLES::ES_MAX);
    static const GLenum kTable[neIGLES::ES_MAX] = {
        GL_ALPHA_TEST,               // 0x0bc0
        GL_BLEND,                    // 0x0be2
        GL_COLOR_LOGIC_OP,           // 0x0bf2
        GL_CLIP_PLANE0,              // 0x3000
        GL_CLIP_PLANE1,              // 0x3001
        GL_CLIP_PLANE2,              // 0x3002
        GL_CLIP_PLANE3,              // 0x3003
        GL_CLIP_PLANE4,              // 0x3004
        GL_CLIP_PLANE5,              // 0x3005
        GL_COLOR_MATERIAL,           // 0x0b57
        GL_CULL_FACE,                // 0x0b44
        GL_DEPTH_TEST,               // 0x0b71
        GL_DITHER,                   // 0x0bd0
        GL_FOG,                      // 0x0b60
        GL_LIGHT0,                   // 0x4000
        GL_LIGHT1,                   // 0x4001
        GL_LIGHT2,                   // 0x4002
        GL_LIGHT3,                   // 0x4003
        GL_LIGHT4,                   // 0x4004
        GL_LIGHT5,                   // 0x4005
        GL_LIGHT6,                   // 0x4006
        GL_LIGHT7,                   // 0x4007
        GL_LIGHTING,                 // 0x0b50
        GL_LINE_SMOOTH,              // 0x0b20
        GL_MULTISAMPLE,              // 0x809d
        GL_NORMALIZE,                // 0x0ba1
        GL_POINT_SMOOTH,             // 0x0b10
        GL_POINT_SPRITE_OES,         // 0x8861
        GL_POLYGON_OFFSET_FILL,      // 0x8037
        GL_RESCALE_NORMAL,           // 0x803a
        GL_SAMPLE_ALPHA_TO_COVERAGE, // 0x809e
        GL_SAMPLE_ALPHA_TO_ONE,      // 0x809f
        GL_SAMPLE_COVERAGE,          // 0x80a0
        GL_SCISSOR_TEST,             // 0x0c11
        GL_TEXTURE_2D,               // 0x0de1
    };
    return kTable[state];
}

// glCullFace. Ghidra: table @ DAT_0012e1c0 (3 entries).
// @complete
static GLenum CullFaceToGL(int face) {
    assert(face >= 0 && face < neIGLES::CULL_FACE_MAX);
    static const GLenum kTable[neIGLES::CULL_FACE_MAX] = {
        GL_FRONT,          // 0x0404
        GL_BACK,           // 0x0405
        GL_FRONT_AND_BACK, // 0x0408
    };
    return kTable[face];
}

// Depth/alpha compare functions. Ghidra: table @ DAT_0012e130 (8 entries).
// @complete
static GLenum CompareFuncToGL(int func) {
    assert(func >= 0 && func < neIGLES::COMPARE_FUNC_MAX);
    static const GLenum kTable[neIGLES::COMPARE_FUNC_MAX] = {
        GL_NEVER,    // 0x0200
        GL_LESS,     // 0x0201
        GL_EQUAL,    // 0x0202
        GL_LEQUAL,   // 0x0203
        GL_GREATER,  // 0x0204
        GL_NOTEQUAL, // 0x0205
        GL_GEQUAL,   // 0x0206
        GL_ALWAYS,   // 0x0207
    };
    return kTable[func];
}

// GL src blend factors. Ghidra: table @ DAT_0012e170 (9 entries; setBlendFunc
// FUN_00013a34 asserts src < BLEND_SRC_VALUE_MAX at neGLES11.cpp:0xa8-0xa9).
// @complete
static GLenum BlendSrcToGL(int src) {
    assert(src >= 0 && src < neIGLES::BLEND_SRC_VALUE_MAX);
    static const GLenum kTable[neIGLES::BLEND_SRC_VALUE_MAX] = {
        GL_ZERO,                // 0x0000
        GL_ONE,                 // 0x0001
        GL_DST_COLOR,           // 0x0306
        GL_ONE_MINUS_DST_COLOR, // 0x0307
        GL_SRC_ALPHA,           // 0x0302
        GL_ONE_MINUS_SRC_ALPHA, // 0x0303
        GL_DST_ALPHA,           // 0x0304
        GL_ONE_MINUS_DST_ALPHA, // 0x0305
        GL_SRC_ALPHA_SATURATE,  // 0x0308
    };
    return kTable[src];
}

// GL dest blend factors. Ghidra: table @ DAT_0012e1a0 (8 entries; setBlendFunc
// FUN_00013a34 asserts dest < BLEND_DEST_VALUE_MAX at neGLES11.cpp:0xbd-0xbe).
// @complete
static GLenum BlendDestToGL(int dest) {
    assert(dest >= 0 && dest < neIGLES::BLEND_DEST_VALUE_MAX);
    static const GLenum kTable[neIGLES::BLEND_DEST_VALUE_MAX] = {
        GL_ZERO,                // 0x0000
        GL_ONE,                 // 0x0001
        GL_SRC_COLOR,           // 0x0300
        GL_ONE_MINUS_SRC_COLOR, // 0x0301
        GL_SRC_ALPHA,           // 0x0302
        GL_ONE_MINUS_SRC_ALPHA, // 0x0303
        GL_DST_ALPHA,           // 0x0304
        GL_ONE_MINUS_DST_ALPHA, // 0x0305
    };
    return kTable[dest];
}

// Ghidra: TexParamTypeFuncToGLType @ FUN_00013864 (table @ DAT_0012e2d0).
// @complete
static GLenum TexParamTypeToGL(int type) {
    assert(type >= 0 && type < neIGLES::TEX_PARAM_TYPE_MAX);
    static const GLenum kTable[neIGLES::TEX_PARAM_TYPE_MAX] = {
        GL_TEXTURE_MAG_FILTER, // 0x2800
        GL_TEXTURE_MIN_FILTER, // 0x2801
        GL_TEXTURE_WRAP_S,     // 0x2802
        GL_TEXTURE_WRAP_T,     // 0x2803
    };
    return kTable[type];
}

// glTexParameter value forward map. Ghidra: table @ DAT_0012e150 (8 entries).
// @complete
static GLint TexParamValueToGL(int value) {
    assert(value >= 0 && value < neIGLES::TEX_PARAM_VALUE_MAX);
    static const GLint kTable[neIGLES::TEX_PARAM_VALUE_MAX] = {
        GL_NEAREST,                // 0x2600
        GL_LINEAR,                 // 0x2601
        GL_NEAREST_MIPMAP_NEAREST, // 0x2700
        GL_LINEAR_MIPMAP_NEAREST,  // 0x2701
        GL_NEAREST_MIPMAP_LINEAR,  // 0x2702
        GL_LINEAR_MIPMAP_LINEAR,   // 0x2703
        GL_CLAMP_TO_EDGE,          // 0x812f
        GL_REPEAT,                 // 0x2901
    };
    return kTable[value];
}

// Ghidra: GLValueToTexParamValue @ FUN_000138cc (reverse of
// glGetTexParameteriv).
// @complete
static neIGLES::TexParamValue GLValueToTexParamValue(GLint v) {
    switch (v) {
    case GL_NEAREST:
        return neIGLES::TEX_PARAM_VALUE_NEAREST;
    case GL_LINEAR:
        return neIGLES::TEX_PARAM_VALUE_LINEAR;
    case GL_NEAREST_MIPMAP_NEAREST:
        return neIGLES::TEX_PARAM_VALUE_NEAREST_MIPMAP_NEAREST;
    case GL_LINEAR_MIPMAP_NEAREST:
        return neIGLES::TEX_PARAM_VALUE_LINEAR_MIPMAP_NEAREST;
    case GL_NEAREST_MIPMAP_LINEAR:
        return neIGLES::TEX_PARAM_VALUE_NEAREST_MIPMAP_LINEAR;
    case GL_LINEAR_MIPMAP_LINEAR:
        return neIGLES::TEX_PARAM_VALUE_LINEAR_MIPMAP_LINEAR;
    case GL_CLAMP_TO_EDGE:
        return neIGLES::TEX_PARAM_VALUE_CLAMP_TO_EDGE;
    case GL_REPEAT:
        return neIGLES::TEX_PARAM_VALUE_REPEAT;
    }
    assert(0);
    return neIGLES::TEX_PARAM_VALUE_NEAREST;
}

// Texture upload format. Ghidra: TextureFormatToGLFormat @ FUN_00013970.
// @complete
static GLenum TextureFormatToGL(int format) {
    switch (format) {
    case neIGLES::TEX_FORMAT_RGBA:
        return GL_RGBA;
    case neIGLES::TEX_FORMAT_LUMINANCE_ALPHA:
        return GL_LUMINANCE_ALPHA;
    }
    assert(0);
    return 0;
}

// Engine primitive ordinal -> GL mode. Ghidra: table @ DAT_0012e2b0 (7
// entries), indexed by drawArrays/drawElements.
// @complete
static GLenum PrimitiveToGL(int mode) {
    assert(mode >= 0 && mode < neIGLES::PRIM_MAX);
    static const GLenum kTable[neIGLES::PRIM_MAX] = {
        GL_POINTS,         // 0x0000
        GL_LINE_STRIP,     // 0x0003
        GL_LINE_LOOP,      // 0x0002
        GL_LINES,          // 0x0001
        GL_TRIANGLE_STRIP, // 0x0005
        GL_TRIANGLE_FAN,   // 0x0006
        GL_TRIANGLES,      // 0x0004
    };
    return kTable[mode];
}

// @ 0x12c78
// Ghidra: neGLESRenderer_ctor — installs the vtable and primes the whole
// ~0x210-byte cached-GL-state block to the backend's power-on defaults.
//
// This reconstruction models only the subset of that block its method subset
// actually reads back: the buffer-bind caches (ivars 0x44/0x50/0x5c/0x6c), the
// two 8-slot texture caches (_boundTextures 0xb4, texBindCache 0xfc), the
// matrix-mode cache (0x2c), the caps probed by initialize() (0x84/0x87/0x88),
// and the blend cache (0x19c/0x1a0/0x1a4). Every one of those defaults to the
// binary's power-on value under the in-class member initializers plus the three
// explicit blend writes below — the buffer/texture/matrix caches are zero in
// the binary (str of 0) and the blend cache is add-equation/ONE/ZERO.
//
// The remaining fields the binary's ctor writes back state consumed only by
// methods outside this subset, so they are intentionally not carried as
// members: the per-texture-unit tex-param cache {4,1,7,7} (0x11c, stride 0x10;
// the reconstructed cache lives on the texture at +0x30, see setTexParamCached),
// the -1 bound-name sentinels (0x94[8], 0x24/0x28/0x4c/0x58/0x64/0xd8/0xe8,
// 0x1fc..0x20c), and the 1.0f current-colour vectors (0x14, 0x1dc/0x1e0/0x1e8).
// @complete
neGLES_11::neGLES_11()
    : _blendEquation(GL_FUNC_ADD_OES), // ivar 0x19c  (&DAT_00008006)
      _blendSrc(BLEND_SRC_ONE),        // ivar 0x1a0  (GL_ONE ordinal)
      _blendDest(BLEND_DEST_ZERO) {    // ivar 0x1a4  (GL_ZERO ordinal)
}

neGLES_11::~neGLES_11() = default;

// @complete
void neGLES_11::enable(EnableState state) {
    glEnable(EnableStateToGL(state));
}

// @complete
void neGLES_11::disable(EnableState state) {
    glDisable(EnableStateToGL(state));
}

// @complete
void neGLES_11::enableClientState(ClientState state) {
    glEnableClientState(ClientStateToGL(state));
}

// @complete
void neGLES_11::disableClientState(ClientState state) {
    glDisableClientState(ClientStateToGL(state));
}

// Ghidra: FUN_00013110 — caches the mode (ivar 0x2c) and only re-issues
// glMatrixMode on change.
// @complete
void neGLES_11::setMatrixMode(MatrixMode mode) {
    if (_matrixMode == static_cast<unsigned>(mode)) {
        return;
    }
    _matrixMode = mode;
    glMatrixMode(MatrixModeToGL(mode));
}

// @complete
void neGLES_11::setHint(Hint target, int mode) {
    glHint(HintTargetToGL(target), static_cast<GLenum>(mode));
}

// @complete
void neGLES_11::setFogMode(FogMode mode) {
    glFogx(GL_FOG_MODE, static_cast<GLfixed>(FogModeToGL(mode)));
}

// @complete
void neGLES_11::setCullFace(CullFace face) {
    glCullFace(CullFaceToGL(face));
}

// @complete
void neGLES_11::setFrontFace(FrontFace face) {
    assert(face >= 0 && face < FRONT_FACE_MAX);
    glFrontFace(face == FRONT_FACE_CW ? GL_CW : GL_CCW);
}

// Ghidra: FUN_00013a34 — caches (equation 0x19c, src 0x1a0, dest 0x1a4), skips
// redundant calls, then glBlendEquationOES(equation); glBlendFunc(src, dest).
// @complete
void neGLES_11::setBlendFunc(BlendSrcValue src, BlendDestValue dest, unsigned equation) {
    if (_blendSrc == static_cast<unsigned>(src) && _blendDest == static_cast<unsigned>(dest) &&
        _blendEquation == equation) {
        return;
    }
    _blendEquation = equation;
    _blendSrc = src;
    _blendDest = dest;
    GLenum glSrc = BlendSrcToGL(src);
    glBlendEquationOES(equation);
    glBlendFunc(glSrc, BlendDestToGL(dest));
}

// @complete
void neGLES_11::setDepthFunc(DepthTestFunc func) {
    glDepthFunc(CompareFuncToGL(func));
}

// @complete
void neGLES_11::setAlphaFunc(AlphaTestFunc func, float ref) {
    glAlphaFunc(CompareFuncToGL(func), ref);
}

// Ghidra: FUN_00013970 — upload a 2D texture (GL_TEXTURE_2D, level 0,
// UNSIGNED_BYTE).
// @complete
void neGLES_11::texImage2D(TexFormat format, int width, int height, const void *pixels) {
    GLenum glFormat = TextureFormatToGL(format);
    glTexImage2D(GL_TEXTURE_2D, 0, glFormat, width, height, 0, glFormat, GL_UNSIGNED_BYTE, pixels);
}

// @complete
void neGLES_11::setTexParameter(TexParamType type, TexParamValue value) {
    glTexParameteri(GL_TEXTURE_2D, TexParamTypeToGL(type), TexParamValueToGL(value));
}

// Ghidra: FUN_000138cc — read a texture parameter back as our enum.
// @complete
neIGLES::TexParamValue neGLES_11::getTexParameter(TexParamType type) {
    GLint value = 0;
    glGetTexParameteriv(GL_TEXTURE_2D, TexParamTypeToGL(type), &value);
    return GLValueToTexParamValue(value);
}

// Ghidra: FUN_00013290 — invalidate any cached binding referring to this buffer
// (ivars 0x44/0x50/0x5c/0x6c and the 8-slot texture array at 0xb4), then
// delete.
// @complete
void neGLES_11::deleteBuffer(unsigned buffer) {
    if (_boundArrayBuffer == buffer) {
        _boundArrayBuffer = 0;
    }
    if (_boundElementBuffer == buffer) {
        _boundElementBuffer = 0;
    }
    if (_boundBuffer2 == buffer) {
        _boundBuffer2 = 0;
    }
    if (_boundBuffer3 == buffer) {
        _boundBuffer3 = 0;
    }
    for (auto &tex : _boundTextures) {
        if (tex == buffer) {
            tex = 0;
        }
    }
    GLuint name = buffer;
    glDeleteBuffers(1, &name);
}

// Attach a renderbuffer at the given attachment point (GL ES OES FBO).
// @complete
void neGLES_11::attachRenderbuffer(RenderKind kind, RenderType type, unsigned renderbuffer) {
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, RenderTypeToGLFormat(type), 0, 0);
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, RenderKindToGL(kind), GL_RENDERBUFFER_OES, renderbuffer);
}

// ---------------------------------------------------------------------------
// OES framebuffer-object management. `RenderKind` selects the attachment point
// (color/depth/stencil) via RenderKindToGL.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00012e94.
// @complete
void neGLES_11::deleteFramebuffer(unsigned framebuffer) {
    GLuint name = framebuffer;
    glDeleteFramebuffersOES(1, &name);
}

// Ghidra: FUN_00012eb8.
// @complete
void neGLES_11::deleteRenderbuffer(unsigned renderbuffer) {
    GLuint name = renderbuffer;
    glDeleteRenderbuffersOES(1, &name);
}

// Ghidra: FUN_00012f3c — attach a 2D texture's level 0 at attachment point
// `kind`.
// @complete
void neGLES_11::framebufferTexture2D(RenderKind kind, unsigned texture) {
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, RenderKindToGL(kind), GL_TEXTURE_2D, texture, 0);
}

// Ghidra: FUN_00012fcc — attach a renderbuffer at attachment point `kind`.
// @complete
void neGLES_11::framebufferRenderbuffer(RenderKind kind, unsigned renderbuffer) {
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, RenderKindToGL(kind), GL_RENDERBUFFER_OES, renderbuffer);
}

// Ghidra: FUN_00012fec — free helper (no `this`).
// @complete
bool isFramebufferComplete() {
    return glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES;
}

// ---------------------------------------------------------------------------
// neRenderer drawing slots (dispatched through by the neDraw* primitives). The
// integer arguments carry the engine's own ordinals, mapped to GL via the
// tables above / the enum-typed wrappers.
// ---------------------------------------------------------------------------

// Ghidra: QueryCaps (FUN_00012da0), the renderer's pInit virtual. Probes the GL
// extension string for GL_OES_matrix_palette, reads GL_MAX_TEXTURE_SIZE, loads the
// texcoord-normalizing texture matrix, and sets the default line width.
// @complete
void neGLES_11::initialize() {
    // Scan the space-delimited extension list for matrix-palette support. The
    // binary copies each token with memcpy (0x12de2) and a single nul terminator,
    // with no length clamp, then strncmp's it against the palette extension name.
    const char *cursor = reinterpret_cast<const char *>(glGetString(GL_EXTENSIONS));
    if (cursor != nullptr) {
        char token[256];
        for (const char *space = std::strchr(cursor, ' '); space != nullptr;
             space = std::strchr(cursor, ' ')) {
            size_t len = static_cast<size_t>(space - cursor);
            std::memcpy(token, cursor, len);
            token[len] = '\0';
            if (std::strncmp(token, "GL_OES_matrix_palette", len) == 0) {
                _hasMatrixPalette = true;
                _maxPaletteMatrices = 9;
            }
            cursor = space + 1;
        }
    }
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &_maxTextureSize);

    // The sprite/glyph texcoords are emitted as GL_SHORT in 0..32767 (uv * 32767).
    // GL ES 1.1 does not normalize integer texcoord arrays, so load a texture matrix
    // whose diagonal is (1/32767, 1/32767, 1, 1) to scale them back to 0..1. Ghidra:
    // QueryCaps builds this matrix (0x38000100 == 1/32767) and loadMatrix
    // (MATRIX_MODE_TEXTURE).
    neMatrix4 texScale = {};
    texScale.m[0] = 1.0f / 32767.0f;
    texScale.m[5] = 1.0f / 32767.0f;
    texScale.m[10] = 1.0f;
    texScale.m[15] = 1.0f;
    loadMatrix(neIGLES::MATRIX_MODE_TEXTURE, texScale);

    glLineWidth(1.0f);
}

// @complete
void neGLES_11::setViewport(int x, int y, int w, int h) {
    glViewport(x, y, w, h);
}

// @complete
void neGLES_11::loadMatrix(int mode, const neMatrix4 &m) {
    setMatrixMode(static_cast<MatrixMode>(mode));
    glLoadMatrixf(m.m);
}

// @complete
void neGLES_11::genBuffer(unsigned &outName) {
    GLuint name = 0;
    glGenBuffers(1, &name);
    outName = name;
}

// @complete
void neGLES_11::selectTextureUnit(int unit) {
    glActiveTexture(GL_TEXTURE0 + unit);
}

// @complete
void neGLES_11::colorPointer(const void *ptr, int stride) {
    glColorPointer(4, GL_UNSIGNED_BYTE, stride, ptr);
}

// @complete
void neGLES_11::vertexPointer(const void *ptr, int size, int stride) {
    // The type is GL_FLOAT: the caching variant FUN_0001342c tail-calls
    // glVertexPointer(size, 0x1406, stride, ptr), and 0x1406 is GL_FLOAT. That
    // variant additionally skips the call when the last (ptr, size, stride)
    // triple is unchanged and no array buffer is bound; it is uncalled in the
    // binary, so only the plain specification is reproduced here.
    glVertexPointer(size, GL_FLOAT, stride, ptr);
}

// @complete
void neGLES_11::texCoordPointer(const void *ptr, int stride) {
    glTexCoordPointer(2, GL_SHORT, stride, ptr); // normalized GL_SHORT UVs
}

// @complete
void neGLES_11::bindElementBuffer(unsigned name) {
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, name);
}

// @complete
void neGLES_11::bufferData(const void *data, int size, int usage) {
    glBufferData(
        GL_ELEMENT_ARRAY_BUFFER, size, data, usage == 0 ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW);
}

// Ghidra: vtable +0xb4 (0x13770) — thin glGenTextures wrapper (movs r0,#1;
// b.w glGenTextures veneer). The renderer `this` is discarded; the caller's
// &outName is already in r1, so this is exactly glGenTextures(1, &outName).
// @complete
void neGLES_11::genTexture(unsigned &outName) {
    GLuint name = 0;
    glGenTextures(1, &name);
    outName = name;
}

// Ghidra: FUN_00013778 (vtable +0xb8) — clear every bound-texture-cache slot
// holding this name (so a later reused name is not treated as still bound),
// then glDeleteTextures. This is the slot the AepTexture teardown path dispatches
// through (deleteTexture), which is why the raw glDeleteTextures would leave a
// stale cache entry.
// @complete
void neGLES_11::deleteTexture(unsigned name) {
    for (unsigned &slot : texBindCache.names) {
        if (slot == name) {
            slot = 0;
        }
    }
    GLuint n = name;
    glDeleteTextures(1, &n);
}

// Ghidra: FUN_000137c0 (vtable +0xc0) — per-unit redundant-bind cache: index
// texBindCache by the active texture unit (ivar 0xf8), skip when the cached name
// already matches, else update the slot and glBindTexture. Keeping the cache
// coherent is why deleteTexture (+0xb8) must clear it on a delete.
// @complete
void neGLES_11::bindTexture(unsigned name) {
    unsigned &slot = texBindCache.names[_activeTexUnit];
    if (slot == name) {
        return;
    }
    slot = name;
    glBindTexture(GL_TEXTURE_2D, name);
}

// @complete
void neGLES_11::applyTexParameter(int type, int value) {
    setTexParameter(static_cast<TexParamType>(type), static_cast<TexParamValue>(value));
}

// @complete
void neGLES_11::uploadTexture(int format, int w, int h, const void *pixels) {
    texImage2D(static_cast<TexFormat>(format), w, h, pixels);
}

// The 2-argument primitive-blend slot uses the default add equation.
// @complete
void neGLES_11::setBlendFunc(int src, int dst) {
    setBlendFunc(
        static_cast<BlendSrcValue>(src), static_cast<BlendDestValue>(dst), GL_FUNC_ADD_OES);
}

// @complete
void neGLES_11::setBlendFuncSeparate(int src, int dst, unsigned equation) {
    setBlendFunc(static_cast<BlendSrcValue>(src), static_cast<BlendDestValue>(dst), equation);
}

// @complete
void neGLES_11::setEnable(int cap, bool on) {
    if (on) {
        enable(static_cast<EnableState>(cap));
    } else {
        disable(static_cast<EnableState>(cap));
    }
}

// @complete
void neGLES_11::setClientArray(int array, bool on) {
    if (on) {
        enableClientState(static_cast<ClientState>(array));
    } else {
        disableClientState(static_cast<ClientState>(array));
    }
}

// The primitive-draw slot (vtable +0x100). Its body is in the binary's undisassembled
// vtable-only region, but its behaviour is pinned by its sole caller neDrawColorArray/
// neDrawTexturedQuad, which the neRenderer verification confirmed issue
// glDrawArrays(PrimitiveToGL(mode), 0, count) (e.g. drawArrays(4, 4) -> GL_TRIANGLE_STRIP).
// @complete
void neGLES_11::drawArrays(int mode, int count) {
    glDrawArrays(PrimitiveToGL(mode), 0, count);
}

// Indexed-draw slot (vtable +0x104). No caller exists in the reconstruction (and the
// index-type constant GL_UNSIGNED_SHORT / 0x1403 does not appear anywhere in the binary),
// so this path is never exercised; it is reconstructed as the standard ES 1.1 indexed
// draw for completeness. The offset is a byte offset into the bound element buffer.
// @complete
void neGLES_11::drawElements(int mode, int count, int offset) {
    glDrawElements(PrimitiveToGL(mode),
                   count,
                   GL_UNSIGNED_SHORT,
                   reinterpret_cast<const void *>(static_cast<intptr_t>(offset)));
}

} // namespace ne
