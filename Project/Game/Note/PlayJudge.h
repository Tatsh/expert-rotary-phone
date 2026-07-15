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
//  The play data (param_1) is the standard-mode MainTask, a large task struct
//  whose full 0xa00-byte layout is owned by the task layer
//  (System/src/Task/PlayTask.h). The note engine stays decoupled from that
//  class: it works through the partial MainTaskPlayData view below, which names
//  — at their binary-exact offsets — only the fields this judge pass touches.
//  The per-note sprite/effect geometry (16.16-fixed / NEON in the original:
//  FUN_0000fd64 note quad, FUN_0000fcd0 hit effect) is a separate draw unit —
//  this file carries the verified judge control flow and delegates the pixel
//  math to those helpers.
//

#pragma once

#include <cstddef> // offsetof
#include <cstdint>

// The play data holds AepLyrCtrl animation-layer transports for the combo
// effects; the judge pass only stores/uses them by pointer, so a forward
// declaration suffices here (PlayJudge.mm includes the real header).
class AepLyrCtrl;

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

// The standard-mode MainTask play-data block, as the NOTE ENGINE sees it. This
// is a deliberately partial overlay: only the fields the judge pass
// reads/writes are named, each at its binary-exact offset (verified against
// Ghidra FUN_0002f1f8 / FUN_0003126c); the regions the note engine never
// touches are `_rsvd_NN[]` fillers so every named field lands on its true
// offset. The whole 0xa00-byte struct is the same memory as the task-layer
// PlayTask (System/src/Task/PlayTask.h) — but the note engine works through
// this view and never pulls in the task class, keeping the two layers
// decoupled. The block is never value-constructed here (playData always aliases
// live task storage), so this carries no member initializers — it is a pure
// memory overlay.
struct MainTaskPlayData {
    uint8_t _rsvd_00[0x84]; // +0x000 task base + HUD/layer tables (task-layer owned)

    // The combo-effect animation layers (AepLyrCtrl transports), owned by the task
    // layer (PlayTask::m_comboLayers). The judge pass restarts the burst layer for
    // each combo milestone as it is first crossed: [0] at 25, [1] at 50, [2] at
    // every 50 past 100. Ghidra: the AepLyrCtrl handles at playData +0x84/88/8c.
    AepLyrCtrl *comboLayers[5]; // +0x084 combo-effect layers ([0..2] = 25/50/100 burst)

    // The sustained combo-effect layers (PlayTask::m_sceneLayers). Past a 5 / 10 /
    // 100 combo the judge holds the matching tier layer ([0]/[1]/[2]) paused at its
    // frame and resets the others. Ghidra: the AepLyrCtrl handles at +0x98/9c/a0.
    AepLyrCtrl *sceneLayers[3]; // +0x098 sustained combo-effect layers

    uint8_t _rsvd_a4[0xc4 - 0xa4]; // +0x0a4 HUD / layout tables (task-layer owned)

    // Per-visual-phase note-sprite layer id (TONE_DEFAULT/NEAR/OUT_0/OUT_1),
    // indexed by the judge phase (0..3). The draw region passes toneJudgeLyr[phase]
    // as the layer to AepManager::drawLayer for the note sprite. Owned by the task
    // layer (PlayTask::m_toneJudgeLyr). Ghidra: playData+0xc4[phase].
    int32_t toneJudgeLyr[4]; // +0x0c4 note-sprite layer id per phase

    // Per-visual-phase note-sprite frame length, indexed by the judge phase
    // (0..3). When a resolved note's elapsed animation frame reaches its phase's
    // length the judge retires the note (setLaneFlag + frees the judge slot).
    // Owned by the task layer (PlayTask::m_toneJudgeFrames); named here because the
    // judge pass reads it as the retire threshold. Ghidra: playData+0xd4[phase].
    int32_t toneJudgeFrames[4]; // +0x0d4 retire threshold per phase

    // Hit-effect layer ids the judge draw flashes at the judge line when a note
    // resolves (PlayTask::m_effectStateLyr). [0] = base GG_HANTEI underlay, [1] =
    // EFF_HIT (phase-1 hit sprite), [2]/[3]/[4] = the GOOD/GREAT/COOL result
    // bursts, [12] (+0x114) = the CD jacket. Ghidra: playData+0xe4[i].
    int32_t effectStateLyr[14]; // +0x0e4 hit-effect layer ids

    // ...and their per-layer frame lengths (PlayTask::m_effectStateFrames): the
    // draw gates each effect sprite on its frame being below its length ([0] =
    // +0x11c base, [1] = +0x120 hit, [2..4] = +0x124/128/12c result bursts).
    // Ghidra: playData+0x11c[i].
    int32_t effectStateFrames[14]; // +0x11c hit-effect frame lengths

    uint8_t _rsvd_154[0x21c - 0x154]; // +0x154 HUD / layout tables (task-layer owned)

    int32_t barSegLyr0; // +0x21c first bar-segment layer id (long-note connecting bar)

    uint8_t _rsvd_220[0x3c4 - 0x220]; // +0x220 HUD / layout tables (task-layer owned)

    int32_t cdFrame; // +0x3c4 CD-jacket animation frame (PlayTask::m_cdFrame)

    // The per-note judge-state pool: FUN_0003126c looks one up by note identity,
    // claiming a free slot on first touch. 60 entries, stride 0x18.
    NoteJudgeState judgePool[60]; // +0x3c8 per-note judge slots (stride 0x18)

    uint8_t _rsvd_968[0x974 - 0x968]; // +0x968

    float playScale; // +0x974 judge-line coordinate scale (touch xy / scale)

    uint8_t _rsvd_978[0x98c - 0x978]; // +0x978 HUD / judge-line geometry

    int32_t pauseBtnCenterX; // +0x98c pause/back-button hit-circle centre x
                             // (pre-scale;
                             //        touch tested via pointInCircle after
                             //        *playScale). FUN_0002dc14.
    int32_t pauseBtnRadius;  // +0x990 pause/back-button hit-circle radius (pre-scale)
    int32_t pauseBtnCenterY; // +0x994 pause/back-button hit-circle centre y
                             // (pre-scale)

    // Long-note connecting-bar parameters (Ghidra: FUN_0002f1f8 0x2f958..0x2fa6a).
    // The bar length grows with the fade: len = fade*barLenScale + barLenBase; the
    // bar sprite (barSegLyr1) is drawn along the head->target angle. barPriority is
    // halved into the draw's anchor slot.
    int32_t barLenScale; // +0x998 bar length gain per fade
    int32_t barSegLyr1;  // +0x99c second bar-segment layer id
    int32_t barPriority; // +0x9a0 bar draw priority (halved)
    int32_t barLenBase;  // +0x9a4 bar length base

    uint8_t _rsvd_9a8[0x9b0 - 0x9a8]; // +0x9a8

    int32_t cachedFinalScore; // +0x9b0 computeFinalScore() cached each frame; the
                              // <70000
                              //        clear-line and rank-SE checks read it.
                              //        FUN_0002dc14.

    uint8_t _rsvd_9b4[0x9b8 - 0x9b4]; // +0x9b4

    float hitRadius; // +0x9b8 note hit-test radius (distance test)

    int32_t noteDrawScale; // +0x9bc note/lane draw scale the judge passes as the
                           // sx/sy
                           //        pair to AepManager::drawLayer for notes.
                           //        FUN_0002f1f8.

    int16_t gaugeValue; // +0x9c0 life gauge, clamped [0, 0x400] (updateGaugeValue)

    int16_t lastMilestone; // +0x9c2 last combo milestone fired (re-trigger guard)

    int16_t comboMilestoneShown; // +0x9c4 last combo milestone celebrated (25 /
                                 // 50 / 100+):
                                 //        the judge fires the milestone layer
                                 //        @+0x84/88/8c and records the crossed
                                 //        value. Ghidra: FUN_0002f1f8.

    uint8_t _rsvd_9c6[0x9c7 - 0x9c6]; // +0x9c6 (state-2 SE/transition gate; role
                                      // not yet nailed)

    uint8_t hudHidden; // +0x9c7 when set, the play update skips playTaskDrawHud
                       //        (the on-screen HUD is suppressed). Ghidra:
                       //        FUN_0002dc14.

    uint8_t clearSeFired; // +0x9c8 one-shot latch: the post-song clear/rank SE fired
                          //        (~1s after every note is judged). FUN_0002dc14.

    uint8_t isDemoPlay;   // +0x9c9 tutorial / auto-demo (milestone-SE gate)
    uint8_t isPadDisplay; // +0x9ca pad-class display (milestone-SE gate)

    uint8_t _rsvd_9cb[0x9cc - 0x9cb]; // +0x9cb

    float gaugeGainGreat; // +0x9cc gauge delta for a GREAT/COOL (result 2/3)
    float gaugeGainGood;  // +0x9d0 gauge delta for a GOOD (result 1)
    float gaugeLossMiss;  // +0x9d4 gauge delta for a BAD/miss (result 0, negative)

    uint8_t _rsvd_9d8[0x9dc - 0x9d8]; // +0x9d8

    uint8_t gaugeMissed; // +0x9dc set to 1 when a note is missed (result 0)

    uint8_t _rsvd_9dd[0x9e0 - 0x9dd]; // +0x9dd

    int32_t hitEffectScale; // +0x9e0 note hit-effect layer extent; the judge
                            // passes its
                            //        half (/2) as the effect anchor/scale.
                            //        Ghidra: FUN_0002f1f8.

    uint8_t spatialTouchMode; // +0x9e4 0 = spatial (distance) hit-test, else in-order
    uint8_t optEffectOn;      // +0x9e5 hit-effect option (milestone-SE gate)
    uint8_t optJacket;        // +0x9e6 CD-jacket overlay option: when set, the note draw
                              //        flashes the jacket sprite at the head. Ghidra:
                              //        the byte at playData+0x9e6 gating the +0x114 draw.

    uint8_t optOldHardware; // +0x9e7 legacy device (milestone-SE gate)

    uint8_t endAudioStopped; // +0x9e8 set once AudioManager::stopAll ran on entering
                             // the
                             //        end state (state 7 -> 8). Ghidra: FUN_0002dc14.

    uint8_t _rsvd_9e9[0x9ec - 0x9e9]; // +0x9e9

    int32_t backBtnTouchId; // +0x9ec pause/back-button hold touch id (-1 = none):
                            // a touch
                            //        held inside the button circle. Ghidra:
                            //        FUN_0002dc14.

    int32_t backBtnHoldStartMs; // +0x9f0 getTimeMillis() when the back-button
                                // hold began;
                                //        held > 500 ms -> pause (onResignActive,
                                //        state = 5).

    uint8_t _rsvd_9f4[0x9f8 - 0x9f4]; // +0x9f4

    int32_t songFinishPos; // +0x9f8 play position when the last note was judged (0 =
                           //        not yet); base for the 1s clear-SE and 3s
                           //        auto-advance.

    int state; // +0x9fc play state-machine field (5 = stopping)
};

// Binary-exact layout guards: the note engine reaches these fields by their
// absolute offsets, so any drift must fail loudly rather than silently mis-read
// the play data. These offsets are the 32-bit (armv7) binary's layout;
// the combo-layer pointers and the judgePool entries widen on the 64-bit rebuild
// target, re-aligning every later field, so the absolute offsets only hold on
// 32-bit. Access is by named member (layout-agnostic), so assert the exact
// layout on 32-bit only — matching the ActiveNote guard in NoteMng.h.
#if !defined(__LP64__) || !__LP64__
static_assert(sizeof(MainTaskPlayData) == 0xa00,
              "MainTaskPlayData must be the 0xa00-byte play-data block");
static_assert(offsetof(MainTaskPlayData, comboLayers) == 0x84, "comboLayers @ +0x84");
static_assert(offsetof(MainTaskPlayData, sceneLayers) == 0x98, "sceneLayers @ +0x98");
static_assert(offsetof(MainTaskPlayData, toneJudgeLyr) == 0xc4, "toneJudgeLyr @ +0xc4");
static_assert(offsetof(MainTaskPlayData, toneJudgeFrames) == 0xd4, "toneJudgeFrames @ +0xd4");
static_assert(offsetof(MainTaskPlayData, effectStateLyr) == 0xe4, "effectStateLyr @ +0xe4");
static_assert(offsetof(MainTaskPlayData, effectStateFrames) == 0x11c, "effectStateFrames @ +0x11c");
static_assert(offsetof(MainTaskPlayData, barSegLyr0) == 0x21c, "barSegLyr0 @ +0x21c");
static_assert(offsetof(MainTaskPlayData, cdFrame) == 0x3c4, "cdFrame @ +0x3c4");
static_assert(offsetof(MainTaskPlayData, barLenScale) == 0x998, "barLenScale @ +0x998");
static_assert(offsetof(MainTaskPlayData, barSegLyr1) == 0x99c, "barSegLyr1 @ +0x99c");
static_assert(offsetof(MainTaskPlayData, barPriority) == 0x9a0, "barPriority @ +0x9a0");
static_assert(offsetof(MainTaskPlayData, barLenBase) == 0x9a4, "barLenBase @ +0x9a4");
static_assert(offsetof(MainTaskPlayData, judgePool) == 0x3c8, "judgePool @ +0x3c8");
static_assert(offsetof(MainTaskPlayData, playScale) == 0x974, "playScale @ +0x974");
static_assert(offsetof(MainTaskPlayData, hitRadius) == 0x9b8, "hitRadius @ +0x9b8");
static_assert(offsetof(MainTaskPlayData, gaugeValue) == 0x9c0, "gaugeValue @ +0x9c0");
static_assert(offsetof(MainTaskPlayData, lastMilestone) == 0x9c2, "lastMilestone @ +0x9c2");
static_assert(offsetof(MainTaskPlayData, gaugeGainGreat) == 0x9cc, "gaugeGainGreat @ +0x9cc");
static_assert(offsetof(MainTaskPlayData, gaugeGainGood) == 0x9d0, "gaugeGainGood @ +0x9d0");
static_assert(offsetof(MainTaskPlayData, gaugeLossMiss) == 0x9d4, "gaugeLossMiss @ +0x9d4");
static_assert(offsetof(MainTaskPlayData, gaugeMissed) == 0x9dc, "gaugeMissed @ +0x9dc");
static_assert(offsetof(MainTaskPlayData, isDemoPlay) == 0x9c9, "isDemoPlay @ +0x9c9");
static_assert(offsetof(MainTaskPlayData, isPadDisplay) == 0x9ca, "isPadDisplay @ +0x9ca");
static_assert(offsetof(MainTaskPlayData, spatialTouchMode) == 0x9e4, "spatialTouchMode @ +0x9e4");
static_assert(offsetof(MainTaskPlayData, optEffectOn) == 0x9e5, "optEffectOn @ +0x9e5");
static_assert(offsetof(MainTaskPlayData, optJacket) == 0x9e6, "optJacket @ +0x9e6");
static_assert(offsetof(MainTaskPlayData, optOldHardware) == 0x9e7, "optOldHardware @ +0x9e7");
static_assert(offsetof(MainTaskPlayData, state) == 0x9fc, "state @ +0x9fc");
static_assert(offsetof(MainTaskPlayData, cachedFinalScore) == 0x9b0, "cachedFinalScore @ +0x9b0");
static_assert(offsetof(MainTaskPlayData, comboMilestoneShown) == 0x9c4,
              "comboMilestoneShown @ +0x9c4");
static_assert(offsetof(MainTaskPlayData, clearSeFired) == 0x9c8, "clearSeFired @ +0x9c8");
static_assert(offsetof(MainTaskPlayData, endAudioStopped) == 0x9e8, "endAudioStopped @ +0x9e8");
static_assert(offsetof(MainTaskPlayData, backBtnTouchId) == 0x9ec, "backBtnTouchId @ +0x9ec");
static_assert(offsetof(MainTaskPlayData, backBtnHoldStartMs) == 0x9f0,
              "backBtnHoldStartMs @ +0x9f0");
static_assert(offsetof(MainTaskPlayData, songFinishPos) == 0x9f8, "songFinishPos @ +0x9f8");
static_assert(offsetof(MainTaskPlayData, noteDrawScale) == 0x9bc, "noteDrawScale @ +0x9bc");
static_assert(offsetof(MainTaskPlayData, hudHidden) == 0x9c7, "hudHidden @ +0x9c7");
static_assert(offsetof(MainTaskPlayData, hitEffectScale) == 0x9e0, "hitEffectScale @ +0x9e0");
static_assert(offsetof(MainTaskPlayData, pauseBtnCenterX) == 0x98c, "pauseBtnCenterX @ +0x98c");
static_assert(offsetof(MainTaskPlayData, pauseBtnRadius) == 0x990, "pauseBtnRadius @ +0x990");
static_assert(offsetof(MainTaskPlayData, pauseBtnCenterY) == 0x994, "pauseBtnCenterY @ +0x994");
#endif // !__LP64__ (32-bit binary-exact layout guards)

// Run one play/judge pass over the global NoteMng's active notes.
//   playData  : the standard-mode MainTask play data.
//   touchXY   : current touch points as (x, y) float pairs in view pixels; a
//               negative x or y marks an empty/consumed slot. Up to 8 pairs.
//   touchIds  : the neGraphics touch id parallel to each touchXY pair (bound to
//   a
//               note when its tap lands, so the hold can track the same
//               finger).
//   touchCount: number of touch pairs.
// Ghidra: FUN_0002f1f8.
void PlayJudge_update(MainTaskPlayData *playData,
                      const float *touchXY,
                      const int *touchIds,
                      int touchCount);

// Play the per-tap feedback SE (retriggering it if already sounding), gated by
// the user's touch-sound volume and skipped while the pause menu is up. Called
// after a frame that resolved any note. (Despite the historical name it does
// NOT recompute the score/gauge — that is done by the play loop via
// PlayCurrentScore.) Ghidra: FUN_00031338.
void PlayScoreGaugeUpdate(MainTaskPlayData *playData);

// The note engine's miss callback: apply the BAD/miss gauge penalty to the play
// data (raise the missed flag, subtract gaugeLossMiss, clamp [0, 0x400]). The
// play scene registers this into NoteMng at chart load (initPlayDataWithData);
// detectMiss fires it when a note scrolls past un-tapped, so the life gauge
// drains on missed notes just as it does on a tapped BAD. `playData` is the
// owning MainTaskPlayData (passed as the callback arg). Ghidra: FUN_0003122c.
void PlayApplyMissGauge(void *playData);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
