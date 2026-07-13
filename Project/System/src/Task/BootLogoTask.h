//
//  BootLogoTask.h
//  pop'n rhythmin
//
//  The boot "logo / warning" splash task, created by startBootTask at
//  priority 3. It shows three branding screens (each faded in, held ~2s or
//  until tapped, then faded out), logs into Game Center, and hands off to the
//  next task. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor BootLogoTask_ctor FUN_0002af58, update FUN_0002b02c, setup
//  FUN_0002b1f4, finish FUN_0002b554).
//

#pragma once

#include "C_TASK.h"

class AepManager;
class neTextureForiOS;

class BootLogoTask : public C_TASK {
public:
    BootLogoTask();                    // Ghidra: BootLogoTask_ctor (FUN_0002af58)
    ~BootLogoTask() override;          // @ 0x2af8c (taskNode_deleteA deleting-dtor: base + delete)
    void update(int deltaMs) override; // Ghidra: BootLogoTask_update (FUN_0002b02c)

private:
    void setup();                         // Ghidra: BootLogoTask_setup (FUN_0002b1f4)
    void finish();                        // Ghidra: BootLogoTask_finish (FUN_0002b554)
    void drawLogo(neTextureForiOS *logo); // Ghidra: neTextureForiOS_draw (FUN_0000fbcc)
    void drawLogo1();                     // @ 0x2b504 (draws m_logo[1] via drawLogo)
    bool skipRequested() const;           // a touch was released this frame

    static const int kHoldFrames = 0x78;      // 120: hold length; advances past 0x77
    static const int kFadeFrames = 0x1e;      // 30:  per-screen fade length
    static const int kFirstFadeFrames = 0x3c; // 60:  the very first fade-in

    // Concrete fields, appended from +0x28 (see BootLogoTask_ctor).
    AepManager *m_aep = nullptr;     // +0x28 render manager
    neTextureForiOS *m_logo[3] = {}; // +0x2c/+0x30/+0x34 the 3 branding sprites
    float m_scale = 0.0f;            // +0x38 saved screen scale (restored on exit)
    int m_counter = 0;               // +0x3c per-screen frame counter
    int m_posX = 0;                  // +0x40 logo centre x
    int m_posY = 0;                  // +0x44 logo centre y
    int m_state = 0;                 // +0x48 state machine (0..9)
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
