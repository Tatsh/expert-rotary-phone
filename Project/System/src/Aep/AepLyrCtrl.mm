//
//  AepLyrCtrl.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. A drawable Aep
//  layer/sprite: ctor FUN_0002c7d8, init-with-texture FUN_0002c834. init creates
//  a texture through the render manager and links the layer into the global layer
//  list (Ghidra: DAT_00188490).
//

#include <cassert>
#include <cmath>
#include <cstdint>

#import "AepLyrCtrl.h"
#import "AepManager.h"

// Intrusive doubly-linked list of all live layers (Ghidra: head @ DAT_00188490).
static AepLyrCtrl *s_layerListHead = nullptr;

// Raw byte-offset field access for the frame-advance state machine below. The binary's
// AepLyrCtrl object layout for the +0x14..+0x34 words does NOT match the member names in
// AepLyrCtrl.h (verified against the drawLayer call @ 0x2c9ce): the geometry the draw
// reads as x/y/scaleX/scaleY sits at +0x18/+0x1c/+0x20/+0x24 (the header labels those
// m_y/m_z/m_width/m_height), +0x14 is the layer's order word (header m_x), +0x28 the
// rotation, +0x2c/+0x30 two more words, +0x34 the blend, and +0x44 is the signed frame
// RATE (header m_alpha). To stay faithful to the binary without disturbing the other
// consumers of those member names, the free functions here reach the object by offset.
namespace {
inline int   &lcI(AepLyrCtrl *l, int off) { return *reinterpret_cast<int *>(reinterpret_cast<char *>(l) + off); }
inline float &lcF(AepLyrCtrl *l, int off) { return *reinterpret_cast<float *>(reinterpret_cast<char *>(l) + off); }
inline short  lcS(AepLyrCtrl *l, int off) { return *reinterpret_cast<short *>(reinterpret_cast<char *>(l) + off); }
inline unsigned short lcH(AepLyrCtrl *l, int off) { return *reinterpret_cast<unsigned short *>(reinterpret_cast<char *>(l) + off); }
inline void  *lcPtr(AepLyrCtrl *l, int off) { return *reinterpret_cast<void **>(reinterpret_cast<char *>(l) + off); }
inline AepLyrCtrl *lcNext(AepLyrCtrl *l) { return *reinterpret_cast<AepLyrCtrl **>(reinterpret_cast<char *>(l) + 0x08); }
}  // namespace

// Ghidra: AepLyrCtrl_ctor (FUN_0002c7d8).
AepLyrCtrl::AepLyrCtrl()
    : m_prev(nullptr), m_next(nullptr), m_texId(-1), m_field10(0),
      m_x(0), m_y(0), m_z(0), m_width(100), m_height(100),
      m_grpA{0, 0, 0}, m_blend(0), m_lyr(-1), m_frameCount(0), m_frame(0),
      m_alpha(1.0f), m_grpC{0, 0, 0, 0}, m_flag55(false), m_playState(0),
      m_visible(false) {}

AepLyrCtrl::~AepLyrCtrl() {
    if (m_prev) m_prev->m_next = m_next;
    if (m_next) m_next->m_prev = m_prev;
    if (s_layerListHead == this) s_layerListHead = m_next;
}

// Base layer draw: overridden by concrete sprite subclasses. vtable @ 0x2c82c.
void AepLyrCtrl::draw() {}

// Ghidra: AepLyrCtrl_init (FUN_0002c834) — resolve the layer by (group, name)
// through the render manager and register in the active-layer list.
void AepLyrCtrl::init(int group, const char *name) {
    assert(group >= 0);           // AepLyrCtrl.mm:0x42
    assert(name != nullptr);
    AepManager &mgr = AepManager::shared();

    m_texId = group;
    m_field10 = 0;
    m_x = 0; m_y = 0; m_z = 0;
    m_width = 100; m_height = 100;
    m_grpA[0] = 0; m_grpA[1] = 0; m_grpA[2] = 0;
    m_blend = 0x20;

    m_lyr = mgr.getLyrNo(group, name);   // Ghidra: AepManager_getLyrNo
    assert(m_lyr >= 0);                  // AepLyrCtrl.mm:0x56
    m_frameCount = mgr.layerFrameCount(m_lyr);   // Ghidra: AepManager_layerFrameCount
    m_frame = 0;
    m_alpha = 1.0f;
    m_flag55 = false;
    m_visible = false;

    // Head-insert into the global layer list.
    m_prev = nullptr;
    m_next = s_layerListHead;
    if (s_layerListHead != nullptr) {
        s_layerListHead->m_prev = this;
    }
    s_layerListHead = this;
}

// Ghidra: AepLyrCtrl_play (FUN_0002caf8) — enter play state. A fully-faded layer
// (alpha <= 0) jumps to its last frame; otherwise it restarts at frame 0.
void AepLyrCtrl::play() {
    m_playState = 2;
    if (m_alpha <= 0.0f) {
        m_frame = m_frameCount - 1;
    } else {
        m_frame = 0;
    }
}

// Ghidra: FUN_0002cb64 — still-animating predicate. `(playState | 4) == 4` is true for
// the idle (0) and held (4) states; otherwise the float play head at +0x40 is compared
// against its travel: a reverse rate (+0x44 <= 0) animates while the head is > 0, a
// forward rate while the head is < the layer length (+0x3c).
bool AepLyrCtrl::isAnimating() const {
    AepLyrCtrl *self = const_cast<AepLyrCtrl *>(this);
    const int playState = lcI(self, 0x58);
    if ((static_cast<unsigned>(playState) | 4u) == 4u) {
        return false;
    }
    const int frame = static_cast<int>(lcF(self, 0x40));   // vcvt.s32.f32: truncate to int
    if (lcF(self, 0x44) <= 0.0f) {
        return frame > 0;
    }
    return frame < lcI(self, 0x3c);
}

// Ghidra: FUN_0002c924 (AepLyrCtrlUpdateAll). Walk the global live-layer list and, for
// every layer whose play state (+0x58) is non-zero, draw it at its current frame through
// AepManager::drawLayer, then (unless drawOnly) step the frame by its signed rate (+0x44)
// and apply the per-play-mode end handling. The drawLayer argument threading and the
// state machine below are byte-verified from the disassembly at 0x2c958..0x2ca82.
void AepLyrCtrlUpdateAll(int drawOnly) {
    AepManager &mgr = AepManager::shared();   // Ghidra: AepManager_shared (FUN_0000f1ec)

    for (AepLyrCtrl *l = s_layerListHead; l != nullptr; l = lcNext(l)) {   // +0x08 next-link
        const int playState = lcI(l, 0x58);
        if (playState == 0) {
            continue;
        }

        // Clip/root arg: the four-word clip rect at +0x48 is threaded only when both gate
        // words +0x50 and +0x54 are positive, else no clip (the layer fills the screen).
        int *root = nullptr;
        if (lcI(l, 0x50) >= 1 && lcI(l, 0x54) > 0) {
            root = &lcI(l, 0x48);
        }

        // Frame index handed to drawLayer: the float play head at +0x40 truncated to int
        // (vcvt.s32.f32). Arg mapping verified against the disassembled bl @ 0x2c9ce (the
        // r0-r3 + sp+0x00..0x38 stores): the constants land as loopFlags=8, colour=100,
        // colourHi=0, p15=0xffffff, p19=1; the +0x2c/+0x30 words are p9/p10; +0x10/+0x14
        // are p17/context; the +0x48 rect is the clip.
        const int frame = static_cast<int>(lcF(l, 0x40));
        mgr.drawLayer(lcI(l, 0x38),                          // lyr        r6+0x38
                      frame,                                 // frame      (int)r6+0x40
                      lcI(l, 0x18),                          // x          r6+0x18
                      lcI(l, 0x1c),                          // y          r6+0x1c
                      lcI(l, 0x20),                          // scaleX     r6+0x20
                      lcI(l, 0x24),                          // scaleY     r6+0x24
                      static_cast<int>(lcS(l, 0x28)),        // rotation   (short)r6+0x28
                      8,                                     // loopFlags  #8 (kDrawClampLast)
                      lcI(l, 0x2c),                          // p9         r6+0x2c
                      lcI(l, 0x30),                          // p10        r6+0x30
                      100,                                   // color      #0x64
                      0,                                     // colorHi    #0
                      static_cast<uint32_t>(lcH(l, 0x34)),   // blendFlags (u16)r6+0x34
                      0x00ffffff,                            // p15        #0x00ffffff
                      root,                                  // clipRect   root or null
                      lcPtr(l, 0x14),                        // context    r6+0x14
                      static_cast<uint32_t>(lcI(l, 0x10)),   // p17        r6+0x10
                      1);                                    // p19        #1

        if (playState == 4 || drawOnly != 0) {
            continue;   // held frame, or draw-only pass: do not advance
        }

        // Advance the play head by the signed rate and apply the end handling per mode.
        const float rate = lcF(l, 0x44);
        const float newFrame = lcF(l, 0x40) + rate;
        lcF(l, 0x40) = newFrame;
        const int frameCount = lcI(l, 0x3c);

        if (rate > 0.0f) {                                   // forward
            if (static_cast<int>(newFrame) >= frameCount) {  // reached the end
                if (playState == 3) {                        // once, stop to idle
                    lcF(l, 0x40) = static_cast<float>(frameCount - 1);
                    lcI(l, 0x58) = 0;
                    *(reinterpret_cast<unsigned char *>(l) + 0x5c) = 1;
                } else if (playState == 2) {                 // loop, wrap to start
                    lcF(l, 0x40) = 0.0f;
                } else if (playState == 1) {                 // once, hold at last frame
                    lcF(l, 0x40) = static_cast<float>(frameCount - 1);
                    lcI(l, 0x58) = 4;
                    *(reinterpret_cast<unsigned char *>(l) + 0x5c) = 1;
                }
            }
        } else {                                             // reverse (rate <= 0)
            if (newFrame <= 0.0f) {                           // reached the start
                if (playState == 3) {                        // once, stop to idle
                    lcF(l, 0x40) = 0.0f;
                    lcI(l, 0x58) = 0;
                    *(reinterpret_cast<unsigned char *>(l) + 0x5c) = 1;
                } else if (playState == 2) {                 // loop, wrap to the end
                    lcF(l, 0x40) = static_cast<float>(frameCount - 1);
                } else if (playState == 1) {                 // once, hold at frame 0
                    lcF(l, 0x40) = 0.0f;
                    lcI(l, 0x58) = 4;
                    *(reinterpret_cast<unsigned char *>(l) + 0x5c) = 1;
                }
            }
        }
    }
}
