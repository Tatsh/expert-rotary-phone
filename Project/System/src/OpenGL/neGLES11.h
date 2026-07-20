/** @file
 * OpenGL ES 1.1 rendering abstraction: the interface every on-screen sprite, texture, and
 * primitive is drawn through.
 *
 * `neIGLES` is the abstract GL interface (it holds the enum vocabulary); `neGLES_11` is the GL ES
 * 1.1 backend. `neIGLES` derives from the engine's abstract `ne::C_RENDER`
 * (System/src/Render), so the immediate-mode primitives dispatch their drawing-slot virtuals
 * through the very same object; `neGLES_11` implements both those slots and the enum-typed wrappers
 * below.
 *
 * Every enum below is decoded from its mapping table in the read-only data region and each member
 * is annotated with the exact GL constant that ordinal maps to. The member names are assigned from
 * those decoded GL constants (the original C++ identifiers are not recoverable), but the ordinal to
 * GL value mapping is byte-accurate.
 */

#pragma once

#include "C_RENDER.h" // ::ne::C_RENDER abstract drawing interface + neMatrix4

namespace ne {

/**
 * @brief Abstract OpenGL ES render interface: the enum vocabulary and pure-virtual drawing API.
 *
 * Derives from the engine's abstract ne::C_RENDER so immediate-mode primitives dispatch their
 * drawing-slot virtuals through the same object. neGLES_11 provides the concrete GL ES 1.1 backend.
 */
class neIGLES : public ne::C_RENDER {
public:
    /**
     * @brief Framebuffer attachment points (three entries), consumed when validating that the
     * attachment kind is below RENDER_KIND_MAX.
     */
    enum RenderKind {
        RENDER_KIND_COLOR = 0, /*!< GL_COLOR_ATTACHMENT0_OES (0x8ce0). */
        RENDER_KIND_DEPTH,     /*!< GL_DEPTH_ATTACHMENT_OES (0x8d00). */
        RENDER_KIND_STENCIL,   /*!< GL_STENCIL_ATTACHMENT_OES (0x8d20). */
        RENDER_KIND_MAX        /*!< Count of framebuffer attachment points. */
    };

    /**
     * @brief Renderbuffer storage formats. These pair one to one with RenderKind above and are the
     * only storage formats the GL ES 1.1 OES FBO path accepts for each.
     */
    enum RenderType {
        RENDER_TYPE_RGBA8 = 0, /*!< GL_RGBA8_OES. */
        RENDER_TYPE_DEPTH16,   /*!< GL_DEPTH_COMPONENT16_OES. */
        RENDER_TYPE_STENCIL8,  /*!< GL_STENCIL_INDEX8_OES. */
        RENDER_TYPE_MAX        /*!< Count of renderbuffer storage formats. */
    };

    /**
     * @brief glMatrixMode targets, with GL_MODELVIEW as the out-of-range default: mode minus one in
     * the range [0, 3) indexes the table, otherwise GL_MODELVIEW is used.
     */
    enum MatrixMode {
        MATRIX_MODE_MODELVIEW = 0,      /*!< GL_MODELVIEW (0x1700, the default). */
        MATRIX_MODE_PROJECTION,         /*!< GL_PROJECTION (0x1701). */
        MATRIX_MODE_TEXTURE,            /*!< GL_TEXTURE (0x1702). */
        MATRIX_MODE_MATRIX_PALETTE_OES, /*!< GL_MATRIX_PALETTE_OES (0x8840). */
        MATRIX_MODE_MAX                 /*!< Count of matrix mode targets. */
    };

    /**
     * @brief glHint targets (five entries), listed alphabetically by GL name.
     */
    enum Hint {
        HINT_FOG = 0,                /*!< GL_FOG_HINT (0x0c54). */
        HINT_GENERATE_MIPMAP,        /*!< GL_GENERATE_MIPMAP_HINT (0x8192). */
        HINT_LINE_SMOOTH,            /*!< GL_LINE_SMOOTH_HINT (0x0c52). */
        HINT_PERSPECTIVE_CORRECTION, /*!< GL_PERSPECTIVE_CORRECTION_HINT (0x0c50). */
        HINT_POINT_SMOOTH,           /*!< GL_POINT_SMOOTH_HINT (0x0c51). */
        HINT_MAX                     /*!< Count of hint targets. */
    };

    /**
     * @brief glFog(GL_FOG_MODE, ...) modes (three entries).
     */
    enum FogMode {
        FOG_MODE_LINEAR = 0, /*!< GL_LINEAR (0x2601). */
        FOG_MODE_EXP,        /*!< GL_EXP (0x0800). */
        FOG_MODE_EXP2,       /*!< GL_EXP2 (0x0801). */
        FOG_MODE_MAX         /*!< Count of fog modes. */
    };

    /**
     * @brief glEnableClientState and glDisableClientState array targets (eight entries): the
     * contiguous block of GL client-array enums that immediately follows the EnableState table.
     */
    enum ClientState {
        CS_MATRIX_PALETTE_OES = 0, /*!< GL_MATRIX_PALETTE_OES (0x8840). */
        CS_COLOR_ARRAY,            /*!< GL_COLOR_ARRAY (0x8076). */
        CS_MATRIX_INDEX_ARRAY_OES, /*!< GL_MATRIX_INDEX_ARRAY_OES (0x8844). */
        CS_NORMAL_ARRAY,           /*!< GL_NORMAL_ARRAY (0x8075). */
        CS_POINT_SIZE_ARRAY_OES,   /*!< GL_POINT_SIZE_ARRAY_OES (0x8b9c). */
        CS_TEXTURE_COORD_ARRAY,    /*!< GL_TEXTURE_COORD_ARRAY (0x8078). */
        CS_VERTEX_ARRAY,           /*!< GL_VERTEX_ARRAY (0x8074). */
        CS_WEIGHT_ARRAY_OES,       /*!< GL_WEIGHT_ARRAY_OES (0x86ad). */
        CS_MAX                     /*!< Count of client-array targets. */
    };

    /**
     * @brief glEnable and glDisable capabilities (35 entries), listed alphabetically by GL name.
     * This is the engine's full enable-capability vocabulary; note that GL_STENCIL_TEST is
     * intentionally absent.
     */
    enum EnableState {
        ES_ALPHA_TEST = 0,           /*!< GL_ALPHA_TEST (0x0bc0). */
        ES_BLEND,                    /*!< GL_BLEND (0x0be2). */
        ES_COLOR_LOGIC_OP,           /*!< GL_COLOR_LOGIC_OP (0x0bf2). */
        ES_CLIP_PLANE0,              /*!< GL_CLIP_PLANE0 (0x3000). */
        ES_CLIP_PLANE1,              /*!< GL_CLIP_PLANE1 (0x3001). */
        ES_CLIP_PLANE2,              /*!< GL_CLIP_PLANE2 (0x3002). */
        ES_CLIP_PLANE3,              /*!< GL_CLIP_PLANE3 (0x3003). */
        ES_CLIP_PLANE4,              /*!< GL_CLIP_PLANE4 (0x3004). */
        ES_CLIP_PLANE5,              /*!< GL_CLIP_PLANE5 (0x3005). */
        ES_COLOR_MATERIAL,           /*!< GL_COLOR_MATERIAL (0x0b57). */
        ES_CULL_FACE,                /*!< GL_CULL_FACE (0x0b44). */
        ES_DEPTH_TEST,               /*!< GL_DEPTH_TEST (0x0b71). */
        ES_DITHER,                   /*!< GL_DITHER (0x0bd0). */
        ES_FOG,                      /*!< GL_FOG (0x0b60). */
        ES_LIGHT0,                   /*!< GL_LIGHT0 (0x4000). */
        ES_LIGHT1,                   /*!< GL_LIGHT1 (0x4001). */
        ES_LIGHT2,                   /*!< GL_LIGHT2 (0x4002). */
        ES_LIGHT3,                   /*!< GL_LIGHT3 (0x4003). */
        ES_LIGHT4,                   /*!< GL_LIGHT4 (0x4004). */
        ES_LIGHT5,                   /*!< GL_LIGHT5 (0x4005). */
        ES_LIGHT6,                   /*!< GL_LIGHT6 (0x4006). */
        ES_LIGHT7,                   /*!< GL_LIGHT7 (0x4007). */
        ES_LIGHTING,                 /*!< GL_LIGHTING (0x0b50). */
        ES_LINE_SMOOTH,              /*!< GL_LINE_SMOOTH (0x0b20). */
        ES_MULTISAMPLE,              /*!< GL_MULTISAMPLE (0x809d). */
        ES_NORMALIZE,                /*!< GL_NORMALIZE (0x0ba1). */
        ES_POINT_SMOOTH,             /*!< GL_POINT_SMOOTH (0x0b10). */
        ES_POINT_SPRITE_OES,         /*!< GL_POINT_SPRITE_OES (0x8861). */
        ES_POLYGON_OFFSET_FILL,      /*!< GL_POLYGON_OFFSET_FILL (0x8037). */
        ES_RESCALE_NORMAL,           /*!< GL_RESCALE_NORMAL (0x803a). */
        ES_SAMPLE_ALPHA_TO_COVERAGE, /*!< GL_SAMPLE_ALPHA_TO_COVERAGE (0x809e). */
        ES_SAMPLE_ALPHA_TO_ONE,      /*!< GL_SAMPLE_ALPHA_TO_ONE (0x809f). */
        ES_SAMPLE_COVERAGE,          /*!< GL_SAMPLE_COVERAGE (0x80a0). */
        ES_SCISSOR_TEST,             /*!< GL_SCISSOR_TEST (0x0c11). */
        ES_TEXTURE_2D,               /*!< GL_TEXTURE_2D (0x0de1). */
        ES_MAX                       /*!< Count of enable capabilities. */
    };

    /**
     * @brief glCullFace values (three entries).
     */
    enum CullFace {
        CULL_FACE_FRONT = 0,      /*!< GL_FRONT (0x0404). */
        CULL_FACE_BACK,           /*!< GL_BACK (0x0405). */
        CULL_FACE_FRONT_AND_BACK, /*!< GL_FRONT_AND_BACK (0x0408). */
        CULL_FACE_MAX             /*!< Count of cull-face values. */
    };

    /**
     * @brief glFrontFace values. These are the only two legal glFrontFace arguments, so the wrapper
     * maps them inline.
     */
    enum FrontFace {
        FRONT_FACE_CCW = 0, /*!< GL_CCW (0x0901). */
        FRONT_FACE_CW,      /*!< GL_CW (0x0900). */
        FRONT_FACE_MAX      /*!< Count of front-face values. */
    };

    /**
     * @brief GL source blend factors (nine entries), validated against BLEND_SRC_VALUE_MAX.
     */
    enum BlendSrcValue {
        BLEND_SRC_ZERO = 0,            /*!< GL_ZERO (0x0000). */
        BLEND_SRC_ONE,                 /*!< GL_ONE (0x0001). */
        BLEND_SRC_DST_COLOR,           /*!< GL_DST_COLOR (0x0306). */
        BLEND_SRC_ONE_MINUS_DST_COLOR, /*!< GL_ONE_MINUS_DST_COLOR (0x0307). */
        BLEND_SRC_SRC_ALPHA,           /*!< GL_SRC_ALPHA (0x0302). */
        BLEND_SRC_ONE_MINUS_SRC_ALPHA, /*!< GL_ONE_MINUS_SRC_ALPHA (0x0303). */
        BLEND_SRC_DST_ALPHA,           /*!< GL_DST_ALPHA (0x0304). */
        BLEND_SRC_ONE_MINUS_DST_ALPHA, /*!< GL_ONE_MINUS_DST_ALPHA (0x0305). */
        BLEND_SRC_SRC_ALPHA_SATURATE,  /*!< GL_SRC_ALPHA_SATURATE (0x0308). */
        BLEND_SRC_VALUE_MAX            /*!< Count of source blend factors. */
    };

    /**
     * @brief GL destination blend factors (eight entries), validated against BLEND_DEST_VALUE_MAX.
     */
    enum BlendDestValue {
        BLEND_DEST_ZERO = 0,            /*!< GL_ZERO (0x0000). */
        BLEND_DEST_ONE,                 /*!< GL_ONE (0x0001). */
        BLEND_DEST_SRC_COLOR,           /*!< GL_SRC_COLOR (0x0300). */
        BLEND_DEST_ONE_MINUS_SRC_COLOR, /*!< GL_ONE_MINUS_SRC_COLOR (0x0301). */
        BLEND_DEST_SRC_ALPHA,           /*!< GL_SRC_ALPHA (0x0302). */
        BLEND_DEST_ONE_MINUS_SRC_ALPHA, /*!< GL_ONE_MINUS_SRC_ALPHA (0x0303). */
        BLEND_DEST_DST_ALPHA,           /*!< GL_DST_ALPHA (0x0304). */
        BLEND_DEST_ONE_MINUS_DST_ALPHA, /*!< GL_ONE_MINUS_DST_ALPHA (0x0305). */
        BLEND_DEST_VALUE_MAX            /*!< Count of destination blend factors. */
    };

    /**
     * @brief Texture upload formats. Exactly these two are recognised; anything else asserts.
     */
    enum TexFormat {
        TEX_FORMAT_RGBA = 1,            /*!< GL_RGBA (0x1908, four bytes per pixel). */
        TEX_FORMAT_LUMINANCE_ALPHA = 2, /*!< GL_LUMINANCE_ALPHA (0x190a, two bytes per pixel). */
        TEX_FORMAT_MAX                  /*!< Count of texture upload formats. */
    };

    /**
     * @brief glTexParameter pname values (four entries).
     */
    enum TexParamType {
        TEX_PARAM_TYPE_MAG_FILTER = 0, /*!< GL_TEXTURE_MAG_FILTER (0x2800). */
        TEX_PARAM_TYPE_MIN_FILTER,     /*!< GL_TEXTURE_MIN_FILTER (0x2801). */
        TEX_PARAM_TYPE_WRAP_S,         /*!< GL_TEXTURE_WRAP_S (0x2802). */
        TEX_PARAM_TYPE_WRAP_T,         /*!< GL_TEXTURE_WRAP_T (0x2803). */
        TEX_PARAM_TYPE_MAX             /*!< Count of texture parameter names. */
    };

    /**
     * @brief glTexParameter values (eight entries). getTexParameter provides the reverse mapping.
     */
    enum TexParamValue {
        TEX_PARAM_VALUE_NEAREST = 0,            /*!< GL_NEAREST (0x2600). */
        TEX_PARAM_VALUE_LINEAR,                 /*!< GL_LINEAR (0x2601). */
        TEX_PARAM_VALUE_NEAREST_MIPMAP_NEAREST, /*!< GL_NEAREST_MIPMAP_NEAREST (0x2700). */
        TEX_PARAM_VALUE_LINEAR_MIPMAP_NEAREST,  /*!< GL_LINEAR_MIPMAP_NEAREST (0x2701). */
        TEX_PARAM_VALUE_NEAREST_MIPMAP_LINEAR,  /*!< GL_NEAREST_MIPMAP_LINEAR (0x2702). */
        TEX_PARAM_VALUE_LINEAR_MIPMAP_LINEAR,   /*!< GL_LINEAR_MIPMAP_LINEAR (0x2703). */
        TEX_PARAM_VALUE_CLAMP_TO_EDGE,          /*!< GL_CLAMP_TO_EDGE (0x812f). */
        TEX_PARAM_VALUE_REPEAT,                 /*!< GL_REPEAT (0x2901). */
        TEX_PARAM_VALUE_MAX                     /*!< Count of texture parameter values. */
    };

    /**
     * @brief Depth and alpha compare functions (eight entries), sharing one table, GL_NEVER through
     * GL_ALWAYS in numeric order.
     */
    enum CompareFunc {
        COMPARE_NEVER = 0, /*!< GL_NEVER (0x0200). */
        COMPARE_LESS,      /*!< GL_LESS (0x0201). */
        COMPARE_EQUAL,     /*!< GL_EQUAL (0x0202). */
        COMPARE_LEQUAL,    /*!< GL_LEQUAL (0x0203). */
        COMPARE_GREATER,   /*!< GL_GREATER (0x0204). */
        COMPARE_NOTEQUAL,  /*!< GL_NOTEQUAL (0x0205). */
        COMPARE_GEQUAL,    /*!< GL_GEQUAL (0x0206). */
        COMPARE_ALWAYS,    /*!< GL_ALWAYS (0x0207). */
        COMPARE_FUNC_MAX   /*!< Count of compare functions. */
    };
    /** @brief Alias for the depth-test compare function; asserts below DEPTH_TEST_FUNC_MAX. */
    using DepthTestFunc = CompareFunc;
    /** @brief Alias for the alpha-test compare function; asserts below ALPHA_TEST_FUNC_MAX. */
    using AlphaTestFunc = CompareFunc;

    /**
     * @brief Engine primitive ordinals mapped to GL modes (seven entries), indexed by the mode the
     * neDraw* free functions pass to drawArrays and drawElements.
     */
    enum Primitive {
        PRIM_POINTS = 0,     /*!< GL_POINTS (0x0000). */
        PRIM_LINE_STRIP,     /*!< GL_LINE_STRIP (0x0003). */
        PRIM_LINE_LOOP,      /*!< GL_LINE_LOOP (0x0002). */
        PRIM_LINES,          /*!< GL_LINES (0x0001). */
        PRIM_TRIANGLE_STRIP, /*!< GL_TRIANGLE_STRIP (0x0005). */
        PRIM_TRIANGLE_FAN,   /*!< GL_TRIANGLE_FAN (0x0006). */
        PRIM_TRIANGLES,      /*!< GL_TRIANGLES (0x0004). */
        PRIM_MAX             /*!< Count of primitive modes. */
    };

    // --- render API (thin GL ES 1.1 wrappers; bodies in the backend) ---

    /**
     * @brief Enable a GL capability.
     * @param state The capability to enable.
     */
    virtual void enable(EnableState state) = 0;

    /**
     * @brief Disable a GL capability.
     * @param state The capability to disable.
     */
    virtual void disable(EnableState state) = 0;

    /**
     * @brief Enable a GL client-side array.
     * @param state The client-array target to enable.
     */
    virtual void enableClientState(ClientState state) = 0;

    /**
     * @brief Disable a GL client-side array.
     * @param state The client-array target to disable.
     */
    virtual void disableClientState(ClientState state) = 0;

    /**
     * @brief Select the current matrix mode.
     * @param mode The matrix mode to make current.
     */
    virtual void setMatrixMode(MatrixMode mode) = 0;

    /**
     * @brief Set an implementation hint.
     * @param target The hint target to configure.
     * @param mode The hint mode passed through to glHint.
     */
    virtual void setHint(Hint target, int mode) = 0;

    /**
     * @brief Select the fog equation.
     * @param mode The fog mode to apply.
     */
    virtual void setFogMode(FogMode mode) = 0;

    /**
     * @brief Select the face-culling mode.
     * @param face The face or faces to cull.
     */
    virtual void setCullFace(CullFace face) = 0;

    /**
     * @brief Select the front-face winding order.
     * @param face The winding order that denotes front-facing polygons.
     */
    virtual void setFrontFace(FrontFace face) = 0;

    /**
     * @brief Configure blending: source and destination factors plus the blend equation.
     * @param src The source blend factor.
     * @param dest The destination blend factor.
     * @param equation The GL blend equation passed to glBlendEquationOES.
     */
    virtual void setBlendFunc(BlendSrcValue src, BlendDestValue dest, unsigned equation) = 0;

    /**
     * @brief Set the depth-test comparison function.
     * @param func The comparison function to apply.
     */
    virtual void setDepthFunc(DepthTestFunc func) = 0;

    /**
     * @brief Set the alpha-test comparison function and reference value.
     * @param func The comparison function to apply.
     * @param ref The alpha reference value to compare against.
     */
    virtual void setAlphaFunc(AlphaTestFunc func, float ref) = 0;

    /**
     * @brief Upload a level-zero 2D texture image.
     * @param format The pixel format of the source data.
     * @param width The image width in pixels.
     * @param height The image height in pixels.
     * @param pixels The source pixel data.
     */
    virtual void texImage2D(TexFormat format, int width, int height, const void *pixels) = 0;

    /**
     * @brief Set a texture parameter on the bound 2D texture.
     * @param type The texture parameter to set.
     * @param value The value to assign to the parameter.
     */
    virtual void setTexParameter(TexParamType type, TexParamValue value) = 0;

    /**
     * @brief Read a texture parameter back from the bound 2D texture.
     * @param type The texture parameter to read.
     * @return The parameter's current value as an engine enum.
     */
    virtual TexParamValue getTexParameter(TexParamType type) = 0;

    /**
     * @brief Delete a GL buffer, invalidating any cached binding that referred to it.
     * @param buffer The name of the buffer to delete.
     */
    virtual void deleteBuffer(unsigned buffer) = 0;

    /**
     * @brief Attach a renderbuffer, of the given storage type, at the given attachment point.
     * @param kind The attachment point to bind to.
     * @param type The renderbuffer storage format.
     * @param renderbuffer The name of the renderbuffer to attach.
     */
    virtual void attachRenderbuffer(RenderKind kind, RenderType type, unsigned renderbuffer) = 0;
};

/**
 * @brief OpenGL ES 1.1 backend implementing the neIGLES render API and the ne::C_RENDER drawing
 * slots.
 */
class neGLES_11 : public neIGLES {
public:
    /**
     * @brief Construct the backend and prime the cached GL state block to its power-on defaults.
     * @ghidraAddress 0x12c78
     */
    neGLES_11();

    /** @brief Destroy the backend. */
    ~neGLES_11() override;

    /**
     * @brief Un-hide the enum-typed setBlendFunc so the drawing-slot overload below can delegate to
     * it.
     */
    using neIGLES::setBlendFunc;

    // --- enum-typed GL wrappers (neIGLES) ---

    /**
     * @brief Enable a GL capability.
     * @param state The capability to enable.
     */
    void enable(EnableState state) override;

    /**
     * @brief Disable a GL capability.
     * @param state The capability to disable.
     */
    void disable(EnableState state) override;

    /**
     * @brief Enable a GL client-side array.
     * @param state The client-array target to enable.
     */
    void enableClientState(ClientState state) override;

    /**
     * @brief Disable a GL client-side array.
     * @param state The client-array target to disable.
     */
    void disableClientState(ClientState state) override;

    /**
     * @brief Select the current matrix mode, caching it and only re-issuing glMatrixMode on change.
     * @param mode The matrix mode to make current.
     * @ghidraAddress 0x13110
     */
    void setMatrixMode(MatrixMode mode) override;

    /**
     * @brief Set an implementation hint.
     * @param target The hint target to configure.
     * @param mode The hint mode passed through to glHint.
     */
    void setHint(Hint target, int mode) override;

    /**
     * @brief Select the fog equation.
     * @param mode The fog mode to apply.
     */
    void setFogMode(FogMode mode) override;

    /**
     * @brief Select the face-culling mode.
     * @param face The face or faces to cull.
     */
    void setCullFace(CullFace face) override;

    /**
     * @brief Select the front-face winding order.
     * @param face The winding order that denotes front-facing polygons.
     */
    void setFrontFace(FrontFace face) override;

    /**
     * @brief Configure blending, caching the factors and equation and skipping redundant calls.
     * @param src The source blend factor.
     * @param dest The destination blend factor.
     * @param equation The GL blend equation passed to glBlendEquationOES.
     * @ghidraAddress 0x13a34
     */
    void setBlendFunc(BlendSrcValue src, BlendDestValue dest, unsigned equation) override;

    /**
     * @brief Set the depth-test comparison function.
     * @param func The comparison function to apply.
     */
    void setDepthFunc(DepthTestFunc func) override;

    /**
     * @brief Set the alpha-test comparison function and reference value.
     * @param func The comparison function to apply.
     * @param ref The alpha reference value to compare against.
     */
    void setAlphaFunc(AlphaTestFunc func, float ref) override;

    /**
     * @brief Upload a level-zero 2D texture image (GL_TEXTURE_2D, GL_UNSIGNED_BYTE).
     * @param format The pixel format of the source data.
     * @param width The image width in pixels.
     * @param height The image height in pixels.
     * @param pixels The source pixel data.
     * @ghidraAddress 0x13970
     */
    void texImage2D(TexFormat format, int width, int height, const void *pixels) override;

    /**
     * @brief Set a texture parameter on the bound 2D texture.
     * @param type The texture parameter to set.
     * @param value The value to assign to the parameter.
     */
    void setTexParameter(TexParamType type, TexParamValue value) override;

    /**
     * @brief Read a texture parameter back from the bound 2D texture.
     * @param type The texture parameter to read.
     * @return The parameter's current value as an engine enum.
     * @ghidraAddress 0x138cc
     */
    TexParamValue getTexParameter(TexParamType type) override;

    /**
     * @brief Delete a GL buffer, first invalidating any cached binding that referred to it.
     * @param buffer The name of the buffer to delete.
     * @ghidraAddress 0x13290
     */
    void deleteBuffer(unsigned buffer) override;

    /**
     * @brief Attach a renderbuffer, of the given storage type, at the given attachment point.
     * @param kind The attachment point to bind to.
     * @param type The renderbuffer storage format.
     * @param renderbuffer The name of the renderbuffer to attach.
     */
    void attachRenderbuffer(RenderKind kind, RenderType type, unsigned renderbuffer) override;

    // --- OES framebuffer-object (FBO) management ---
    // Thin GL ES 1.1 OES_framebuffer_object wrappers that pair with attachRenderbuffer; the
    // attachment point maps through RenderKindToGL. These carry the renderer `this` but touch no
    // cached state (pure GL).

    /**
     * @brief Delete an OES framebuffer object.
     * @param framebuffer The name of the framebuffer to delete.
     * @ghidraAddress 0x12e94
     */
    void deleteFramebuffer(unsigned framebuffer);

    /**
     * @brief Delete an OES renderbuffer object.
     * @param renderbuffer The name of the renderbuffer to delete.
     * @ghidraAddress 0x12eb8
     */
    void deleteRenderbuffer(unsigned renderbuffer);

    /**
     * @brief Attach a 2D texture's level zero at the given attachment point.
     * @param kind The attachment point to bind to.
     * @param texture The name of the texture to attach.
     * @ghidraAddress 0x12f3c
     */
    void framebufferTexture2D(RenderKind kind, unsigned texture);

    /**
     * @brief Attach a renderbuffer at the given attachment point.
     * @param kind The attachment point to bind to.
     * @param renderbuffer The name of the renderbuffer to attach.
     * @ghidraAddress 0x12fcc
     */
    void framebufferRenderbuffer(RenderKind kind, unsigned renderbuffer);

    // Front-buffer FBO lifecycle driven by neGLView (the remaining vtable slots the view dispatches
    // through its m_GLInterface pointer). Each is a thin GL ES 1.1 OES wrapper.

    /**
     * @brief Return the GL_RENDERBUFFER_OES constant the view caches for -presentRenderbuffer:.
     * @return The GL_RENDERBUFFER_OES present target.
     * @ghidraAddress 0x12e84
     */
    unsigned presentTarget() const;

    /**
     * @brief Generate one OES framebuffer name.
     * @param outName Receives the generated framebuffer name.
     * @ghidraAddress 0x12e8c
     */
    void genFramebuffer(unsigned &outName);

    /**
     * @brief Bind an OES framebuffer.
     * @param framebuffer The name of the framebuffer to bind.
     * @ghidraAddress 0x12ea8
     */
    void bindFramebuffer(unsigned framebuffer);

    /**
     * @brief Generate one OES renderbuffer name.
     * @param outName Receives the generated renderbuffer name.
     * @ghidraAddress 0x12eb0
     */
    void genRenderbuffer(unsigned &outName);

    /**
     * @brief Bind an OES renderbuffer.
     * @param renderbuffer The name of the renderbuffer to bind.
     * @ghidraAddress 0x12ecc
     */
    void bindRenderbuffer(unsigned renderbuffer);

    /**
     * @brief Report whether the currently-bound OES framebuffer is complete.
     * @return True when the framebuffer status is GL_FRAMEBUFFER_COMPLETE_OES.
     * @ghidraAddress 0x12fec
     */
    bool isFramebufferComplete();

    /**
     * @brief Read the bound renderbuffer's pixel width.
     * @param outWidth Receives the renderbuffer width in pixels.
     * @ghidraAddress 0x13008
     */
    void getRenderbufferWidth(int &outWidth);

    /**
     * @brief Read the bound renderbuffer's pixel height.
     * @param outHeight Receives the renderbuffer height in pixels.
     * @ghidraAddress 0x13018
     */
    void getRenderbufferHeight(int &outHeight);

    // --- drawing slots (::ne::C_RENDER) dispatched through by the neDraw* primitives ---

    /**
     * @brief Probe GL capabilities, load the texcoord-normalising texture matrix, and set the
     * default line width. Scans the extension string for GL_OES_matrix_palette and reads
     * GL_MAX_TEXTURE_SIZE.
     * @ghidraAddress 0x12da0
     */
    void initialize() override;

    /**
     * @brief Set the viewport rectangle.
     * @param x The lower-left x coordinate.
     * @param y The lower-left y coordinate.
     * @param w The viewport width in pixels.
     * @param h The viewport height in pixels.
     */
    void setViewport(int x, int y, int w, int h) override;

    /**
     * @brief Select the matrix mode and load the given matrix into it.
     * @param mode The matrix mode to load into.
     * @param m The matrix to load.
     */
    void loadMatrix(int mode, const neMatrix4 &m) override;

    /**
     * @brief Generate one GL buffer name.
     * @param outName Receives the generated buffer name.
     */
    void genBuffer(unsigned &outName) override;

    /**
     * @brief Select the active texture unit.
     * @param unit The texture unit offset from GL_TEXTURE0.
     */
    void selectTextureUnit(int unit) override;

    /**
     * @brief Specify the colour array (four unsigned bytes per vertex).
     * @param ptr The base pointer of the colour data.
     * @param stride The byte stride between vertices.
     */
    void colorPointer(const void *ptr, int stride) override;

    /**
     * @brief Specify the vertex-position array (GL_FLOAT components).
     * @param ptr The base pointer of the vertex data.
     * @param size The number of components per vertex.
     * @param stride The byte stride between vertices.
     */
    void vertexPointer(const void *ptr, int size, int stride) override;

    /**
     * @brief Specify the texture-coordinate array (two GL_SHORT components).
     * @param ptr The base pointer of the texture-coordinate data.
     * @param stride The byte stride between vertices.
     */
    void texCoordPointer(const void *ptr, int stride) override;

    /**
     * @brief Bind the element (index) buffer.
     * @param name The name of the buffer to bind.
     */
    void bindElementBuffer(unsigned name) override;

    /**
     * @brief Upload data into the bound element buffer.
     * @param data The source data.
     * @param size The size of the data in bytes.
     * @param usage Zero selects GL_STATIC_DRAW, otherwise GL_DYNAMIC_DRAW.
     */
    void bufferData(const void *data, int size, int usage) override;

    /**
     * @brief Generate one GL texture name.
     * @param outName Receives the generated texture name.
     * @ghidraAddress 0x13770
     */
    void genTexture(unsigned &outName) override;

    /**
     * @brief Delete a GL texture, first clearing every bound-texture-cache slot holding its name so
     * a later reused name is not treated as still bound.
     * @param name The name of the texture to delete.
     * @ghidraAddress 0x13778
     */
    void deleteTexture(unsigned name) override;

    /**
     * @brief Bind a texture to the active unit through a per-unit redundant-bind cache, skipping
     * the call when the cached name already matches.
     * @param name The name of the texture to bind.
     * @ghidraAddress 0x137c0
     */
    void bindTexture(unsigned name) override;

    /**
     * @brief Apply a texture parameter on the bound 2D texture.
     * @param type The texture parameter to set.
     * @param value The value to assign to the parameter.
     */
    void applyTexParameter(int type, int value) override;

    /**
     * @brief Upload a 2D texture image.
     * @param format The pixel format of the source data.
     * @param w The image width in pixels.
     * @param h The image height in pixels.
     * @param pixels The source pixel data.
     */
    void uploadTexture(int format, int w, int h, const void *pixels) override;

    /**
     * @brief Configure blending using the default add equation.
     * @param src The source blend factor ordinal.
     * @param dst The destination blend factor ordinal.
     */
    void setBlendFunc(int src, int dst) override;

    /**
     * @brief Configure blending with an explicit blend equation.
     * @param src The source blend factor ordinal.
     * @param dst The destination blend factor ordinal.
     * @param equation The GL blend equation.
     */
    void setBlendFuncSeparate(int src, int dst, unsigned equation) override;

    /**
     * @brief Enable or disable a GL capability.
     * @param cap The capability ordinal.
     * @param on True to enable, false to disable.
     */
    void setEnable(int cap, bool on) override;

    /**
     * @brief Enable or disable a client-side array. The drawing ordinal is one less than the
     * matching ClientState enum value; the wrapper adds one before indexing.
     * @param array The drawing-slot client-array ordinal.
     * @param on True to enable, false to disable.
     */
    void setClientArray(int array, bool on) override;

    /**
     * @brief Draw non-indexed primitives.
     * @param mode The primitive mode ordinal.
     * @param count The number of vertices to draw.
     */
    void drawArrays(int mode, int count) override;

    /**
     * @brief Draw indexed primitives from the bound element buffer.
     * @param mode The primitive mode ordinal.
     * @param count The number of indices to draw.
     * @param offset The byte offset into the bound element buffer.
     */
    void drawElements(int mode, int count, int offset) override;

    /**
     * @brief The eight-slot bound-texture-name cache, indexed by the active texture unit.
     * @details bindTexture updates it and deleteTexture clears it when a name is deleted. Public so
     * the texture-teardown path can reach it.
     */
    struct TexBindCache {
        unsigned names[8] = {}; /*!< Bound texture name per texture unit (+0xfc). */
    };
    /** @brief The bound-texture-name cache for this backend. */
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
