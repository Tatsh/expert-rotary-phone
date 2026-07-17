//
//  neGLES11.h
//  pop'n rhythmin
//
//  OpenGL ES 1.1 rendering abstraction — the interface every on-screen sprite,
//  texture and primitive is drawn through. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (RTTI: ne::neGLES_11, "N2ne9neGLES_11E" @
//  DAT_0012e100).
//
//  `neIGLES` is the abstract GL interface (holds the enum vocabulary,
//  referenced in the binary as "neIGLES::HINT_MAX" etc.); `neGLES_11` is the GL
//  ES 1.1 backend. neIGLES derives from the engine's abstract `ne::C_RENDER`
//  (System/src/Render), so the immediate-mode primitives dispatch their
//  drawing-slot virtuals through the very same object; neGLES_11 implements
//  both those slots and the enum-typed wrappers below.
//
//  Every enum below is decoded from its mapping table in the __const region and
//  each member is annotated with the exact GL constant that ordinal maps to.
//  The member *names* are assigned from those decoded GL constants (the
//  original C++ identifiers are not recoverable), but the ordinal -> GL value
//  mapping is byte-accurate. Table addresses and the decompiled mapper
//  functions are cited inline and in neGLES11.cpp.
//

#pragma once

#include "C_RENDER.h" // ::ne::C_RENDER abstract drawing interface + neMatrix4

namespace ne {

class neIGLES : public ne::C_RENDER {
public:
    // Framebuffer attachment points. Table @ DAT_0012e110 (3 entries), consumed
    // by RenderKindToGLRenderKind (FUN_00012f64; asserts kind < RENDER_KIND_MAX).
    enum RenderKind {
        RENDER_KIND_COLOR = 0, // GL_COLOR_ATTACHMENT0_OES  (0x8ce0)
        RENDER_KIND_DEPTH,     // GL_DEPTH_ATTACHMENT_OES   (0x8d00)
        RENDER_KIND_STENCIL,   // GL_STENCIL_ATTACHMENT_OES (0x8d20)
        RENDER_KIND_MAX
    };

    // Renderbuffer storage formats. No dedicated DAT table was located (the
    // attach path was inlined); these pair 1:1 with RenderKind above and are the
    // only storage formats the GL ES 1.1 OES FBO path accepts for each.
    enum RenderType {
        RENDER_TYPE_RGBA8 = 0, // GL_RGBA8_OES
        RENDER_TYPE_DEPTH16,   // GL_DEPTH_COMPONENT16_OES
        RENDER_TYPE_STENCIL8,  // GL_STENCIL_INDEX8_OES
        RENDER_TYPE_MAX
    };

    // glMatrixMode targets. Table @ DAT_0012e11c (3 entries) with GL_MODELVIEW as
    // the out-of-range default; decoded from setMatrixMode (FUN_00013110):
    //   mode-1 in [0,3) -> DAT_0012e11c[mode-1], else GL_MODELVIEW (0x1700).
    enum MatrixMode {
        MATRIX_MODE_MODELVIEW = 0,      // GL_MODELVIEW           (0x1700, default)
        MATRIX_MODE_PROJECTION,         // GL_PROJECTION          (0x1701)
        MATRIX_MODE_TEXTURE,            // GL_TEXTURE             (0x1702)
        MATRIX_MODE_MATRIX_PALETTE_OES, // GL_MATRIX_PALETTE_OES  (0x8840)
        MATRIX_MODE_MAX
    };

    // glHint targets. Table @ DAT_0012e290 (5 entries), alphabetical by GL name.
    enum Hint {
        HINT_FOG = 0,                // GL_FOG_HINT                    (0x0c54)
        HINT_GENERATE_MIPMAP,        // GL_GENERATE_MIPMAP_HINT        (0x8192)
        HINT_LINE_SMOOTH,            // GL_LINE_SMOOTH_HINT            (0x0c52)
        HINT_PERSPECTIVE_CORRECTION, // GL_PERSPECTIVE_CORRECTION_HINT (0x0c50)
        HINT_POINT_SMOOTH,           // GL_POINT_SMOOTH_HINT           (0x0c51)
        HINT_MAX
    };

    // glFog(GL_FOG_MODE, ...) modes. Table @ DAT_0012e27c (3 entries).
    enum FogMode {
        FOG_MODE_LINEAR = 0, // GL_LINEAR (0x2601)
        FOG_MODE_EXP,        // GL_EXP    (0x0800)
        FOG_MODE_EXP2,       // GL_EXP2   (0x0801)
        FOG_MODE_MAX
    };

    // glEnableClientState / glDisableClientState array targets. Table @
    // DAT_0012e25c (8 entries); the contiguous block of GL client-array enums
    // that immediately follows the EnableState table.
    enum ClientState {
        CS_MATRIX_PALETTE_OES = 0, // GL_MATRIX_PALETTE_OES     (0x8840)
        CS_COLOR_ARRAY,            // GL_COLOR_ARRAY            (0x8076)
        CS_MATRIX_INDEX_ARRAY_OES, // GL_MATRIX_INDEX_ARRAY_OES (0x8844)
        CS_NORMAL_ARRAY,           // GL_NORMAL_ARRAY           (0x8075)
        CS_POINT_SIZE_ARRAY_OES,   // GL_POINT_SIZE_ARRAY_OES   (0x8b9c)
        CS_TEXTURE_COORD_ARRAY,    // GL_TEXTURE_COORD_ARRAY    (0x8078)
        CS_VERTEX_ARRAY,           // GL_VERTEX_ARRAY           (0x8074)
        CS_WEIGHT_ARRAY_OES,       // GL_WEIGHT_ARRAY_OES       (0x86ad)
        CS_MAX
    };

    // glEnable / glDisable capabilities. Table @ DAT_0012e1d0 (35 entries),
    // alphabetical by GL name. This is the engine's full enable-cap vocabulary
    // (note GL_STENCIL_TEST is intentionally absent).
    enum EnableState {
        ES_ALPHA_TEST = 0,           // GL_ALPHA_TEST               (0x0bc0)
        ES_BLEND,                    // GL_BLEND                    (0x0be2)
        ES_COLOR_LOGIC_OP,           // GL_COLOR_LOGIC_OP           (0x0bf2)
        ES_CLIP_PLANE0,              // GL_CLIP_PLANE0              (0x3000)
        ES_CLIP_PLANE1,              // GL_CLIP_PLANE1              (0x3001)
        ES_CLIP_PLANE2,              // GL_CLIP_PLANE2              (0x3002)
        ES_CLIP_PLANE3,              // GL_CLIP_PLANE3              (0x3003)
        ES_CLIP_PLANE4,              // GL_CLIP_PLANE4              (0x3004)
        ES_CLIP_PLANE5,              // GL_CLIP_PLANE5              (0x3005)
        ES_COLOR_MATERIAL,           // GL_COLOR_MATERIAL           (0x0b57)
        ES_CULL_FACE,                // GL_CULL_FACE                (0x0b44)
        ES_DEPTH_TEST,               // GL_DEPTH_TEST               (0x0b71)
        ES_DITHER,                   // GL_DITHER                   (0x0bd0)
        ES_FOG,                      // GL_FOG                      (0x0b60)
        ES_LIGHT0,                   // GL_LIGHT0                   (0x4000)
        ES_LIGHT1,                   // GL_LIGHT1                   (0x4001)
        ES_LIGHT2,                   // GL_LIGHT2                   (0x4002)
        ES_LIGHT3,                   // GL_LIGHT3                   (0x4003)
        ES_LIGHT4,                   // GL_LIGHT4                   (0x4004)
        ES_LIGHT5,                   // GL_LIGHT5                   (0x4005)
        ES_LIGHT6,                   // GL_LIGHT6                   (0x4006)
        ES_LIGHT7,                   // GL_LIGHT7                   (0x4007)
        ES_LIGHTING,                 // GL_LIGHTING                 (0x0b50)
        ES_LINE_SMOOTH,              // GL_LINE_SMOOTH              (0x0b20)
        ES_MULTISAMPLE,              // GL_MULTISAMPLE              (0x809d)
        ES_NORMALIZE,                // GL_NORMALIZE                (0x0ba1)
        ES_POINT_SMOOTH,             // GL_POINT_SMOOTH             (0x0b10)
        ES_POINT_SPRITE_OES,         // GL_POINT_SPRITE_OES         (0x8861)
        ES_POLYGON_OFFSET_FILL,      // GL_POLYGON_OFFSET_FILL      (0x8037)
        ES_RESCALE_NORMAL,           // GL_RESCALE_NORMAL           (0x803a)
        ES_SAMPLE_ALPHA_TO_COVERAGE, // GL_SAMPLE_ALPHA_TO_COVERAGE (0x809e)
        ES_SAMPLE_ALPHA_TO_ONE,      // GL_SAMPLE_ALPHA_TO_ONE      (0x809f)
        ES_SAMPLE_COVERAGE,          // GL_SAMPLE_COVERAGE          (0x80a0)
        ES_SCISSOR_TEST,             // GL_SCISSOR_TEST             (0x0c11)
        ES_TEXTURE_2D,               // GL_TEXTURE_2D               (0x0de1)
        ES_MAX
    };

    // glCullFace. Table @ DAT_0012e1c0 (3 entries).
    enum CullFace {
        CULL_FACE_FRONT = 0,      // GL_FRONT          (0x0404)
        CULL_FACE_BACK,           // GL_BACK           (0x0405)
        CULL_FACE_FRONT_AND_BACK, // GL_FRONT_AND_BACK (0x0408)
        CULL_FACE_MAX
    };

    // glFrontFace. No dedicated DAT table was located (only two legal values, so
    // the wrapper maps inline); these are the only glFrontFace arguments.
    enum FrontFace {
        FRONT_FACE_CCW = 0, // GL_CCW (0x0901)
        FRONT_FACE_CW,      // GL_CW  (0x0900)
        FRONT_FACE_MAX
    };

    // GL src blend factors. Table @ DAT_0012e170 (9 entries); decoded from
    // setBlendFunc (FUN_00013a34; asserts src < BLEND_SRC_VALUE_MAX == 9).
    enum BlendSrcValue {
        BLEND_SRC_ZERO = 0,            // GL_ZERO                     (0x0000)
        BLEND_SRC_ONE,                 // GL_ONE                      (0x0001)
        BLEND_SRC_DST_COLOR,           // GL_DST_COLOR                (0x0306)
        BLEND_SRC_ONE_MINUS_DST_COLOR, // GL_ONE_MINUS_DST_COLOR      (0x0307)
        BLEND_SRC_SRC_ALPHA,           // GL_SRC_ALPHA                (0x0302)
        BLEND_SRC_ONE_MINUS_SRC_ALPHA, // GL_ONE_MINUS_SRC_ALPHA      (0x0303)
        BLEND_SRC_DST_ALPHA,           // GL_DST_ALPHA                (0x0304)
        BLEND_SRC_ONE_MINUS_DST_ALPHA, // GL_ONE_MINUS_DST_ALPHA      (0x0305)
        BLEND_SRC_SRC_ALPHA_SATURATE,  // GL_SRC_ALPHA_SATURATE       (0x0308)
        BLEND_SRC_VALUE_MAX
    };

    // GL dest blend factors. Table @ DAT_0012e1a0 (8 entries); decoded from
    // setBlendFunc (FUN_00013a34; asserts dest < BLEND_DEST_VALUE_MAX == 8).
    enum BlendDestValue {
        BLEND_DEST_ZERO = 0,            // GL_ZERO                (0x0000)
        BLEND_DEST_ONE,                 // GL_ONE                 (0x0001)
        BLEND_DEST_SRC_COLOR,           // GL_SRC_COLOR           (0x0300)
        BLEND_DEST_ONE_MINUS_SRC_COLOR, // GL_ONE_MINUS_SRC_COLOR (0x0301)
        BLEND_DEST_SRC_ALPHA,           // GL_SRC_ALPHA           (0x0302)
        BLEND_DEST_ONE_MINUS_SRC_ALPHA, // GL_ONE_MINUS_SRC_ALPHA (0x0303)
        BLEND_DEST_DST_ALPHA,           // GL_DST_ALPHA           (0x0304)
        BLEND_DEST_ONE_MINUS_DST_ALPHA, // GL_ONE_MINUS_DST_ALPHA (0x0305)
        BLEND_DEST_VALUE_MAX
    };

    // Texture upload formats (TextureFormatToGLFormat, FUN_00013970 — recognizes
    // exactly these two, asserting on anything else).
    enum TexFormat {
        TEX_FORMAT_RGBA = 1,            // GL_RGBA            (0x1908, 4 bytes/pixel)
        TEX_FORMAT_LUMINANCE_ALPHA = 2, // GL_LUMINANCE_ALPHA (0x190a, 2 bytes/pixel)
        TEX_FORMAT_MAX
    };

    // glTexParameter pname. Table @ DAT_0012e2d0 (4 entries); consumed by
    // TexParamTypeFuncToGLType (FUN_00013864).
    enum TexParamType {
        TEX_PARAM_TYPE_MAG_FILTER = 0, // GL_TEXTURE_MAG_FILTER (0x2800)
        TEX_PARAM_TYPE_MIN_FILTER,     // GL_TEXTURE_MIN_FILTER (0x2801)
        TEX_PARAM_TYPE_WRAP_S,         // GL_TEXTURE_WRAP_S     (0x2802)
        TEX_PARAM_TYPE_WRAP_T,         // GL_TEXTURE_WRAP_T     (0x2803)
        TEX_PARAM_TYPE_MAX
    };

    // glTexParameter value. Table @ DAT_0012e150 (8 entries);
    // GLValueToTexParamValue (FUN_000138cc) is the reverse map used by
    // getTexParameter.
    enum TexParamValue {
        TEX_PARAM_VALUE_NEAREST = 0,            // GL_NEAREST                (0x2600)
        TEX_PARAM_VALUE_LINEAR,                 // GL_LINEAR                 (0x2601)
        TEX_PARAM_VALUE_NEAREST_MIPMAP_NEAREST, // GL_NEAREST_MIPMAP_NEAREST
                                                // (0x2700)
        TEX_PARAM_VALUE_LINEAR_MIPMAP_NEAREST,  // GL_LINEAR_MIPMAP_NEAREST  (0x2701)
        TEX_PARAM_VALUE_NEAREST_MIPMAP_LINEAR,  // GL_NEAREST_MIPMAP_LINEAR  (0x2702)
        TEX_PARAM_VALUE_LINEAR_MIPMAP_LINEAR,   // GL_LINEAR_MIPMAP_LINEAR   (0x2703)
        TEX_PARAM_VALUE_CLAMP_TO_EDGE,          // GL_CLAMP_TO_EDGE          (0x812f)
        TEX_PARAM_VALUE_REPEAT,                 // GL_REPEAT                 (0x2901)
        TEX_PARAM_VALUE_MAX
    };

    // Depth/alpha compare functions share one table @ DAT_0012e130 (8 entries),
    // GL_NEVER..GL_ALWAYS in numeric order.
    enum CompareFunc {
        COMPARE_NEVER = 0, // GL_NEVER    (0x0200)
        COMPARE_LESS,      // GL_LESS     (0x0201)
        COMPARE_EQUAL,     // GL_EQUAL    (0x0202)
        COMPARE_LEQUAL,    // GL_LEQUAL   (0x0203)
        COMPARE_GREATER,   // GL_GREATER  (0x0204)
        COMPARE_NOTEQUAL,  // GL_NOTEQUAL (0x0205)
        COMPARE_GEQUAL,    // GL_GEQUAL   (0x0206)
        COMPARE_ALWAYS,    // GL_ALWAYS   (0x0207)
        COMPARE_FUNC_MAX
    };
    using DepthTestFunc = CompareFunc; // asserts func < DEPTH_TEST_FUNC_MAX
    using AlphaTestFunc = CompareFunc; // asserts func < ALPHA_TEST_FUNC_MAX

    // Engine primitive ordinals -> GL mode. Table @ DAT_0012e2b0 (7 entries),
    // indexed by the mode the neDraw* free functions pass to
    // drawArrays/drawElements.
    enum Primitive {
        PRIM_POINTS = 0,     // GL_POINTS         (0x0000)
        PRIM_LINE_STRIP,     // GL_LINE_STRIP     (0x0003)
        PRIM_LINE_LOOP,      // GL_LINE_LOOP      (0x0002)
        PRIM_LINES,          // GL_LINES          (0x0001)
        PRIM_TRIANGLE_STRIP, // GL_TRIANGLE_STRIP (0x0005)
        PRIM_TRIANGLE_FAN,   // GL_TRIANGLE_FAN   (0x0006)
        PRIM_TRIANGLES,      // GL_TRIANGLES      (0x0004)
        PRIM_MAX
    };

    // --- render API (thin GL ES 1.1 wrappers; bodies in the backend) ---
    virtual void enable(EnableState state) = 0;
    virtual void disable(EnableState state) = 0;
    virtual void enableClientState(ClientState state) = 0;
    virtual void disableClientState(ClientState state) = 0;
    virtual void setMatrixMode(MatrixMode mode) = 0;
    virtual void setHint(Hint target, int mode) = 0;
    virtual void setFogMode(FogMode mode) = 0;
    virtual void setCullFace(CullFace face) = 0;
    virtual void setFrontFace(FrontFace face) = 0;
    // src -> DAT_0012e170, dest -> DAT_0012e1a0, equation -> glBlendEquationOES.
    virtual void setBlendFunc(BlendSrcValue src, BlendDestValue dest, unsigned equation) = 0;
    virtual void setDepthFunc(DepthTestFunc func) = 0;
    virtual void setAlphaFunc(AlphaTestFunc func, float ref) = 0;
    virtual void texImage2D(TexFormat format, int width, int height, const void *pixels) = 0;
    virtual void setTexParameter(TexParamType type, TexParamValue value) = 0;
    virtual TexParamValue getTexParameter(TexParamType type) = 0;
    virtual void deleteBuffer(unsigned buffer) = 0;
    // Attach a renderbuffer (of `type` storage) at attachment point `kind`.
    virtual void attachRenderbuffer(RenderKind kind, RenderType type, unsigned renderbuffer) = 0;
};

// OpenGL ES 1.1 backend.
class neGLES_11 : public neIGLES {
public:
    neGLES_11();
    ~neGLES_11() override;

    // Un-hide the enum-typed setBlendFunc so the drawing-slot overload below can
    // delegate.
    using neIGLES::setBlendFunc;

    // --- enum-typed GL wrappers (neIGLES) ---
    void enable(EnableState state) override;
    void disable(EnableState state) override;
    void enableClientState(ClientState state) override;
    void disableClientState(ClientState state) override;
    void setMatrixMode(MatrixMode mode) override;
    void setHint(Hint target, int mode) override;
    void setFogMode(FogMode mode) override;
    void setCullFace(CullFace face) override;
    void setFrontFace(FrontFace face) override;
    void setBlendFunc(BlendSrcValue src, BlendDestValue dest, unsigned equation) override;
    void setDepthFunc(DepthTestFunc func) override;
    void setAlphaFunc(AlphaTestFunc func, float ref) override;
    void texImage2D(TexFormat format, int width, int height, const void *pixels) override;
    void setTexParameter(TexParamType type, TexParamValue value) override;
    TexParamValue getTexParameter(TexParamType type) override;
    void deleteBuffer(unsigned buffer) override;
    void attachRenderbuffer(RenderKind kind, RenderType type, unsigned renderbuffer) override;

    // --- OES framebuffer-object (FBO) management ---
    // Thin GL ES 1.1 OES_framebuffer_object wrappers that pair with
    // attachRenderbuffer; the attachment point maps through RenderKindToGL. These
    // carry the renderer `this` but touch no cached state (pure GL). Ghidra
    // addresses annotated per body.
    void deleteFramebuffer(unsigned framebuffer);                 // @ 0x12e94 (vtable +0x14)
    void deleteRenderbuffer(unsigned renderbuffer);               // @ 0x12eb8 (vtable +0x20)
    void framebufferTexture2D(RenderKind kind, unsigned texture); // @ 0x12f3c (vtable +0x2c)
    void framebufferRenderbuffer(RenderKind kind,
                                 unsigned renderbuffer); // @ 0x12fcc (vtable +0x30)

    // Front-buffer FBO lifecycle driven by neGLView (the remaining vtable slots
    // the view dispatches through its m_GLInterface pointer). Each is a thin GL ES
    // 1.1 OES wrapper; presentTarget just returns the GL_RENDERBUFFER_OES constant
    // the view caches for -presentRenderbuffer:.
    unsigned presentTarget() const;               // @ 0x12e84 (+0x0c) -> GL_RENDERBUFFER_OES
    void genFramebuffer(unsigned &outName);       // @ 0x12e8c (+0x10) glGenFramebuffersOES
    void bindFramebuffer(unsigned framebuffer);   // @ 0x12ea8 (+0x18) glBindFramebufferOES
    void genRenderbuffer(unsigned &outName);      // @ 0x12eb0 (+0x1c) glGenRenderbuffersOES
    void bindRenderbuffer(unsigned renderbuffer); // @ 0x12ecc (+0x24) glBindRenderbufferOES
    bool isFramebufferComplete();                 // @ 0x12fec (+0x34) glCheckFramebufferStatusOES
    void getRenderbufferWidth(int &outWidth);   // @ 0x13008 (+0x38) glGetRenderbufferParameterivOES
    void getRenderbufferHeight(int &outHeight); // @ 0x13018 (+0x3c) glGetRenderbufferParameterivOES

    // --- drawing slots (::ne::C_RENDER) dispatched through by the neDraw*
    // primitives ---
    void initialize() override;
    void setViewport(int x, int y, int w, int h) override;
    void loadMatrix(int mode, const neMatrix4 &m) override;
    void genBuffer(unsigned &outName) override;
    void selectTextureUnit(int unit) override;
    void colorPointer(const void *ptr, int stride) override;
    void vertexPointer(const void *ptr, int size, int stride) override;
    void texCoordPointer(const void *ptr, int stride) override;
    void bindElementBuffer(unsigned name) override;
    void bufferData(const void *data, int size, int usage) override;
    void genTexture(unsigned &outName) override;
    void deleteTexture(unsigned name) override;
    void bindTexture(unsigned name) override;
    void applyTexParameter(int type, int value) override;
    void uploadTexture(int format, int w, int h, const void *pixels) override;
    void setBlendFunc(int src, int dst) override;
    void setBlendFuncSeparate(int src, int dst, unsigned equation) override;
    void setEnable(int cap, bool on) override;
    void setClientArray(int array, bool on) override;
    void drawArrays(int mode, int count) override;
    void drawElements(int mode, int count, int offset) override;

    // The 8-slot bound-texture-name cache (renderer ivars at +0xfc), indexed by
    // the active texture unit. bindTexture updates it and deleteTexture (+0xb8,
    // FUN_00013778) clears it when a name is deleted. Public so the texture-teardown
    // path can reach it.
    struct TexBindCache {
        unsigned names[8] = {}; // +0xfc
    };
    TexBindCache texBindCache;

private:
    // Cached GL state, at the ivar offsets observed in the decompiled backend.
    unsigned _activeTexUnit = 0;      // ivar 0xf8  (index into texBindCache, set on unit select)
    unsigned _matrixMode = 0;         // ivar 0x2c  (setMatrixMode cache)
    unsigned _boundArrayBuffer = 0;   // ivar 0x44 (cleared by deleteBuffer)
    unsigned _boundElementBuffer = 0; // ivar 0x50
    unsigned _boundBuffer2 = 0;       // ivar 0x5c
    unsigned _boundBuffer3 = 0;       // ivar 0x6c
    unsigned _blendEquation = 0;      // ivar 0x19c (setBlendFunc cache)
    unsigned _blendSrc = 0;           // ivar 0x1a0
    unsigned _blendDest = 0;          // ivar 0x1a4
    unsigned _boundTextures[8] = {};  // ivar 0xb4[8] (cleared by deleteBuffer)
    // GL caps probed by initialize() (Ghidra: QueryCaps FUN_00012da0).
    int _maxTextureSize = 0;        // ivar 0x84  (GL_MAX_TEXTURE_SIZE)
    bool _hasMatrixPalette = false; // ivar 0x87  (GL_OES_matrix_palette present)
    int _maxPaletteMatrices = 0;    // ivar 0x88
};

} // namespace ne

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
