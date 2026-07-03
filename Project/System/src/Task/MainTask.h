//
//  MainTask.h
//  pop'n rhythmin
//
//  The standard-mode MUSIC-SELECT task: the song list + score display + option
//  navigation that the mode menu (MenuMainTask) launches. It previews BGM, shows
//  the player's ScoreData, routes to recommend / sort / over-score-log / settings,
//  and spawns the actual note-play (or first-play tutorial) task once a song is
//  chosen. Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor
//  MainTask_ctor FUN_00034d48, dtor mainTask_dtor FUN_00034d90, update
//  MainTask_update FUN_00035914; the engine work area is the "MusicSelTask" struct,
//  0xcc1 bytes — the +0x28..+0xaa8 region is the zeroed play data, +0xaa8..+0xcc1
//  the setup()-filled UI layout block).
//
//  This is a ~17-state machine. update()'s state flow, button dispatch and every
//  manager/nav call are reconstructed faithfully. The engine work area is reached by
//  raw byte offset (matching the MenuMainTask reconstruction): the WorkStruct HEAD
//  fields (Aep layers, jacket-cell array, song-name/artist textures, music list) have
//  exact offsets recovered from the struct layout; the packed SCALAR TAIL that holds
//  the per-song select state + button rectangles is a documented seam — its field
//  roles and the control flow that reads them are exact, the individual sub-offsets
//  are best-effort (see the kOff* table + hitButton() in MainTask.mm).
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class MainTask : public C_TASK {
public:
    MainTask();                          // Ghidra: MainTask_ctor  (FUN_00034d48)
    ~MainTask() override;                // Ghidra: mainTask_dtor  (FUN_00034d90)
    void update(int deltaMs) override;   // Ghidra: MainTask_update (FUN_00035914)

private:
    // The music-select buttons hit-tested each frame. hitButton() maps each to its
    // stored screen rectangle in the work area and tests the current tap against it
    // (via the engine point-in-rect primitive, Ghidra FUN_0002d974). kBtnSongCell /
    // kBtnFavToggle / kBtnDifficulty take a cell/row index.
    enum Button {
        kBtnSettings, kBtnSort, kBtnRecommend, kBtnOverScoreLog,   // state 2 top row
        kBtnBackToMenu, kBtnTutorial, kBtnDiffToggle,              // state 2 overlay
        kBtnSongCell, kBtnFavToggle,                               // state 2 song grid
        kBtnPlay, kBtnFriendScore, kBtnDifficulty,                 // state 4 preview
    };

    // Hit-test `button` (screen rect scaled by the work area's UI-scale factor) against
    // the tap at (tapX, tapY). Ghidra: the inline FixedToFP/FloatVectorMult(...scale...)
    // transform feeding pointInRect (FUN_0002d974). `cellIndex` selects the rect for the
    // per-cell buttons. Rect storage is the packed-tail seam.
    bool hitButton(int tapX, int tapY, Button button, int cellIndex = -1) const;

    // state 3/4 seams into the packed work area (documented in MainTask.mm):
    void initOverscoreRows();            // fill the 3 over-score display counters
    void refreshScoreRows();             // re-read the 3 difficulty score rows

    // ---- engine work area (raw-offset access; see MainTask.mm kOff* table) ----
    // C_TASK's base is exactly 0x28 bytes, so this padding lands m_spawnedTask/m_state
    // at their true binary offsets AND backs every raw offset in [0x28, 0xcc1).
    uint8_t  m_pad0[0xaa0 - 0x28] = {};  // +0x28..+0xaa0 play data (Aep layers @+0x34,
                                         //   jacket cells @+0x2d8, textures @+0x54/+0x58,
                                         //   music list @+0x30, packed select scalars)
    C_TASK  *m_spawnedTask = nullptr;    // +0xaa0 the note-play / tutorial / menu sub-task
    int      m_state = 0;                // +0xaa4 state field
    uint8_t  m_pad1[0xcc1 - 0xaa8] = {}; // +0xaa8..+0xcc1 setup()-filled UI layout (seam)
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
