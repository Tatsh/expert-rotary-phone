//
//  PlayResultTask.h
//  pop'n rhythmin
//
//  The note-play result screen, spawned by the play task on a completed normal
//  play (PlayTaskGotoResult -> PlayResultCreateTask). Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (ctor FUN_0003d5bc, update
//  FUN_0003d690).
//
//  Like AcMainTask, update() is a state machine reached by byte offset into a
//  flat data block; it is reconstructed in pieces. The screen: fade/BGM in
//  (0-1), present the score + a Twitter share button and run the rank jingle
//  (2), count the score up with a tick SE (3-6), wait for a dismiss tap (7),
//  show the "communicating" overlay while the score upload finishes (8-9), then
//  fade out and hand off (10-0xc). The animation layers it drives (m_layers @
//  +0x214..+0x228) are AepLyrCtrl overlays that the intro/score cues also poke
//  as SeInstance controllers (see SeInstance.h). Progress tracked in STUBS.md.
//
//  ---- work area (this class IS the 0x3a0-byte result-data struct) ----
//  C_TASK's base is exactly 0x28 bytes, so the members below land at their true
//  binary offsets. The whole body is memset 0 by the ctor (FUN_0003d5bc: memset
//  +0x28..+0x3a0
//  == 0x378 bytes). Every offset the reconstructed methods (resultSetup / the
//  update state machine / loadNumberTextures / resultGotoNext / the draw
//  callback) reach by flat
//  `*(T*)(this+off)` in the binary is named at its exact offset (with a `//
//  +0xNN` comment). Gaps verified against Ghidra are named for what they are:
//  `_pad_NN` for alignment padding before a wider field, `unused_NN` for dead
//  allocation gaps no reconstructed method reaches. The two interior gaps
//  (+0x310..+0x32b and +0x330..+0x33b) are the latter: a program-wide instruction
//  search finds no resultTask access to those offsets (only stack frames, literal
//  pools, and other classes' objects), so they are kept as `unused_NN`.
//
//  NOTE (target ABI): offsets assume the 32-bit ARMv7 target (pointers and
//  `unsigned long` are 4 bytes), matching the reference reworks; this header is
//  documentary and is not host-compiled.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class AepLyrCtrl;
class neTextureForiOS;

class PlayResultTask : public C_TASK {
public:
    PlayResultTask();                  // Ghidra: FUN_0003d5bc
    void update(int deltaMs) override; // Ghidra: FUN_0003d690

private:
    // Intricate sub-bodies lifted out of update()'s switch as their own
    // reconstruction pieces (declared real methods, called as if present):
    //  * resultSetup (FUN_0003dfe0): populate the result data (score/rank/combo
    //  counters
    //    + treasure points), post the score save, build the result layers, load
    //    the ~130 number textures + the rank SEs, and load + volume the result
    //    BGM. Large asset unit; a whole reconstruction piece of its own.
    //  * updateResultPresent (case 2): once the intro layer settles, build the
    //  Twitter
    //    share UIButton (device-branched frame from its image size) and watch for
    //    the dismiss tap; while it is still animating, fire the rank jingle on
    //    frame cues.
    //  * updateScoreCount (case 6): tick the displayed score up toward the final,
    //  firing
    //    the count SE every fifth step.
    //  * resultGotoNext (FUN_0003f2e0): tear the screen down and spawn the next
    //  scene.
    void resultSetup();
    void updateResultPresent(bool tapped, int tapX, int tapY, int displayType);
    void updateScoreCount(bool tapped);
    void resultGotoNext();

    // The case-2 Twitter share-button build (FUN_0003d690 @ ~0x3da3e): lay out
    // the UIButton, wrap a TwitterUtil(text,image) as its tweet target, add it
    // over the GL view and fade it in. Frame breakdown (decompiled from
    // FUN_0003d690):
    //   x = 5.0f (0x40a00000) — exact constant.
    //   y = device-branched exact constant: phone 435.0f (0x43d98000), +15.0f on
    //   Retina
    //       (→ 450.0f), 527.0f (0x4403c000) for displayType 2 (+15.0f → 542.0f),
    //       965.0f (0x44714000) on pad.
    //   w, h = bt_twitter image .size at runtime — not fixed constants.
    // The NEON register spills affect only the w/h path; x and y are plain
    // constants. Remaining work: the TwitterUtil class body.
    void buildShareButton(int displayType);

    // The 10-lane x 12-array number-texture load
    // (num_cool_/great_/good_/bad_/com_/
    // score_/bonus_clear/bonus_combo/bonus_rank/bonus_perfect/points/pointb_),
    // lifted out of resultSetup as a real helper. Ghidra: FUN_0003dfe0's inner
    // double loop
    // @ 0x3ea84..0x3ef9e.
    void loadNumberTextures();

    // The per-frame draw pass reaches the members below through its `context` (=
    // this), so it is a friend rather than reaching them by raw offset.
    static void PlayResultDrawCallback(int child,
                                       int frame,
                                       int x,
                                       int y,
                                       int scaleX,
                                       int scaleY,
                                       int anchorX,
                                       int anchorY,
                                       int color,
                                       int alpha,
                                       int rotation,
                                       uint32_t blend,
                                       int *clipRect,
                                       uint32_t p17,
                                       void *context);

    // ================= work-area layout (offsets are binary-exact)
    // =================
    // --- Artwork / name-image / chara portraits (standalone textures) ---
    neTextureForiOS *m_artworkTex = nullptr; // +0x28 music artwork2xData
    neTextureForiOS *m_nameTex = nullptr;    // +0x2c music-name image2xData
    neTextureForiOS *m_charaTex = nullptr;   // +0x30 result_chara<id>@2x

    // --- 12 digit-strip texture rows (0..9 glyphs each), drawn by the num_*
    // branches ---
    neTextureForiOS *m_numCool[10] = {};         // +0x34  num_cool_
    neTextureForiOS *m_numGreat[10] = {};        // +0x5c  num_great_
    neTextureForiOS *m_numGood[10] = {};         // +0x84  num_good_
    neTextureForiOS *m_numBad[10] = {};          // +0xac  num_bad_
    neTextureForiOS *m_numCom[10] = {};          // +0xd4  num_com_
    neTextureForiOS *m_numScore[10] = {};        // +0xfc  num_score_
    neTextureForiOS *m_numBonusClear[10] = {};   // +0x124 num_bonus_clear
    neTextureForiOS *m_numBonusCombo[10] = {};   // +0x14c num_bonus_combo
    neTextureForiOS *m_numBonusRank[10] = {};    // +0x174 num_bonus_rank
    neTextureForiOS *m_numBonusPerfect[10] = {}; // +0x19c num_bonus_perfect
    neTextureForiOS *m_numPoints[10] = {};       // +0x1c4 num_points (S_POINT_NUM)
    neTextureForiOS *m_numPointsBig[10] = {};    // +0x1ec num_pointb_ (total, big)

    // --- 6 result overlay layers (device-branched names; owner = this). The
    // intro/score
    //     layers [0..3] are also poked as SeInstance controllers (SeInstance*,
    //     void*). ---
    AepLyrCtrl *m_layers[6] = {}; // +0x214 640IMG/BONUS_*/NEW_RECORD/EVENT

    // --- Resolved Aep handle tables (frame/user numbers, by name) ---
    int m_frmA[4] = {};          // +0x22c FULLCOMBO/PERFECT/BONUS_COM/FULLCOM board
    int m_frmDifficulty[3] = {}; // +0x23c DIFFICULTY_NORMAL/HYPER/EX_FONT
    int m_frmRank[7] = {};       // +0x248 DIFFICULTY_RUNK_NUMBER_AAA..D (AAA twice)
    int m_usr[20] = {};          // +0x264 user-frame numbers (draw dispatch)
    int m_effLyrNo[4] = {};      // +0x2b4 DIFFICULTY_*/PERFECT_EFF layer numbers
    int m_effLyrFrames[4] = {};  // +0x2c4 those layers' frame counts
    int m_effFrame[4] = {};      // +0x2d4 those layers' animation counters (mutable)

    // --- 11 rank / count SEs (RSND_SOURCE_ID; 4-byte on the target) ---
    // Indexed slots the cue code names directly: [1] v32 perfect jingle, [6] v38
    // line-in, [7] se07_count tick, [8] se08_bonus_fai, [9] se09_bonus_cl.
    uint32_t m_rankSe[11] = {}; // +0x2e4 (..+0x30f)

    uint8_t unused_310[0x32c - 0x310] =
        {};                // +0x310 unused gap (Ghidra: no resultTask field access)
    int m_countSeInst = 0; // +0x32c currently-playing count-SE instance id
    uint8_t unused_330[0x33c - 0x330] =
        {}; // +0x330 unused gap (Ghidra: no resultTask field access)

    int m_overlayWidth = 0;               // +0x33c transition fade-quad width
    int m_overlayHeight = 0;              // +0x340 transition fade-quad height
    int m_score = 0;                      // +0x344 final play score
    int16_t m_coolCount = 0;              // +0x348 COOL tally
    int16_t m_greatCount = 0;             // +0x34a GREAT tally
    int16_t m_goodCount = 0;              // +0x34c GOOD tally
    int16_t m_badCount = 0;               // +0x34e BAD tally
    int16_t m_maxCombo = 0;               // +0x350 max combo
    uint8_t m_isNewRecord = 0;            // +0x352 new-record flag
    uint8_t m_perfectFullCombo = 0;       // +0x353 cleared + no GOOD/BAD
    uint8_t m_cleared = 0;                // +0x354 cleared flag
    uint8_t m_padDisplay = 0;             // +0x355 pad-class display
    uint8_t m_eventBonus = 0;             // +0x356 event-song bonus flag
    uint8_t _pad_357 = 0;                 // +0x357 alignment pad before m_sheet (no access)
    int16_t m_sheet = 0;                  // +0x358 played difficulty index
    int16_t m_level = 0;                  // +0x35a chart level for the played sheet
    int16_t m_rank = 0;                   // +0x35c play rank (0 best .. 6 fail)
    uint8_t _pad_35e[0x360 - 0x35e] = {}; // +0x35e alignment pad before m_treasureStart (no access)
    int m_treasureStart = 0;              // +0x360 starting treasure point
    int m_treasurePoint = 0;              // +0x364 running treasure point (S_POINT_NUM)
    int m_baseBonus = 0;                  // +0x368 play-count base bonus (+event)
    int m_clearBonus = 0;                 // +0x36c clear bonus (0 on wash-out)
    int m_fullComboBonus = 0;             // +0x370 full-combo bonus (note-count scaled)
    int m_rankBonus = 0;                  // +0x374 rank bonus (S..fail)
    int m_perfectBonus = 0;               // +0x378 perfect-full-combo bonus
    int m_pointsCountUp = 0;              // +0x37c animated count-up total (big strip)
    int m_bonusSubtotal = 0;              // +0x380 perfect+clear+fc+rank subtotal
    int m_boardScale = 0;                 // +0x384 result board scale (100 pad / 50 phone)
    int m_tickCounter = 0;                // +0x388 count-up tick counter (read as uint for %5)
    int m_music = 0;                      // +0x38c played music id
    C_TASK *m_nextTask = nullptr;         // +0x390 spawned music-select task
    int m_state = 0;                      // +0x394 update() state machine field
    void *m_shareButton = nullptr;        // +0x398 Twitter share UIButton (ARC-bridged raw)
    void *m_tweeter = nullptr;            // +0x39c TwitterUtil (unmanaged +1)
                                          // object end +0x3a0
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
