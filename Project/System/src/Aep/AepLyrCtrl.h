//
//  AepLyrCtrl.h
//  pop'n rhythmin
//
//  A single drawable layer / sprite in the Aep 2D scene (position, size, color,
//  alpha, a texture reference and its slot in the ordering table). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin.
//
//  Layout derived from the constructor (Ghidra: FUN_0002c7d8, 0x60 bytes);
//  init-with-texture is FUN_0002c834. Several vec3 groups are transform/color
//  channels whose exact roles are still being pinned down.
//

#pragma once

#include <cstdint>

class AepTexture;

class AepLyrCtrl {
public:
    AepLyrCtrl();                     // Ghidra: FUN_0002c7d8
    virtual ~AepLyrCtrl();

    virtual void draw();              // vtable @ PTR_LAB_0002c82c

    // Bind a texture / named resource to this layer. Ghidra: AepLyrCtrl_init
    // (FUN_0002c834): resolves the layer via AepManager::getLyrNo/layerFrameCount and
    // links into the active-layer list.
    void init(int group, const char *name);

    // Full four-parameter form the binary actually exports (FUN_0002c834 takes
    // this,group,name,arg3,arg4). `owner` is stored at +0x10 (the owning task the
    // result screen threads in) and `order` at +0x14. The two-arg form above is the
    // simplified reconstruction used by scenes that pass neither.
    void init(int group, const char *name, void *owner, int order);

    // Unlink this layer from the global active-layer list (DAT_00188490) without
    // destroying it; the owner then deletes it. Ghidra: AepLyrCtrl_unlink @ 0x2ca9c.
    void unlink();

    // Start playing the layer's animation (Ghidra: AepLyrCtrl_play FUN_0002caf8):
    // enters play state; a fully-faded layer seeks to its last frame, else frame 0.
    void play();

    bool isVisible() const { return m_visible; }

    // Whether this layer is still mid-animation: false when idle (play-state 0) or held
    // (play-state 4), otherwise true while the play head at +0x40 has not reached the end
    // of its travel (0..m_frameCount for a forward rate, >0 for a reverse rate). The play
    // + result draw passes gate their layer draws on this. Ghidra: FUN_0002cb64. NOTE:
    // the play head at +0x40 is a float in the binary, so it is read as such here even
    // though the reconstructed m_frame models it as int.
    bool isAnimating() const;

    // Mutable access to the resolved layer length / alpha. The sugoroku scene builder
    // trims two of its roulette layers by hand after resolving them (Ghidra:
    // FUN_0009fc90 pokes +0x3c / +0x44).
    int   &frameCount() { return m_frameCount; }  // +0x3c
    float &alpha()      { return m_alpha; }        // +0x44

    // Mutable access to the blend mode (+0x34). The play scene forces its three additive
    // field layers to 0x200 after building them (Ghidra: PlayTask_init stores into +0x34).
    int   &blend()      { return m_blend; }        // +0x34

    // Stop this layer's animation without unlinking it. Ghidra: FUN_0002cb5c (clears
    // the play-state field at +0x58); the arcade map reload calls it on every scene
    // layer before rebuilding.
    void stopPlay() { m_playState = 0; }

    // Freeze this layer on its current frame without unlinking or hiding it: enters the
    // "held" play-state (4). AepLyrCtrl::isAnimating() treats state 4 as done, and
    // AepLyrCtrlUpdateAll keeps drawing the held frame but stops advancing it (the
    // `playState == 4` early-continue). Ghidra: aepLyrCtrlPause FUN_0002cb54 (stores 4
    // at +0x58). The music-select preview pauses its layer this way between songs.
    void pause() { m_playState = 4; }   // @ 0x2cb54

    // Stop this layer, optionally leaving it drawn at its current frame. Ghidra:
    // aepLyrCtrlStop (FUN_0002cb24) — the music-select preview transitions call it
    // with keepVisible = 1 to freeze the preview layer on screen.
    void stop(int keepVisible);

    // Rewind this layer's play head to frame 0 (without unlinking). Ghidra:
    // aepLyrCtrlReset (FUN_0002cb5c) — used when backing out of a song preview.
    void reset();

    // Sugoroku roulette-layer anchor: clear the draw-x slot and store the raw integer
    // into the draw-y slot. Ghidra: the +0x18 / +0x1c stores in FUN_0009fc90.
    void setRouletteAnchor(int value) {
        m_x = 0;
        m_y = value;
    }

    // Position the layer's on-screen anchor: the +0x18/+0x1c integer draw x/y that
    // AepLyrCtrlUpdateAll reads. The arcade hit-flash arrows re-anchor this every frame
    // (Ghidra: FUN_0009fc90 stores the computed x/y into these two words).
    void setPosition(int x, int y) {
        m_x = x;
        m_y = y;
    }

    // Grant the free-function frame-advance loop access to the members below (it was the
    // reason the file-static lc* offset helpers existed). Ghidra: FUN_0002c924.
    friend void AepLyrCtrlUpdateAll(int drawOnly);

protected:
    // Field TYPES/offsets are byte-verified from the updateAndDrawAepLayers (0x2c924)
    // disassembly (ldr/ldm = int, ldrsh = short, vldr/vcvt = float), which is authoritative
    // over the NEON-mangled ctor decompile. +0x04..0x08 intrusive list links.
    AepLyrCtrl *m_prev;   // +0x04
    AepLyrCtrl *m_next;   // +0x08
    int   m_texId;        // +0x0c  (-1 = unassigned, sentinel)
    void *m_owner;        // +0x10  owning task/context (threaded to drawLayer)
    int   m_order;        // +0x14  ordering-priority word (drawLayer p17)
    int   m_x;            // +0x18  draw x  (int, not float)
    int   m_y;            // +0x1c  draw y  (int, not float)
    int   m_scaleX;       // +0x20  (default 100)
    int   m_scaleY;       // +0x24  (default 100)
    int16_t m_rotation;   // +0x28  packed rotation (read as signed short)
    int16_t m_pad2a;      // +0x2a
    int   m_p9;           // +0x2c  drawLayer p9
    int   m_p10;          // +0x30  drawLayer p10
    int   m_blend;        // +0x34  blend mode (default 0x20; low 16 bits read)
    int   m_lyr;          // +0x38  resolved layer handle (AepManager::getLyrNo)
    int   m_frameCount;   // +0x3c  layer length (AepManager::layerFrameCount)
    float m_frame;        // +0x40  current play head (float)
    float m_alpha;        // +0x44  signed frame rate / fade (default 1.0)
    int   m_clipRect[4];  // +0x48..0x58  clip rect (0x50/0x54 double as >0 gate words)
    int   m_playState;    // +0x58  0 idle / 1 once-hold / 2 loop / 3 once-idle / 4 held
    bool  m_visible;      // +0x59
    uint8_t m_pad5a[2];   // +0x5a
    uint8_t m_finished;   // +0x5c  animation-completed flag (set at end of travel)
    uint8_t m_pad5d[3];   // +0x5d  -> 0x60
};

// Advance and draw every active animation layer in the global list (the intrusive
// +0x08 chain from the DAT_00188490 head) for this frame: each playing layer is drawn
// through AepManager::drawLayer at its current frame, then (when drawOnly == 0) its
// frame is stepped by its play mode (1 once, 2 loop, 3 once-reverse) and finished
// layers are marked done. The result screen calls this each update.
// Ghidra: FUN_0002c924.
void AepLyrCtrlUpdateAll(int drawOnly);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
