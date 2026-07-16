//
//  neRenderer.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  engine-side renderer facade: the global current renderer, 4x4 matrix
//  helpers, the orthographic viewport, the immediate-mode primitives and the
//  scene-graph transform node. All GL is issued through the ne::neGLES_11
//  backend (System/src/OpenGL/neGLES11.*) via the neRenderer virtual interface;
//  this file never reimplements GL, it wires it.
//

#include <cmath>
#include <cstdint>

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>

#include "AepTexture.h" // AepTexture::name() for the sprite blit
#include "neDebugLog.h"
#include "neGLES11.h" // ne::neGLES_11 concrete backend
#include "neRenderer.h"

// ---------------------------------------------------------------------------
// Globals (Ghidra data symbols).
// ---------------------------------------------------------------------------

static neRenderer *g_pCurrentRenderer = nullptr; // Ghidra: g_pCurrentRenderer
static neViewport *g_pCurrentViewport = nullptr; // Ghidra: g_pCurrentViewport (app-side)
static neViewport *g_pAppliedViewport = nullptr; // Ghidra: DAT_00188454 (renderer-side)

// @complete
neViewport *neGetCurrentViewport(void) {
    return g_pCurrentViewport;
}

// ---------------------------------------------------------------------------
// 4x4 matrix helpers (column-major, element m[col*4 + row]).
// ---------------------------------------------------------------------------

// Ghidra: FUN_00012af4.
// @complete
void matrixSetTranslate(neMatrix4 &out, float tx, float ty, float tz) {
    out.m[0] = 1.0f;
    out.m[1] = 0.0f;
    out.m[2] = 0.0f;
    out.m[3] = 0.0f;
    out.m[4] = 0.0f;
    out.m[5] = 1.0f;
    out.m[6] = 0.0f;
    out.m[7] = 0.0f;
    out.m[8] = 0.0f;
    out.m[9] = 0.0f;
    out.m[10] = 1.0f;
    out.m[11] = 0.0f;
    out.m[12] = tx;
    out.m[13] = ty;
    out.m[14] = tz;
    out.m[15] = 1.0f;
}

// Ghidra: FUN_00012b2c — cos/sin fill the upper-left 2x2 (column-major).
// @complete
void matrixSetRotateZ(neMatrix4 &out, float radians) {
    float c = std::cos(radians);
    float s = std::sin(radians);
    out.m[0] = c;
    out.m[1] = s;
    out.m[2] = 0.0f;
    out.m[3] = 0.0f;
    out.m[4] = -s;
    out.m[5] = c;
    out.m[6] = 0.0f;
    out.m[7] = 0.0f;
    out.m[8] = 0.0f;
    out.m[9] = 0.0f;
    out.m[10] = 1.0f;
    out.m[11] = 0.0f;
    out.m[12] = 0.0f;
    out.m[13] = 0.0f;
    out.m[14] = 0.0f;
    out.m[15] = 1.0f;
}

// Ghidra: FUN_00012ba8 — top-left-origin ortho. (The decompiler drops the 2.0f
// numerator on m[0]; m[5] keeps its -2.0f, confirming the standard form.)
// @complete
void matrixSetOrtho(neMatrix4 &out, float width, float height, float near, float far) {
    float depth = far - near;
    out.m[0] = 2.0f / width;
    out.m[1] = 0.0f;
    out.m[2] = 0.0f;
    out.m[3] = 0.0f;
    out.m[4] = 0.0f;
    out.m[5] = -2.0f / height;
    out.m[6] = 0.0f;
    out.m[7] = 0.0f;
    out.m[8] = 0.0f;
    out.m[9] = 0.0f;
    out.m[10] = 1.0f / depth;
    out.m[11] = 0.0f;
    out.m[12] = -1.0f;
    out.m[13] = 1.0f;
    out.m[14] = -near / depth;
    out.m[15] = 1.0f;
}

// Ghidra: FUN_000129ac — out = a * b (column-major). The binary uses NEON; the
// math is the plain 4x4 product.
// @complete
void matrix4MultiplyInto(neMatrix4 &out, const neMatrix4 &a, const neMatrix4 &b) {
    for (int col = 0; col < 4; ++col) {
        for (int row = 0; row < 4; ++row) {
            out.m[col * 4 + row] =
                a.m[0 * 4 + row] * b.m[col * 4 + 0] + a.m[1 * 4 + row] * b.m[col * 4 + 1] +
                a.m[2 * 4 + row] * b.m[col * 4 + 2] + a.m[3 * 4 + row] * b.m[col * 4 + 3];
        }
    }
}

// Ghidra: FUN_00012958 — inout = inout * rhs (copies inout to a temp first).
// @complete
void matrix4Multiply(neMatrix4 &inout, const neMatrix4 &rhs) {
    neMatrix4 tmp = inout;
    matrix4MultiplyInto(inout, tmp, rhs);
}

// ---------------------------------------------------------------------------
// Renderer lifecycle.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00012c14.
// @complete
neRenderer *neGetCurrentRenderer(void) {
    return g_pCurrentRenderer;
}

// Ghidra: FUN_00012c24 — swap the current renderer, destroying the previous one.
// The binary invokes the old renderer's vtable slot +0x04, which is the compiler-
// emitted deleting destructor (b.w -> operator delete @ 0x12feb8) -- i.e. `delete cur`;
// there is no distinct "shutdown" virtual. The engine builds one renderer and never
// replaces it, so this branch is not exercised in practice.
// @complete
void neSetCurrentRenderer(neRenderer *r) {
    if (g_pCurrentRenderer != nullptr && g_pCurrentRenderer != r) {
        delete g_pCurrentRenderer;
    }
    g_pCurrentRenderer = r;
}

// Ghidra: FUN_00012c4c — create the GL ES 1.1 backend on first use and activate
// its GL state. (Ghidra: operator new(0x224) + neGLESRenderer_ctor
// FUN_00012c78; the ctor's cache/state seeding is now the neGLES_11
// constructor's job.)
// @complete
void neEnsureRenderer(void) {
    if (neGetCurrentRenderer() != nullptr) {
        return;
    }
    neSetCurrentRenderer(new ne::neGLES_11());
    neGetCurrentRenderer()->initialize();
}

// Ghidra: FUN_00014ba0 — refcount at +0x00; on the last reference the viewport
// is freed.
// @complete
void neReleaseRef(neViewport *vp) {
    if (--vp->refCount == 0) {
        delete vp;
    }
}

// ---------------------------------------------------------------------------
// Viewport.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00014bb4 — refcount starts at 1 (the caller's
// neSetCurrentViewport retains a second reference, then releases this creation
// reference).
// @complete
neViewport *neCreateOrthoViewport(float width, float height, int x, int y, int w, int h) {
    neViewport *vp = new neViewport();
    vp->refCount = 1;
    vp->x = x;
    vp->y = y;
    vp->w = w;
    vp->h = h;
    // near = 0, far = 1.0 (Ghidra: matrixSetOrtho(vp+0x10, width, height, 0,
    // 0x3f800000)).
    matrixSetOrtho(vp->proj, width, height, 0.0f, 1.0f);
    return vp;
}

// Ghidra: FUN_00014db8.
// @complete
void neSetCurrentViewport(neViewport *vp) {
    if (g_pCurrentViewport == vp) {
        return;
    }
    if (g_pCurrentViewport != nullptr) {
        neReleaseRef(g_pCurrentViewport);
    }
    ++vp->refCount;
    g_pCurrentViewport = vp;
}

// Ghidra: FUN_00015e78.
// @complete
void neApplyViewport(neRenderer *r, neViewport *vp) {
    if (g_pAppliedViewport == vp) {
        return;
    }
    if (g_pAppliedViewport != nullptr) {
        neReleaseRef(g_pAppliedViewport);
    }
    ++vp->refCount;
    g_pAppliedViewport = vp;
    r->setViewport(vp->x, vp->y, vp->w, vp->h);
    r->loadMatrix(1, vp->proj); // projection
    if (NE_DBG_FIRST(60)) {
        neDebugLog("neApplyViewport rect=[%d,%d,%d,%d] proj[0]=%.4f proj[5]=%.4f proj[12]=%.4f "
                   "proj[13]=%.4f",
                   vp->x,
                   vp->y,
                   vp->w,
                   vp->h,
                   vp->proj.m[0],
                   vp->proj.m[5],
                   vp->proj.m[12],
                   vp->proj.m[13]);
    }
}

// ---------------------------------------------------------------------------
// Render state + immediate-mode primitives.
// ---------------------------------------------------------------------------

// One interleaved vertex: 16.16 fixed-point position + premultiplied RGBA8.
// Stride 12, position size 2 (glVertexPointer), colour at +8 (glColorPointer).
// Ghidra: built inline on the stack by each neDraw* primitive. Positions are
// GL_FLOAT (the backend's glVertexPointer uses type 0x1406); each primitive
// receives already-scaled float coordinates and stores them verbatim.
struct neColorVertex {
    float x;
    float y;
    uint32_t rgba;
};

// Ghidra: colours arrive as 0..255 (a,r,g,b); rgb is premultiplied by alpha/255
// (DAT = 255.0f) and stored [R,G,B,A]. FixedToFP/FPToFixed here are int<->float
// conversions.
// @complete
static uint32_t nePremultRGBA(int a, int r, int g, int b) {
    float f = static_cast<float>(a) / 255.0f;
    uint8_t rr = static_cast<uint8_t>(static_cast<int>(static_cast<float>(r) * f));
    uint8_t gg = static_cast<uint8_t>(static_cast<int>(static_cast<float>(g) * f));
    uint8_t bb = static_cast<uint8_t>(static_cast<int>(static_cast<float>(b) * f));
    return static_cast<uint32_t>(rr) | (static_cast<uint32_t>(gg) << 8) |
           (static_cast<uint32_t>(bb) << 16) | (static_cast<uint32_t>(a) << 24);
}

// Shared tail of the untextured primitives: bind the colour vertex arrays,
// reset to the default 2D state, and draw. Ghidra: the identical block ending
// each of FUN_00014de4 / FUN_00015188 / FUN_000152ac / FUN_000153e8.
// @complete
static void neDrawColorArray(const neColorVertex *verts, int mode, int count) {
    neRenderer *r = neGetCurrentRenderer();
    r->setClientArray(5, true); // texcoord array on
    r->vertexPointer(&verts[0].x, 2, sizeof(neColorVertex));
    r->setClientArray(2, false);
    r->setClientArray(0, true);
    r->colorPointer(&verts[0].rgba, sizeof(neColorVertex));
    neApplyDefaultRenderState();
    r->drawArrays(mode, count);
}

// Ghidra: FUN_00014de4 — primitive 3 (GL_LINES), 2 vertices.
// @complete
void neDrawLine(float x0, float y0, float x1, float y1, int a, int r, int g, int b) {
    uint32_t c = nePremultRGBA(a, r, g, b);
    neColorVertex v[2] = {{x0, y0, c}, {x1, y1, c}};
    neDrawColorArray(v, 3, 2);
}

// Ghidra: FUN_00015188 — primitive 6 (GL_TRIANGLES), 3 vertices.
// @complete
void neDrawTriangle(
    float x0, float y0, float x1, float y1, float x2, float y2, int a, int r, int g, int b) {
    uint32_t c = nePremultRGBA(a, r, g, b);
    neColorVertex v[3] = {{x0, y0, c}, {x1, y1, c}, {x2, y2, c}};
    neDrawColorArray(v, 6, 3);
}

// Ghidra: FUN_000152ac — primitive 4 (GL_TRIANGLE_STRIP) rectangle from (x,y)
// size (w,h): (x,y),(x+w,y),(x,y+h),(x+w,y+h). The binary adds w/h with
// vadd.f32, so the corner arithmetic is in floating point.
// @complete
void neDrawRect(float x, float y, float w, float h, int a, int r, int g, int b) {
    uint32_t c = nePremultRGBA(a, r, g, b);
    neColorVertex v[4] = {
        {x, y, c},
        {x + w, y, c},
        {x, y + h, c},
        {x + w, y + h, c},
    };
    neDrawColorArray(v, 4, 4);
}

// Ghidra: FUN_000153e8 — primitive 4 (GL_TRIANGLE_STRIP), four explicit
// corners.
// @complete
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
                int b) {
    uint32_t c = nePremultRGBA(a, r, g, b);
    neColorVertex v[4] = {{x0, y0, c}, {x1, y1, c}, {x2, y2, c}, {x3, y3, c}};
    neDrawColorArray(v, 4, 4);
}

// Ghidra: FUN_00014ef4 — apply the current viewport, load an identity model
// matrix and force every enable-cap to its 2D default (only BLEND stays on).
// @complete
void neApplyDefaultRenderState(void) {
    neRenderer *r = neGetCurrentRenderer();
    neApplyViewport(r, g_pCurrentViewport);

    neMatrix4 model;
    matrixSetTranslate(model, 0.0f, 0.0f, 0.0f);
    r->loadMatrix(0, model); // modelview

    r->setEnable(0x22, false); // GL_TEXTURE_2D off
    r->setClientArray(6, false);
    r->setClientArray(1, false);
    r->setBlendFunc(1, 5); // GL_ONE, GL_ONE_MINUS_SRC_ALPHA

    // Every remaining cap ordinal to off, except BLEND (1) which stays enabled.
    // This is the exact ordinal sequence the decompiled function issues.
    static const int kCaps[] = {
        3,  4,  5,  6,  7,  8,  0,  1,  2,  9,  10, 11, 12, 13, 14, 15, 16,   17,
        18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 0x23,
    };
    for (int cap : kCaps) {
        r->setEnable(cap, cap == 1);
    }
}

// ---------------------------------------------------------------------------
// Renderer texture helpers.
// ---------------------------------------------------------------------------

// Ghidra: FUN_0001885c — skip glTexParameteri when the value is already cached
// on the texture; the setter itself is dispatched on the renderer (+0xc4). The
// cache is the AepTexture's own 4-entry tex-param array (Ghidra: tex+0x30),
// seeded by neTextureUpload to the values it applies at upload time.
// @complete
void setTexParamCached(void *tex, neRenderer *r, int type, int value) {
    int &slot = static_cast<AepTexture *>(tex)->m_texParamCache[type];
    if (slot == value) {
        return;
    }
    r->applyTexParameter(type, value);
    slot = value;
}

// FUN_0001342c was previously reconstructed here as a redundant-caching
// `neBindTexture`, but it is not a texture bind at all: it tail-calls
// glVertexPointer(size, 0x1406 = GL_FLOAT, stride, ptr) after a redundant
// (ptr, size, stride) cache, i.e. it is a caching variant of the vertex-array
// setter (see neGLES_11::vertexPointer). It has no callers in the binary, and
// the real texture bind is neGLES_11::bindTexture (glBindTexture, vtable +0xc0),
// so the mislabelled helper is dropped rather than kept as dead code.

// ---------------------------------------------------------------------------
// Textured sprite blit.
// ---------------------------------------------------------------------------

// One textured vertex: GL_FLOAT position, GL_SHORT-normalized UV, premult RGBA8.
// Stride 16; position size 2 (+0x00), UV (+0x08), colour (+0x0c). Ghidra: built
// on the stack (local_a4 block) by FUN_00015fb8; the backend specifies the
// position array as GL_FLOAT (0x1406), so the corners must be stored as floats —
// storing ints here would be reinterpreted as near-zero denormals and collapse
// every quad to the origin.
struct neTexVertex {
    float x;
    float y;
    int16_t u;
    int16_t v;
    uint32_t rgba;
};

// View of the sprite command the blit reads: refcount (+0x00), the AepTexture
// (+0x04, null => untextured), and the 4 tex-param values (+0x08). Ghidra:
// fields at param_1+4/+8.
struct neSpriteView {
    int32_t refCount;     // +0x00
    void *texture;        // +0x04 AepTexture* (GL name at texture+0x18)
    int32_t texParams[4]; // +0x08 mag/min/wrapS/wrapT
};

// @complete
static int16_t neNormUV(float t) {
    return static_cast<int16_t>(t * 32767.0f); // DAT_0001630c
}

// Ghidra: FUN_00015fb8.
// @complete
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
                        const float *clipRect) {
    neSpriteView *s = static_cast<neSpriteView *>(sprite);
    NE_DBG((void)glGetError()); // clear accumulated error so the quadGL probe isolates this draw
    uint32_t c = nePremultRGBA(alpha, red, green, blue);

    // UV sub-rect (V flipped for GL's bottom-left origin), normalized to
    // GL_SHORT.
    int16_t uL = neNormUV(u0), uR = neNormUV(u0 + uSpan);
    int16_t vT = neNormUV(1.0f - v0), vB = neNormUV(1.0f - (v0 + vSpan));

    // Corners: (0,0),(w,0),(0,h),(w,h) — the model matrix positions/rotates the
    // quad.
    const float fw = static_cast<float>(width);
    const float fh = static_cast<float>(height);
    neTexVertex verts[4] = {
        {0.0f, 0.0f, uL, vT, c},
        {fw, 0.0f, uR, vT, c},
        {0.0f, fh, uL, vB, c},
        {fw, fh, uR, vB, c},
    };

    neRenderer *r = neGetCurrentRenderer();

    if (NE_DBG_FIRST(600)) {
        const neViewport *vp = g_pCurrentViewport;
        neDebugLog(
            "quad sprite=%p tex=%p glName=%u xy=(%d,%d) wh=(%d,%d) uv=(%d,%d,%d,%d) "
            "rot=%.2f pivot=(%d,%d) argb=(%d,%d,%d,%d) blend=%d clip=%p vp=[%d,%d,%d,%d] r=%p",
            sprite,
            s->texture,
            s->texture ? static_cast<AepTexture *>(s->texture)->name() : 0,
            x,
            y,
            width,
            height,
            uL,
            uR,
            vT,
            vB,
            rotation,
            pivotX,
            pivotY,
            alpha,
            red,
            green,
            blue,
            blendMode,
            (const void *)clipRect,
            vp ? vp->x : -1,
            vp ? vp->y : -1,
            vp ? vp->w : -1,
            vp ? vp->h : -1,
            (void *)r);
    }

    // Model matrix: translate(x,y) [* rotateZ(-rotation)] * translate(-pivot).
    neApplyViewport(r, g_pCurrentViewport);
    neMatrix4 model;
    matrixSetTranslate(model, static_cast<float>(x), static_cast<float>(y), 0.0f);
    if (rotation != 0.0f) {
        neMatrix4 rot;
        matrixSetRotateZ(rot, -rotation);
        matrix4Multiply(model, rot);
    }
    neMatrix4 pivot;
    matrixSetTranslate(pivot, static_cast<float>(-pivotX), static_cast<float>(-pivotY), 0.0f);
    matrix4Multiply(model, pivot);
    r->loadMatrix(0, model);

    // Vertex + colour arrays.
    r->setClientArray(5, true);
    r->vertexPointer(&verts[0].x, 2, sizeof(neTexVertex));
    r->setClientArray(2, false);
    r->setClientArray(0, true);
    r->colorPointer(&verts[0].rgba, sizeof(neTexVertex));

    // Texture (or flat colour).
    if (s->texture == nullptr) {
        r->setEnable(0x22, false); // GL_TEXTURE_2D off
    } else {
        GLuint name = static_cast<AepTexture *>(s->texture)->name(); // AepTexture +0x18
        r->setEnable(0x22, true);
        r->bindTexture(name);
        r->setClientArray(4, true);
        r->texCoordPointer(&verts[0].u, sizeof(neTexVertex));
        for (int i = 0; i < 4; ++i) {
            setTexParamCached(s->texture, r, i, s->texParams[i]);
        }
    }

    r->setEnable(6, false);
    r->setEnable(1, false);

    // Blend mode: 1 = additive-on-white, 0 = straight alpha, else additive
    // preset.
    if (blendMode == 1) {
        r->setBlendFunc(1, 1);
    } else if (blendMode == 0) {
        r->setBlendFunc(1, 5);
    } else {
        r->setBlendFuncSeparate(4, 1, 0x800b); // GL_FUNC_REVERSE_SUBTRACT_OES
    }

    // Clip rect -> 4 clip planes (rotated with the quad when rotation != 0).
    if (clipRect == nullptr) {
        r->setEnable(3, false);
        r->setEnable(4, false);
        r->setEnable(5, false);
        r->setEnable(6, false);
    } else {
        // Plane equations bound the rect (left/top/right/bottom) in the quad's
        // pre-transform (local) space: the screen-space clip rect is mapped back
        // through the model's net translate (x - pivot), so left = clipRect[0] - (x
        // - pivotX). Ghidra rotates each equation by `rotation` before
        // glClipPlanef.
        float left = static_cast<float>(clipRect[0] - (x - pivotX));
        float top = static_cast<float>(clipRect[1] - (y - pivotY));
        float right = left + static_cast<float>(clipRect[2]);
        float bottom = top + static_cast<float>(clipRect[3]);
        // Plane-to-slot assignment matches the binary exactly (each equation is
        // built on the stack and passed to glClipPlanef in this order): PLANE0 is
        // the top edge (y >= top), PLANE1 the bottom (y <= bottom), PLANE2 the
        // left (x >= left), and PLANE3 the right (x <= right). All four are
        // enabled together, so the clip region is their intersection irrespective
        // of slot, but the slot order is kept faithful to Ghidra.
        GLfloat pTop[4] = {0.0f, 1.0f, 0.0f, -top};
        GLfloat pBottom[4] = {0.0f, -1.0f, 0.0f, bottom};
        GLfloat pLeft[4] = {1.0f, 0.0f, 0.0f, -left};
        GLfloat pRight[4] = {-1.0f, 0.0f, 0.0f, right};
        // Ghidra: when the sprite is rotated the binary rotates each plane's normal
        // by +rotation (cos/sin of the positive angle) and re-derives the offset
        // about the pivot: a' = c*a - s*b, b' = s*a + c*b, d' = d + pivotX*(a-a') +
        // pivotY*(b-b'). (The decompiler dropped this whole FloatVector* /
        // _cos/_sin block.)
        if (rotation != 0.0f) {
            const float c = cosf(rotation), s = sinf(rotation);
            const float px = static_cast<float>(pivotX), py = static_cast<float>(pivotY);
            GLfloat *planes[4] = {pTop, pBottom, pLeft, pRight};
            for (GLfloat *p : planes) {
                const float a2 = c * p[0] - s * p[1];
                const float b2 = s * p[0] + c * p[1];
                p[3] = p[3] + px * (p[0] - a2) + py * (p[1] - b2);
                p[0] = a2;
                p[1] = b2;
            }
        }
        glClipPlanef(GL_CLIP_PLANE0, pTop);
        glClipPlanef(GL_CLIP_PLANE1, pBottom);
        glClipPlanef(GL_CLIP_PLANE2, pLeft);
        glClipPlanef(GL_CLIP_PLANE3, pRight);
        r->setEnable(3, true);
        r->setEnable(4, true);
        r->setEnable(5, true);
        r->setEnable(6, true);
    }

    // Reset the remaining caps (same ordinal tail as neApplyDefaultRenderState).
    static const int kCaps[] = {
        7,  8,  0,  1,  2,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18,   19,
        20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 0x23,
    };
    for (int cap : kCaps) {
        r->setEnable(cap, cap == 1);
    }

    r->drawArrays(4, 4); // GL_TRIANGLE_STRIP

    if (NE_DBG_FIRST(40)) {
        GLenum err = glGetError();
        GLboolean texEnabled = glIsEnabled(GL_TEXTURE_2D);
        GLboolean blendEnabled = glIsEnabled(GL_BLEND);
        GLboolean depthEnabled = glIsEnabled(GL_DEPTH_TEST);
        GLint boundTex = 0, arrBuf = -1, elemBuf = -1;
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &boundTex);
        glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &arrBuf);
        glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &elemBuf);
        GLint viewport[4] = {0, 0, 0, 0};
        glGetIntegerv(GL_VIEWPORT, viewport);
        GLfloat proj[16] = {0}, modelview[16] = {0};
        glGetFloatv(GL_PROJECTION_MATRIX, proj);
        glGetFloatv(GL_MODELVIEW_MATRIX, modelview);
        GLint blendSrc = 0, blendDst = 0;
        glGetIntegerv(GL_BLEND_SRC, &blendSrc);
        glGetIntegerv(GL_BLEND_DST, &blendDst);
        neDebugLog("quadGL glErr=0x%x texEnabled=%d blend=%d(src=0x%x dst=0x%x) depth=%d "
                   "boundTex=%d arrBuf=%d elemBuf=%d vp=[%d,%d,%d,%d] "
                   "verts=[(%.1f,%.1f)(%.1f,%.1f)(%.1f,%.1f)(%.1f,%.1f)] "
                   "proj[0,5,12,13]=%.4f,%.4f,%.2f,%.2f mv[12,13]=%.2f,%.2f",
                   (unsigned)err,
                   (int)texEnabled,
                   (int)blendEnabled,
                   (unsigned)blendSrc,
                   (unsigned)blendDst,
                   (int)depthEnabled,
                   boundTex,
                   arrBuf,
                   elemBuf,
                   viewport[0],
                   viewport[1],
                   viewport[2],
                   viewport[3],
                   verts[0].x,
                   verts[0].y,
                   verts[1].x,
                   verts[1].y,
                   verts[2].x,
                   verts[2].y,
                   verts[3].x,
                   verts[3].y,
                   proj[0],
                   proj[5],
                   proj[12],
                   proj[13],
                   modelview[12],
                   modelview[13]);
    }
}

// ---------------------------------------------------------------------------
// Scene-graph transform node.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00014c5c — a fresh node: empty owner list, no parent, identity
// matrices, visible.
// @complete
neRenderNode::neRenderNode() {
    matrixSetTranslate(localMatrix, 0.0f, 0.0f,
                       0.0f); // Ghidra: identity via FUN_00012acc
    matrixSetTranslate(worldMatrix, 0.0f, 0.0f, 0.0f);
}

// Ghidra: FUN_00014d40 — detach a node from its parent's child ring.
// @complete
void neRenderNode::unlink() {
    if (parent == nullptr) {
        return;
    }
    neRenderNode *prev = siblingPrev;
    if (parent->childHead == this) {
        parent->childHead = (prev == this) ? nullptr : prev;
    }
    prev->siblingNext = siblingNext;
    siblingNext->siblingPrev = prev;
    parent = nullptr;
    siblingNext = this;
    siblingPrev = this;
}

// Ghidra: FUN_00014cf4 — unlink from the owner list and from the parent,
// recursively detach all children, then drop the colour buffer. (The
// compiler-emitted deleting destructor FUN_00014d70 is just `delete node;`.)
// @complete
neRenderNode::~neRenderNode() {
    listPrev->listNext = listNext;
    listNext->listPrev = listPrev;
    if (parent != nullptr) {
        unlink();
    }
    while (childHead != nullptr) {
        childHead->unlink();
    }
    delete[] colorBuffer;
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
