//
//  neGLES11.h
//  pop'n rhythmin
//
//  OpenGL ES 1.1 rendering abstraction — the interface every on-screen sprite,
//  texture and primitive is drawn through. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (RTTI: ne::neGLES_11, "N2ne9neGLES_11E").
//
//  `neIGLES` is the abstract interface (holds the enum vocabulary, referenced in
//  the binary as "neIGLES::HINT_MAX" etc.); `neGLES_11` is the GL ES 1.1 backend.
//  Enum members map to GL constants via the To/From helpers in neGLES11.cpp;
//  values decoded from the mapping tables are noted, the rest are sequential and
//  bounded by their _MAX sentinel (as the original asserts require).
//

#pragma once

namespace ne {

class neIGLES {
public:
    virtual ~neIGLES() {}

    // Primitive kinds passed to draw() (table @ DAT_0012e110; GL primitive enum).
    enum RenderKind {
        RENDER_KIND_TRIANGLES = 0,
        RENDER_KIND_TRIANGLE_STRIP,
        RENDER_KIND_TRIANGLE_FAN,
        RENDER_KIND_MAX
    };

    enum RenderType { RENDER_TYPE_MAX };   // TODO: enumerate

    enum Hint { HINT_MAX };                // glHint targets/modes
    enum FogMode { FOG_MODE_MAX };         // glFog modes

    enum ClientState { CS_MAX };           // glEnableClientState arrays
    enum EnableState { ES_MAX };           // glEnable capabilities

    enum CullFace { CULL_FACE_MAX };       // glCullFace
    enum FrontFace { FRONT_FACE_MAX };     // glFrontFace

    enum BlendSrcValue { BLEND_SRC_VALUE_MAX };
    enum BlendDestValue { BLEND_DEST_VALUE_MAX };

    // Texture upload formats (TextureFormatToGLFormat @ 0x13970).
    enum TexFormat {
        TEX_FORMAT_ALPHA = 0,   // GL_ALPHA-like (format 0)
        TEX_FORMAT_RGB,         // 1 -> GL_RGB   (0x1908)
        TEX_FORMAT_RGBA,        // 2 -> GL_RGBA  (0x190a)
        TEX_FORMAT_MAX
    };

    // glTexParameter type (TexParamTypeFuncToGLType @ 0x13864; table DAT_0012e2d0).
    enum TexParamType {
        TEX_PARAM_TYPE_MIN_FILTER = 0,  // GL_TEXTURE_MIN_FILTER
        TEX_PARAM_TYPE_MAG_FILTER,      // GL_TEXTURE_MAG_FILTER
        TEX_PARAM_TYPE_WRAP_S,          // GL_TEXTURE_WRAP_S
        TEX_PARAM_TYPE_WRAP_T,          // GL_TEXTURE_WRAP_T
        TEX_PARAM_TYPE_MAX
    };

    // glTexParameter value (GLValueToTexParamValue @ 0x138cc).
    enum TexParamValue {
        TEX_PARAM_VALUE_NEAREST = 0,                 // GL_NEAREST (0x2600)
        TEX_PARAM_VALUE_LINEAR,                       // GL_LINEAR  (0x2601)
        TEX_PARAM_VALUE_NEAREST_MIPMAP_NEAREST,       // 0x2700
        TEX_PARAM_VALUE_LINEAR_MIPMAP_NEAREST,        // 0x2701
        TEX_PARAM_VALUE_NEAREST_MIPMAP_LINEAR,        // 0x2702
        TEX_PARAM_VALUE_LINEAR_MIPMAP_LINEAR,         // 0x2703
        TEX_PARAM_VALUE_CLAMP_TO_EDGE,                // 0x812f
        TEX_PARAM_VALUE_REPEAT,                       // 0x2901
        TEX_PARAM_VALUE_MAX
    };

    enum DepthTestFunc { DEPTH_TEST_FUNC_MAX };   // glDepthFunc
    enum AlphaTestFunc { ALPHA_TEST_FUNC_MAX };   // glAlphaFunc

    // --- render API (thin GL ES 1.1 wrappers; bodies in the backend) ---
    virtual void enable(EnableState state) = 0;
    virtual void disable(EnableState state) = 0;
    virtual void enableClientState(ClientState state) = 0;
    virtual void disableClientState(ClientState state) = 0;
    virtual void setHint(Hint target, int mode) = 0;
    virtual void setFogMode(FogMode mode) = 0;
    virtual void setCullFace(CullFace face) = 0;
    virtual void setFrontFace(FrontFace face) = 0;
    virtual void setBlendFunc(BlendSrcValue src, BlendDestValue dest) = 0;
    virtual void setDepthFunc(DepthTestFunc func) = 0;
    virtual void setAlphaFunc(AlphaTestFunc func, float ref) = 0;
    virtual void texImage2D(TexFormat format, int width, int height, const void *pixels) = 0;
    virtual void setTexParameter(TexParamType type, TexParamValue value) = 0;
    virtual TexParamValue getTexParameter(TexParamType type) = 0;
    virtual void draw(RenderKind kind, RenderType type, int first, int count) = 0;
};

// OpenGL ES 1.1 backend.
class neGLES_11 : public neIGLES {
public:
    neGLES_11();
    ~neGLES_11() override;

    void enable(EnableState state) override;
    void disable(EnableState state) override;
    void enableClientState(ClientState state) override;
    void disableClientState(ClientState state) override;
    void setHint(Hint target, int mode) override;
    void setFogMode(FogMode mode) override;
    void setCullFace(CullFace face) override;
    void setFrontFace(FrontFace face) override;
    void setBlendFunc(BlendSrcValue src, BlendDestValue dest) override;
    void setDepthFunc(DepthTestFunc func) override;
    void setAlphaFunc(AlphaTestFunc func, float ref) override;
    void texImage2D(TexFormat format, int width, int height, const void *pixels) override;
    void setTexParameter(TexParamType type, TexParamValue value) override;
    TexParamValue getTexParameter(TexParamType type) override;
    void draw(RenderKind kind, RenderType type, int first, int count) override;
};

}  // namespace ne

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
