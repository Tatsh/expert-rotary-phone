//
//  PlayResultTask.h
//  pop'n rhythmin
//
//  The note-play result screen, spawned by the play task on a completed normal play
//  (PlayTaskGotoResult -> PlayResultCreateTask). Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (ctor FUN_0003d5bc, update FUN_0003d690).
//
//  Like AcMainTask, update() is a state machine reached by byte offset into a flat
//  data block; it is reconstructed in pieces. The screen: fade/BGM in (0-1), present
//  the score + a Twitter share button and run the rank jingle (2), count the score up
//  with a tick SE (3-6), wait for a dismiss tap (7), show the "communicating" overlay
//  while the score upload finishes (8-9), then fade out and hand off (10-0xc). The
//  animation layers it drives (@ +0x214..+0x228) are AepLyrCtrl/SE-instance controllers
//  (see SeInstance.h). Progress tracked in STUBS.md.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class PlayResultTask : public C_TASK {
public:
    PlayResultTask();                    // Ghidra: FUN_0003d5bc
    void update(int deltaMs) override;   // Ghidra: FUN_0003d690

private:
    // 0x3a0-byte object (C_TASK base 0x28 + a 0x378 data block the ctor memsets and
    // then reaches by byte offset). Reserve it so the raw-offset access is in-bounds.
    uint8_t m_data[0x3a0 - 0x28] = {};

    template <typename T> T &field(int off) {
        return *reinterpret_cast<T *>(reinterpret_cast<char *>(this) + off);
    }

    // The state the update switch dispatches on (@ +0x394).
    int &state() { return field<int>(0x394); }

    // Intricate sub-bodies lifted out of update()'s switch as their own reconstruction
    // pieces (declared real methods, called as if present):
    //  * resultSetup (FUN_0003dfe0): populate the result data (score/rank/combo counters
    //    + treasure points), post the score save, build the result layers, load the ~130
    //    number textures + the rank SEs, and load + volume the result BGM. Large asset
    //    unit; a whole reconstruction piece of its own.
    //  * updateResultPresent (case 2): once the intro layer settles, build the Twitter
    //    share UIButton (device-branched frame from its image size) and watch for the
    //    dismiss tap; while it is still animating, fire the rank jingle on frame cues.
    //  * updateScoreCount (case 6): tick the displayed score up toward the final, firing
    //    the count SE every fifth step.
    //  * resultGotoNext (FUN_0003f2e0): tear the screen down and spawn the next scene.
    void resultSetup();
    void updateResultPresent(bool tapped, int tapX, int tapY, int displayType);
    void updateScoreCount(bool tapped);
    void resultGotoNext();

    // The 10-lane x 12-array number-texture load (num_cool_/great_/good_/bad_/com_/
    // score_/bonus_clear/bonus_combo/bonus_rank/bonus_perfect/points/pointb_), lifted
    // out of resultSetup as a real helper. Ghidra: FUN_0003dfe0's inner double loop
    // @ 0x3ea84..0x3ef9e.
    void loadNumberTextures();
};

// The result screen's per-frame draw pass, registered with the Aep manager as
// group 4's draw callback (context = the task). Reconstructed separately.
// Ghidra: FUN_0003f5f0.
void PlayResultDrawCallback(int child, int frame, int x, int y, int scaleX, int scaleY,
                            int anchorX, int anchorY, int color, int alpha, int rotation,
                            uint32_t blend, int *clipRect, uint32_t p17, void *context);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
