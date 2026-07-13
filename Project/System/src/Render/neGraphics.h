//
//  neGraphics.h
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  render/input manager singleton (@ DAT_00188384, operator_new(0x8c)): it owns
//  the device content scale and the pool of live touch points. The GL view
//  (neGLView) feeds touches in; the play-judge loop reads them back out.
//
//  PROVISIONAL name: the exact class name is not recovered from RTTI, so this
//  keeps the System-layer "ne" convention. The bridge accessor FUN_00012358
//  simply returns the DAT_00188384 global (see HANDOFF.md — Engine).
//

#pragma once

// One tracked touch. The manager pre-allocates a fixed pool of these
// (operator_new(0x30) = 48 bytes each) at init and mutates them in place as
// touches begin/move/end; slots are never freed. All coordinates are 16.16
// fixed-point in *pixels* (the raw point value from UIKit is multiplied by the
// content scale on the way in). Ghidra: sentinel-initialised by FUN_0001243c.
struct neTouchPoint {
    int id;                 // +0x00 rolling id assigned at began (-1 when never used)
    int startX;             // +0x04 down point                     (pair A)
    int startY;             // +0x08
    int x;                  // +0x0c current point (the match key on move/end) (pair B)
    int y;                  // +0x10
    int prevX;              // +0x14 previous point                 (pair C)
    int prevY;              // +0x18
    int downX;              // +0x1c copy of the down point, left untouched by move (pair D)
    int downY;              // +0x20
    int width;              // +0x24 view width at began (fixed); 0x7fffffff when free
    int height;             // +0x28 view height
    unsigned char valid;    // +0x2c allocated-slot marker (init 1, always set)
    unsigned char released; // +0x2d set on end/clear, cleared on began
    unsigned char pad[2];   // +0x2e..+0x2f (record rounded up to 0x30)
};

// C-ABI accessors the play-judge loop uses on the raw manager pointer. Ghidra:
// FUN_000124bc reads +0x80 (touch count); FUN_000124c4 reads the +0x00 pool
// array (i-th touch pointer). Thin wrappers over the class members; declared
// here (ahead of the class) so the friend declarations below bind to these
// C-linkage functions.
class neGraphics;
extern "C" int NEGraphics_activeTouchCount(const neGraphics *g); // Ghidra: FUN_000124bc
extern "C" const neTouchPoint *NEGraphics_touchAt(const neGraphics *g,
                                                  int i); // Ghidra: FUN_000124c4

// Render/input manager. Singleton created lazily by configure() at launch.
class neGraphics {
public:
    static neGraphics &shared();               // Ghidra: FUN_00012358 (returns DAT_00188384)
    static void configure(float contentScale); // Ghidra: NEGraphics_configure (FUN_00012368)

    // Touch plumbing. neGLView forwards UIKit touches here as 16.16 fixed-point
    // point coordinates; this scales them to pixels and records them. The
    // play-judge loop (FUN_0002f1f8) reads the pool back via shared().
    void touchBegan(int x, int y, int width, int height); // Ghidra: FUN_000124f8
    void touchMoved(int x, int y, int prevX, int prevY);  // Ghidra: FUN_00012588
    void touchEnded(int x, int y, int prevX, int prevY);  // Ghidra: FUN_000125ec
    void clearTouches();                                  // Ghidra: FUN_00012698

    int activeTouchCount() const {
        return m_touchCount;
    } // +0x80
    const neTouchPoint *touchAt(int i) const {
        return m_touches[i];
    }
    float contentScale() const {
        return m_contentScale;
    } // +0x88

    // Find a recorded touch by its rolling id, or nullptr. The play-judge loop
    // uses this to tell whether the finger that started a hold is still down.
    const neTouchPoint *findTouchById(int id) const; // Ghidra: FUN_000124cc

    // Point-in-rect test primitive: true when (x,y) lies inside the rect
    // (rx,ry,rw,rh). Ghidra: FUN_0002d974 — the same primitive the bridge's
    // higher-level neEngine::menuButtonHit(gfx,touchId,rect,enable) wraps; the
    // music-select task calls it directly with pre-scaled corners.
    static bool pointInRect(int x, int y, int rx, int ry, int rw, int rh);

private:
    neGraphics(); // Ghidra: FUN_0001243c (allocates the pool)
    neGraphics(const neGraphics &) = delete;
    neGraphics &operator=(const neGraphics &) = delete;

    static const int kMaxTouches = 32; // pool size (loop count 0x20 in FUN_0001243c)

    neTouchPoint *m_touches[kMaxTouches]; // +0x00..+0x7c pool pointers
    int m_touchCount = 0;                 // +0x80 touches recorded this frame
    int m_nextTouchId = 0;                // +0x84 rolling id counter
    float m_contentScale = 1.0f;          // +0x88 device content scale

    friend int NEGraphics_activeTouchCount(const neGraphics *g);
    friend const neTouchPoint *NEGraphics_touchAt(const neGraphics *g, int i);
};

// ---- free text / geometry helpers (siblings of neGraphics::pointInRect) ----
// These are plain C-linkage-shaped free functions in the binary (no `this`);
// they live beside the pointInRect primitive as the engine's small layout
// helpers.

// Count the '\n'-separated lines in a C string. Empty string -> 0; a trailing
// newline is NOT counted as an extra empty line. Ghidra: FUN_0002d858.
int countLines(const char *text);

// 2D range containment over eight floats. Recovered predicate (FUN_0002d9dc):
// true when the pair (x1,x2) is at/under the upper bounds (xMax1,xMax2) AND the
// pair (y1,y2) is at/above the lower bounds (yMin1,yMin2) — i.e. two corners
// inside a half-open box.
bool isWithinRange2D(
    float x1, float y1, float x2, float y2, float yMin1, float xMax1, float yMin2, float xMax2);

#ifdef __OBJC__
// Character index at which `text` first fills `columnWidth` display columns,
// counting a full-width (CJK / non-halfwidth) glyph as 2 columns and a
// halfwidth glyph as 1 — used to ellipsis-truncate song/artist names to a fixed
// banner width. Returns -1 (0xffffffff) when the whole string fits. Sibling
// engine text helper; defined in neEngineBridge.mm because it needs Foundation
// (NSString). Ghidra: findCharIndexForColumn @ 0x2da34.
int findCharIndexForColumn(NSString *text, int columnWidth);
#endif

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
