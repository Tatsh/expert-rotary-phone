/** @file
 * The engine-side renderer facade: the abstract renderer interface, the global "current
 * renderer", the immediate drawing primitives (line, triangle, rect, quad and textured quad), the
 * 4x4 matrix helpers, the orthographic viewport object and the scene-graph transform node.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * Every primitive funnels through a single polymorphic renderer created by neEnsureRenderer().
 * ne::C_RENDER is the abstract interface those primitives call; the concrete backend is
 * ne::neGLES_11 (System/src/OpenGL/neGLES11.{h,cpp}), which derives from ne::C_RENDER and wraps
 * OpenGL ES 1.1. These functions are not reimplementations of OpenGL — they wire the app's GL
 * calls, dispatched through that backend, exactly as the binary does.
 */

#pragma once

#include <cstdint>
#include <memory>

/**
 * @brief A column-major 4x4 matrix, laid out exactly like the 16-word blocks the binary builds on
 * the stack and hands to loadMatrix (glLoadMatrixf).
 */
struct neMatrix4 {
    float m[16]; /**< The 16 elements, indexed as `m[col * 4 + row]`. */
};

/**
 * @brief Build an identity rotation and scale with the given translation.
 * @param out The matrix to fill.
 * @param tx Translation along x.
 * @param ty Translation along y.
 * @param tz Translation along z.
 * @ghidraAddress 0x12af4
 */
void matrixSetTranslate(neMatrix4 &out, float tx, float ty, float tz);

/**
 * @brief Build a rotation about the Z axis (cosine and sine on the XY block).
 * @param out The matrix to fill.
 * @param radians The rotation angle, in radians.
 * @ghidraAddress 0x12b2c
 */
void matrixSetRotateZ(neMatrix4 &out, float radians);

/**
 * @brief Build a top-left-origin orthographic projection.
 *
 * m[0] = 2/w, m[5] = -2/h (Y flipped), m[10] = 1/(far-near), m[12] = -1, m[13] = 1,
 * m[14] = -near/(far-near).
 * @param out The matrix to fill.
 * @param width Front-buffer width, in pixels.
 * @param height Front-buffer height, in pixels.
 * @param near The near Z bound.
 * @param far The far Z bound.
 * @ghidraAddress 0x12ba8
 */
void matrixSetOrtho(neMatrix4 &out, float width, float height, float near, float far);

/**
 * @brief Multiply two column-major matrices into a third, using the NEON 4x4 multiply.
 * @param out Receives `a * b`; must not alias @p a or @p b.
 * @param a The left operand.
 * @param b The right operand.
 * @ghidraAddress 0x129ac
 */
void matrix4MultiplyInto(neMatrix4 &out, const neMatrix4 &a, const neMatrix4 &b);

/**
 * @brief Multiply in place: `inout = inout * rhs`. Copies @p inout, then calls
 * matrix4MultiplyInto().
 * @param inout The matrix to multiply and overwrite.
 * @param rhs The right operand.
 * @ghidraAddress 0x12958
 */
void matrix4Multiply(neMatrix4 &inout, const neMatrix4 &rhs);

namespace ne {

/**
 * @brief The abstract renderer: the polymorphic GL-wrapper interface every primitive dispatches
 * through.
 *
 * The concrete backend (ne::neGLES_11) overrides each method with a thin OpenGL ES 1.1 call. Only
 * the slots the engine's free functions actually call are declared here — the real ne::neGLES_11
 * vtable has more (its enum-typed GL wrappers live on the backend itself). Integer arguments carry
 * the engine's own ordinals (primitive mode, enable-cap, client-array, blend factor, tex-param),
 * which the backend maps to GL via its decoded tables. RTTI type ne::C_RENDER, type_info @
 * 0x12e2e0.
 */
class C_RENDER {
public:
    /**
     * @brief Destroy the renderer. Virtual so `delete` through this interface reaches the
     * backend.
     */
    virtual ~C_RENDER() = default;

    /**
     * @brief Query the device capabilities and activate the default GL state.
     *
     * Vtable slot +0x08. Slot +0x04 is the compiler-emitted deleting destructor (invoked by
     * neSetCurrentRenderer's `delete`), not a distinct shutdown method — the virtual destructor
     * above supplies both destructor slots, so initialize() lands at +0x08.
     */
    virtual void initialize() = 0;

    /**
     * @brief glViewport. Vtable slot +0x50.
     * @param x Left edge, in pixels.
     * @param y Bottom edge, in pixels.
     * @param w Width, in pixels.
     * @param h Height, in pixels.
     */
    virtual void setViewport(int x, int y, int w, int h) = 0;
    /**
     * @brief glMatrixMode followed by glLoadMatrixf. Vtable slot +0x54.
     * @param mode The engine's matrix-mode ordinal.
     * @param m The matrix to load.
     */
    virtual void loadMatrix(int mode, const neMatrix4 &m) = 0;
    /**
     * @brief glGenBuffers for a single buffer. Vtable slot +0x68.
     * @param outName Receives the generated buffer name.
     */
    virtual void genBuffer(unsigned &outName) = 0;
    /**
     * @brief glActiveTexture. Vtable slot +0x70.
     * @param unit The texture unit to select.
     */
    virtual void selectTextureUnit(int unit) = 0;
    /**
     * @brief glColorPointer. Vtable slot +0x78.
     * @param ptr The colour array.
     * @param stride The byte stride between colours.
     */
    virtual void colorPointer(const void *ptr, int stride) = 0;
    /**
     * @brief glVertexPointer. Vtable slot +0x88.
     * @param ptr The vertex array.
     * @param size Components per vertex.
     * @param stride The byte stride between vertices.
     */
    virtual void vertexPointer(const void *ptr, int size, int stride) = 0;
    /**
     * @brief glTexCoordPointer. Vtable slot +0x94.
     * @param ptr The texture-coordinate array.
     * @param stride The byte stride between coordinates.
     */
    virtual void texCoordPointer(const void *ptr, int stride) = 0;
    /**
     * @brief glBindBuffer against the element-array target. Vtable slot +0xac.
     * @param name The buffer name to bind.
     */
    virtual void bindElementBuffer(unsigned name) = 0;
    /**
     * @brief glBufferData. Vtable slot +0xb0.
     * @param data The data to upload.
     * @param size The upload size, in bytes.
     * @param usage The engine's buffer-usage ordinal.
     */
    virtual void bufferData(const void *data, int size, int usage) = 0;
    /**
     * @brief glGenTextures for a single texture. Vtable slot +0xb4.
     * @param outName Receives the generated texture name.
     */
    virtual void genTexture(unsigned &outName) = 0;
    /**
     * @brief glDeleteTextures, then clear the bind cache. Vtable slot +0xb8.
     * @param name The texture name to delete.
     */
    virtual void deleteTexture(unsigned name) = 0;
    /**
     * @brief glBindTexture, honouring the per-unit bind cache. Vtable slot +0xc0.
     * @param name The texture name to bind.
     */
    virtual void bindTexture(unsigned name) = 0;
    /**
     * @brief glTexParameteri. Vtable slot +0xc4.
     * @param type The engine's texture-parameter ordinal.
     * @param value The value to set.
     */
    virtual void applyTexParameter(int type, int value) = 0;
    /**
     * @brief glTexImage2D. Vtable slot +0xcc.
     * @param format The engine's pixel-format ordinal.
     * @param w Width, in texels.
     * @param h Height, in texels.
     * @param pixels The pixel data.
     */
    virtual void uploadTexture(int format, int w, int h, const void *pixels) = 0;
    /**
     * @brief glBlendFunc with the default blend equation. Vtable slot +0xd0.
     * @param src The engine's source-factor ordinal.
     * @param dst The engine's destination-factor ordinal.
     */
    virtual void setBlendFunc(int src, int dst) = 0;
    /**
     * @brief glBlendFunc with an explicit blend equation. Vtable slot +0xd4.
     * @param src The engine's source-factor ordinal.
     * @param dst The engine's destination-factor ordinal.
     * @param equation The blend equation.
     */
    virtual void setBlendFuncSeparate(int src, int dst, unsigned equation) = 0;
    /**
     * @brief glEnable or glDisable. Vtable slot +0xe0.
     * @param cap The engine's capability ordinal.
     * @param on YES to enable, NO to disable.
     */
    virtual void setEnable(int cap, bool on) = 0;
    /**
     * @brief glEnableClientState or glDisableClientState. Vtable slot +0xe4.
     * @param array The engine's client-array ordinal.
     * @param on YES to enable, NO to disable.
     */
    virtual void setClientArray(int array, bool on) = 0;
    /**
     * @brief glDrawArrays. Vtable slot +0x100.
     * @param mode The engine's primitive-mode ordinal.
     * @param count The vertex count.
     */
    virtual void drawArrays(int mode, int count) = 0;
    /**
     * @brief glDrawElements. Vtable slot +0x104.
     * @param mode The engine's primitive-mode ordinal.
     * @param count The index count.
     * @param offset The byte offset into the bound element buffer.
     */
    virtual void drawElements(int mode, int count, int offset) = 0;
};

} // namespace ne

/**
 * @brief The current renderer (Ghidra: g_pCurrentRenderer), lazily created by neEnsureRenderer().
 * @return The current renderer, or nullptr before one has been created.
 * @ghidraAddress 0x12c14
 */
ne::C_RENDER *neGetCurrentRenderer(void);
/**
 * @brief Install @p r as the current renderer, deleting the previous one.
 * @param r The renderer to install; ownership transfers.
 * @ghidraAddress 0x12c24
 */
void neSetCurrentRenderer(ne::C_RENDER *r);
/**
 * @brief Create the current renderer if there is not one already.
 * @ghidraAddress 0x12c4c
 */
void neEnsureRenderer(void);

/**
 * @brief A refcounted orthographic projection plus its pixel rectangle.
 *
 * A non-polymorphic value type (Ghidra: refcount at +0x00, the ortho matrix at +0x10, the
 * rectangle at +0x50).
 */
struct neViewport {
    int32_t refCount = 0; /**< Outstanding references; the viewport is deleted when it hits 0. */
    neMatrix4 proj{};     /**< The orthographic projection matrix. */
    int32_t x = 0;        /**< glViewport rectangle: left edge, in pixels. */
    int32_t y = 0;        /**< glViewport rectangle: bottom edge, in pixels. */
    int32_t w = 0;        /**< glViewport rectangle: width, in pixels. */
    int32_t h = 0;        /**< glViewport rectangle: height, in pixels. */
};

/**
 * @brief Build an orthographic viewport with the given projection size and glViewport rectangle.
 * @param width Projection width, in pixels.
 * @param height Projection height, in pixels.
 * @param x glViewport rectangle left edge.
 * @param y glViewport rectangle bottom edge.
 * @param w glViewport rectangle width.
 * @param h glViewport rectangle height.
 * @return The new viewport, carrying one reference.
 * @ghidraAddress 0x14bb4
 */
neViewport *neCreateOrthoViewport(float width, float height, int x, int y, int w, int h);

/**
 * @brief Retain @p vp as the app-side current viewport, releasing the previous one.
 * @param vp The viewport to install.
 * @ghidraAddress 0x14db8
 */
void neSetCurrentViewport(neViewport *vp);

/**
 * @brief If @p vp differs from the renderer's last-applied viewport, retain it, issue glViewport
 * and load its projection matrix.
 * @param r The renderer to apply the viewport to.
 * @param vp The viewport to apply.
 * @ghidraAddress 0x15e78
 */
void neApplyViewport(ne::C_RENDER *r, neViewport *vp);

/**
 * @brief The app-side current viewport, as set by neSetCurrentViewport().
 *
 * Used by the primitives and by neDrawText (neTextTexture.mm) to re-apply the projection each
 * draw.
 * @return The current viewport, or nullptr when none is set.
 */
neViewport *neGetCurrentViewport(void);

/**
 * @brief Release one reference of a viewport, deleting it on the last one.
 *
 * The shipped generic helper is type-erased over any refcounted engine object; in this subset
 * viewports are its only clients.
 * @param vp The viewport to release.
 * @ghidraAddress 0x14ba0
 */
void neReleaseRef(neViewport *vp);

// Render-state + immediate-mode primitives. Coordinates are GL_FLOAT pixels (already scaled by
// the caller); colours are 0..255 (a, r, g, b) and are stored premultiplied.

/**
 * @brief Reset to the default 2D draw state: apply the current viewport, load an identity model
 * matrix and disable every extra capability.
 * @ghidraAddress 0x14ef4
 */
void neApplyDefaultRenderState(void);

/**
 * @brief Draw a line between two points.
 * @param x0 First endpoint x, in pixels.
 * @param y0 First endpoint y, in pixels.
 * @param x1 Second endpoint x, in pixels.
 * @param y1 Second endpoint y, in pixels.
 * @param a Alpha, 0..255.
 * @param r Red, 0..255.
 * @param g Green, 0..255.
 * @param b Blue, 0..255.
 * @ghidraAddress 0x14de4
 */
void neDrawLine(float x0, float y0, float x1, float y1, int a, int r, int g, int b);
/**
 * @brief Draw a filled triangle.
 * @param x0 First vertex x, in pixels.
 * @param y0 First vertex y, in pixels.
 * @param x1 Second vertex x, in pixels.
 * @param y1 Second vertex y, in pixels.
 * @param x2 Third vertex x, in pixels.
 * @param y2 Third vertex y, in pixels.
 * @param a Alpha, 0..255.
 * @param r Red, 0..255.
 * @param g Green, 0..255.
 * @param b Blue, 0..255.
 * @ghidraAddress 0x15188
 */
void neDrawTriangle(
    float x0, float y0, float x1, float y1, float x2, float y2, int a, int r, int g, int b);
/**
 * @brief Draw a filled axis-aligned rectangle.
 * @param x Left edge, in pixels.
 * @param y Top edge, in pixels.
 * @param w Width, in pixels.
 * @param h Height, in pixels.
 * @param a Alpha, 0..255.
 * @param r Red, 0..255.
 * @param g Green, 0..255.
 * @param b Blue, 0..255.
 * @ghidraAddress 0x152ac
 */
void neDrawRect(float x, float y, float w, float h, int a, int r, int g, int b);
/**
 * @brief Draw a filled quadrilateral.
 * @param x0 First vertex x, in pixels.
 * @param y0 First vertex y, in pixels.
 * @param x1 Second vertex x, in pixels.
 * @param y1 Second vertex y, in pixels.
 * @param x2 Third vertex x, in pixels.
 * @param y2 Third vertex y, in pixels.
 * @param x3 Fourth vertex x, in pixels.
 * @param y3 Fourth vertex y, in pixels.
 * @param a Alpha, 0..255.
 * @param r Red, 0..255.
 * @param g Green, 0..255.
 * @param b Blue, 0..255.
 * @ghidraAddress 0x153e8
 */
void neDrawQuad(float x0,
                float y0,
                float x1,
                float y1,
                float x2,
                float y2,
                float x3,
                float y3,
                int a,
                int r,
                int g,
                int b);

/**
 * @brief Blit a textured, rotated, tinted quad. The core sprite path.
 *
 * The model matrix is `translate(x, y) [* rotateZ(-rotation)] * translate(-pivotX, -pivotY)`.
 * @param sprite Carries the ne::C_TEXTURE at +0x04; a null texture draws untextured.
 * @param x Draw x, in pixels.
 * @param y Draw y, in pixels.
 * @param width Draw width, in pixels.
 * @param height Draw height, in pixels.
 * @param u0 Sub-rect origin U, normalised 0..1 (stored as 0..32767 GL_SHORT).
 * @param v0 Sub-rect origin V, normalised 0..1 and flipped.
 * @param uSpan Sub-rect U extent, normalised 0..1.
 * @param vSpan Sub-rect V extent, normalised 0..1.
 * @param rotation Rotation about the pivot, in radians.
 * @param pivotX Pivot x offset, in pixels.
 * @param pivotY Pivot y offset, in pixels.
 * @param alpha Alpha, 0..255.
 * @param red Red, 0..255.
 * @param green Green, 0..255.
 * @param blue Blue, 0..255.
 * @param blendMode Selects GL_ONE, GL_SRC_ALPHA or an additive preset.
 * @param clipRect Four clip-plane values, or nullptr to leave the quad unclipped.
 * @ghidraAddress 0x15fb8
 */
void neDrawTexturedQuad(void *sprite,
                        int x,
                        int y,
                        int width,
                        int height,
                        float u0,
                        float v0,
                        float uSpan,
                        float vSpan,
                        float rotation,
                        int pivotX,
                        int pivotY,
                        int alpha,
                        int red,
                        int green,
                        int blue,
                        int blendMode,
                        const float *clipRect);

/**
 * @brief Cache-aware glTexParameteri: skips the call when @p value already matches the texture's
 * per-type cache.
 * @param tex The texture whose parameter cache to consult.
 * @param r The renderer to issue the call through.
 * @param type The engine's texture-parameter ordinal.
 * @param value The value to set.
 * @ghidraAddress 0x1885c
 */
void setTexParamCached(void *tex, ne::C_RENDER *r, int type, int value);

/**
 * @brief A polymorphic scene-graph transform node.
 *
 * A tree of per-node local and world matrices, linked into an owner list and a
 * parent/child/sibling ring. The full node vtable (draw and update slots) is outside this subset;
 * only the destructor is reconstructed, which is enough to make the type polymorphic.
 */
class neRenderNode {
public:
    /**
     * @brief Construct a detached node: every link points at itself.
     * @ghidraAddress 0x14c5c
     */
    neRenderNode();
    /**
     * @brief Destroy the node. The compiler-emitted deleting destructor is FUN_00014d70.
     * @ghidraAddress 0x14cf4
     */
    virtual ~neRenderNode();

    /**
     * @brief Detach this node from its parent's child ring.
     * @ghidraAddress 0x14d40
     */
    void unlink();

    neRenderNode *listNext = this;     /**< +0x04 Owner list; points at self when detached. */
    neRenderNode *listPrev = this;     /**< +0x08 Owner list; points at self when detached. */
    neRenderNode *parent = nullptr;    /**< +0x10 Parent node, or nullptr at the root. */
    neRenderNode *childHead = nullptr; /**< +0x14 First child, or nullptr when there are none. */
    neRenderNode *siblingNext = this;  /**< +0x18 Sibling ring; points at self when only child. */
    neRenderNode *siblingPrev = this;  /**< +0x1c Sibling ring; points at self when only child. */
    std::unique_ptr<uint8_t[]> colorBuffer; /**< +0x20 Per-node colour and vertex buffer. */
    neMatrix4 localMatrix{};                /**< +0x30 The node's own transform. */
    neMatrix4 worldMatrix{};                /**< +0x70 The cached world transform. */
    bool visible = true;                    /**< +0xb1 Whether the node and its subtree draw. */
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
