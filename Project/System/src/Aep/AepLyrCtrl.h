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

    float z() const { return m_z; }
    bool isVisible() const { return m_visible; }

    // Mutable access to the resolved layer length / alpha. The sugoroku scene builder
    // trims two of its roulette layers by hand after resolving them (Ghidra:
    // FUN_0009fc90 pokes +0x3c / +0x44).
    int   &frameCount() { return m_frameCount; }  // +0x3c
    float &alpha()      { return m_alpha; }        // +0x44

    // Stop this layer's animation without unlinking it. Ghidra: FUN_0002cb5c (clears
    // the play-state field at +0x58); the arcade map reload calls it on every scene
    // layer before rebuilding.
    void stopPlay() { m_playState = 0; }

    // Sugoroku roulette-layer anchor: clear the y slot and store a raw integer into
    // the z slot (the scene copies play data field<int>(0x614) in as raw 4 bytes, not
    // a float). Ghidra: the +0x18 / +0x1c stores in FUN_0009fc90.
    void setRouletteAnchor(int value) {
        m_y = 0.0f;
        *reinterpret_cast<int *>(&m_z) = value;
    }

protected:
    // +0x04 / +0x08: intrusive links in the ordering table.
    AepLyrCtrl *m_prev; // +0x04
    AepLyrCtrl *m_next; // +0x08
    int m_texId;        // +0x0c  (-1 = unassigned, sentinel)
    int m_field10;      // +0x10
    float m_x, m_y, m_z;// +0x14..0x1c  position
    int m_width;        // +0x20  (default 100)
    int m_height;       // +0x24  (default 100)
    float m_grpA[3];    // +0x28..0x30  (color or uv)  [roles TBD]
    int m_blend;        // +0x34  blend mode (default 0x20)
    int m_lyr;          // +0x38  resolved layer handle (AepManager::getLyrNo)
    int m_frameCount;   // +0x3c  layer length (AepManager::layerFrameCount)
    int m_frame;        // +0x40  current animation frame
    float m_alpha;      // +0x44  (default 1.0)
    float m_grpC[4];    // +0x48..0x54
    bool m_flag55;      // +0x55
    int m_playState;    // +0x58  0 idle, 2 playing
    bool m_visible;     // +0x59
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
