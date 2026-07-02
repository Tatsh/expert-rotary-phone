//
//  MainTask.h
//  pop'n rhythmin
//
//  The standard-mode MUSIC-SELECT task: the song list + score display + option
//  navigation that the mode menu (MenuMainTask) launches. It previews BGM, shows
//  the player's ScoreData, routes to recommend / sort / over-score-log / settings,
//  and spawns the actual note-play (or tutorial) task once a song is chosen.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor MainTask_ctor
//  FUN_00034d48, update MainTask_update FUN_00035914; 0xaa8-byte play data).
//
//  This is a ~17-state machine; the reconstruction captures the verified state flow
//  and manager/nav calls. The heavy per-state screen geometry and the note-play
//  sub-task it spawns are their own units (see HANDOFF).
//

#pragma once

#include "C_TASK.h"

class MainTask : public C_TASK {
public:
    MainTask();                          // Ghidra: MainTask_ctor (FUN_00034d48)
    void update(int deltaMs) override;   // Ghidra: MainTask_update (FUN_00035914)

private:
    int m_state = 0;      // play-data state field
    void *m_spawnedTask = nullptr;   // the note-play / tutorial sub-task
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
