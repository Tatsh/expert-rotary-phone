//
//  AepLyrCtrl.h
//  pop'n rhythmin
//
//  A single drawable layer / sprite in the Aep 2D scene (position, size, color,
//  alpha, a texture reference and its slot in the ordering table).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  Layout derived from the constructor (Ghidra: FUN_0002c7d8, 0x60 bytes);
//  init-with-texture is FUN_0002c834. Several vec3 groups are transform/color
//  channels whose exact roles are still being pinned down.
//

#pragma once

#include <cstdint>

namespace ne {
class C_TEXTURE;
}

class AepLyrCtrl {
public:
    AepLyrCtrl(); // Ghidra: FUN_0002c7d8
    virtual ~AepLyrCtrl();

    virtual void draw(); // vtable @ PTR_LAB_0002c82c

    // Bind a texture / named resource to this layer. Ghidra: AepLyrCtrl_init
    // (FUN_0002c834): resolves the layer via AepManager::getLyrNo/layerFrameCount
    // and links into the active-layer list.
    void init(int group, const char *name);

    // Full four-parameter form the binary actually exports (FUN_0002c834 takes
    // this,group,name,arg3,arg4). `owner` is stored at +0x10 (the owning task the
    // result screen threads in) and `order` at +0x14. The two-arg form above is
    // the simplified reconstruction used by scenes that pass neither.
    void init(int group, const char *name, void *owner, int order);

    // Unlink this layer from the global active-layer list (DAT_00188490) without
    // destroying it; the owner then deletes it. Ghidra: AepLyrCtrl_unlink @
    // 0x2ca9c.
    void unlink();

    // Start playing the layer's animation in the LOOPING mode (play-state 2)
    // (Ghidra: AepLyrCtrl_play FUN_0002caf8): a fully-faded layer seeks to its
    // last frame, else frame 0. On reaching the end the play head wraps, so the
    // layer animates forever until stopped.
    void play();

    // Start playing the layer's animation ONCE (play-state 1) (Ghidra:
    // AepLyrCtrl::Play FUN_0002cac0): defaults the rate to 1.0 when unset, then
    // seeks (frame 0 forward, last frame in reverse). On reaching the end the
    // play head holds at the last frame and the layer enters the held state (4),
    // so isAnimating() goes false — the caller (e.g. the mode-select open
    // animation) polls that to know the intro has finished. Distinct from play()
    // (FUN_0002caf8), which loops.
    void playOnce();

    // Animation play-state values (m_state / Ghidra nState @ +0x58).
    enum AnimState {
        kAnimIdle = 0,     // not playing
        kAnimOnceHold = 1, // play once, then hold at the last frame (-> kAnimHeld)
        kAnimLoop = 2,     // play looping forever
        kAnimOnceIdle = 3, // play once, then stop back to idle (-> kAnimIdle)
        kAnimHeld = 4,     // held at the final frame after a once-hold play
    };

    bool isVisible() const {
        return m_visible;
    }

    // Whether this layer-control is in any non-idle play-state (m_state != 0). The
    // play scene drives some layers as one-shot SE cues and gates a new cue on this
    // (idle == the previous cue finished). Ghidra: aepLyrCtrlIsActive (FUN_0002cba4).
    bool isActive() const {
        return m_state != kAnimIdle;
    }

    // Whether this layer is still mid-animation: false when idle (play-state 0)
    // or held (play-state 4), otherwise true while the play head at +0x40 has not
    // reached the end of its travel (0..m_frameCount for a forward rate, >0 for a
    // reverse rate). The play
    // + result draw passes gate their layer draws on this. Ghidra: FUN_0002cb64.
    // NOTE: the play head at +0x40 is a float in the binary, so it is read as
    // such here even though the reconstructed m_curFrame models it as int.
    bool isAnimating() const;

    // Mutable access to the resolved layer length (+0x3c nFrameCount) and the play
    // speed / frame-advance rate (+0x44 flPlaySpeed). The sugoroku scene builder
    // trims two of its roulette layers by hand after resolving them (Ghidra:
    // FUN_0009fc90 pokes +0x3c / +0x44).
    int &frameCount() {
        return m_frameCount;
    } // +0x3c
    // Current play head (+0x40 flCurFrame). The sugoroku warp-bounce reads it as a
    // float (Ghidra sugorokuDrawPlayerAndUi @ 0xa53aa: vldr.32 s0, [layer,#0x40]).
    float &curFrame() {
        return m_curFrame;
    } // +0x40
    float &playSpeed() {
        return m_playSpeed;
    } // +0x44

    // Mutable access to the render mode (+0x34 nRenderMode; encodes the blend). The
    // play scene forces its three additive field layers to 0x200 after building
    // them (Ghidra: PlayTask_init stores into +0x34).
    int &renderMode() {
        return m_renderMode;
    } // +0x34

    // Stop this layer's animation without unlinking it. Ghidra: FUN_0002cb5c
    // (clears the play-state field at +0x58); the arcade map reload calls it on
    // every scene layer before rebuilding.
    void stopPlay() {
        m_state = kAnimIdle;
    }

    // Freeze this layer on its current frame without unlinking or hiding it:
    // enters the "held" play-state (4). AepLyrCtrl::isAnimating() treats state 4
    // as done, and updateAndDrawAepLayers keeps drawing the held frame but stops
    // advancing it (the `playState == 4` early-continue). Ghidra: aepLyrCtrlPause
    // FUN_0002cb54 (stores 4 at +0x58). The music-select preview pauses its layer
    // this way between songs.
    void pause() {
        m_state = kAnimHeld;
    } // @ 0x2cb54

    // Stop this layer, optionally leaving it drawn at its current frame. Ghidra:
    // aepLyrCtrlStop (FUN_0002cb24) — the music-select preview transitions call
    // it with keepVisible = 1 to freeze the preview layer on screen.
    void stop(int keepVisible);

    // Rewind this layer's play head to frame 0 (without unlinking). Ghidra:
    // aepLyrCtrlReset (FUN_0002cb5c) — used when backing out of a song preview.
    void reset();

    // Sugoroku roulette-layer anchor: clear the draw-x slot and store the raw
    // integer into the draw-y slot. Ghidra: the +0x18 / +0x1c stores in
    // FUN_0009fc90.
    void setRouletteAnchor(int value) {
        m_originX = 0;
        m_originY = value;
    }

    // Position the layer's on-screen anchor: the +0x18/+0x1c integer draw x/y
    // that updateAndDrawAepLayers reads. The arcade hit-flash arrows re-anchor this
    // every frame (Ghidra: FUN_0009fc90 stores the computed x/y into these two
    // words).
    void setPosition(int x, int y) {
        m_originX = x;
        m_originY = y;
    }

    // Advance and draw every live AEP layer for the frame (drawOnly != 0 redraws
    // the held frame without advancing time). A static member: it walks the global
    // live-layer list and reaches each layer's members directly. Ghidra:
    // FUN_0002c924.
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
