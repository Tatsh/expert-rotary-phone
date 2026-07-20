/** @file
 * A single drawable layer or sprite in the Aep 2D scene: its position, size, colour, alpha, a
 * texture reference, and its slot in the ordering table. Reconstructed from Ghidra project rb420,
 * program PopnRhythmin. The layout is derived from the constructor (0x60 bytes); several vec3
 * groups are transform or colour channels whose exact roles are still being pinned down.
 */

#pragma once

#include <cstdint>

namespace ne {
class C_TEXTURE;
}

/**
 * @brief A single drawable layer or sprite in the Aep 2D scene.
 *
 * Holds a layer's position, size, colour, alpha, animation play-state, a resolved texture or layer
 * reference, and its slot in the ordering table.
 */
class AepLyrCtrl {
public:
    /**
     * @brief Construct an empty layer with default transform and play-state.
     * @ghidraAddress 0x2c7d8
     */
    AepLyrCtrl();

    /**
     * @brief Destroy the layer, splicing it out of the global active-layer list.
     */
    virtual ~AepLyrCtrl();

    /**
     * @brief Draw the base layer; overridden by concrete sprite subclasses.
     */
    virtual void draw();

    /**
     * @brief Bind a texture or named resource to this layer.
     *
     * Resolves the layer via AepManager::getLyrNo and layerFrameCount, then links it into the
     * active-layer list. Simplified reconstruction used by scenes that pass neither owner nor
     * order.
     *
     * @param group Resource group of the layer to bind.
     * @param name Name of the layer resource to resolve.
     */
    void init(int group, const char *name);

    /**
     * @brief Bind a texture or named resource to this layer, with owner and order.
     *
     * Full four-parameter form the binary actually exports. Resolves the layer via AepManager and
     * links it into the active-layer list.
     *
     * @param group Resource group of the layer to bind.
     * @param name Name of the layer resource to resolve.
     * @param owner Owning task or context (the result screen threads it in).
     * @param order Ordering-priority word threaded into drawLayer.
     * @ghidraAddress 0x2c834
     */
    void init(int group, const char *name, void *owner, int order);

    /**
     * @brief Splice this layer out of the global active-layer list.
     *
     * Removes the layer without destroying it; the owner then deletes it. Standard doubly-linked
     * removal that patches the neighbours and advances the head when this layer was the head.
     * @ghidraAddress 0x2ca9c
     */
    void unlink();

    /**
     * @brief Start playing the layer's animation in the looping mode.
     *
     * Enters play-state 2. A fully-faded layer seeks to its last frame, else frame 0. On reaching
     * the end the play head wraps, so the layer animates forever until stopped.
     * @ghidraAddress 0x2caf8
     */
    void play();

    /**
     * @brief Start playing the layer's animation once.
     *
     * Enters play-state 1. Defaults the rate to 1.0 when unset, then seeks (frame 0 forward, last
     * frame in reverse). On reaching the end the play head holds at the last frame and the layer
     * enters the held state, so isAnimating() goes false; the caller polls that to know the intro
     * has finished. Distinct from play(), which loops.
     * @ghidraAddress 0x2cac0
     */
    void playOnce();

    /**
     * @brief Animation play-state values held in m_state.
     */
    enum AnimState {
        kAnimIdle = 0,     /*!< Not playing. */
        kAnimOnceHold = 1, /*!< Play once, then hold at the last frame (-> kAnimHeld). */
        kAnimLoop = 2,     /*!< Play looping forever. */
        kAnimOnceIdle = 3, /*!< Play once, then stop back to idle (-> kAnimIdle). */
        kAnimHeld = 4,     /*!< Held at the final frame after a once-hold play. */
    };

    /**
     * @brief Report whether the layer is currently visible.
     * @return True when the layer is drawn.
     */
    bool isVisible() const {
        return m_visible;
    }

    /**
     * @brief Report whether the layer is in any non-idle play-state.
     *
     * The play scene drives some layers as one-shot SE cues and gates a new cue on this, since idle
     * means the previous cue finished.
     * @return True when the play-state is not idle.
     * @ghidraAddress 0x2cba4
     */
    bool isActive() const {
        return m_state != kAnimIdle;
    }

    /**
     * @brief Report whether the layer is still mid-animation.
     *
     * False when idle or held, otherwise true while the play head has not reached the end of its
     * travel (0..m_frameCount for a forward rate, >0 for a reverse rate). The play and result draw
     * passes gate their layer draws on this. The play head is a float in the binary, so it is read
     * as such even though the reconstruction models the current frame as an int.
     * @return True while the animation is still advancing.
     * @ghidraAddress 0x2cb64
     */
    bool isAnimating() const;

    /**
     * @brief Mutable access to the resolved layer length.
     *
     * The sugoroku scene builder trims two of its roulette layers by hand after resolving them.
     * @return Reference to the frame count.
     */
    int &frameCount() {
        return m_frameCount;
    } // +0x3c

    /**
     * @brief Mutable access to the current play head.
     *
     * The sugoroku warp-bounce reads it as a float.
     * @return Reference to the current frame.
     */
    float &curFrame() {
        return m_curFrame;
    } // +0x40

    /**
     * @brief Mutable access to the frame-advance rate.
     * @return Reference to the play speed.
     */
    float &playSpeed() {
        return m_playSpeed;
    } // +0x44

    /**
     * @brief Mutable access to the render mode, which encodes the blend.
     *
     * The play scene forces its three additive field layers to 0x200 after building them.
     * @return Reference to the render mode.
     */
    int &renderMode() {
        return m_renderMode;
    } // +0x34

    /**
     * @brief Stop this layer's animation without unlinking it.
     *
     * Clears the play-state field; the arcade map reload calls it on every scene layer before
     * rebuilding.
     * @ghidraAddress 0x2cb5c
     */
    void stopPlay() {
        m_state = kAnimIdle;
    }

    /**
     * @brief Freeze this layer on its current frame without unlinking or hiding it.
     *
     * Enters the held play-state. isAnimating() treats the held state as done, and
     * updateAndDrawAepLayers keeps drawing the held frame but stops advancing it. The music-select
     * preview pauses its layer this way between songs.
     * @ghidraAddress 0x2cb54
     */
    void pause() {
        m_state = kAnimHeld;
    }

    /**
     * @brief Stop this layer, optionally leaving it drawn at its current frame.
     *
     * The music-select preview transitions call it with keepVisible = 1 to freeze the preview layer
     * on screen.
     * @param keepVisible When 1, seek and keep the current frame drawn; otherwise leave the play
     * head where it is.
     * @ghidraAddress 0x2cb24
     */
    void stop(int keepVisible);

    /**
     * @brief Rewind this layer's play head to frame 0 without unlinking.
     *
     * Used when backing out of a song preview.
     * @ghidraAddress 0x2cb5c
     */
    void reset();

    /**
     * @brief Set the sugoroku roulette-layer anchor.
     *
     * Clears the draw-x slot and stores the raw integer into the draw-y slot.
     * @param value Raw draw-y value to store.
     */
    void setRouletteAnchor(int value) {
        m_originX = 0;
        m_originY = value;
    }

    /**
     * @brief Position the layer's on-screen anchor.
     *
     * Sets the integer draw x/y that updateAndDrawAepLayers reads. The arcade hit-flash arrows
     * re-anchor this every frame.
     * @param x Draw x coordinate.
     * @param y Draw y coordinate.
     */
    void setPosition(int x, int y) {
        m_originX = x;
        m_originY = y;
    }

    /**
     * @brief Advance and draw every live AEP layer for the frame.
     *
     * Walks the global live-layer list and reaches each layer's members directly.
     * @param drawOnly When non-zero, redraw the held frame without advancing time.
     * @ghidraAddress 0x2c924
     */
    static void updateAndDrawAepLayers(int drawOnly);

protected:
    // Field TYPES/offsets are byte-verified from the updateAndDrawAepLayers
    // (0x2c924) disassembly (ldr/ldm = int, ldrsh = short, vldr/vcvt = float),
    // which is authoritative over the NEON-mangled ctor decompile. +0x04..0x08
    // intrusive list links.
    AepLyrCtrl *m_prev; // +0x04  pPrev
    AepLyrCtrl *m_next; // +0x08  pNext
    int m_group;        // +0x0c  nGroup (-1 = unassigned, sentinel)
    void *m_owner;      // +0x10  nArg4: owning task/context (threaded to drawLayer)
    int m_order;        // +0x14  nArg5: ordering-priority word (drawLayer p17)
    int m_originX;      // +0x18  nOriginX (int draw x, not float)
    int m_originY;      // +0x1c  nOriginY (int draw y, not float)
    int m_posX;         // +0x20  nPosX: scale x (default 100)
    int m_posY;         // +0x24  nPosY: scale y (default 100)
    int16_t m_rotation; // +0x28  packed rotation (read as signed short; pReserved28)
    int16_t m_pad2a;    // +0x2a
    int m_anchorX;      // +0x2c  drawLayer anchorX (pivot X offset)
    int m_anchorY;      // +0x30  drawLayer anchorY (pivot Y offset)
    int m_renderMode;   // +0x34  nRenderMode (blend mode; default 0x20, low 16 bits read)
    int m_lyr;          // +0x38  nLyr: resolved layer handle (AepManager::getLyrNo)
    int m_frameCount;   // +0x3c  nFrameCount: layer length (AepManager::layerFrameCount)
    float m_curFrame;   // +0x40  flCurFrame: current play head
    float m_playSpeed;  // +0x44  flPlaySpeed: signed frame-advance rate (default 1.0)
    int m_clipRect[4];  // +0x48  pReserved48 (0x50/0x54 double as >0 gate words)
    AnimState m_state;  // +0x58  nState animation play-state
    bool m_visible;     // +0x59
    uint8_t m_pad5a[2]; // +0x5a
    bool m_finished;    // +0x5c  bFlag59: animation-completed flag (set at end of travel)
    uint8_t m_pad5d[3]; // +0x5d  -> 0x60
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
