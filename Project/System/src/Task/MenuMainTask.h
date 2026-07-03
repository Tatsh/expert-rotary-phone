//
//  MenuMainTask.h
//  pop'n rhythmin
//
//  The central mode-select hub task, spawned by TitleTask after the title screen.
//  It fetches news + player data, runs the daily/login-bonus/unlock gates, then
//  drives the interactive main menu: hit-testing the mode buttons to spawn the
//  play / tutorial / arcade tasks or navigate to Store / Friend / PopnLink / Invite
//  / PresentBox / ArcadeSearch / Settings. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (ctor MenuMainTask_ctor FUN_0006aba0, update
//  MenuMainTask_update FUN_0006ad88, ~0x1b0-byte task).
//
//  This is the single largest, most-connected task in the app; the verified state
//  machine + button dispatch are reconstructed here, with the per-button screen
//  rectangles recovered as real members (below).
//
//  ---- work area (this class IS the 0x1b0-byte MenuMainTask struct) ----
//  C_TASK's base is exactly 0x28 bytes, and MenuMainTask_ctor does
//  memset(this + 0x28, 0, 0x185) — i.e. every field from +0x28..+0x1ad is
//  zero-initialised — so the members below (default-initialised to 0) land at their
//  true binary offsets. Offsets that setup()/update()/drawOverlay() reach in the
//  binary are named; the two write-only sub-blocks that do not decompile into
//  distinct scalars (the news-cache copy and the NEWS-ticker draw params) are kept
//  as documented named blocks.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class AepManager;
class AepLyrCtrl;
class neTextureForiOS;

class MenuMainTask : public C_TASK {
public:
    MenuMainTask();                     // Ghidra: MenuMainTask_ctor (FUN_0006aba0)
    void update(int deltaMs) override;  // Ghidra: MenuMainTask_update (FUN_0006ad88)

    // Set the "info screen already shown" flag (TitleTask passes 1). Ghidra:
    // MenuMainTask_setInfoFlag (FUN_0006d194) @ +0x1ac.
    void setInfoFlag(bool shown);

    // One menu button's on-screen rectangle, in the engine hit-test's field order
    // (x, y, w, h). pointInRect (FUN_0002d974) tests x in [x, x+w], y in [y, y+h].
    struct ButtonRect {   // 0x10 bytes
        int x;
        int y;
        int w;
        int h;
    };

    // The eight array-laid-out mode buttons hit-tested in state 0xc (+0x128..+0x1a4).
    enum Button {
        kBtnPlay,        // +0x128 standard play (tutorial on first play)
        kBtnStore,       // +0x138 store
        kBtnFriend,      // +0x148 friend management
        kBtnArcade,      // +0x158 arcade select+play
        kBtnPopnLink,    // +0x168 pop'n link
        kBtnInvite,      // +0x178 invite code
        kBtnPresentBox,  // +0x188 present box
        kBtnSugoroku,    // +0x198 sugoroku / arcade search
        kBtnCount,
    };

private:
    void setup();                       // Ghidra: FUN_0006c6a4 (state 0)
    // The per-frame menu overlay pass (warning badge, event badges, button labels),
    // pulsed by the triangle-wave phase at +0xec. Ghidra: modeSelectTaskDraw
    // (FUN_0006d428).
    void drawOverlay();

    // Hit-test one of the eight array buttons against the current tap. Delegates to
    // the engine hit-test (Ghidra FUN_0002d974). Returns true on a tap inside the rect.
    bool hitButton(int touchId, Button button) const;
    // The settings button is a packed rect in the top cluster (rect x @ +0x98, y @
    // +0x94), so it is tested separately.
    bool hitSettingsButton(int touchId) const;

    // ---- packed top-row cluster (+0x94.. settings/gift rects, overlapping fields) ----
    struct TopCluster {
        int rowY;         // +0x94 shared top-row Y (also the settings enable field)
        int settingsX;    // +0x98 settings rect x
        int field9c;      // +0x9c
        int fielda0;      // +0xa0
        int fielda4;      // +0xa4
        int fielda8;      // +0xa8
    };

    // ---- one badge / sprite screen position ----
    struct SpritePos { int x, y; };   // 0x8 bytes

    // ================= work-area layout (offsets are binary-exact) =================
    AepLyrCtrl      *m_layers[3] = {};        // +0x28 open / loop-bg / prompt transports
    int              m_newsHandle = 0;        // +0x34 resolved NEWS ticker Aep handle
    int              m_badgeHandles[5] = {};  // +0x38 NEWS/BT_SETTING/NEW_STORE/BT_GIFT/BT_FEATU
    neTextureForiOS *m_warnTexture = nullptr; // +0x4c friend-request warning texture
    int              m_seId[6] = {};          // +0x50 six UI SE source ids
    int              m_seInst[6] = {};        // +0x68 their playing-instance handles (-1 idle)
    void            *m_spawnedTask = nullptr;  // +0x80 the sub-task being launched into
    int              m_labelRowY = 0;         // +0x84 button-label row Y
    int              m_settingsLabelX = 0;    // +0x88 settings label X
    int              m_storeLabelX = 0;       // +0x8c store label X
    int              m_giftLabelX = 0;        // +0x90 gift label X
    TopCluster       m_top = {};              // +0x94 settings/gift packed rects
    int              m_warnScaleX = 0;        // +0xac warning-badge scale X
    int              m_warnScaleY = 0;        // +0xb0 warning-badge scale Y
    uint8_t          m_suppressOverlay = 0;   // +0xb4 overlay suppressed while tearing down
    uint8_t          m_tutorialSkip = 0;      // +0xb5 tutorial already played
    uint8_t          m_giftEnabled = 0;       // +0xb6 gift button/label enabled
    uint8_t          m_treasureEvent = 0;     // +0xb7 treasure-event badge visible
    uint8_t          m_gameEvent = 0;         // +0xb8 game-event badge visible
    // +0xb9..+0xe8 the news-text array copy + reward/event scan state (news seam;
    // populated by the tail of FUN_0006c6a4, read by the news branch of the binary's
    // update — outside this reconstruction's scope). Kept as a documented block.
    uint8_t          _reserved_newsCache[0xe8 - 0xb9] = {};
    int              m_layoutYOffset = 0;     // +0xe8 tall-screen vertical shift
    int              m_pulsePhase = 0;        // +0xec attention-pulse phase counter
    int              m_unlockStep = 0;        // +0xf0 invite-present unlock step (case-6 seam)
    // +0xf4..+0x108 the NEWS ticker draw params (position/scale); write-only in this
    // scope (consumed by the news draw seam). Kept as a documented named block.
    int              m_newsTickerParams[5] = {};   // +0xf4
    SpritePos        m_newPackBadgePos = {};  // +0x108 "new music pack" badge
    SpritePos        m_treasureBadgePos = {}; // +0x110 treasure-event badge
    SpritePos        m_gameBadgePos = {};     // +0x118 game-event badge
    SpritePos        m_warnBadgePos = {};     // +0x120 friend-request warning badge
    ButtonRect       m_buttons[kBtnCount] = {};    // +0x128 the eight mode-button rects
    int              m_state = 0;             // +0x1a8 state-machine state
    bool             m_infoFlag = false;      // +0x1ac daily-info screen already shown
    uint8_t          m_pad_tail[3] = {};      // +0x1ad..+0x1b0 tail padding
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
