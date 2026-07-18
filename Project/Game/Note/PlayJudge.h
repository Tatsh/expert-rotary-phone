//
//  PlayJudge.h
//  pop'n rhythmin
//
//  The per-frame play/judge pass of the standard-mode main task: it walks the
//  active notes, hit-tests the current touches against each, dispatches hits to
//  NoteMng's judgement, auto-judges in demo mode, resolves holds, draws each
//  note
//  + its effects, and fires the combo-milestone sound effects. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (FUN_0002f1f8, the play
//  megafunction).
//
//  The play data (param_1) is the standard-mode play task, PlayTask, a large
//  task struct whose full 0xa00-byte layout is owned by the task layer
//  (System/src/Task/PlayTask.h). The judge functions here take it by pointer and
//  reach its named members; this header only forward-declares the class.
//  The per-note sprite/effect geometry (plain float / NEON in the original:
//  FUN_0000fd64 note quad, FUN_0000fcd0 hit effect) is a separate draw unit —
//  this file carries the verified judge control flow and delegates the pixel
//  math to those helpers.
//

#pragma once

#include <cstdint>

// The play data the judge pass operates on IS the standard-mode play task,
// PlayTask (System/src/Task/PlayTask.h) — the whole 0xa00-byte class. The judge
// only takes it by pointer, so a forward declaration keeps this note-engine
// header free of the task class (PlayJudge.mm includes the real header). PlayTask
// in turn includes this header for NoteJudgeState (its +0x3c8 judge pool), so the
// dependency runs one way: task -> note engine.
class PlayTask;

// Per-note judge state. The play data owns a fixed pool of 60 of these at
// +0x3c8 (each 24 bytes); FUN_0003126c looks one up by note id, allocating a
// free slot (id < 0) on first touch. Ghidra: FUN_0003126c.
struct NoteJudgeState {
    int layerId;     // +0x00 the note's sprite/layer id (draw arg)
    uint32_t noteId; // +0x04 owning note's pool id (0xffffffff when the slot is
                     //       free; judgeStateFor claims a slot whose noteId, as a
                     //       signed int, is < 0). The judge pass feeds this back
                     //       to NoteMng::setLaneFlag on retire, and the play draw
                     //       reads it as the raw tone note id. Ghidra: nNoteId @ +4.
    int phase;       // +0x08 visual phase: 0 pending, 1 active, 2/3 resolved
    int result;      // +0x0c judged tier: -1 unjudged, else NoteJudge 0..3
                     //       (0 = BAD/worst .. 3 = COOL/best)
    int timestamp;   // +0x10 position when the phase/result last changed
    int touchId;     // +0x14 bound neGraphics touch id (-1 = none)
};

// (The play-data struct itself is PlayTask, defined in
// System/src/Task/PlayTask.h; the judge functions below operate on it by
// pointer. This file used to carry a duplicate MainTaskPlayData overlay of the
// same 0xa00-byte memory — removed once the two were reconciled.)

// The per-frame play/judge pass and the per-tap feedback SE are PlayTask methods
// (PlayTask::playJudgeUpdate — Ghidra FUN_0002f1f8 — and PlayTask::playTouchSound
// — Ghidra FUN_00031338); their bodies live in PlayJudge.mm / PlayScore.mm but
// they are declared on the class in PlayTask.h. Only the miss callback below,
// which NoteMng invokes through a function pointer, stays a free function.

// The note engine's miss callback: apply the BAD/miss gauge penalty to the play
// data (raise the missed flag, subtract gaugeLossMiss, clamp [0, 0x400]). The
// play scene registers this into NoteMng at chart load (initPlayDataWithData);
// detectMiss fires it when a note scrolls past un-tapped, so the life gauge
// drains on missed notes just as it does on a tapped BAD. `playData` is the
// owning PlayTask (passed as the callback arg). Ghidra: FUN_0003122c.
void PlayApplyMissGauge(void *playData);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
