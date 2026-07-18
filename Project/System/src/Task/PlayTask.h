//
//  PlayTask.h
//  pop'n rhythmin
//
//  The standard-mode NOTE-PLAY task: the actual gameplay screen. It runs the
//  play clock, drives the per-frame note judge/render pass (playJudgeUpdate /
//  NoteMng), handles the pause menu, fires combo SEs, watches the gauge + song
//  end, and hands off to the result screen. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (init PlayTask_init FUN_0002e2d8, update
//  PlayTask_update FUN_0002dc14).
//
//  This task's storage IS the play data the judge pass operates on (state @
//  +0x9fc, judge-state pool @ +0x3c8, scale/radius @ +0x974/+0x9b8). The judge
//  pass is the member playJudgeUpdate() (its body lives in the note engine,
//  Game/Note/PlayJudge.mm); PlayJudge.h only declares the NoteJudgeState pool
//  element. The heavy per-state screen geometry is delegated to the note draw +
//  pause-menu units.
//
//  ---- work area (this class IS the 0xa00-byte play-data struct) ----
//  ne::C_TASK's base is exactly 0x28 bytes, so the members below land at their true
//  binary offsets. The whole body is memset 0 by playTask_ctor (@ 0x2db2c:
//  memset +0x28..+0x9fc
//  == 0x9d4 bytes, then m_state @ +0x9fc). Every offset the reconstructed
//  methods (resetState / reloadChart / updateGauge / update) reach by flat
//  `*(T*)(this+off)` is named at its exact offset (with a `// +0xNN` comment);
//  genuine gaps are `_rsvd_NN[]` fillers. The device-branched HUD/layout tables
//  that PlayTask_init fills by name (scene textures @ +0x28, resolved Aep
//  layer/frame/user-number tables @ +0xc4, pause- menu + note-field + popkun
//  geometry @ +0x978) are the members the play-scene lifecycle seams
//  (PlayScene.mm: PlayTaskInit / PlayBuildFieldLayers / PlayTaskDraw /
//  PlayTaskGotoResult) fill and read, so they are named here at their exact
//  offsets; the few sub-regions no reconstructed function reaches stay
//  documented `_rsvd_NN[]` fillers. The per-note judge pool @ +0x3c8 is the
//  real NoteJudgeState[60] array PlayJudge.h defines.
//

#pragma once

#include <cstdint>
#include <memory>
#include <span>

#include "C_TASK.h"
#include "PlayJudge.h" // NoteJudgeState (the +0x3c8 pool element)

class AepLyrCtrl;
class neAppEventCenter;
class neTextureForiOS;

// Indices into PlayTask::m_sceneLayers (the +0x98 bank of AepLyrCtrl layers, some
// driven as one-shot SE cues). [0..2] are the sustained combo-milestone effect
// tiers (the judge holds the crossed tier paused and resets the others); [4..10]
// are the song-clear rank jingles fired by playEndResultSe.
enum SceneLayer {
    kSceneComboTier5 = 0,       // sustained combo effect for combo band 5..9
    kSceneComboTier10 = 1,      // ...10..99
    kSceneComboTier100 = 2,     // ...100+
    kSceneLayer3 = 3,           // paused at song end (Ghidra: Pause(pAepLyrSub[3]))
    kSceneRankClearMiss = 4,    // score >= 70000, some GOOD/BAD, combo broken
    kSceneRankClearFC = 5,      // score >= 70000, some GOOD/BAD, full combo
    kSceneRankPerfectGreat = 6, // score >= 70000, no GOOD/BAD, at least one GREAT
    kSceneRankPerfectCool = 7,  // score >= 70000, no GOOD/BAD, all COOL
    kSceneRankFailMiss = 8,     // score < 70000, combo broken
    kSceneRankFailFC = 9,       // score < 70000, full combo
    kSceneRankFanfare = 10,     // clear fanfare, layered over the chosen rank jingle
};

// Indices into PlayTask::m_userSprite (the +0x2f8 user-no table). PlayTaskDraw
// dispatches on the AEP callback's `child` id by matching it against each slot,
// so these name the sprite each slot drives (verified against FUN_00030944).
enum UserSprite {
    kUserSpriteGaugeFlash = 0, // GG_IFL gauge-flash frames
    kUserSpritePauseCmd = 1,   // CMD_PAUSE_1 pause command icon
    kUserSpriteToneLane = 2,   // TONE_1 tone-lane graphic
    kUserSpriteToneNumber = 3, // TONE_08_NUM tone-number overlay
    kUserSpritePauseEye0 = 4,  // ORB_EYES_* pause-eye tone frames [4..8]
    kUserSpritePauseEye1 = 5,
    kUserSpritePauseEye2 = 6,
    kUserSpritePauseEye3 = 7,
    kUserSpritePauseEye4 = 8,
    kUserSpriteBgColor = 9,       // BG_CL_COLOR background colour layer
    kUserSpriteScoreStar = 10,    // FRAME_STAR score-star badge
    kUserSpriteGaugeSideBar = 11, // FRAME_SIDEBAR gauge side bar
    kUserSpriteComboDigit1 = 12,  // EFF_C_NUM001/010/100 on-field combo digits
    kUserSpriteComboDigit10 = 13,
    kUserSpriteComboDigit100 = 14,
};

// PlayTask::m_state (+0x9fc) play state-machine values, in the order update()
// walks them (Ghidra: FUN_0002dc14).
enum PlayState {
    kPlayStateInit = 0,        // allocate the play scene, then fall through
    kPlayStateBringUp = 1,     // NoteMng bring-up, fade in, pause the intro layers
    kPlayStateReady = 2,       // draw the field; on BGM-ready cue the "go" voice
    kPlayStateRetry = 3,       // after a fade, rebuild the play and restart
    kPlayStateWaitIntro = 4,   // wait for the intro layer, then start the clock
    kPlayStatePauseMenu = 5,   // hit-test resume/retry/quit, draw the menu + field
    kPlayStatePlaying = 6,     // drive the note engine: judge, gauge, song-end
    kPlayStateQuit = 7,        // stop all audio, latch stopped, fall into fade-out
    kPlayStateFadeOut = 8,     // start the fade-out transition
    kPlayStateWaitFade = 9,    // wait for the fade-out to finish
    kPlayStateGotoResult = 10, // hand off to the result screen
};

// The clear/fail score boundary. A score at or above this is the "clear" tier
// (hi fever-gauge layer, high end-of-song voice, lit score star, clear rank
// jingles); below it is the "fail" tier. The same line is rank 5's lower bound
// in scoreToRank. Ghidra compares against 0x1116f (69999) with a signed bgt.
inline constexpr int kScoreClearThreshold = 70000;

class PlayTask : public ne::C_TASK {
public:
    PlayTask();                        // Ghidra: MainTask spawns this; PlayTask_init
    ~PlayTask() override;              // @ 0x2db74 (taskNode_deleteB deleting-dtor: base + delete)
    void update(int deltaMs) override; // Ghidra: PlayTask_update (FUN_0002dc14)

    // Reset the play scene for a fresh attempt: reload the chart, reset the
    // animated layers, zero the 0x3c-entry judge pool (@ +0x3c8, stride 0x18)
    // with sequential indices + -1 sentinels, and reset the gauge/score scalars
    // (@ +0x9ac..+0x9dc). Ghidra: playTaskResetState (FUN_0002fed8).
    void resetState(); // @ 0x2fed8

    // Nudge the life gauge (@ +0x9c0, clamped to [0, 0x400]) by the per-mode
    // delta: mode 0 = miss/down (+0x9d4, also sets the "damaged" flag @ +0x9dc),
    // 1 = good
    // (+0x9d0), 2/3 = great/perfect (+0x9cc). Ghidra: updateGaugeValue
    // (FUN_000312cc).
    void updateGauge(int mode); // @ 0x312cc

private:
    // Reload the chart into the play data (restart = the arg the reset path
    // passes 1). Ghidra: playTaskLoadChart — a PlayTask method (takes the play
    // data as `this`).
    void reloadChart(int restart); // @ 0x30720

    // Draw the per-frame note-play HUD (score/best/combo gauges, the fever gauge,
    // the gauge-overflow band and the eased scrub/gauge bar), keyed off the
    // NoteMng beat phase and the running score/combo. Called from update()'s tail
    // while the task is not finishing (m_suppressHud == 0). Ghidra:
    // PlayTask::DrawHud (FUN_000303fc).
    void DrawHud(); // @ 0x303fc

    // The per-frame note judge/render pass: hit-tests the touches against the
    // active notes, dispatches to NoteMng, resolves holds, draws each note + its
    // effects, and fires the combo-milestone bursts. update() calls it every
    // frame. Body lives in the note engine (Game/Note/PlayJudge.mm). Ghidra:
    // FUN_0002f1f8 (MainTask::PlayJudgeUpdate). touchXY is a fixed 8-pair (x, y)
    // block (a negative coordinate marks an empty slot); touchIds carries the
    // parallel neGraphics touch ids for the live touches, its size being the
    // touch count the binary passes separately.
    void playJudgeUpdate(const float *touchXY, std::span<const int> touchIds);

    // Play the per-tap feedback SE, restarting any still-playing instance, gated
    // by the touch-sound volume and skipped during the pause menu; playJudgeUpdate
    // calls it after a frame that resolved a note. Body in PlayScore.mm. Ghidra:
    // FUN_00031338 (PlayTask::PlayTouchSound).
    void playTouchSound();

    // Fire the song-clear rank jingle(s) chosen by the final score, layering the
    // clear fanfare over the chosen jingle. update() state 6 calls it. Body in
    // PlayScore.mm. Ghidra: the SE-instance cascade inlined in PlayTask_update
    // state 6 (FUN_0002cba4 / 0002cac0 / 0002cb24 on the m_sceneLayers cue layers).
    void playEndResultSe(int score);

    // Fire one m_sceneLayers cue layer (an AepLyrCtrl driven as an SE) if it is
    // idle -- the "if not busy, play" idiom the rank cascade repeats.
    void firePlayCue(int layer);

public:
    // ================= work-area layout (offsets are binary-exact)
    // ================= This is a flat engine work area the whole play scene
    // shares: the state-machine member update()/resetState()/updateGauge() and
    // the free play-scene lifecycle seams in PlayScene.mm (PlayTaskInit,
    // PlayBuildFieldLayers, PlayLoadCharaTextures, PlayTaskDraw,
    // PlayTaskGotoResult — some are C callbacks that must stay free functions)
    // all reach these fields, so they are public named members rather than raw
    // `*(T*)(this+off)` offset access.

    // +0x28 scene textures (neTextureForiOS*), allocated by PlayLoadCharaTextures
    // and freed in PlayTaskGotoResult. Slot 1 of the first pair is the demo
    // window frame (t_window @ +0x2c).
    std::unique_ptr<neTextureForiOS> m_windowTex[2];   // +0x28 window-frame texture pair
    std::unique_ptr<neTextureForiOS> m_charaTex[8];    // +0x30 character portrait textures
    std::unique_ptr<neTextureForiOS> m_textPanels[13]; // +0x50 demo text-panel textures

    // The two animated AepLyrCtrl layer banks: PlayTask_init operator_new's +
    // AepLyrCtrl::init's each element; resetState() rewinds every non-null layer.
    // update() cues the combo-milestone SEs off m_sceneLayers[4..10].
    std::unique_ptr<AepLyrCtrl> m_comboLayers[5];  // +0x84 EFF_COM* combo-effect transports
    std::unique_ptr<AepLyrCtrl> m_sceneLayers[11]; // +0x98 scene / HUD / combo-cue transports

    // +0xc4 resolved Aep layer-no / frame-count / user-no tables.
    // PlayBuildFieldLayers fills them (AepManager getLyrNo / layerFrameCount /
    // getFrmNo / getUsrNo); PlayTaskDraw reads them to pick each note / digit /
    // tone / chara sprite. Names track the getLyrNo/getFrmNo tables.
    int m_toneJudgeLyr[4] = {};    // +0xc4  TONE_DEFAULT/NEAR/OUT_0/OUT_1 lyr handles
    int m_toneJudgeFrames[4] = {}; // +0xd4  ...their frame counts
    int m_effectStateLyr[14] = {}; // +0xe4  GG_HANTEI..EFF_HIT lyr handles;
                                   //        [6]/[7]=FRAME_SIDEMT_BARSTAR0/1 @+0xfc/+0x100,
    //        [8]=FRAME_SIDEMT_BAR @+0x104, [11]=BGMT_CD_COLOR @+0x110
    int m_effectStateFrames[14] = {}; // +0x11c ...frame counts ([8]=BAR length @+0x13c)
    int m_scoreBpmLyr[5] = {};        // +0x154 BPM / score lyr handles
    int m_scoreBpmFrames[5] = {};     // +0x168 ...frame counts
    int m_charaJumpLyr[8] = {};       // +0x17c BGMTBPM1_CHARAn_JUMP lyr handles
    // +0x19c a 64-byte gap in the chara-jump tables. A program-wide instruction
    // search finds no PlayTask access to this offset (every #0x19c reference
    // belongs to another task / struct, or is a stack / literal-pool slot), so it
    // is a dead gap rather than a live per-chara table.
#ifndef ENABLE_PATCHES
    uint8_t unused_19c[0x1dc - 0x19c] =
        {}; // +0x19c unused 64-byte gap (Ghidra: no PlayTask access)
#endif
    int m_charaJumpFrames[8] = {}; // +0x1dc ...chara-jump layer frame counts
    int m_pauseEyeToneFrm[8] = {}; // +0x1fc CMD_PAUSE_1_F / ORB_EYES / TONE_L1_2 frame nos
    int m_barSegFrame = 0;         // +0x21c long-note connecting-bar segment frame
                                   //        (getFrmNo; judge draws it via drawAepFrameEx)
    int m_scoreDigitFrm[10] = {};  // +0x220 SCO_0..9 frame nos
    int m_comboDigitFrm[10] = {};  // +0x248 EFF_C_NUM0..9 frame nos
    int m_gaugeFlashFrm[4] = {};   // +0x270 GG_IFL_* frame nos
    int m_tone08Frm[5] = {};       // +0x280 TONE_08_1.. frame nos
    int m_tone08NumFrm[5] = {};    // +0x294 TONE_08_NUM2.. frame nos
    int m_toneNumberFrm[10] = {};  // +0x2a8 tone-number frame nos
    int m_toneSameFrm[10] = {};    // +0x2d0 tone-same frame nos
    int m_userSprite[15] = {};     // +0x2f8 GG_IFL..EFF_C_NUM100 user nos (indices
                                   //        map to the CMD_PAUSE/TONE/ORB/FRAME reads)
    int m_numComboUser[3] = {};    // +0x334 NUM_COMBO_* user nos
    int m_scoreNumUser[6] = {};    // +0x340 SCO_0000NN user nos
    int m_charaUser[8] = {};       // +0x358 CHARAn user nos
    int m_charaAnmUser[8] = {};    // +0x378 CHARAn_ANM user nos

    int m_hitSeId = 0;          // +0x398 per-tap hit-SE source id (reloadChart loadSe)
    int m_gaugeSeId = 0;        // +0x39c second gauge/tap SE source id (freed in gotoResult)
    int m_timingSeInst[2] = {}; // +0x3a0 timing-SE playing instances (-1 idle,
                                //        reaped each frame in update)
    int m_playSeIds[3] = {};    // +0x3a8 v12/v29/v30 play-SE source ids
    uint8_t _pad_3b4[0x3b8 - 0x3b4] = {}; // +0x3b4 4-byte gap; no play-task access (only
                                          //        pc-relative literals alias this offset)
    int m_scrubBarFrame = 0;              // +0x3b8 gauge/scrub-bar eased frame (DrawHud)
    int m_cdColorFrame = 0;               // +0x3bc BGMT_CD_COLOR anim frame / HUD fever-loop frame
    int m_barStarFrame = 0;               // +0x3c0 FRAME_SIDEMT_BARSTAR1 anim frame (update wraps)
    int m_cdFrame = 0;                    // +0x3c4 BGMT_CD anim frame (update wraps)
    NoteJudgeState m_judgePool[60] = {};  // +0x3c8 per-note judge slots (stride 0x18)
    neAppEventCenter *m_eventCenter = nullptr; // +0x968 picked {musicId, sheet} carrier
    int m_screenWidth = 0;                     // +0x96c aep screen width
    int m_screenHeight = 0;                    // +0x970 aep screen height
    float m_uiScale = 0.0f;                    // +0x974 UI scale (g_uiScale; the judge and the
    //        note draw read it directly as a float)
    int m_pauseOriginX = 0; // +0x978 pause-menu layout x origin
    // +0x97c device-branched pause-menu + note-field geometry (phone/pad
    // constants). The pause fields are verified against the state-5/6 hit tests
    // in PlayTask_update; the note-field fields are consumed by the delegated
    // note-quad draw.
    int m_pauseBtnResumeX = 0; // +0x97c pause button 0 (resume) x
    int m_pauseBtnRetryX = 0;  // +0x980 pause button 1 (retry) x
    int m_pauseBtnQuitX = 0;   // +0x984 pause button 2 (quit) x
    int m_pauseBtnWidth = 0;   // +0x988 pause-menu button hit width
    int m_pauseTapCenterX = 0; // +0x98c in-play pause-tap hit-circle center x
    int m_pauseTapCenterY = 0; // +0x990 in-play pause-tap hit-circle center y
    int m_pauseTapRadius = 0;  // +0x994 in-play pause-tap hit-circle radius
    // Long-note connecting-bar geometry (judge FUN_0002f1f8: len = fade*scale +
    // base, drawn along the head->target angle; priority halved into the anchor).
    int m_barLenScale = 0;                // +0x998 bar length gain per fade
    int m_barSegLyr1 = 0;                 // +0x99c second bar-segment layer id
    int m_barPriority = 0;                // +0x9a0 bar draw priority (halved)
    int m_barLenBase = 0;                 // +0x9a4 bar length base
    int m_charaDrawSize = 0;              // +0x9a8 chara portrait draw size (PlayTaskDraw)
    int16_t m_gaugeBase = 0;              // +0x9ac default life-gauge base (g_wPlayDefaultGauge)
    uint8_t _pad_9ae[0x9b0 - 0x9ae] = {}; // +0x9ae alignment before m_score (no access)
    int m_score = 0;                      // +0x9b0 running score readout (PlayCurrentScore)
    int16_t m_seVolume = 0;               // +0x9b4 touch-sound volume (UserSettingData)
    uint8_t _pad_9b6[0x9b8 - 0x9b6] = {}; // +0x9b6 alignment before m_hitRadius (no access)
    float m_hitRadius = 0.0f; // +0x9b8 note hit-test radius (read as float by PlayJudge)
    int m_popkunSize = 0;     // +0x9bc note ("popkun") size, 16.16 fixed
    int16_t m_gaugeValue = 0; // +0x9c0 life-gauge value (0..0x400)
    // +0x9c2 combo-milestone re-trigger guard: the judge sets it to the current
    // combo count each frame and compares it against the 25 / 50 / every-50 past
    // 100 thresholds to fire each milestone burst once.
    int16_t m_comboMilestoneGuard = 0; // +0x9c2 previous combo count (milestone guard)
    // +0x9c4 the combo milestone just celebrated (25 / 50 / 100+): the judge
    // records the crossed value here as it stops the matching burst layer.
    int16_t m_comboMilestoneShown = 0;    // +0x9c4 last combo milestone celebrated
    bool m_bgmReady = false;              // +0x9c6 async BGM decode finished (state-2 gate)
    bool m_suppressHud = false;           // +0x9c7 hide the HUD (teardown)
    bool m_endSeFired = false;            // +0x9c8 one-shot song-end clear/rank-SE latch
    bool m_isDemoPlay = false;            // +0x9c9 tutorial / auto-demo flag
                                          //        (init from event-center +0x33)
    bool m_isPadDisplay = false;          // +0x9ca pad-class display (g_bIsPadDisplay)
    uint8_t _pad_9cb[0x9cc - 0x9cb] = {}; // +0x9cb alignment before the gauge floats (no access)
    float m_gaugeGainGreat = 0.0f;        // +0x9cc great / perfect gauge delta
    float m_gaugeGainGood = 0.0f;         // +0x9d0 good gauge delta (1.0)
    float m_gaugeLossMiss = 0.0f;         // +0x9d4 miss / down gauge delta (negative)
    int m_damageAccum = 0;                // +0x9d8 damage accumulator (reset 0)
    bool m_damagedThisFrame = false;      // +0x9dc took damage this frame (updateGauge)
    uint8_t _pad_9dd[0x9e0 - 0x9dd] = {}; // +0x9dd alignment before m_hitEffectScale (no access)
    int m_hitEffectScale = 0;             // +0x9e0 note hit-effect extent (init 500/1000); the
                                          //        judge passes its half (/2) as the draw scale
    bool m_optSimpleMode = false;         // +0x9e4 UserSettingData isSimpleMode
    bool m_optEffectOn = false;           // +0x9e5 UserSettingData isEffectOn
    bool m_optLongNoteEffect = false;     // +0x9e6 UserSettingData isLongNotesEffectOn
    bool m_optOldHardware = false;        // +0x9e7 AppDelegate isOldHardware
    bool m_stopped = false;               // +0x9e8 audio stopped (quit path)
    uint8_t _pad_9e9[0x9ec - 0x9e9] = {}; // +0x9e9 alignment before m_backTouchId (no access)
    int m_backTouchId = -1;               // +0x9ec held back-tap touch id (-1 none)
    int m_backTouchTime = 0;              // +0x9f0 getTimeMillis at back-tap start
    int m_beatPulse = 0;                  // +0x9f4 demo chara-window beat pulse (0..100)
    int m_endPos = 0;                     // +0x9f8 NoteMng position latched at song end
    int m_state = 0;                      // +0x9fc play state-machine field (PlayState)
};

// Play-scene lifecycle seams operating on the play-data block.
void PlayTaskInit(void *playData);       // Ghidra: FUN_0002e2d8 (allocate the scene)
void PlayTaskGotoResult(void *playData); // Ghidra: FUN_0003003c (transition to results)

// The current running score/gauge value used for end-of-song rank SEs.
int PlayCurrentScore(); // Ghidra: FUN_0002ff7c

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
