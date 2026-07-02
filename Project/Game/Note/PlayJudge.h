//
//  PlayJudge.h
//  pop'n rhythmin
//
//  The per-frame play/judge pass of the standard-mode main task: it walks the
//  active notes, hit-tests the current touches against each, dispatches hits to
//  NoteMng's judgement, auto-judges in demo mode, resolves holds, draws each note
//  + its effects, and fires the combo-milestone sound effects. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (FUN_0002f1f8, the play megafunction).
//
//  The play data (param_1) is the standard-mode MainTask, a large task struct that
//  is not yet reconstructed as a whole; the fields this pass touches are reached by
//  cited byte offset. The per-note sprite/effect geometry (16.16-fixed / NEON in the
//  original: FUN_0000fd64 note quad, FUN_0000fcd0 hit effect) is a separate draw
//  unit — this file carries the verified judge control flow and delegates the pixel
//  math to those helpers.
//

#pragma once

// Forward declaration of the not-yet-reconstructed standard-mode MainTask play
// data. Accessed here only through documented byte offsets.
struct MainTaskPlayData;

// Per-note judge state. The play data owns a fixed pool of 60 of these at
// +0x3c8 (each 24 bytes); FUN_0003126c looks one up by note id, allocating a free
// slot (id < 0) on first touch. Ghidra: FUN_0003126c.
struct NoteJudgeState {
    int layerId;           // +0x00 the note's sprite/layer id (draw arg)
    const void *noteKey;   // +0x04 owning note identity (nullptr when the slot is free)
    int phase;             // +0x08 visual phase: 0 pending, 1 active, 2/3 resolved
    int result;            // +0x0c judged tier: -1 unjudged, else NoteJudge 0..3
                           //        (0 = BAD/worst .. 3 = COOL/best)
    int timestamp;         // +0x10 position when the phase/result last changed
    int touchId;           // +0x14 bound neGraphics touch id (-1 = none)
};

// Run one play/judge pass over the global NoteMng's active notes.
//   playData  : the standard-mode MainTask play data.
//   touchXY   : current touch points as (x, y) float pairs in view pixels; a
//               negative x or y marks an empty/consumed slot. Up to 8 pairs.
//   touchIds  : the neGraphics touch id parallel to each touchXY pair (bound to a
//               note when its tap lands, so the hold can track the same finger).
//   touchCount: number of touch pairs.
// Ghidra: FUN_0002f1f8.
void PlayJudge_update(MainTaskPlayData *playData, const float *touchXY,
                      const int *touchIds, int touchCount);

// Play the per-tap feedback SE (retriggering it if already sounding), gated by the
// user's touch-sound volume and skipped while the pause menu is up. Called after a
// frame that resolved any note. (Despite the historical name it does NOT recompute
// the score/gauge — that is done by the play loop via PlayCurrentScore.)
// Ghidra: FUN_00031338.
void PlayScoreGaugeUpdate(MainTaskPlayData *playData);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
