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
//  The play data (param_1) is the standard-mode MainTask, a large task struct whose
//  full 0xa00-byte layout is owned by the task layer (System/src/Task/PlayTask.h).
//  The note engine stays decoupled from that class: it works through the partial
//  MainTaskPlayData view below, which names — at their binary-exact offsets — only the
//  fields this judge pass touches. The per-note sprite/effect geometry (16.16-fixed /
//  NEON in the original: FUN_0000fd64 note quad, FUN_0000fcd0 hit effect) is a separate
//  draw unit — this file carries the verified judge control flow and delegates the pixel
//  math to those helpers.
//

#pragma once

#include <cstddef>   // offsetof
#include <cstdint>

// Per-note judge state. The play data owns a fixed pool of 60 of these at
// +0x3c8 (each 24 bytes); FUN_0003126c looks one up by note id, allocating a free
// slot (id < 0) on first touch. Ghidra: FUN_0003126c.
struct NoteJudgeState {
    int layerId;           // +0x00 the note's sprite/layer id (draw arg)
    const void *noteKey;   // +0x04 owning note identity (-1/0xffffffff when the slot is free;
                           //        judgeStateFor claims a slot whose noteKey, as a signed int, is < 0)
    int phase;             // +0x08 visual phase: 0 pending, 1 active, 2/3 resolved
    int result;            // +0x0c judged tier: -1 unjudged, else NoteJudge 0..3
                           //        (0 = BAD/worst .. 3 = COOL/best)
    int timestamp;         // +0x10 position when the phase/result last changed
    int touchId;           // +0x14 bound neGraphics touch id (-1 = none)
};

// The standard-mode MainTask play-data block, as the NOTE ENGINE sees it. This is a
// deliberately partial overlay: only the fields the judge pass reads/writes are named,
// each at its binary-exact offset (verified against Ghidra FUN_0002f1f8 / FUN_0003126c);
// the regions the note engine never touches are `_rsvd_NN[]` fillers so every named
// field lands on its true offset. The whole 0xa00-byte struct is the same memory as the
// task-layer PlayTask (System/src/Task/PlayTask.h) — but the note engine works through
// this view and never pulls in the task class, keeping the two layers decoupled. The
// block is never value-constructed here (playData always aliases live task storage), so
// this carries no member initializers — it is a pure memory overlay.
struct MainTaskPlayData {
    uint8_t _rsvd_00[0x84];              // +0x000 task base + HUD/layer tables (task-layer owned)

    // The three combo-milestone SE-instance handles the play data pre-creates: [0] fires
    // at 25 combo, [1] at 50, [2] at every 50 past 100. Each is a pointer to an SE-instance
    // / effect object owned elsewhere (see seInstancePlay in PlayJudge.mm). Ghidra: the
    // handles at playData +0x84 / +0x88 / +0x8c.
    void   *milestoneSe[3];              // +0x084 combo-milestone SE-instance handles

    uint8_t _rsvd_90[0x3c8 - 0x90];      // +0x090 HUD / layout tables (task-layer owned)

    // The per-note judge-state pool: FUN_0003126c looks one up by note identity, claiming a
    // free slot on first touch. 60 entries, stride 0x18.
    NoteJudgeState judgePool[60];        // +0x3c8 per-note judge slots (stride 0x18)

    uint8_t _rsvd_968[0x974 - 0x968];    // +0x968

    float   playScale;                   // +0x974 judge-line coordinate scale (touch xy / scale)

    uint8_t _rsvd_978[0x9b0 - 0x978];    // +0x978 HUD / judge-line geometry (coords @+0x98c/990/994)

    int32_t cachedFinalScore;            // +0x9b0 computeFinalScore() cached each frame; the <70000
                                         //        clear-line and rank-SE checks read it. FUN_0002dc14.

    uint8_t _rsvd_9b4[0x9b8 - 0x9b4];    // +0x9b4

    float   hitRadius;                   // +0x9b8 note hit-test radius (distance test)

    uint8_t _rsvd_9bc[0x9c0 - 0x9bc];    // +0x9bc

    int16_t gaugeValue;                  // +0x9c0 life gauge, clamped [0, 0x400] (updateGaugeValue)

    int16_t lastMilestone;               // +0x9c2 last combo milestone fired (re-trigger guard)

    int16_t comboMilestoneShown;         // +0x9c4 last combo milestone celebrated (25 / 50 / 100+):
                                         //        the judge fires the milestone layer @+0x84/88/8c
                                         //        and records the crossed value. Ghidra: FUN_0002f1f8.

    uint8_t _rsvd_9c6[0x9c8 - 0x9c6];    // +0x9c6

    uint8_t clearSeFired;                // +0x9c8 one-shot latch: the post-song clear/rank SE fired
                                         //        (~1s after every note is judged). FUN_0002dc14.

    uint8_t isDemoPlay;                  // +0x9c9 tutorial / auto-demo (milestone-SE gate)
    uint8_t isPadDisplay;                // +0x9ca pad-class display (milestone-SE gate)

    uint8_t _rsvd_9cb[0x9cc - 0x9cb];    // +0x9cb

    float   gaugeGainGreat;              // +0x9cc gauge delta for a GREAT/COOL (result 2/3)
    float   gaugeGainGood;               // +0x9d0 gauge delta for a GOOD (result 1)
    float   gaugeLossMiss;               // +0x9d4 gauge delta for a BAD/miss (result 0, negative)

    uint8_t _rsvd_9d8[0x9dc - 0x9d8];    // +0x9d8

    uint8_t gaugeMissed;                 // +0x9dc set to 1 when a note is missed (result 0)

    uint8_t _rsvd_9dd[0x9e4 - 0x9dd];    // +0x9dd

    uint8_t spatialTouchMode;            // +0x9e4 0 = spatial (distance) hit-test, else in-order
    uint8_t optEffectOn;                 // +0x9e5 hit-effect option (milestone-SE gate)

    uint8_t _rsvd_9e6[0x9e7 - 0x9e6];    // +0x9e6

    uint8_t optOldHardware;              // +0x9e7 legacy device (milestone-SE gate)

    uint8_t endAudioStopped;             // +0x9e8 set once AudioManager::stopAll ran on entering the
                                         //        end state (state 7 -> 8). Ghidra: FUN_0002dc14.

    uint8_t _rsvd_9e9[0x9ec - 0x9e9];    // +0x9e9

    int32_t backBtnTouchId;              // +0x9ec pause/back-button hold touch id (-1 = none): a touch
                                         //        held inside the button circle. Ghidra: FUN_0002dc14.

    int32_t backBtnHoldStartMs;          // +0x9f0 getTimeMillis() when the back-button hold began;
                                         //        held > 500 ms -> pause (onResignActive, state = 5).

    uint8_t _rsvd_9f4[0x9f8 - 0x9f4];    // +0x9f4

    int32_t songFinishPos;               // +0x9f8 play position when the last note was judged (0 =
                                         //        not yet); base for the 1s clear-SE and 3s auto-advance.

    int     state;                       // +0x9fc play state-machine field (5 = stopping)
};

// Binary-exact layout guards: the note engine reaches these fields by their absolute
// offsets, so any drift must fail loudly rather than silently mis-read the play data.
// These offsets are the 32-bit (armv7) binary's layout; milestoneSe (void*[3]) and the
// judgePool entries widen on the 64-bit rebuild target, re-aligning every later field, so
// the absolute offsets only hold on 32-bit. Access is by named member (layout-agnostic),
// so assert the exact layout on 32-bit only — matching the ActiveNote guard in NoteMng.h.
#if !defined(__LP64__) || !__LP64__
static_assert(sizeof(MainTaskPlayData) == 0xa00, "MainTaskPlayData must be the 0xa00-byte play-data block");
static_assert(offsetof(MainTaskPlayData, milestoneSe)      == 0x84,  "milestoneSe @ +0x84");
static_assert(offsetof(MainTaskPlayData, judgePool)        == 0x3c8, "judgePool @ +0x3c8");
static_assert(offsetof(MainTaskPlayData, playScale)        == 0x974, "playScale @ +0x974");
static_assert(offsetof(MainTaskPlayData, hitRadius)        == 0x9b8, "hitRadius @ +0x9b8");
static_assert(offsetof(MainTaskPlayData, gaugeValue)       == 0x9c0, "gaugeValue @ +0x9c0");
static_assert(offsetof(MainTaskPlayData, lastMilestone)    == 0x9c2, "lastMilestone @ +0x9c2");
static_assert(offsetof(MainTaskPlayData, gaugeGainGreat)   == 0x9cc, "gaugeGainGreat @ +0x9cc");
static_assert(offsetof(MainTaskPlayData, gaugeGainGood)    == 0x9d0, "gaugeGainGood @ +0x9d0");
static_assert(offsetof(MainTaskPlayData, gaugeLossMiss)    == 0x9d4, "gaugeLossMiss @ +0x9d4");
static_assert(offsetof(MainTaskPlayData, gaugeMissed)      == 0x9dc, "gaugeMissed @ +0x9dc");
static_assert(offsetof(MainTaskPlayData, isDemoPlay)       == 0x9c9, "isDemoPlay @ +0x9c9");
static_assert(offsetof(MainTaskPlayData, isPadDisplay)     == 0x9ca, "isPadDisplay @ +0x9ca");
static_assert(offsetof(MainTaskPlayData, spatialTouchMode) == 0x9e4, "spatialTouchMode @ +0x9e4");
static_assert(offsetof(MainTaskPlayData, optEffectOn)      == 0x9e5, "optEffectOn @ +0x9e5");
static_assert(offsetof(MainTaskPlayData, optOldHardware)   == 0x9e7, "optOldHardware @ +0x9e7");
static_assert(offsetof(MainTaskPlayData, state)            == 0x9fc, "state @ +0x9fc");
static_assert(offsetof(MainTaskPlayData, cachedFinalScore)   == 0x9b0, "cachedFinalScore @ +0x9b0");
static_assert(offsetof(MainTaskPlayData, comboMilestoneShown)== 0x9c4, "comboMilestoneShown @ +0x9c4");
static_assert(offsetof(MainTaskPlayData, clearSeFired)       == 0x9c8, "clearSeFired @ +0x9c8");
static_assert(offsetof(MainTaskPlayData, endAudioStopped)    == 0x9e8, "endAudioStopped @ +0x9e8");
static_assert(offsetof(MainTaskPlayData, backBtnTouchId)     == 0x9ec, "backBtnTouchId @ +0x9ec");
static_assert(offsetof(MainTaskPlayData, backBtnHoldStartMs) == 0x9f0, "backBtnHoldStartMs @ +0x9f0");
static_assert(offsetof(MainTaskPlayData, songFinishPos)      == 0x9f8, "songFinishPos @ +0x9f8");
#endif  // !__LP64__ (32-bit binary-exact layout guards)

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
