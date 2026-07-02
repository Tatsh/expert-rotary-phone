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
//  rectangles and the individual play/arcade sub-task ctors referenced as seams
//  (see HANDOFF — the button layout lives at +0x94..+0x19c, the state at +0x1a8).
//

#pragma once

#include "C_TASK.h"

class AepManager;
class AepLyrCtrl;

class MenuMainTask : public C_TASK {
public:
    MenuMainTask();                     // Ghidra: MenuMainTask_ctor (FUN_0006aba0)
    void update(int deltaMs) override;  // Ghidra: MenuMainTask_update (FUN_0006ad88)

    // Set the "info screen already shown" flag (TitleTask passes 1). Ghidra:
    // MenuMainTask_setInfoFlag (FUN_0006d194) @ +0x1ac.
    void setInfoFlag(bool shown);

private:
    void setup();                       // Ghidra: FUN_0006c6a4 (state 0)
    // Hit-test a menu button rect against the current touch (delegates to the
    // engine hit-test FUN_0002d974). Returns true on a tap inside the rect.
    bool hitButton(int touchId, int rectField, int enableField);

    // Field offsets into the ~0x1b0-byte task (documented, not fully modelled):
    //   +0x28/+0x2c/+0x30 title/menu AepLyrCtrl layers; +0x50..+0x64 SE ids;
    //   +0x68..+0x80 spawned sub-task / SE-instance slots; +0x94..+0x19c the mode
    //   button rects + enable flags; +0x1a8 state; +0x1ac info-shown flag.
    int m_state = 0;                    // +0x1a8
    bool m_infoFlag = false;            // +0x1ac
    bool m_tutorialSkip = false;        // +0xb5 (tutorial already played)
    void *m_spawnedTask = nullptr;      // +0x80 the task being launched into
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
