//
//  AcMainTask.h
//  pop'n rhythmin
//
//  The ARCADE-mode task: arcade song select + option select + note play, driving
//  the arcade note engine (AcNoteMng, already reconstructed). Launched by the mode
//  menu (MenuMainTask). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor AcMainTask_ctor FUN_00099ab0, update AcMainTask_update FUN_00099d18).
//
//  AcMainTask_update is the app's largest function (~24 KB): a big select+play state
//  machine that parallels the standard MainTask -> PlayTask chain. This file carries
//  the task's ctor + the state-machine entry; the full per-state logic is a large
//  deferred reconstruction unit (see HANDOFF). Its note engine (AcNoteMng) is done.
//

#pragma once

#include "C_TASK.h"

class AcMainTask : public C_TASK {
public:
    AcMainTask();                        // Ghidra: AcMainTask_ctor (FUN_00099ab0)
    void update(int deltaMs) override;   // Ghidra: AcMainTask_update (FUN_00099d18)

private:
    int m_state = 0;   // arcade state (play-data state field @ +0x62c region)
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
