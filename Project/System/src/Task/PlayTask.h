//
//  PlayTask.h
//  pop'n rhythmin
//
//  The standard-mode NOTE-PLAY task: the actual gameplay screen. It runs the play
//  clock, drives the per-frame note judge/render pass (PlayJudge_update / NoteMng),
//  handles the pause menu, fires combo SEs, watches the gauge + song end, and hands
//  off to the result screen. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (init PlayTask_init FUN_0002e2d8, update PlayTask_update FUN_0002dc14).
//
//  This task's storage IS the play data the judge pass operates on (state @ +0x9fc,
//  judge-state pool @ +0x3c8, scale/radius @ +0x974/+0x9b8 — see PlayJudge.h's
//  MainTaskPlayData). The heavy per-state screen geometry is delegated to the note
//  draw + pause-menu units.
//

#pragma once

#include "C_TASK.h"

class PlayTask : public C_TASK {
public:
    PlayTask();                          // Ghidra: MainTask spawns this; PlayTask_init
    ~PlayTask() override;                // @ 0x2db74 (taskNode_deleteB deleting-dtor: base + delete)
    void update(int deltaMs) override;   // Ghidra: PlayTask_update (FUN_0002dc14)

    // Reset the play scene for a fresh attempt: reload the chart, reset the animated
    // layers, zero the 0x3c-entry judge pool (@ +0x3c8, stride 0x18) with sequential
    // indices + -1 sentinels, and reset the gauge/score scalars (@ +0x9ac..+0x9dc).
    // Ghidra: playTaskResetState (FUN_0002fed8).
    void resetState();                   // @ 0x2fed8

    // Nudge the life gauge (@ +0x9c0, clamped to [0, 0x400]) by the per-mode delta:
    // mode 0 = miss/down (+0x9d4, also sets the "damaged" flag @ +0x9dc), 1 = good
    // (+0x9d0), 2/3 = great/perfect (+0x9cc). Ghidra: updateGaugeValue (FUN_000312cc).
    void updateGauge(int mode);          // @ 0x312cc

private:
    // Reload the chart into the play data (restart = the arg the reset path passes 1).
    // Ghidra: playTaskLoadChart — a PlayTask method (takes the play data as `this`).
    void reloadChart(int restart);       // @ 0x30720
};

// Play-scene lifecycle seams operating on the play-data block.
void PlayTaskInit(void *playData);       // Ghidra: FUN_0002e2d8 (allocate the scene)
void PlayTaskGotoResult(void *playData); // Ghidra: FUN_0003003c (transition to results)

// The current running score/gauge value used for end-of-song rank SEs.
int PlayCurrentScore();                  // Ghidra: FUN_0002ff7c
// Fire the song-clear rank jingle(s) chosen by the final score. Ghidra: the SE-
// instance cascade in PlayTask_update state 6 (FUN_0002cba4/0002cac0/0002cb24).
void PlayEndResultSe(void *playData, int score);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
