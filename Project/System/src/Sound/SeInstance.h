/** @file
 * The play scene's "SE-instance" cue controllers are not a distinct type: they are AepLyrCtrl
 * animation layers driven as one-shot sound cues. The combo milestone jingles (PlayJudge) and
 * the song-clear rank jingles (PlayScore) fire a handful of layers this way, and
 * PlayResultTask does the same with its result overlay layers (m_layers, AepLyrCtrl*).
 *
 * This was reconstructed once as an opaque `struct SeInstance` with a play cursor, rate,
 * frame-count, and command byte, but every field and every function maps exactly onto
 * AepLyrCtrl (same underlying routines):
 *   field   SE view          AepLyrCtrl                offset
 *   ------  ---------------  ------------------------  ------
 *   cursor  play cursor      m_curFrame  (play head)   +0x40
 *   rate    playback rate    m_playSpeed (advance)     +0x44
 *   length  frame count      m_frameCount              +0x3c
 *   command SE command       m_state (play-state)      +0x58
 * So there is no separate structure to model: the reserved regions were just AepLyrCtrl's
 * vtable, intrusive-list, transform, and clip-rect fields. The five helpers below are
 * byte-for-byte the AepLyrCtrl methods the binary calls, so they forward to them and keep the
 * sound-cue names at the call sites.
 *   - SeInstanceIsBusy    == AepLyrCtrl::isActive   (m_state != 0)
 *   - SeInstancePlay      == AepLyrCtrl::playOnce
 *   - SeInstancePlayMode  == AepLyrCtrl::stop
 *   - SeInstanceIsPlaying == AepLyrCtrl::isAnimating
 *   - SeInstanceStop      == AepLyrCtrl::reset
 */

#pragma once

#include "AepLyrCtrl.h"

/**
 * @brief Whether a cue is still pending (play-state is not idle).
 * @details Callers only fire a new jingle when the controller is idle.
 * @param inst The controller to query.
 * @return true while the cue is still pending, false when idle.
 * @ghidraAddress 0x2cba4
 */
inline bool SeInstanceIsBusy(AepLyrCtrl *inst) {
    return inst->isActive();
}

/**
 * @brief Arm one-shot playback and rewind the cursor to the head.
 * @details Arms forward (or, for a reverse-rate controller, backward) playback and rewinds the
 * cursor to the head (or tail). A zero rate is normalised to 1.0.
 * @param inst The controller to play.
 * @ghidraAddress 0x2cac0
 */
inline void SeInstancePlay(AepLyrCtrl *inst) {
    inst->playOnce();
}

/**
 * @brief Issue the "stop" command (play-state 3), optionally rewinding the cursor.
 * @details With mode == 1 the cursor is also rewound: to the head for a forward rate, or to the
 * last frame when the rate runs backwards.
 * @param inst The controller to stop.
 * @param mode Pass 1 to rewind the cursor as well as stopping.
 * @ghidraAddress 0x2cb24
 */
inline void SeInstancePlayMode(AepLyrCtrl *inst, int mode) {
    inst->stop(mode);
}

/**
 * @brief Whether the controller is still running its cursor.
 * @param inst The controller to query.
 * @return true while the cursor is still running, false otherwise.
 * @ghidraAddress 0x2cb64
 */
inline bool SeInstanceIsPlaying(AepLyrCtrl *inst) {
    return inst->isAnimating();
}

/**
 * @brief Stop the controller by clearing its play-state.
 * @details Clears the play-state so the per-frame tick skips the controller.
 * @param inst The controller to stop.
 * @ghidraAddress 0x2cb5c
 */
inline void SeInstanceStop(AepLyrCtrl *inst) {
    inst->reset();
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
