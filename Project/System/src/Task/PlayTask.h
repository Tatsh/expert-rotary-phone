/**
 * @file
 * @brief The standard-mode note-play task: the gameplay screen itself.
 *
 * It runs the play clock, drives the per-frame note judge and render pass (playJudgeUpdate,
 * NoteMng), handles the pause menu, fires combo SEs, watches the gauge and song end, and hands
 * off to the result screen. Reconstructed from Ghidra project rb420, program PopnRhythmin (init
 * PlayTask_init FUN_0002e2d8, update PlayTask_update FUN_0002dc14).
 *
 * This task's storage IS the play data the judge pass operates on (state @ +0x9fc, judge-state
 * pool @ +0x3c8, scale and radius @ +0x974/+0x9b8). The judge pass is the member
 * playJudgeUpdate(), whose body lives in the note engine (Game/Note/PlayJudge.mm); PlayJudge.h
 * only declares the NoteJudgeState pool element. The heavy per-state screen geometry is delegated
 * to the note draw and pause-menu units.
 *
 * Work area (this class IS the 0xa00-byte play-data struct): ne::C_TASK's base is exactly 0x28
 * bytes, so the members below land at their true binary offsets. The whole body is memset 0 by
 * playTask_ctor (@ 0x2db2c: memset +0x28..+0x9fc, 0x9d4 bytes, then m_state @ +0x9fc). Every
 * offset the reconstructed methods (resetState, reloadChart, updateGauge, update) reach by flat
 * `*(T*)(this+off)` is named at its exact offset (with a `// +0xNN` comment); genuine gaps are
 * `_rsvd_NN[]` fillers. The device-branched HUD and layout tables that PlayTask_init fills by
 * name (scene textures @ +0x28, resolved Aep layer, frame, and user-number tables @ +0xc4,
 * pause-menu, note-field, and popkun geometry @ +0x978) are the members the play-scene lifecycle
 * seams (PlayScene.mm: PlayTaskInit, PlayBuildFieldLayers, PlayTaskDraw, PlayTaskGotoResult) fill
 * and read, so they are named here at their exact offsets; the few sub-regions no reconstructed
 * function reaches stay documented `_rsvd_NN[]` fillers. The per-note judge pool @ +0x3c8 is the
 * real NoteJudgeState[60] array PlayJudge.h defines.
 */

#pragma once

#include <cstdint>
#include <memory>
#include <span>

#import <Foundation/Foundation.h>

#include "C_TASK.h"
#include "PlayJudge.h" // NoteJudgeState (the +0x3c8 pool element)

class AepLyrCtrl;
class neAppEventCenter;
class neTextureForiOS;

/**
 * @brief Indices into PlayTask::m_sceneLayers, the +0x98 bank of AepLyrCtrl layers, some driven
 * as one-shot SE cues.
 *
 * Slots 0..2 are the sustained combo-milestone effect tiers; the judge holds the crossed tier
 * paused and resets the others. Slots 4..10 are the song-clear rank jingles playEndResultSe
 * fires.
 */
enum SceneLayer {
    kSceneComboTier5 = 0,   /**< Sustained combo effect for the combo band 5..9. */
    kSceneComboTier10 = 1,  /**< Sustained combo effect for the combo band 10..99. */
    kSceneComboTier100 = 2, /**< Sustained combo effect for combos of 100 or more. */
    /** Paused at song end (Ghidra: Pause(pAepLyrSub[3])). */
    kSceneLayer3 = 3,
    kSceneRankClearMiss = 4,    /**< Score 70000 or above, some GOOD or BAD, combo broken. */
    kSceneRankClearFC = 5,      /**< Score 70000 or above, some GOOD or BAD, full combo. */
    kSceneRankPerfectGreat = 6, /**< Score 70000 or above, no GOOD or BAD, at least one GREAT. */
    kSceneRankPerfectCool = 7,  /**< Score 70000 or above, no GOOD or BAD, all COOL. */
    kSceneRankFailMiss = 8,     /**< Score below 70000, combo broken. */
    kSceneRankFailFC = 9,       /**< Score below 70000, full combo. */
    kSceneRankFanfare = 10,     /**< Clear fanfare, layered over the chosen rank jingle. */
};

/**
 * @brief Indices into PlayTask::m_scoreBpmLyr and m_scoreBpmFrames, the +0x154 and +0x168 handle
 * and frame-count tables.
 *
 * The names come from the getLyrNo source layer names.
 */
enum ScoreBpmLayer {
    kScoreBpmScoreGauge = 0, /**< BG_*_BPM2SCORE, the score gauge; skipped in the auto-demo. */
    kScoreBpmBestGauge = 1,  /**< BG_*_BPM0, the best gauge; effects-on only. */
    kScoreBpmComboGauge = 2, /**< BG_*_BPM1, the combo gauge; always drawn. */
    kScoreBpmFeverLo = 3,    /**< BGMTSCO_TW0_*, the fever gauge for a score below 70000. */
    kScoreBpmFeverHi = 4,    /**< BGMTSCO_TW1_*, the fever gauge for a score of 70000 or above. */
};

/**
 * @brief Indices into PlayTask::m_effectStateLyr and m_effectStateFrames, the +0xe4 and +0x11c
 * tables, in the order kEffectStateNames resolves them.
 */
enum EffectStateLayer {
    kEffectStateGgHantei = 0,    /**< GG_HANTEI, the judge-ground flash. */
    kEffectStateNearUnder = 1,   /**< EFF_NEAR_UNDER. */
    kEffectStateHitOver = 2,     /**< EFF_HIT_OVER. */
    kEffectStateHitOver2 = 3,    /**< EFF_HIT_OVER2. */
    kEffectStateHitOverMore = 4, /**< EFF_HIT_OVER_MORE. */
    kEffectStatePauseLoop = 5,   /**< PAUSE_LOOP, the pause-menu overlay layer. */
    kEffectStateBarStar0 = 6,    /**< FRAME_SIDEMT_BARSTAR0. */
    kEffectStateBarStar1 = 7,    /**< FRAME_SIDEMT_BARSTAR1. */
    /** FRAME_SIDEMT_BAR, the fever bar; slot 8's frame count is its length. */
    kEffectStateBar = 8,
    kEffectStateTwl0Start = 9, /**< BGMTSCO_TWL0_START. */
    kEffectStateCd = 10,       /**< BGMT_CD. */
    kEffectStateCdColor = 11,  /**< BGMT_CD_COLOR. */
    /** EFF_HIT_LONG; slot 12's frame count is the CD-jacket length. */
    kEffectStateHitLong = 12,
    kEffectStateHit = 13, /**< EFF_HIT. */
};

/**
 * @brief Indices into PlayTask::m_userSprite, the +0x2f8 user-no table.
 *
 * PlayTaskDraw dispatches on the AEP callback's `child` id by matching it against each slot, so
 * these name the sprite each slot drives (verified against FUN_00030944).
 */
enum UserSprite {
    kUserSpriteGaugeFlash = 0,    /**< GG_IFL gauge-flash frames. */
    kUserSpritePauseCmd = 1,      /**< CMD_PAUSE_1, the pause command icon. */
    kUserSpriteToneLane = 2,      /**< TONE_1, the tone-lane graphic. */
    kUserSpriteToneNumber = 3,    /**< TONE_08_NUM, the tone-number overlay. */
    kUserSpritePauseEye0 = 4,     /**< First of the ORB_EYES_* pause-eye tone frames. */
    kUserSpritePauseEye1 = 5,     /**< Second ORB_EYES_* pause-eye tone frame. */
    kUserSpritePauseEye2 = 6,     /**< Third ORB_EYES_* pause-eye tone frame. */
    kUserSpritePauseEye3 = 7,     /**< Fourth ORB_EYES_* pause-eye tone frame. */
    kUserSpritePauseEye4 = 8,     /**< Fifth ORB_EYES_* pause-eye tone frame. */
    kUserSpriteBgColor = 9,       /**< BG_CL_COLOR, the background colour layer. */
    kUserSpriteScoreStar = 10,    /**< FRAME_STAR, the score-star badge. */
    kUserSpriteGaugeSideBar = 11, /**< FRAME_SIDEBAR, the gauge side bar. */
    kUserSpriteComboDigit1 = 12,  /**< EFF_C_NUM001, the on-field combo units digit. */
    kUserSpriteComboDigit10 = 13, /**< EFF_C_NUM010, the on-field combo tens digit. */
    /** EFF_C_NUM100, the on-field combo hundreds digit. */
    kUserSpriteComboDigit100 = 14,
};

/**
 * @brief PlayTask::m_state (+0x9fc) play state-machine values, in the order update() walks them.
 *
 * Ghidra: FUN_0002dc14.
 */
enum PlayState {
    kPlayStateInit = 0,      /**< Allocate the play scene, then fall through. */
    kPlayStateBringUp = 1,   /**< NoteMng bring-up, fade in, pause the intro layers. */
    kPlayStateReady = 2,     /**< Draw the field; on the BGM-ready cue, play the "go" voice. */
    kPlayStateRetry = 3,     /**< After a fade, rebuild the play and restart. */
    kPlayStateWaitIntro = 4, /**< Wait for the intro layer, then start the clock. */
    /** Hit-test resume, retry, and quit, and draw the menu over the field. */
    kPlayStatePauseMenu = 5,
    kPlayStatePlaying = 6,     /**< Drive the note engine: judge, gauge, and song end. */
    kPlayStateQuit = 7,        /**< Stop all audio, latch stopped, and fall into the fade-out. */
    kPlayStateFadeOut = 8,     /**< Start the fade-out transition. */
    kPlayStateWaitFade = 9,    /**< Wait for the fade-out to finish. */
    kPlayStateGotoResult = 10, /**< Hand off to the result screen. */
};

/**
 * @brief The clear and fail score boundary.
 *
 * A score at or above this is the "clear" tier: the hi fever-gauge layer, the high end-of-song
 * voice, a lit score star, and the clear rank jingles. Below it is the "fail" tier. The same line
 * is rank 5's lower bound in scoreToRank. Ghidra compares against 0x1116f (69999) with a signed
 * bgt.
 */
inline constexpr int kScoreClearThreshold = 70000;

/**
 * @brief The standard-mode note-play task: the play scene's state machine, HUD and judge pass.
 *
 * This class is also the flat engine work area the whole play scene shares.
 */
class PlayTask : public ne::C_TASK {
public:
    /**
     * @brief Construct the play task. MainTask spawns it (Ghidra: PlayTask_init).
     */
    PlayTask();
    /**
     * @brief Tear the play task down.
     * @ghidraAddress 0x2db74
     */
    ~PlayTask() override;
    /**
     * @brief Per-frame play tick: advance the play-state machine, run the judge pass and draw the
     * HUD.
     * @param deltaMs Milliseconds elapsed since the previous scheduler tick.
     * @ghidraAddress 0x2dc14
     */
    void update(int deltaMs) override;

    /**
     * @brief Reset the play scene for a fresh attempt.
     *
     * Reloads the chart, resets the animated layers, zeroes the 0x3c-entry judge pool (@ +0x3c8,
     * stride 0x18) with sequential indices and -1 sentinels, and resets the gauge and score
     * scalars (@ +0x9ac..+0x9dc).
     * @ghidraAddress 0x2fed8
     */
    void resetState();

    /**
     * @brief Nudge the life gauge (@ +0x9c0, clamped to [0, 0x400]) by the per-mode delta.
     * @param mode 0 for miss/down (+0x9d4, which also sets the "damaged" flag @ +0x9dc), 1 for
     * good (+0x9d0), 2 or 3 for great/perfect (+0x9cc).
     * @ghidraAddress 0x312cc
     */
    void updateGauge(int mode);

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
    void playJudgeUpdate(std::span<const float> touchXY, std::span<const int> touchIds);

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
    std::unique_ptr<neTextureForiOS> m_windowTex[2];   /**< +0x28 Window-frame texture pair. */
    std::unique_ptr<neTextureForiOS> m_charaTex[8];    /**< +0x30 Character portrait textures. */
    std::unique_ptr<neTextureForiOS> m_textPanels[13]; /**< +0x50 Demo text-panel textures. */

    // The two animated AepLyrCtrl layer banks: PlayTask_init operator_new's +
    // AepLyrCtrl::init's each element; resetState() rewinds every non-null layer.
    // update() cues the combo-milestone SEs off m_sceneLayers[4..10].
    std::unique_ptr<AepLyrCtrl> m_comboLayers[5]; /**< +0x84 EFF_COM* combo-effect transports. */
    /** +0x98 Scene / HUD / combo-cue transports. */
    std::unique_ptr<AepLyrCtrl> m_sceneLayers[11];

    // +0xc4 resolved Aep layer-no / frame-count / user-no tables.
    // PlayBuildFieldLayers fills them (AepManager getLyrNo / layerFrameCount /
    // getFrmNo / getUsrNo); PlayTaskDraw reads them to pick each note / digit /
    // tone / chara sprite. Names track the getLyrNo/getFrmNo tables.
    int m_toneJudgeLyr[4] = {};    /**< +0xc4 TONE_DEFAULT/NEAR/OUT_0/OUT_1 layer handles. */
    int m_toneJudgeFrames[4] = {}; /**< +0xd4 Frame counts of the m_toneJudgeLyr layers. */
    /**
     * +0xe4 GG_HANTEI..EFF_HIT layer handles. [6] and [7] are FRAME_SIDEMT_BARSTAR0/1 (@ +0xfc
     * and +0x100), [8] is FRAME_SIDEMT_BAR (@ +0x104) and [11] is BGMT_CD_COLOR (@ +0x110).
     */
    int m_effectStateLyr[14] = {};
    /** +0x11c Frame counts of the m_effectStateLyr layers; [8] is the bar length (@ +0x13c). */
    int m_effectStateFrames[14] = {};
    int m_scoreBpmLyr[5] = {};    /**< +0x154 BPM / score layer handles. */
    int m_scoreBpmFrames[5] = {}; /**< +0x168 Frame counts of the m_scoreBpmLyr layers. */
    int m_charaJumpLyr[8] = {};   /**< +0x17c BGMTBPM1_CHARAn_JUMP layer handles. */
    // +0x19c a 64-byte gap in the chara-jump tables. A program-wide instruction
    // search finds no PlayTask access to this offset (every #0x19c reference
    // belongs to another task / struct, or is a stack / literal-pool slot), so it
    // is a dead gap rather than a live per-chara table.
#ifndef ENABLE_PATCHES
    /** +0x19c Unused 64-byte gap (Ghidra: no PlayTask access). */
    uint8_t unused_19c[0x1dc - 0x19c] = {};
#endif
    int m_charaJumpFrames[8] = {}; /**< +0x1dc Frame counts of the chara-jump layers. */
    /** +0x1fc CMD_PAUSE_1_F / ORB_EYES / TONE_L1_2 frame numbers. */
    int m_pauseEyeToneFrm[8] = {};
    /** +0x21c Long-note connecting-bar segment frame; the judge draws it via drawAepFrameEx. */
    int m_barSegFrame = 0;
    int m_scoreDigitFrm[10] = {}; /**< +0x220 SCO_0..9 frame numbers. */
    int m_comboDigitFrm[10] = {}; /**< +0x248 EFF_C_NUM0..9 frame numbers. */
    int m_gaugeFlashFrm[4] = {};  /**< +0x270 GG_IFL_* frame numbers. */
    int m_tone08Frm[5] = {};      /**< +0x280 TONE_08_1.. frame numbers. */
    int m_tone08NumFrm[5] = {};   /**< +0x294 TONE_08_NUM2.. frame numbers. */
    int m_toneNumberFrm[10] = {}; /**< +0x2a8 Tone-number frame numbers. */
    int m_toneSameFrm[10] = {};   /**< +0x2d0 Tone-same frame numbers. */
    /** +0x2f8 GG_IFL..EFF_C_NUM100 user numbers; indices map to the
     * CMD_PAUSE/TONE/ORB/FRAME reads. */
    int m_userSprite[15] = {};
    int m_numComboUser[3] = {}; /**< +0x334 NUM_COMBO_* user numbers. */
    int m_scoreNumUser[6] = {}; /**< +0x340 SCO_0000NN user numbers. */
    int m_charaUser[8] = {};    /**< +0x358 CHARAn user numbers. */
    int m_charaAnmUser[8] = {}; /**< +0x378 CHARAn_ANM user numbers. */

    int m_hitSeId = 0;   /**< +0x398 Per-tap hit-SE source id, loaded by reloadChart. */
    int m_gaugeSeId = 0; /**< +0x39c Second gauge/tap SE source id, freed in gotoResult. */
    /** +0x3a0 Timing-SE playing instances; -1 when idle, reaped each frame in update(). */
    int m_timingSeInst[2] = {};
    int m_playSeIds[3] = {}; /**< +0x3a8 The v12/v29/v30 play-SE source ids. */
    /** +0x3b4 4-byte gap; no play-task access (only pc-relative literals alias this offset). */
    uint8_t _pad_3b4[0x3b8 - 0x3b4] = {};
    int m_scrubBarFrame = 0; /**< +0x3b8 Gauge/scrub-bar eased frame, driven by DrawHud(). */
    int m_cdColorFrame = 0;  /**< +0x3bc BGMT_CD_COLOR animation / HUD fever-loop frame. */
    /** +0x3c0 FRAME_SIDEMT_BARSTAR1 animation frame; update() wraps it. */
    int m_barStarFrame = 0;
    int m_cdFrame = 0;                   /**< +0x3c4 BGMT_CD animation frame; update() wraps it. */
    NoteJudgeState m_judgePool[60] = {}; /**< +0x3c8 Per-note judge slots (stride 0x18). */
    neAppEventCenter *m_eventCenter = nullptr; /**< +0x968 Picked {musicId, sheet} carrier. */
    int m_screenWidth = 0;                     /**< +0x96c Aep screen width. */
    int m_screenHeight = 0;                    /**< +0x970 Aep screen height. */
    /** +0x974 UI scale (g_uiScale); the judge and the note draw read it directly as a float. */
    float m_uiScale = 0.0f;
    int m_pauseOriginX = 0; /**< +0x978 Pause-menu layout x origin. */
    // +0x97c device-branched pause-menu + note-field geometry (phone/pad
    // constants). The pause fields are verified against the state-5/6 hit tests
    // in PlayTask_update; the note-field fields are consumed by the delegated
    // note-quad draw.
    int m_pauseBtnResumeX = 0; /**< +0x97c Pause button 0 (resume) x. */
    int m_pauseBtnRetryX = 0;  /**< +0x980 Pause button 1 (retry) x. */
    int m_pauseBtnQuitX = 0;   /**< +0x984 Pause button 2 (quit) x. */
    int m_pauseBtnWidth = 0;   /**< +0x988 Pause-menu button hit width. */
    int m_pauseTapCenterX = 0; /**< +0x98c In-play pause-tap hit-circle centre x. */
    int m_pauseTapCenterY = 0; /**< +0x990 In-play pause-tap hit-circle centre y. */
    int m_pauseTapRadius = 0;  /**< +0x994 In-play pause-tap hit-circle radius. */
    // Long-note connecting-bar geometry (judge FUN_0002f1f8: len = fade*scale +
    // base, drawn along the head->target angle; priority halved into the anchor).
    int m_barLenScale = 0;   /**< +0x998 Bar length gain per fade. */
    int m_barSegLyr1 = 0;    /**< +0x99c Second bar-segment layer id. */
    int m_barPriority = 0;   /**< +0x9a0 Bar draw priority, halved into the anchor. */
    int m_barLenBase = 0;    /**< +0x9a4 Bar length base. */
    int m_charaDrawSize = 0; /**< +0x9a8 Character portrait draw size (PlayTaskDraw). */
    int16_t m_gaugeBase = 0; /**< +0x9ac Default life-gauge base (g_wPlayDefaultGauge). */
    uint8_t _pad_9ae[0x9b0 - 0x9ae] = {}; /**< +0x9ae Alignment before m_score. */
    int m_score = 0;                      /**< +0x9b0 Running score readout (PlayCurrentScore). */
    int16_t m_seVolume = 0;               /**< +0x9b4 Touch-sound volume (UserSettingData). */
    uint8_t _pad_9b6[0x9b8 - 0x9b6] = {}; /**< +0x9b6 Alignment before m_hitRadius. */
    /** +0x9b8 Note hit-test radius; PlayJudge reads it as a float. */
    float m_hitRadius = 0.0f;
    /** +0x9bc Note ("popkun") size; a float truncated to int @ 0x2e418. */
    int m_popkunSize = 0;
    int16_t m_gaugeValue = 0; /**< +0x9c0 Life-gauge value (0..0x400). */
    // +0x9c2 combo-milestone re-trigger guard: the judge sets it to the current
    // combo count each frame and compares it against the 25 / 50 / every-50 past
    // 100 thresholds to fire each milestone burst once.
    int16_t m_comboMilestoneGuard = 0; /**< +0x9c2 Previous combo count (milestone guard). */
    // +0x9c4 the combo milestone just celebrated (25 / 50 / 100+): the judge
    // records the crossed value here as it stops the matching burst layer.
    int16_t m_comboMilestoneShown = 0; /**< +0x9c4 Last combo milestone celebrated. */
    bool m_bgmReady = false;           /**< +0x9c6 Async BGM decode finished; the state-2 gate. */
    bool m_suppressHud = false;        /**< +0x9c7 Hide the HUD during teardown. */
    bool m_endSeFired = false;         /**< +0x9c8 One-shot song-end clear/rank-SE latch. */
    /** +0x9c9 Tutorial / auto-demo flag, from event-centre +0x33. */
    bool m_isDemoPlay = false;
    bool m_isPadDisplay = false;          /**< +0x9ca Pad-class display (g_bIsPadDisplay). */
    uint8_t _pad_9cb[0x9cc - 0x9cb] = {}; /**< +0x9cb Alignment before the gauge floats. */
    float m_gaugeGainGreat = 0.0f;        /**< +0x9cc Great / perfect gauge delta. */
    float m_gaugeGainGood = 0.0f;         /**< +0x9d0 Good gauge delta (1.0). */
    float m_gaugeLossMiss = 0.0f;         /**< +0x9d4 Miss / down gauge delta; negative. */
    int m_damageAccum = 0;                /**< +0x9d8 Damage accumulator; reset to 0. */
    bool m_damagedThisFrame = false;      /**< +0x9dc Took damage this frame (updateGauge). */
    uint8_t _pad_9dd[0x9e0 - 0x9dd] = {}; /**< +0x9dd Alignment before m_hitEffectScale. */
    /** +0x9e0 Note hit-effect extent (initialised to 500 or 1000); the judge passes half of it
     * as the draw scale. */
    int m_hitEffectScale = 0;
    bool m_optSimpleMode = false;         /**< +0x9e4 UserSettingData isSimpleMode. */
    bool m_optEffectOn = false;           /**< +0x9e5 UserSettingData isEffectOn. */
    bool m_optLongNoteEffect = false;     /**< +0x9e6 UserSettingData isLongNotesEffectOn. */
    bool m_optOldHardware = false;        /**< +0x9e7 AppDelegate isOldHardware. */
    bool m_stopped = false;               /**< +0x9e8 Audio stopped; the quit path. */
    uint8_t _pad_9e9[0x9ec - 0x9e9] = {}; /**< +0x9e9 Alignment before m_backTouchId. */
    int m_backTouchId = -1;               /**< +0x9ec Held back-tap touch id; -1 when none. */
    int m_backTouchTime = 0;              /**< +0x9f0 getTimeMillis at back-tap start. */
    int m_beatPulse = 0;                  /**< +0x9f4 Demo character-window beat pulse (0..100). */
    int m_endPos = 0;                     /**< +0x9f8 NoteMng position latched at song end. */
    PlayState m_state = kPlayStateInit;   /**< +0x9fc Play state-machine field. */
};

/**
 * @brief Allocate the play scene for a play-data block.
 * @param playData The play-data block, a PlayTask.
 * @ghidraAddress 0x2e2d8
 */
void PlayTaskInit(void *playData);
/**
 * @brief Transition a play-data block to the result screen.
 * @param playData The play-data block, a PlayTask.
 * @ghidraAddress 0x3003c
 */
void PlayTaskGotoResult(void *playData);

/**
 * @brief The current running score, or gauge value, used for the end-of-song rank SEs.
 * @return The current score.
 * @ghidraAddress 0x2ff7c
 */
int PlayCurrentScore();
