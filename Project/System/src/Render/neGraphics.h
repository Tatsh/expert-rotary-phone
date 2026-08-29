/**
 * @file
 * @brief The render and input manager singleton.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (@ DAT_00188384,
 * operator_new(0x8c)). It owns the device content scale and the pool of live touch points. The GL
 * view (neGLView) feeds touches in; the play-judge loop reads them back out.
 *
 * Provisional name: the exact class name is not recovered from RTTI, so this keeps the
 * System-layer "ne" convention. The bridge accessor FUN_00012358 simply returns the DAT_00188384
 * global (see HANDOFF.md — Engine).
 */

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

/**
 * @brief One tracked touch.
 *
 * The manager pre-allocates a fixed pool of these (operator_new(0x30) = 48 bytes each) at init and
 * mutates them in place as touches begin, move and end; slots are never freed. All coordinates are
 * plain integer device pixels (the raw point value from UIKit is multiplied by the content scale
 * on the way in via vcvt). Ghidra: sentinel-initialised by FUN_0001243c.
 */
struct neTouchPoint {
    int id;     /**< +0x00 Rolling id assigned at began; -1 when the slot was never used. */
    int startX; /**< +0x04 Down point x (pair A). */
    int startY; /**< +0x08 Down point y (pair A). */
    int x;      /**< +0x0c Current point x; the match key on move and end (pair B). */
    int y;      /**< +0x10 Current point y (pair B). */
    int prevX;  /**< +0x14 Previous point x (pair C). */
    int prevY;  /**< +0x18 Previous point y (pair C). */
    int downX;  /**< +0x1c Copy of the down point x, left untouched by move (pair D). */
    int downY;  /**< +0x20 Copy of the down point y (pair D). */
    int width;  /**< +0x24 View width at began (fixed); 0x7fffffff when the slot is free. */
    int height; /**< +0x28 View height at began. */
    unsigned char valid;    /**< +0x2c Allocated-slot marker; initialised to 1 and always set. */
    unsigned char released; /**< +0x2d Set on end or clear, cleared on began. */
    unsigned char pad[2];   /**< +0x2e Padding rounding the record up to 0x30. */
};

// C-ABI accessors the play-judge loop uses on the raw manager pointer. Thin wrappers over the
// class members; declared here (ahead of the class) so the friend declarations below bind to these
// C-linkage functions.
class neGraphics;
/**
 * @brief The number of touches recorded this frame, read from the manager's +0x80 field.
 * @param g The manager.
 * @return The live touch count.
 * @ghidraAddress 0x124bc
 */
extern "C" int NEGraphics_activeTouchCount(const neGraphics *g);
/**
 * @brief The @p i -th touch in the manager's +0x00 pool array.
 * @param g The manager.
 * @param i The pool index.
 * @return The touch record.
 * @ghidraAddress 0x124c4
 */
extern "C" const neTouchPoint *NEGraphics_touchAt(const neGraphics *g, int i);

/**
 * @brief The render and input manager: a singleton created lazily by configure() at launch, owning
 * the device content scale and the live touch pool.
 */
class neGraphics {
public:
    /**
     * @brief The singleton instance (Ghidra: returns DAT_00188384).
     * @return The manager.
     * @ghidraAddress 0x12358
     */
    static neGraphics &shared();
    /**
     * @brief Create the singleton and record the device content scale.
     * @param contentScale The device content scale.
     * @ghidraAddress 0x12368
     */
    static void configure(float contentScale);

    // Touch plumbing. neGLView forwards UIKit touch points here; this scales them to plain device
    // pixels (multiply by content scale) and records them. The play-judge loop (FUN_0002f1f8)
    // reads the pool back via shared().

    /**
     * @brief Record a new touch, allocating it a pool slot and a rolling id.
     * @param x Touch x, in UIKit points.
     * @param y Touch y, in UIKit points.
     * @param width View width at the time of the touch.
     * @param height View height at the time of the touch.
     * @ghidraAddress 0x124f8
     */
    void touchBegan(int x, int y, int width, int height);
    /**
     * @brief Update the pool slot whose current point matches (@p prevX, @p prevY).
     * @param x New touch x, in UIKit points.
     * @param y New touch y, in UIKit points.
     * @param prevX Previous touch x, the match key.
     * @param prevY Previous touch y, the match key.
     * @ghidraAddress 0x12588
     */
    void touchMoved(int x, int y, int prevX, int prevY);
    /**
     * @brief Flag the matching pool slot released; endFrame() reaps it.
     * @param x Final touch x, in UIKit points.
     * @param y Final touch y, in UIKit points.
     * @param prevX Previous touch x, the match key.
     * @param prevY Previous touch y, the match key.
     * @ghidraAddress 0x125ec
     */
    void touchEnded(int x, int y, int prevX, int prevY);
    /**
     * @brief Release every recorded touch.
     * @ghidraAddress 0x12698
     */
    void clearTouches();

    /**
     * @brief Per-frame touch-pool upkeep, run once at the end of each task tick.
     *
     * For every recorded touch it clears the +0x2c frame marker and latches the current point
     * (+0x0c/+0x10) into the down-point copy (+0x1c/+0x20), then swap-removes any slot flagged
     * released (+0x2d): the released pool pointer is swapped to the tail (the pool never frees a
     * slot) and the live count (+0x80) is decremented. Tail-called from -[MainViewController
     * task].
     * @ghidraAddress 0x126b8
     */
    void endFrame();

    /**
     * @brief The number of touches recorded this frame (binary field @ +0x80).
     * @return The live touch count.
     */
    int activeTouchCount() const {
        return m_touchCount;
    }
    /**
     * @brief The @p i -th recorded touch.
     * @param i The pool index; must be below activeTouchCount().
     * @return The touch record.
     */
    const neTouchPoint *touchAt(int i) const {
        return m_touches[i];
    }
    /**
     * @brief The device content scale (binary field @ +0x88).
     * @return The content scale.
     */
    float contentScale() const {
        return m_contentScale;
    }

    /**
     * @brief Find a recorded touch by its rolling id.
     *
     * The play-judge loop uses this to tell whether the finger that started a hold is still down.
     * @param id The rolling touch id.
     * @return The touch record, or nullptr when no slot carries that id.
     * @ghidraAddress 0x124cc
     */
    const neTouchPoint *findTouchById(int id) const;

    /**
     * @brief Point-in-rect test primitive.
     *
     * The same primitive the bridge's higher-level neEngine::menuButtonHit(gfx, touchId, rect,
     * enable) wraps; the music-select task calls it directly with pre-scaled corners.
     * @param x Test point x.
     * @param y Test point y.
     * @param rx Rectangle left edge.
     * @param ry Rectangle top edge.
     * @param rw Rectangle width.
     * @param rh Rectangle height.
     * @return true when (@p x, @p y) lies inside the rectangle.
     * @ghidraAddress 0x2d974
     */
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
};

// Free text / geometry helpers (siblings of neGraphics::pointInRect). These are plain
// C-linkage-shaped free functions in the binary (no `this`); they live beside the pointInRect
// primitive as the engine's small layout helpers.

/**
 * @brief Count the newline-separated lines in a C string.
 *
 * An empty string counts as 0; a trailing newline is not counted as an extra empty line.
 * @param text The string to measure.
 * @return The line count.
 * @ghidraAddress 0x2d858
 */
int countLines(const char *text);

/**
 * @brief 2D range containment over eight floats.
 *
 * The recovered predicate is true when the pair (@p x1, @p x2) is at or under the upper bounds
 * (@p xMax1, @p xMax2) and the pair (@p y1, @p y2) is at or above the lower bounds (@p yMin1,
 * @p yMin2) — that is, two corners inside a half-open box.
 * @param x1 First corner x.
 * @param y1 First corner y.
 * @param x2 Second corner x.
 * @param y2 Second corner y.
 * @param yMin1 Lower bound for @p y1.
 * @param xMax1 Upper bound for @p x1.
 * @param yMin2 Lower bound for @p y2.
 * @param xMax2 Upper bound for @p x2.
 * @return true when both corners lie inside the box.
 * @ghidraAddress 0x2d9dc
 */
bool isWithinRange2D(
    float x1, float y1, float x2, float y2, float yMin1, float xMax1, float yMin2, float xMax2);

#ifdef __OBJC__
/**
 * @brief The character index at which @p text first fills @p columnWidth display columns.
 *
 * A full-width (CJK or non-halfwidth) glyph counts as 2 columns and a halfwidth glyph as 1. Used
 * to ellipsis-truncate song and artist names to a fixed banner width. A sibling engine text
 * helper, defined in neEngineBridge.mm because it needs Foundation (NSString).
 * @param text The string to measure.
 * @param columnWidth The column budget.
 * @return The character index, or -1 (0xffffffff) when the whole string fits.
 * @ghidraAddress 0x2da34
 */
int findCharIndexForColumn(NSString *text, int columnWidth);
#endif
