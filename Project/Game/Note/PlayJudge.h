//
//  PlayJudge.h
//  pop'n rhythmin
//
//  The per-frame play/judge pass of the standard-mode main task: it walks the
//  active notes, hit-tests the current touches against each, dispatches hits to
//  NoteMng's judgement, auto-judges passed notes, draws them, and fires the
//  combo-milestone sound effects. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (FUN_0002f1f8, the play megafunction).
//
//  Modelled as a free function on the play-data / task pointer, matching the
//  binary (the play data is one large task struct). The intricate per-note screen
//  geometry (16.16 fixed-point / SIMD in the original) is factored into the sprite
//  draw; this file carries the game-logic control flow.
//

#pragma once

#ifdef __OBJC__
@class NSValue;
#endif

// One touch this frame, in engine 16.16 fixed-point view coordinates.
struct PlayTouch {
    int x;
    int y;
};

// Run one play/judge pass over the global NoteMng's active notes.
//   playData : the main task / play-data struct (opaque here; the fields used are
//              cited by offset in the .mm).
//   touches  : the current touch points (nullptr / count 0 when there is no input).
//   noteIds  : optional per-touch note-id assignment buffer (from the input layer).
// Ghidra: FUN_0002f1f8.
void PlayJudge_update(void *playData, const PlayTouch *touches, int touchCount,
                      const int *noteIds);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
