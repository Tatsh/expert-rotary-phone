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

#include <cstdint>

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

    // The binary's task is a 0x1b0-byte object whose fields setup()/update()/
    // hitButton() reach by raw byte offset from `this` (there are too many button
    // rects / layer / SE slots to name). That storage MUST be reserved here or those
    // accesses run off the object. C_TASK's base is exactly 0x28 bytes (vptr + 8
    // words + killed flag + pad), so the padding below lands each named field at its
    // true binary offset AND backs every raw offset in [0x28, 0x1b0). Documented
    // regions: +0x28/+0x2c/+0x30 menu AepLyrCtrl layers; +0x34..+0x48 badge handles;
    // +0x4c warning texture; +0x50..+0x64 SE ids; +0x68..+0x7c SE-instance slots;
    // +0x84..+0x1a4 the mode-button rects + enable flags; +0xec pulse phase.
    uint8_t m_pad0[0x80 - 0x28] = {};   // +0x28..+0x80
    void *m_spawnedTask = nullptr;      // +0x80 the task being launched into
    uint8_t m_pad1[0xb5 - 0x84] = {};   // +0x84..+0xb5
    bool m_tutorialSkip = false;        // +0xb5 tutorial already played
    uint8_t m_pad2[0x1a8 - 0xb6] = {};  // +0xb6..+0x1a8
    int m_state = 0;                    // +0x1a8
    bool m_infoFlag = false;            // +0x1ac
    uint8_t m_pad3[3] = {};             // +0x1ad..+0x1b0 tail padding
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
