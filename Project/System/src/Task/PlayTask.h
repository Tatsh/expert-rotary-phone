//
//  PlayTask.h
//  pop'n rhythmin
//
//  The standard-mode NOTE-PLAY task: the actual gameplay screen. It runs the play
//  clock, drives the per-frame note judge/render pass (PlayJudge_update / NoteMng),
//  handles the pause menu, fires combo SEs, watches the gauge + song end, and hands
//  off to the result screen. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (init PlayTask_init FUN_0002e2d8, update PlayTask_update FUN_0002dc14).
//
//  This task's storage IS the play data the judge pass operates on (state @ +0x9fc,
//  judge-state pool @ +0x3c8, scale/radius @ +0x974/+0x9b8 — see PlayJudge.h's
//  MainTaskPlayData). The heavy per-state screen geometry is delegated to the note
//  draw + pause-menu units.
//
//  ---- work area (this class IS the 0xa00-byte play-data struct) ----
//  C_TASK's base is exactly 0x28 bytes, so the members below land at their true binary
//  offsets. The whole body is memset 0 by playTask_ctor (@ 0x2db2c: memset +0x28..+0x9fc
//  == 0x9d4 bytes, then m_state @ +0x9fc). Every offset the reconstructed methods
//  (resetState / reloadChart / updateGauge / update) reach by flat `*(T*)(this+off)` is
//  named at its exact offset (with a `// +0xNN` comment); genuine gaps are `_rsvd_NN[]`
//  fillers. The device-branched HUD/layout tables that PlayTask_init fills by name
//  (texture handles @ +0x28, resolved Aep layer/frame/user-number tables @ +0xc4, pause-
//  menu + note-field + popkun geometry @ +0x978) are only partly reached by name here;
//  their un-accessed interior is kept as documented reserved fillers (the ROLES and the
//  control flow reading the named members are exact). The per-note judge pool @ +0x3c8 is
//  the real NoteJudgeState[60] array PlayJudge.h defines.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"
#include "PlayJudge.h"   // NoteJudgeState (the +0x3c8 pool element)

class AepLyrCtrl;
class neAppEventCenter;

class PlayTask : public C_TASK {
public:
    PlayTask();                          // Ghidra: MainTask spawns this; PlayTask_init
    ~PlayTask() override;                // @ 0x2db74 (taskNode_deleteB deleting-dtor: base + delete)
    void update(int deltaMs) override;   // Ghidra: PlayTask_update (FUN_0002dc14)

    // Reset the play scene for a fresh attempt: reload the chart, reset the animated
    // layers, zero the 0x3c-entry judge pool (@ +0x3c8, stride 0x18) with sequential
    // indices + -1 sentinels, and reset the gauge/score scalars (@ +0x9ac..+0x9dc).
    // Ghidra: playTaskResetState (FUN_0002fed8).
    void resetState();                   // @ 0x2fed8

    // Nudge the life gauge (@ +0x9c0, clamped to [0, 0x400]) by the per-mode delta:
    // mode 0 = miss/down (+0x9d4, also sets the "damaged" flag @ +0x9dc), 1 = good
    // (+0x9d0), 2/3 = great/perfect (+0x9cc). Ghidra: updateGaugeValue (FUN_000312cc).
    void updateGauge(int mode);          // @ 0x312cc

private:
    // Reload the chart into the play data (restart = the arg the reset path passes 1).
    // Ghidra: playTaskLoadChart — a PlayTask method (takes the play data as `this`).
    void reloadChart(int restart);       // @ 0x30720

    // ================= work-area layout (offsets are binary-exact) =================
    uint8_t _rsvd_28[0x84 - 0x28] = {};              // +0x28 chara / window / text textures
                                                     //       (neTextureForiOS*) built by init — seam
    // The two animated AepLyrCtrl layer banks: PlayTask_init operator_new's + AepLyrCtrl::init's
    // each element; resetState() rewinds every non-null layer. update() cues the combo-milestone
    // SEs off m_sceneLayers[4..10].
    AepLyrCtrl      *m_comboLayers[5] = {};          // +0x84 EFF_COM* combo-effect transports
    AepLyrCtrl      *m_sceneLayers[11] = {};         // +0x98 scene / HUD / combo-cue transports
    uint8_t _rsvd_c4[0x398 - 0xc4] = {};             // +0xc4 resolved Aep layer-no / frame-count /
                                                     //       user-no tables + anim frame counters
                                                     //       (init getLyrNo/getFrmNo/getUsrNo) — seam
    int              m_hitSeId = 0;                  // +0x398 per-tap hit-SE source id (reloadChart loadSe)
    uint8_t _rsvd_39c[0x3a0 - 0x39c] = {};           // +0x39c
    int              m_timingSeInst[2] = {};         // +0x3a0 timing-SE playing instances (-1 idle,
                                                     //        reaped each frame in update)
    uint8_t _rsvd_3a8[0x3c8 - 0x3a8] = {};           // +0x3a8 timing-SE source ids[3] (+0x3a8) +
                                                     //        note-anim frame counters (+0x3c0/+0x3c4)
    NoteJudgeState   m_judgePool[60] = {};           // +0x3c8 per-note judge slots (stride 0x18)
    neAppEventCenter *m_eventCenter = nullptr;       // +0x968 picked {musicId, sheet} carrier
    int              m_screenWidth = 0;              // +0x96c aep screen width
    int              m_screenHeight = 0;             // +0x970 aep screen height
    int              m_uiScale = 0;                  // +0x974 UI scale (g_dwUiScale; note/hit-test scale)
    int              m_pauseOriginX = 0;             // +0x978 pause-menu layout x origin
    uint8_t _rsvd_97c[0x9ac - 0x97c] = {};           // +0x97c pause-menu button rects + note-field /
                                                     //        popkun geometry (device-branched) — seam
    int16_t          m_gaugeBase = 0;                // +0x9ac default life-gauge base (g_wPlayDefaultGauge)
    uint8_t _rsvd_9ae[0x9b0 - 0x9ae] = {};           // +0x9ae
    int              m_score = 0;                    // +0x9b0 running score readout (PlayCurrentScore)
    int16_t          m_seVolume = 0;                 // +0x9b4 touch-sound volume (UserSettingData)
    uint8_t _rsvd_9b6[0x9c0 - 0x9b6] = {};           // +0x9b6 popkun radius (+0x9b8 float / +0x9bc fixed) — seam
    int16_t          m_gaugeValue = 0;               // +0x9c0 life-gauge value (0..0x400)
    int16_t          m_gaugeValueSub = 0;            // +0x9c2 secondary gauge word (reset with m_gaugeValue)
    uint8_t _rsvd_9c4[0x9c6 - 0x9c4] = {};           // +0x9c4
    uint8_t          m_bgmReady = 0;                 // +0x9c6 async BGM decode finished (state-2 gate)
    uint8_t          m_suppressHud = 0;              // +0x9c7 hide the HUD (teardown)
    uint8_t          m_endSeFired = 0;               // +0x9c8 one-shot song-end clear/rank-SE latch
    uint8_t          m_isDemoPlay = 0;               // +0x9c9 tutorial / auto-demo flag
                                                     //        (init from event-center +0x33)
    uint8_t          m_isPadDisplay = 0;             // +0x9ca pad-class display (g_bIsPadDisplay)
    uint8_t _rsvd_9cb[0x9cc - 0x9cb] = {};           // +0x9cb
    float            m_gaugeGainGreat = 0.0f;        // +0x9cc great / perfect gauge delta
    float            m_gaugeGainGood = 0.0f;         // +0x9d0 good gauge delta (1.0)
    float            m_gaugeLossMiss = 0.0f;         // +0x9d4 miss / down gauge delta (negative)
    int              m_damageAccum = 0;              // +0x9d8 damage accumulator (reset 0)
    uint8_t          m_damagedThisFrame = 0;         // +0x9dc took damage this frame (updateGauge)
    uint8_t _rsvd_9dd[0x9e0 - 0x9dd] = {};           // +0x9dd
    int              m_startHoldMs = 0;              // +0x9e0 device-branched start-hold ms (init 500/1000)
    uint8_t          m_optSimpleMode = 0;            // +0x9e4 UserSettingData isSimpleMode
    uint8_t          m_optEffectOn = 0;              // +0x9e5 UserSettingData isEffectOn
    uint8_t          m_optLongNoteEffect = 0;        // +0x9e6 UserSettingData isLongNotesEffectOn
    uint8_t          m_optOldHardware = 0;           // +0x9e7 AppDelegate isOldHardware
    uint8_t          m_stopped = 0;                  // +0x9e8 audio stopped (quit path)
    uint8_t _rsvd_9e9[0x9ec - 0x9e9] = {};           // +0x9e9
    int              m_backTouchId = -1;             // +0x9ec held back-tap touch id (-1 none)
    int              m_backTouchTime = 0;            // +0x9f0 getTimeMillis at back-tap start
    uint8_t _rsvd_9f4[0x9f8 - 0x9f4] = {};           // +0x9f4
    int              m_endPos = 0;                   // +0x9f8 NoteMng position latched at song end
    int              m_state = 0;                    // +0x9fc play state-machine field
};

// Play-scene lifecycle seams operating on the play-data block.
void PlayTaskInit(void *playData);       // Ghidra: FUN_0002e2d8 (allocate the scene)
void PlayTaskGotoResult(void *playData); // Ghidra: FUN_0003003c (transition to results)

// The current running score/gauge value used for end-of-song rank SEs.
int PlayCurrentScore();                  // Ghidra: FUN_0002ff7c
// Fire the song-clear rank jingle(s) chosen by the final score. Ghidra: the SE-
// instance cascade in PlayTask_update state 6 (FUN_0002cba4/0002cac0/0002cb24).
void PlayEndResultSe(void *playData, int score);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
