//
//  neGraphics.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Render/input
//  manager: content scale + the live touch pool that neGLView writes and the
//  play-judge loop reads.
//

#include "neGraphics.h"

#include <cstring> // strchr

// 16.16 fixed-point <-> float. UIKit hands neGLView point coordinates already
// converted to fixed; the manager scales them to pixels with the content scale.
static inline float FixedToFloat(int v) {
    return (float)v / 65536.0f;
}
static inline int FloatToFixed(float v) {
    return (int)(v * 65536.0f);
}

// Sentinel coordinate a free slot is initialised to (Ghidra: 0x80000000).
static const int kUnsetCoord = (int)0x80000000;
// Sentinel width/height of a free slot (Ghidra: 0x7fffffff).
static const int kUnsetSize = 0x7fffffff;

#pragma mark - Lifecycle (singleton @ DAT_00188384)

// Ghidra: FUN_0001243c — allocate the 32-slot touch pool (operator_new(0x30)
// each) and sentinel-initialise every record; content scale defaults to 1.0.
// @complete
neGraphics::neGraphics() {
    m_touchCount = 0;
    m_nextTouchId = 0;
    m_contentScale = 1.0f; // 0x3f800000
    for (int i = 0; i < kMaxTouches; ++i) {
        auto *rec = new neTouchPoint;
        rec->id = -1; // 0xffffffff
        rec->startX = rec->startY = kUnsetCoord;
        rec->x = rec->y = kUnsetCoord;
        rec->prevX = rec->prevY = kUnsetCoord;
        rec->downX = rec->downY = kUnsetCoord;
        rec->width = kUnsetSize;
        rec->height = kUnsetSize;
        rec->valid = 1;
        rec->released = 0;
        rec->pad[0] = rec->pad[1] = 0;
        m_touches[i] = rec;
    }
}

// Ghidra: FUN_00012358 returns the DAT_00188384 global. The object is created
// lazily by configure() at launch (FUN_00012368: operator_new(0x8c) + init);
// modelled here as a function-local static that mirrors that lazy singleton.
// @complete
neGraphics &neGraphics::shared() {
    static neGraphics instance;
    return instance;
}

// Ghidra: FUN_00012368 — store the device content scale (from
// [UIScreen mainScreen].scale), lazily creating the singleton.
// @complete
void neGraphics::configure(float contentScale) {
    shared().m_contentScale = contentScale;
}

#pragma mark - Touch input

// Ghidra: FUN_000124f8 — append a fresh touch at the next pool slot. The point
// is scaled to pixels; width/height are stored raw. The rolling id wraps at
// INT_MAX back to 0.
// @complete
void neGraphics::touchBegan(int x, int y, int width, int height) {
    int slot = m_touchCount;
    auto *rec = m_touches[slot];
    int px = FloatToFixed(FixedToFloat(x) * m_contentScale);
    int py = FloatToFixed(FixedToFloat(y) * m_contentScale);
    rec->id = m_nextTouchId;
    // All four coordinate pairs start at the down point.
    rec->startX = px;
    rec->startY = py; // pair A (+0x04)
    rec->x = px;
    rec->y = py; // pair B (+0x0c) current / match key
    rec->prevX = px;
    rec->prevY = py; // pair C (+0x14)
    rec->downX = px;
    rec->downY = py;      // pair D (+0x1c)
    rec->width = width;   // +0x24 (unscaled)
    rec->height = height; // +0x28
    rec->valid = 1;       // +0x2c
    rec->released = 0;    // +0x2d
    m_nextTouchId = (m_nextTouchId == 0x7fffffff) ? 0 : m_nextTouchId + 1;
    m_touchCount = slot + 1;
}

// Ghidra: FUN_00012588 — find the live touch whose current point equals the
// reported previous point and slide it: current <- new, previous <- old point.
// @complete
void neGraphics::touchMoved(int x, int y, int prevX, int prevY) {
    if (m_touchCount < 1) {
        return;
    }
    int nx = FloatToFixed(FixedToFloat(x) * m_contentScale);
    int ny = FloatToFixed(FixedToFloat(y) * m_contentScale);
    int ox = FloatToFixed(FixedToFloat(prevX) * m_contentScale);
    int oy = FloatToFixed(FixedToFloat(prevY) * m_contentScale);
    for (int i = 0; i < m_touchCount; ++i) {
        auto *rec = m_touches[i];
        if (rec->x == ox && rec->y == oy) {
            rec->x = nx;
            rec->y = ny; // pair B (+0x0c)
            rec->prevX = ox;
            rec->prevY = oy; // pair C (+0x14)
            return;
        }
    }
}

// Ghidra: FUN_000125ec — like touchMoved but only over un-released slots, and
// it marks the touch released once matched (an end reported per-touch).
// @complete
void neGraphics::touchEnded(int x, int y, int prevX, int prevY) {
    if (m_touchCount < 1) {
        return;
    }
    int nx = FloatToFixed(FixedToFloat(x) * m_contentScale);
    int ny = FloatToFixed(FixedToFloat(y) * m_contentScale);
    int ox = FloatToFixed(FixedToFloat(prevX) * m_contentScale);
    int oy = FloatToFixed(FixedToFloat(prevY) * m_contentScale);
    for (int i = 0; i < m_touchCount; ++i) {
        auto *rec = m_touches[i];
        if (rec->released == 0 && rec->x == ox && rec->y == oy) {
            rec->x = nx;
            rec->y = ny;
            rec->prevX = ox;
            rec->prevY = oy;
            rec->released = 1; // +0x2d
            return;
        }
    }
    // Fallback (Ghidra: FUN_000125ec second loop @ 0x12650-0x12674): no slot matched
    // the old point, so rescan for an un-released slot whose CURRENT point equals the
    // NEW point and reposition both current and previous to the new point before
    // releasing it (the binary stores nx/ny to all four coord words at +0xc..+0x18).
    for (int i = 0; i < m_touchCount; ++i) {
        auto *rec = m_touches[i];
        if (rec->released == 0 && rec->x == nx && rec->y == ny) {
            rec->x = nx;
            rec->y = ny;
            rec->prevX = nx;
            rec->prevY = ny;
            rec->released = 1; // +0x2d
            return;
        }
    }
}

// Ghidra: FUN_00012698 — mark every recorded touch released (all fingers up).
// @complete
void neGraphics::clearTouches() {
    for (int i = 0; i < m_touchCount; ++i) {
        m_touches[i]->released = 1;
    }
}

// Ghidra: FUN_000124cc — linear scan of the recorded touches for a matching id.
// @complete
const neTouchPoint *neGraphics::findTouchById(int id) const {
    for (int i = 0; i < m_touchCount; ++i) {
        if (m_touches[i]->id == id) {
            return m_touches[i];
        }
    }
    return nullptr;
}

// Ghidra: pointInRect FUN_0002d974 — inclusive point-in-rect test: x in [rx,
// rx+rw] and y in [ry, ry+rh]. The ~13 inlined menu hit-tests and menuButtonHit
// call this.
// @complete
bool neGraphics::pointInRect(int x, int y, int rx, int ry, int rw, int rh) {
    return x >= rx && x <= rx + rw && y >= ry && y <= ry + rh;
}

// Ghidra: FUN_000124bc — returns the count at +0x80.
// @complete
extern "C" int NEGraphics_activeTouchCount(const neGraphics *g) {
    return g->m_touchCount;
}

// Ghidra: FUN_000124c4 — returns the i-th pointer from the pool array at +0x00.
// @complete
extern "C" const neTouchPoint *NEGraphics_touchAt(const neGraphics *g, int i) {
    return g->m_touches[i];
}

#pragma mark - Free text / geometry helpers

// @ 0x2d858 — count '\n'-separated lines. The loop advances past each newline
// and, when the newline was the last character, stops without counting a
// trailing empty line.
// @complete
int countLines(const char *text) {
    if (*text == '\0') {
        return 0;
    }
    int count = 1;
    for (;;) {
        const char *nl = strchr(text, '\n');
        if (nl == nullptr) {
            return count; // no more newlines: current line is the last
        }
        text = nl + 1;
        if (*text == '\0') {
            return count; // trailing newline: no extra empty line
        }
        ++count;
    }
}

// @ 0x2d9dc — returns true iff x1<=xMax1 && x2<=xMax2 && y1>=yMin1 &&
// y2>=yMin2. The binary encodes the two `<=` comparisons with the usual
// NaN-aware two-stage compare.
// @complete
bool isWithinRange2D(
    float x1, float y1, float x2, float y2, float yMin1, float xMax1, float yMin2, float xMax2) {
    if (x1 <= xMax1 && x2 <= xMax2) {
        if (y1 < yMin1) {
            return false;
        }
        return y2 >= yMin2;
    }
    return false;
}
