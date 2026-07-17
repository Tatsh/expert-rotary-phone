//
//  SeInstance.h
//  pop'n rhythmin
//
//  The play scene's "SE-instance" cue controllers are NOT a distinct type: they
//  ARE AepLyrCtrl animation layers driven as one-shot sound cues. The combo
//  milestone jingles (PlayJudge) and the song-clear rank jingles (PlayScore) fire
//  a handful of layers this way, and PlayResultTask does the same with its result
//  overlay layers (m_layers, AepLyrCtrl*).
//
//  This was reconstructed once as an opaque `struct SeInstance` with a play
//  cursor / rate / frame-count / command byte, but every field and every function
//  maps exactly onto AepLyrCtrl (same Ghidra addresses):
//    field   SE view          AepLyrCtrl                offset
//    ------  ---------------  ------------------------  ------
//    cursor  play cursor      m_curFrame  (play head)   +0x40
//    rate    playback rate    m_playSpeed (advance)     +0x44
//    length  frame count      m_frameCount              +0x3c
//    command SE command       m_state (play-state)      +0x58
//  So there is no separate structure to model: the reserved regions were just
//  AepLyrCtrl's vtable / intrusive-list / transform / clip-rect fields. The five
//  helpers below are byte-for-byte the AepLyrCtrl methods the binary calls, so
//  they forward to them and keep the sound-cue names at the call sites.
//    - SeInstanceIsBusy    FUN_0002cba4  == AepLyrCtrl::isActive   (m_state != 0)
//    - SeInstancePlay      FUN_0002cac0  == AepLyrCtrl::playOnce
//    - SeInstancePlayMode  FUN_0002cb24  == AepLyrCtrl::stop
//    - SeInstanceIsPlaying FUN_0002cb64  == AepLyrCtrl::isAnimating
//    - SeInstanceStop      FUN_0002cb5c  == AepLyrCtrl::reset
//

#pragma once

#include "AepLyrCtrl.h"

// True while a cue is still pending (play-state != idle). Callers only fire a new
// jingle when the controller is idle. Ghidra: FUN_0002cba4.
inline bool SeInstanceIsBusy(AepLyrCtrl *inst) {
    return inst->isActive();
}

// Arm forward (or, for a reverse-rate controller, backward) playback and rewind
// the cursor to the head (or tail). A zero rate is normalised to 1.0. Ghidra:
// FUN_0002cac0.
inline void SeInstancePlay(AepLyrCtrl *inst) {
    inst->playOnce();
}

// Issue the "stop" command (play-state 3). With mode == 1 the cursor is also
// rewound: to the head for a forward rate, or to the last frame when the rate
// runs backwards. Ghidra: FUN_0002cb24.
inline void SeInstancePlayMode(AepLyrCtrl *inst, int mode) {
    inst->stop(mode);
}

// Whether the controller is still running its cursor. Ghidra: FUN_0002cb64.
inline bool SeInstanceIsPlaying(AepLyrCtrl *inst) {
    return inst->isAnimating();
}

// Stop the controller: clear its play-state so the per-frame tick skips it.
// Ghidra: FUN_0002cb5c.
inline void SeInstanceStop(AepLyrCtrl *inst) {
    inst->reset();
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
