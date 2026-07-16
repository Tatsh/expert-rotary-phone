//
//  neRenderer.h
//  pop'n rhythmin
//
//  The engine-side renderer facade: the abstract renderer interface, the global
//  "current renderer", the immediate drawing primitives
//  (line/triangle/rect/quad/ textured-quad), the 4x4 matrix helpers, the
//  orthographic viewport object and the scene-graph transform node.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  Every primitive funnels through a single polymorphic renderer created by
//  neEnsureRenderer(). `neRenderer` is the abstract interface those primitives
//  call; the concrete backend is ne::neGLES_11
//  (System/src/OpenGL/neGLES11.{h,cpp}), which derives from neRenderer and
//  wraps OpenGL ES 1.1. These functions are NOT reimplementations of OpenGL —
//  they wire the app's GL calls, dispatched through that backend, exactly as
//  the binary does. The `// @ 0xADDR` / `Ghidra:` annotations map each function
//  to its address in the shipped binary.
//

#pragma once

#include <cstdint>

// ---------------------------------------------------------------------------
// 4x4 matrix (column-major, 16 floats) and its builders.
// ---------------------------------------------------------------------------

// Column-major 4x4, laid out exactly like the 16-word blocks the binary builds
// on the stack and hands to loadMatrix (glLoadMatrixf). Element m[col*4 + row].
struct neMatrix4 {
    float m[16];
};

// Ghidra: FUN_00012af4 — identity rotation/scale with translation (tx,ty,tz).
void matrixSetTranslate(neMatrix4 &out, float tx, float ty, float tz);

// Ghidra: FUN_00012b2c — rotation about Z by `radians` (cos/sin on the XY
// block).
void matrixSetRotateZ(neMatrix4 &out, float radians);

// Ghidra: FUN_00012ba8 — top-left-origin orthographic projection.
// `width`/`height` are the front-buffer pixel size; `near`/`far` bound Z.
// m[0]=2/w, m[5]=-2/h (Y flipped), m[10]=1/(far-near), m[12]=-1, m[13]=1,
// m[14]=-near/(far-near).
void matrixSetOrtho(neMatrix4 &out, float width, float height, float near, float far);

// Ghidra: FUN_000129ac — out = a * b (column-major). NEON 4x4 multiply.
void matrix4MultiplyInto(neMatrix4 &out, const neMatrix4 &a, const neMatrix4 &b);

// Ghidra: FUN_00012958 — in-place inout = inout * rhs (copies inout, then
// MultiplyInto).
void matrix4Multiply(neMatrix4 &inout, const neMatrix4 &rhs);

// ---------------------------------------------------------------------------
// The renderer interface.
// ---------------------------------------------------------------------------

// Abstract renderer: the polymorphic GL-wrapper interface every primitive
// dispatches through. The concrete backend (ne::neGLES_11) overrides each
// method with a thin OpenGL ES 1.1 call. Only the slots the engine's free
// functions actually call are declared here — the real ne::neGLES_11 vtable has
// more (its enum-typed GL wrappers live on the backend itself). Integer
// arguments carry the engine's own ordinals (primitive mode, enable-cap,
// client-array, blend factor, tex-param), which the backend maps to GL via its
// decoded tables.
class neRenderer {
public:
    virtual ~neRenderer() = default;

    // Lifecycle. Ghidra: initialize = vtbl +0x08 (QueryCaps, activate default GL
    // state). Slot +0x04 is the compiler-emitted deleting destructor (invoked by
    // neSetCurrentRenderer's `delete`), not a distinct shutdown method -- the virtual
    // destructor above supplies both dtor slots, so initialize lands at +0x08.
    virtual void initialize() = 0;

    virtual void setViewport(int x, int y, int w, int h) = 0; // +0x50 glViewport
    virtual void loadMatrix(int mode,
                            const neMatrix4 &m) = 0; // +0x54 glMatrixMode/glLoadMatrixf
    virtual void genBuffer(unsigned &outName) = 0;   // +0x68 glGenBuffers
    virtual void selectTextureUnit(int unit) = 0;    // +0x70 glActiveTexture
    virtual void colorPointer(const void *ptr,
                              int stride) = 0; // +0x78 glColorPointer
    virtual void vertexPointer(const void *ptr, int size,
                               int stride) = 0; // +0x88 glVertexPointer
    virtual void texCoordPointer(const void *ptr,
                                 int stride) = 0;      // +0x94 glTexCoordPointer
    virtual void bindElementBuffer(unsigned name) = 0; // +0xac glBindBuffer(ELEMENT)
    virtual void bufferData(const void *data, int size,
                            int usage) = 0;         // +0xb0 glBufferData
    virtual void genTexture(unsigned &outName) = 0; // +0xb4 glGenTextures
    virtual void deleteTexture(unsigned name) = 0;  // +0xb8 glDeleteTextures + clear bind cache
    virtual void bindTexture(unsigned name) = 0;    // +0xc0 glBindTexture (per-unit bind cache)
    virtual void applyTexParameter(int type,
                                   int value) = 0; // +0xc4 glTexParameteri
    virtual void uploadTexture(int format,
                               int w,
                               int h,
                               const void *pixels) = 0; // +0xcc glTexImage2D
    virtual void setBlendFunc(int src, int dst) = 0;    // +0xd0 glBlendFunc (default equation)
    virtual void setBlendFuncSeparate(int src, int dst,
                                      unsigned equation) = 0; // +0xd4
    virtual void setEnable(int cap, bool on) = 0;             // +0xe0 glEnable/glDisable
    virtual void setClientArray(int array,
                                bool on) = 0;         // +0xe4 glEnable/DisableClientState
    virtual void drawArrays(int mode, int count) = 0; // +0x100 glDrawArrays
    virtual void drawElements(int mode, int count,
                              int offset) = 0; // +0x104 glDrawElements
};

// The current renderer (Ghidra: g_pCurrentRenderer). Lazily created by
// neEnsureRenderer.
neRenderer *neGetCurrentRenderer(void);   // Ghidra: FUN_00012c14
void neSetCurrentRenderer(neRenderer *r); // Ghidra: FUN_00012c24
void neEnsureRenderer(void);              // Ghidra: FUN_00012c4c

// ---------------------------------------------------------------------------
// Orthographic viewport (a refcounted projection + glViewport rectangle).
// ---------------------------------------------------------------------------

// A refcounted ortho projection + pixel rectangle. Non-polymorphic value type
// (Ghidra: refcount at +0x00, the ortho matrix at +0x10, the rectangle at
// +0x50).
struct neViewport {
    int32_t refCount = 0;
    neMatrix4 proj{};                   // ortho projection matrix
    int32_t x = 0, y = 0, w = 0, h = 0; // glViewport rectangle
};

// Build an ortho viewport sized to `width`x`height` with glViewport rect
// (x,y,w,h); the returned viewport carries one reference. Ghidra: FUN_00014bb4.
neViewport *neCreateOrthoViewport(float width, float height, int x, int y, int w, int h);

// Retain `vp` as the app-side current viewport, releasing the previous one.
void neSetCurrentViewport(neViewport *vp); // Ghidra: FUN_00014db8

// If `vp` differs from the renderer's last-applied viewport, retain it, issue
// glViewport and load its projection matrix. Ghidra: FUN_00015e78.
void neApplyViewport(neRenderer *r, neViewport *vp);

// The app-side current viewport (set by neSetCurrentViewport). Used by the
// primitives and by neDrawText (neTextTexture.mm) to re-apply the projection
// each draw.
neViewport *neGetCurrentViewport(void);

// Release one reference of a viewport; on the last reference it is deleted. The
// shipped generic helper (FUN_00014ba0) is type-erased over any refcounted
// engine object; in this subset viewports are its only clients. Ghidra:
// FUN_00014ba0.
void neReleaseRef(neViewport *vp);

// ---------------------------------------------------------------------------
// Render-state + immediate-mode primitives. Coordinates are GL_FLOAT pixels
// (already scaled by the caller); colours are 0..255 (a,r,g,b) and are stored
// premultiplied.
// ---------------------------------------------------------------------------

// Reset to the default 2D draw state: apply the current viewport, load an
// identity model matrix and disable every extra cap. Ghidra: FUN_00014ef4.
void neApplyDefaultRenderState(void);

void neDrawLine(float x0, float y0, float x1, float y1, int a, int r, int g,
                int b); // FUN_00014de4
void neDrawTriangle(float x0,
                    float y0,
                    float x1,
                    float y1,
                    float x2,
                    float y2, // FUN_00015188
                    int a,
                    int r,
                    int g,
                    int b);
void neDrawRect(float x, float y, float w, float h, int a, int r, int g,
                int b); // FUN_000152ac
void neDrawQuad(float x0,
                float y0,
                float x1,
                float y1,
                float x2,
                float y2,
                float x3,
                float y3, // FUN_000153e8
                int a,
                int r,
                int g,
                int b);

// Blit a textured, rotated, tinted quad of pixel size (width x height) at
// (x,y). The texture sub-rect is (u0,v0)+(uSpan,vSpan) in normalized 0..1
// coords (V flipped, stored as 0..32767 GL_SHORT); the model matrix is
// translate(x,y) [* rotateZ(-rotation)] * translate(-pivotX,-pivotY). `sprite`
// carries the AepTexture at +0x04 (null => untextured). `blendMode` selects
// GL_ONE / GL_SRC_ALPHA / an additive preset; `clipRect` (or null) installs 4
// clip planes. Ghidra: FUN_00015fb8. Core sprite path.
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

// ---------------------------------------------------------------------------
// Texture cache helpers used by the renderer (defined alongside the
// primitives).
// ---------------------------------------------------------------------------

// Cache-aware glTexParameteri: skips the call when `value` already matches the
// texture's per-type cache. Ghidra: FUN_0001885c.
void setTexParamCached(void *tex, neRenderer *r, int type, int value);

// ---------------------------------------------------------------------------
// Scene-graph transform node (a child/sibling tree with per-node matrices).
// ---------------------------------------------------------------------------

// A polymorphic transform node: a tree of per-node local/world matrices linked
// into an owner list and a parent/child/sibling ring. The full node vtable
// (draw/update slots) is outside this subset; only the destructor is
// reconstructed, which is enough to make the type polymorphic. Ghidra: ctor
// FUN_00014c5c, dtor FUN_00014cf4.
class neRenderNode {
public:
    neRenderNode();          // Ghidra: FUN_00014c5c
    virtual ~neRenderNode(); // Ghidra: FUN_00014cf4 (+ compiler-emitted deleting
                             // dtor FUN_00014d70)

    // Detach this node from its parent's child ring. Ghidra: FUN_00014d40.
    void unlink();

    neRenderNode *listNext = this;     // +0x04 owner list (self when detached)
    neRenderNode *listPrev = this;     // +0x08
    neRenderNode *parent = nullptr;    // +0x10
    neRenderNode *childHead = nullptr; // +0x14 first child (null when none)
    neRenderNode *siblingNext = this;  // +0x18 sibling ring (self when only child)
    neRenderNode *siblingPrev = this;  // +0x1c
    uint8_t *colorBuffer = nullptr;    // +0x20 per-node colour/vertex buffer (delete[] on destroy)
    neMatrix4 localMatrix{};           // +0x30 node transform
    neMatrix4 worldMatrix{};           // +0x70 cached world transform
    bool visible = true;               // +0xb1
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
