//
//  PlayResultTask.mm
//  pop'n rhythmin
//
//  See PlayResultTask.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (ctor FUN_0003d5bc, update FUN_0003d690). update() is
//  reconstructed in pieces: the fade/BGM intro, the wait states and the
//  fade-out hand-off are here; the three intricate blocks (result-data setup,
//  the Twitter share button + rank-jingle cue, and the score count-up) are
//  their own methods (declared in the header; each fires a result SE whose
//  source id the decompiler could not trace to a field, so they are
//  reconstructed separately). Progress tracked in STUBS.md.
//

#import "PlayResultTask.h"

#include <array>
#include <span>

#import <UIKit/UIKit.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "MainViewController.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "OverScoreData+Store.h"
#import "OverScoreData.h"
#import "SeInstance.h"
#import "TaskFactory.h"
#import "TwitterUtil.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host (MainViewController) the result screen drives.
static MainViewController *RootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

// NOTE: resultTaskSetup @ 0x3d048 was placed here by binary proximity only; it
// is NOT a PlayResultTask method. It walks the 27×0x38 jacket-cell array @
// +0x2d8 with the semaphore
// @ +0xa90 and stop-flag @ +0xa8c — the music-select task's work area — so it
// is the MainTask background jacket loader. It is now reconstructed as
// MainTask::backgroundCellLoader() (Project/System/src/Task/MainTask.mm), the
// dispatch_async body rebuildList kicks off.

// Ghidra: resultTask_ctor @ 0x3d5bc — ne::C_TASK base ctor + vtable init +
// 0x378-byte memset on the data block starting at +0x28. Corresponds to
// PlayResultTask::PlayResultTask() (confirmed: *param_1 =
// &PTR_resultTaskUpdate_1; _memset(param_1+10, 0, 0x378)).
//
// Ghidra: resultTask_delete @ 0x3d5f0 — compiler-generated deleting destructor.
// Calls caSourceNode_dtor (= ne::C_TASK::~ne::C_TASK() base-dtor chain via SjLj EH
// frame) then operator_delete on the same pointer. No user-defined
// ~PlayResultTask() exists in source; this thunk is synthesised by the compiler
// for the vtable delete slot.
//
// Ghidra: FUN_0003d5bc — base ne::C_TASK ctor, set the vtable, and zero the
// 0x378-byte result-data block (already done by the members' in-class
// initialisers and the base ctor).
// Verified against disassembly: bl 0x27ea8 (ne::C_TASK base ctor), str [r0],#0x28
// (vtable at +0, advance to data block), _memset(+0x28, 0, 0x378).
// @complete
PlayResultTask::PlayResultTask() {
}

// Out-of-line so the unique_ptr texture / layer members are destroyed where
// neTextureForiOS and AepLyrCtrl are complete (the header keeps them on forward
// declarations). Matches the compiler-generated deleting destructor at 0x3d5f0:
// resultGotoNext already frees every slot, so this only runs the base chain.
PlayResultTask::~PlayResultTask() = default;

// Ghidra: FUN_0003d690 — the result-screen state machine.
// Verified against disassembly: tap detection uses < 11 on both axes (dx =
// startX-x @ +4/+c, dy = startY-y @ +8/+10); state ivar @ +0x394; case 1 plays
// m_layers[5] (eventBonus @ +0x356, via 0x2caf8) then m_layers[4] (isNewRecord
// @ +0x352); case 4 checks +0x218 not playing then rank != 6 (+0x35c); every
// case store/order matches.
// @complete
void PlayResultTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];
    AudioManager *audio = [AudioManager sharedManager];
    neGraphics &gfx = neGraphics::shared();

    // Dismiss-tap detection: a released touch that barely moved (< 11 on both
    // axes).
    bool tapped = false;
    int tapX = -1, tapY = -1;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->released != 0) {
            int dx = t->startX - t->x;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx < NE_TAP_SLOP(11)) { // slop widened under ENABLE_PATCHES (NE_TAP_SLOP)
                int dy = t->startY - t->y;
                if (dy < 0) {
                    dy = -dy;
                }
                if (dy < NE_TAP_SLOP(11)) {
                    tapped = true;
                    tapX = t->x;
                    tapY = t->y;
                    break;
                }
            }
        }
    }

    const int displayType = [[AppDelegate appDelegate] displayType];

    switch (m_state) {
    case 0:
        // Set up the result data + load the result BGM, then start it. (The playBgm
        // fade argument is clobbered in the decompile by the preceding void call;
        // 0.5 matches the fade the app's other playBgm sites use.)
        resultSetup(); // FUN_0003dfe0
        [audio playBgm:0.5f];
        m_state = 1;
        break;
    case 1:
        // Fade the screen in and start the intro animation layers; drop the play
        // scene's captured backdrop now that this scene owns the display.
        aep.setAepTransitionMode(1); // fade in (fixed 30 frames)
        SeInstancePlay(m_layers[0].get());
        if (m_eventBonus) {
            m_layers[5]->play();
        }
        if (m_isNewRecord) {
            SeInstancePlay(m_layers[4].get());
        }
        [RootVC() releaseCapturedImage];
        m_state = 2;
        break;
    case 2:
        updateResultPresent(tapped, tapX, tapY, displayType);
        break;
    case 3:
    case 5:
    case 6:
        updateScoreCount(tapped);
        break;
    case 4:
        // The score-line animation finished: start the count-up, unless this was a
        // wash-out (rank 6), which drops straight to waiting for the dismiss tap.
        if (!SeInstanceIsPlaying(m_layers[1].get())) {
            if (m_rank != 6) {
                m_state = 5;
                break;
            }
            if (tapped) { // rank 6 falls into the case-7 dismiss wait
                m_state = 8;
            }
        }
        break;
    case 7:
        if (tapped) {
            m_state = 8;
        }
        break;
    case 8:
        // Show the "communicating" overlay while the score upload is still in
        // flight.
        if ([dl isSaveScoreDownLoading]) {
            [RootVC() InsertCommunicating];
            m_state = 9;
        } else {
            m_state = 10;
        }
        break;
    case 9:
        if (![dl isSaveScoreDownLoading]) {
            [RootVC() DeleteCommunicating];
            m_state = 10;
        }
        break;
    case 10:
        aep.setAepTransitionMode(2); // fade out (fixed 30 frames)
        m_state = 0xb;
        break;
    case 0xb:
        if (aep.isTransitionDone()) {
            m_state = 0xc;
        }
        break;
    case 0xc:
        resultGotoNext(); // FUN_0003f2e0 — tear down + spawn the next scene
        break;
    default:
        break;
    }

    // Advance + draw every active animation layer this frame.
    AepLyrCtrl::updateAndDrawAepLayers(0); // FUN_0002c924
}

// Ghidra: FUN_0003dfe0 — build the whole result screen: snapshot the finished
// play's global result vars (the neAppEventCenter singleton fields,
// DAT_00187bxx), commit + upload the score, delete stale over-score records,
// compute the treasure bonuses, build the 6 animation layers + the ~130
// number/artwork/chara textures, load the 11 rank SEs and the result BGM.
// Verified against disassembly: field offsets (m_score +0x344, m_maxCombo
// +0x350, cool/great +0x348/+0x34a, good/bad +0x34c/+0x34e, m_isNewRecord
// +0x352, m_cleared +0x354, m_perfectFullCombo +0x353, m_sheet +0x358, m_rank
// +0x35c, treasure +0x360/+0x364, m_music +0x38c); base treasure award by play
// count (100/70/50/30/20 at <5/<7/<9/<11/else), +100 event bonus, clear bonus
// +0x36c (20, 0 on rank 6), FC bonus +0x370 by note count, rank bonus +0x374,
// perfect bonus +0x378 (10), m_bonusSubtotal +0x380, m_baseBonus +0x368, 9999
// cap, m_boardScale +0x384 (pad 100 / phone 50 via +0x355).
// @complete
void PlayResultTask::resultSetup() {
    AepManager &aep = AepManager::shared();
    neAppEventCenter &evt = neAppEventCenter::shared();
    DownloadMain *dl = [DownloadMain getInstance];

    // Cache the fade-quad extents this scene draws its transition through.
    m_overlayWidth = aep.transitionOverlayWidth();   // FUN_0000f498
    m_overlayHeight = aep.transitionOverlayHeight(); // FUN_0000f4a4

    // --- Snapshot the just-finished play's result (neAppEventCenter fields) ---
    m_score = evt.playScore();                 // DAT_00187bc8 score
    m_maxCombo = evt.maxCombo();               // DAT_00187bd0 max combo
    m_coolCount = evt.coolCount();             // DAT_00187bc0 low  COOL tally
    m_greatCount = evt.greatCount();           // DAT_00187bc0 high GREAT tally
    m_goodCount = evt.goodCount();             // DAT_00187bc4 low  GOOD tally
    m_badCount = evt.badCount();               // DAT_00187bc4 high BAD tally
    m_isNewRecord = evt.isNewRecord() ? 1 : 0; // DAT_00187bea new-record flag
    const bool cleared = evt.isCleared();      // DAT_00187bd4
    m_cleared = cleared ? 1 : 0;

    // +0x353: perfect full-combo == cleared with no GOOD and no BAD.
    m_perfectFullCombo = (cleared && evt.goodCount() == 0 && evt.badCount() == 0) ? 1 : 0;

    m_sheet = (short)evt.lastSheet(); // DAT_00187bbc difficulty index
    m_rank = evt.playRank();          // DAT_00187bcc rank (0 best .. 6 fail)

    const short treasureStart = [UserSettingData treasurePoint];
    m_treasureStart = treasureStart; // starting treasure point (for the count-up)
    m_treasurePoint = treasureStart; // running treasure point

    const int music = evt.lastMusic(); // DAT_00187bb8
    const short sheet = m_sheet;
    const short rank = m_rank;
    m_music = music;

    // Pad-vs-phone display flag (scene manager DAT_00187b84).
    neSceneManager::shared();
    m_padDisplay = neSceneManager::isPadDisplay() ? 1 : 0;

    // --- Decide + post the score save (FUN_0003dfe0 @ 0x3e12c..0x3e604) ---
    int stScore = 0;
    short stRank = 0;
    int stPlayCnt = 0;
    bool stFullCombo = false, stPerfect = false;
    evt.readStoredResult(&stScore, &stRank, &stPlayCnt, &stFullCombo,
                         &stPerfect); // FUN_000293c4
    evt.commitResultToScoreData();    // FUN_00028ca0 — write the new local best

    const short charaId = [UserSettingData charaId];
    const short charaIdServer = [UserSettingData charaIdServer];
    const bool charaChanged = (charaId != charaIdServer);
    if (charaChanged) {
        [UserSettingData saveCharaIdServer:[UserSettingData charaId]];
    }

    // Medal for the current play: 2 = perfect full-combo, else the cleared flag.
    const int medalCur = m_perfectFullCombo ? 2 : m_cleared;

    bool improved = false;
    if (stScore < m_score || rank < stRank || (!stFullCombo && cleared)) {
        improved = true; // beat the stored score / rank, or first clear
    } else if (!stPerfect) {
        improved = (charaChanged || m_perfectFullCombo); // new record / char resync
    } else {
        improved = charaChanged;
    }

    if (improved) {
        [UserSettingData addUncompleteSaveMusic:music sheet:sheet];
        [dl startSaveScoreHttp:music
                         sheet:sheet
                         score:m_score
                         medal:medalCur
                       charaId:[UserSettingData charaId]];
    } else {
        // Not improved: flush a previously-queued uncomplete-save entry if one
        // exists, otherwise re-sync this chart's stored score.
        NSArray *pendMusic = [UserSettingData uncompleteSaveMusic];
        NSArray *pendSheet = [UserSettingData uncompleteSaveSheet];
        if (pendMusic && pendSheet && pendMusic.count && pendSheet.count) {
            const int pMusic = (int)[[pendMusic objectAtIndex:0] longValue];
            const short pSheet = (short)[[pendSheet objectAtIndex:0] intValue];
            int rScore = 0;
            short rRank = 0;
            int rPlay = 0;
            bool rFC = false, rPerfect = false;
            evt.readStoredResult(&rScore, &rRank, &rPlay, &rFC,
                                 &rPerfect); // re-read stored
            const int medalPend = rPerfect ? 2 : m_cleared;
            [dl startSaveScoreHttp:pMusic
                             sheet:pSheet
                             score:rScore
                             medal:medalPend
                           charaId:[UserSettingData charaId]];
        } else {
            const int medalSync = stPerfect ? 2 : (stFullCombo ? 1 : 0);
            [dl startSaveScoreHttp:music
                             sheet:sheet
                             score:stScore
                             medal:medalSync
                           charaId:[UserSettingData charaId]];
        }
    }

    // Clear this chart's stale rival ("over") score records before a fresh fetch.
    AppDelegate *app = [AppDelegate appDelegate];
    [OverScoreData deleteRecordWithMusic:music
                                   sheet:sheet
                  inManagedObjectContext:[app managedObjectContext]];

    // Award the event bonus if this song is one of the active game events. The
    // binary evaluates a folded predicate (FUN_000e2c48(x) == (x == 0)) and then
    // redundantly re-tests x == 0, so the net condition is [id intValue] == 0.
    for (id eventId in [dl gameEventIdArray]) {
        if ([eventId intValue] == 0) {
            m_eventBonus = 1;
        }
    }

    // --- Treasure-point bonuses ---
    // Base award by stored play count (newer songs award more).
    int treasureGain;
    if (stPlayCnt < 5) {
        treasureGain = 100;
    } else if (stPlayCnt < 7) {
        treasureGain = 70;
    } else if (stPlayCnt < 9) {
        treasureGain = 50;
    } else if (stPlayCnt < 11) {
        treasureGain = 30;
    } else {
        treasureGain = 20;
    }
    m_baseBonus = treasureGain;
    if (m_eventBonus) { // event-song bonus
        treasureGain += 100;
        m_baseBonus = treasureGain;
    }
    m_pointsCountUp = treasureGain;

    // Clear bonus (20), zero on a wash-out (rank 6).
    m_clearBonus = (rank == 6) ? 0 : 20;

    // Full-combo bonus, scaled by chart note count (only on a non-fail clear).
    if (m_cleared && rank != 6) {
        const int notes = NoteMng::shared().totalNoteCount(); // FUN_0000b278 / DAT_00178ccc
        int fcBonus;
        if (notes < 0x33) {
            fcBonus = 10;
        } else if (notes < 0x65) {
            fcBonus = 11;
        } else if (notes < 0x97) {
            fcBonus = 12;
        } else if (notes < 0xc9) {
            fcBonus = 13;
        } else if (notes < 0xfb) {
            fcBonus = 14;
        } else if (notes < 0x12d) {
            fcBonus = 15;
        } else if (notes < 0x15f) {
            fcBonus = 16;
        } else if (notes < 0x191) {
            fcBonus = 18;
        } else {
            fcBonus = 20;
        }
        m_fullComboBonus = fcBonus;
    }

    // Rank bonus (S..fail). The default (rank > 6) leaves m_rankBonus unchanged.
    switch (rank) {
    case 0:
        m_rankBonus = 50;
        break;
    case 1:
        m_rankBonus = 40;
        break;
    case 2:
        m_rankBonus = 30;
        break;
    case 3:
        m_rankBonus = 20;
        break;
    case 4:
        m_rankBonus = 10;
        break;
    case 5:
        m_rankBonus = 5;
        break;
    case 6:
        m_rankBonus = 0;
        break;
    default:
        break;
    }

    // Perfect-full-combo bonus (10) and the total, then persist (capped at 9999).
    m_perfectBonus = m_perfectFullCombo ? 10 : 0;
    m_bonusSubtotal = m_perfectBonus + m_clearBonus + m_fullComboBonus + m_rankBonus;
    const short treasureTotal = (short)(m_bonusSubtotal + m_treasureStart + m_baseBonus);
    [UserSettingData saveTreasurePoint:(treasureTotal < 9999 ? treasureTotal : 9999)];

    // Board scale for the result layout (100 on pad, 50 on phone).
    m_boardScale = m_padDisplay ? 100 : 50;

    // --- Load the result asset group + build the animation layers ---
    const bool pad = (m_padDisplay != 0);
    aep.loadAepDataDefaultPath(4, pad ? "result_ipad" : "result"); // FUN_0000f758

    // 4 effect layers resolved to raw layer handles + their frame counts.
    static const char *const kEffLayers[4] = {
        "DIFFICULTY_AAA_EFF", "DIFFICULTY_AA_EFF", "PERFECT_EFF_IN", "PERFECT_EFF_ROOP"};
    for (int i = 0; i < 4; i++) {
        const int lyr = aep.getLyrNo(4, kEffLayers[i]); // FUN_0000fac8
        m_effLyrNo[i] = lyr;
        m_effLyrFrames[i] = aep.layerFrameCount(lyr); // FUN_0000fb8c
    }

    // The 6 AepLyrCtrl overlay layers (device-branched names; per-layer order
    // value from the static table @ 0x12e698; owner = this task).
    static const char *const kLayerPhone[6] = {"640IMG",
                                               "BONUS_FAILED_640",
                                               "BONUS_CLEAR_640",
                                               "BONUS_PERFECT_640",
                                               "NEW_RECORD_640",
                                               "BONUS_EVENT"};
    static const char *const kLayerPad[6] = {"1136IMG",
                                             "BONUS_FAILED_1136",
                                             "BONUS_CLEAR_1136",
                                             "BONUS_PERFECT_1136",
                                             "NEW_RECORD_1136",
                                             "BONUS_EVENT"};
    static const int kLayerOrder[6] = {12, 9, 9, 9, 10, 11};
    const int displayType = [[AppDelegate appDelegate] displayType];
    const char *const *layerNames = (displayType == 2) ? kLayerPad : kLayerPhone;
    for (int i = 0; i < 6; i++) {
        m_layers[i] = std::make_unique<AepLyrCtrl>(); // operator_new(0x60) + FUN_0002c7d8
        m_layers[i]->init(4, layerNames[i], this, kLayerOrder[i]); // FUN_0002c834
    }

    // Frame/sprite handles resolved by name (getFrmNo).
    static const char *const kFrmA[4] = {
        "FULLCOMBO", "PERFECT", "BONUS_COM_BOARD", "BONUS_FULLCOM_BOARD"};
    for (int i = 0; i < 4; i++) {
        m_frmA[i] = aep.getFrameNo(4, kFrmA[i]); // FUN_0000f9cc
    }
    static const char *const kFrmB[3] = {
        "DIFFICULTY_NORMAL_FONT", "DIFFICULTY_HYPER_FONT", "DIFFICULTY_EX_FONT"};
    for (int i = 0; i < 3; i++) {
        m_frmDifficulty[i] = aep.getFrameNo(4, kFrmB[i]);
    }
    // Note: entries 0 and 1 are both "..._AAA" in the binary (the AAA rank glyph
    // is referenced twice); reproduced faithfully.
    static const char *const kFrmC[7] = {"DIFFICULTY_RUNK_NUMBER_AAA",
                                         "DIFFICULTY_RUNK_NUMBER_AAA",
                                         "DIFFICULTY_RUNK_NUMBER_AA",
                                         "DIFFICULTY_RUNK_NUMBER_A",
                                         "DIFFICULTY_RUNK_NUMBER_B",
                                         "DIFFICULTY_RUNK_NUMBER_C",
                                         "DIFFICULTY_RUNK_NUMBER_D"};
    for (int i = 0; i < 7; i++) {
        m_frmRank[i] = aep.getFrameNo(4, kFrmC[i]);
    }

    // User-frame handles resolved by name (getUsrNo).
    static const char *const kUsr[20] = {"MUSIC_TITLE",
                                         "RESULT_CHARA",
                                         "DIFFICULTY_RUNK_NUMBER_E",
                                         "DIFFICULTY_RUNK_NUMBER_E2",
                                         "JACKET00",
                                         "FULLCOMBO",
                                         "COOL_0",
                                         "GREAT_0",
                                         "GOOD_0",
                                         "BAD_0",
                                         "COM_0",
                                         "RESULT_SCORE",
                                         "DIFFICULTY_FONT",
                                         "BONUS_COM_BOARD",
                                         "BONUS_CLEAR",
                                         "BONUS_COM",
                                         "BONUS_RANK",
                                         "BONUS_PERFECT",
                                         "S_POINT_NUM",
                                         "S_POINT_NUM_BIG"};
    for (int i = 0; i < 20; i++) {
        m_usr[i] = aep.getUserNo(4, kUsr[i]); // FUN_0000fb40
    }

    // --- Artwork / name-image / chara textures ---
    MusicManager *mm = [MusicManager getInstance];
    [mm getMusicDataArray]; // ensure the catalog cache is built
    MusicData *md = [mm getMusicData:music];

    m_artworkTex = std::make_unique<neTextureForiOS>(); // operator_new(0x18) + FUN_00011818
    m_artworkTex->loadFromImageData((__bridge const void *)[md artwork2xData]); // FUN_00011cbc

    m_nameTex = std::make_unique<neTextureForiOS>();
    m_nameTex->loadFromImageData((__bridge const void *)[md musicNameImage2xData]);

    // Difficulty level for the played sheet (other sheet ids leave m_level as
    // is).
    switch (sheet) {
    case 0:
        m_level = (short)[md lvNormal];
        break;
    case 1:
        m_level = (short)[md lvHyper];
        break;
    case 2:
        m_level = (short)[md lvEx];
        break;
    default:
        break;
    }

    m_charaTex = std::make_unique<neTextureForiOS>();
    NSString *charaFile =
        [NSString stringWithFormat:@"result_chara%03d@2x.png", (int)[UserSettingData charaId]];
    NSString *charaPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
    m_charaTex->load([charaPath UTF8String]); // FUN_00011a2c

    loadNumberTextures();

    // Install this scene's per-frame draw pass for group 4.
    aep.setGroupDrawCallback(4,
                             &PlayResultTask::PlayResultDrawCallback,
                             this); // FUN_0000f9b0 (cb FUN_0003f5f0)

    // --- 11 rank SEs + the result BGM ---
    AudioManager *audio = [AudioManager sharedManager];
    // Entry 10 is a null pointer in the static image (a runtime-bound CFString
    // that could not be resolved statically); the loop still issues 11 loads,
    // matching the binary, so it stays as nil here.
    static NSString *const kRankSe[11] = {@"v31",
                                          @"v32",
                                          @"v33",
                                          @"v34",
                                          @"v35",
                                          @"v36",
                                          @"v38",
                                          @"se07_count",
                                          @"se08_bonus_fai",
                                          @"se09_bonus_cl",
                                          nil};
    for (int i = 0; i < 11; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:kRankSe[i] ofType:@"m4a"];
        m_rankSe[i] = (uint32_t)[audio loadSe:sePath isLoop:NO callName:nil group:1];
    }

    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm03_result.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];
}

// Ghidra: FUN_0003dfe0 inner double loop @ 0x3ea84..0x3ef9e — load the 10 digit
// glyphs (0..9) of each of the 12 number groups into the per-lane texture
// arrays.
// Verified against disassembly: outer lane loop 0..9 (sp+0x34), inner group
// loop 0..0xb; per-cell operator_new(0x18) + FUN_00011818 + load; store bases
// step +0x28 per group (+0x34, +0x5c, ... +0x1ec), matching resultGotoNext.
// @complete
void PlayResultTask::loadNumberTextures() {
    // {digit-texture row, resource-name prefix}. The digit 0..9 is appended to
    // the prefix; note the underscore is present/absent exactly as in the binary
    // (byte-verified: e.g. num_bonus_clear<d> and num_points<d> have no
    // separator).
    struct NumGroup {
        std::span<std::unique_ptr<neTextureForiOS>> row; // a view of the owning member array
        const char *prefix;
    };
    const NumGroup kGroups[12] = {
        {m_numCool, "num_cool_"},
        {m_numGreat, "num_great_"},
        {m_numGood, "num_good_"},
        {m_numBad, "num_bad_"},
        {m_numCom, "num_com_"},
        {m_numScore, "num_score_"},
        {m_numBonusClear, "num_bonus_clear"},
        {m_numBonusCombo, "num_bonus_combo"},
        {m_numBonusRank, "num_bonus_rank"},
        {m_numBonusPerfect, "num_bonus_perfect"},
        {m_numPoints, "num_points"},
        {m_numPointsBig, "num_pointb_"},
    };
    NSBundle *bundle = [NSBundle mainBundle];
    for (int lane = 0; lane < 10; lane++) {
        for (int g = 0; g < 12; g++) {
            auto tex = std::make_unique<neTextureForiOS>(); // operator_new(0x18) + FUN_00011818
            NSString *name = [NSString stringWithFormat:@"%s%d", kGroups[g].prefix, lane];
            NSString *path = [bundle pathForResource:name ofType:@"png"];
            tex->load([path UTF8String]); // FUN_00011a2c
            kGroups[g].row[lane] = std::move(tex);
        }
    }
}

// Ghidra: FUN_0003d690 case 2 — the results presentation. While the intro
// effect layer
// (+0x214) is still animating, fire the score-tally count SE (se07_count @
// +0x2e4[7]) on its cue frames, and at frame 0x46 fire the rank-up jingle
// (v31..v36 @ +0x2e4[0..5]) selected by perfect/clear/rank; once it settles,
// build the Twitter share button (once the GL backdrop has been captured) and
// wait for a dismiss tap outside the button to advance to the count-up (state
// 3). All SE ids and frame cues traced from the disassembly.
//
// Frame cues (byte-verified @ 0x3d834..0x3dc7c / 0x3dfbc):
//   0x18                        -> playSe(se07_count) into m_countSeInst; NO
//   preceding stopSe. 0x20,0x28,0x30,0x38,0x40    -> stopSe(m_countSeInst);
//   playSe(se07_count) into m_countSeInst. 0x46                        ->
//   fire-and-forget rank jingle (result not tracked):
//        perfectFC:   rank!=0 -> v32 (m_rankSe[1]),  rank==0 -> v31
//        (m_rankSe[0]) !perfectFC:  cleared -> v33 (m_rankSe[2]),
//                     else rank<=3 -> v34[3], rank>5 -> v36[5], else(4,5) ->
//                     v35[4].
// Verified against disassembly: intro play head @ +0x40 (vcvt.s32.f32); frame
// switch 0x18 / 0x20..0x40 / 0x46; jingle select via +0x353 (pfc), +0x354
// (cleared), +0x35c (rank) into m_rankSe[+0x2e4..]; dismiss edge 0x370 (pad,
// displayType 2) / 0x30c, tapX > 0xdc or tapY < edge -> state 3.
// @complete
void PlayResultTask::updateResultPresent(bool tapped, int tapX, int tapY, int displayType) {
    AudioManager *audio = [AudioManager sharedManager];
    AepLyrCtrl *intro = m_layers[0].get();

    // Binary case 2 (resultTaskUpdate @ 0x3d690): AepLyrCtrl::IsPlaying(m_layers[0]),
    // then FPToFixed of the layer's +0x40 play head truncates it to a frame number.
    if (intro->isAnimating()) {
        const int frame = static_cast<int>(intro->curFrame()); // +0x40 flCurFrame
        switch (frame) {
        case 0x18:
            // First count tick: nothing to stop yet.
            m_countSeInst = static_cast<int>([audio playSe:nil resourceId:m_rankSe[7]]);
            break;
        case 0x20:
        case 0x28:
        case 0x30:
        case 0x38:
        case 0x40:
            [audio stopSe:static_cast<RSND_INSTANCE_ID>(m_countSeInst)];
            m_countSeInst = static_cast<int>([audio playSe:nil resourceId:m_rankSe[7]]);
            break;
        case 0x46: {
            // Rank-up jingle (played without stopping/tracking m_countSeInst).
            uint32_t jingle;
            if (m_perfectFullCombo) {
                jingle = (m_rank != 0) ? m_rankSe[1] : m_rankSe[0];
            } else if (m_cleared) {
                jingle = m_rankSe[2];
            } else if (m_rank <= 3) {
                jingle = m_rankSe[3];
            } else if (m_rank > 5) {
                jingle = m_rankSe[5];
            } else {
                jingle = m_rankSe[4];
            }
            [audio playSe:nil resourceId:jingle];
            break;
        }
        default:
            break;
        }
        return;
    }

    // Intro settled. Once the GL view has captured the backdrop, lay out the
    // share button (only once). Then a tap outside the button's area dismisses
    // the presentation.
    if ([RootVC() getCapturedImage] != nil && m_shareButton == nullptr) {
        buildShareButton(displayType);
    }
    if (tapped) {
        const int bottomEdge = (displayType == 2) ? 0x370 : 0x30c;
        if (tapX > 0xdc || tapY < bottomEdge) {
            m_state = 3;
            UIButton *shareButton = (__bridge UIButton *)m_shareButton;
            if (shareButton != nil) {
                [shareButton setUserInteractionEnabled:NO];
            }
        }
    }
}

// Ghidra: FUN_0003d690 case 2, share-button build (@ 0x3daf8..0x3df1e). Lay out
// the "bt_twitter" UIButton over the captured result backdrop, wrap a
// TwitterUtil as its tweet target, add it to the root view and bounce it in.
//
// Frame math (device-branched, byte-verified from the disassembly):
//   x = 5.0 always (0x40a00000).
//   phone (not a pad display): y = 435.0 (0x43d98000), or 526.9921875 == 527.0
//     (0x4403c000) when displayType == 2 (the tall-screen layout). On a Retina
//     board (transition overlay >= 640x960) the image is drawn at half size and
//     y += 15.0.
//   pad: y = 965.0 (0x44714000); no half-scaling.
//   w/h come straight from the "bt_twitter" image size (0,0 if it failed to
//   load).
//
// The tweet text is stringWithFormat @ 0x135FF8 (UTF-16): song title, score (@
// +0x344) and rank letter (rankLetter[@ +0x35c]); it embeds the bit.ly short
// link + #リズミン hashtag literally. English: "I played <title>! Score:<n>
// Rank:<R> <link> #Rhythmin".
// Verified against disassembly: x = 5.0 (0x40a00000); phone y = 435.0
// (0x43d98000) or 527.0 (0x4403c000) when displayType == 2; pad y = 965.0
// (0x44714000); Retina half-scale (0.5) + y += 15.0 when overlayW > 0x27f &&
// overlayH > 0x3bf; rank-letter table @ 0xf3d64 indexed by m_rank; tweet
// UTF-16 format @ 0x12bde0 (byte-verified); bounce options literal 2.
// @complete
void PlayResultTask::buildShareButton(int displayType) {
    UIImage *btImage = [UIImage imageNamed:@"bt_twitter"];

    MusicManager *mm = [MusicManager getInstance];
    [mm getMusicDataArray]; // ensure the catalog cache is built
    MusicData *md = [mm getMusicData:m_music];

    // Rank-letter table (PTR_cf_S_00131884): index by the play rank (0 best .. 6
    // fail).
    static NSString *const kRankLetter[7] = {@"S", @"AAA", @"AA", @"A", @"B", @"C", @"D"};
    NSString *tweetText = [NSString stringWithFormat:@"%@をプレイしたよ！スコア:%d ランク:%@ "
                                                     @"http://bit.ly/188OxQr #リズミン",
                                                     [md musicName],
                                                     m_score,
                                                     kRankLetter[m_rank]];

    AepManager &aep = AepManager::shared();
    neSceneManager::shared(); // ensure the scene singleton (pad flag) is live

    CGSize size = (btImage != nil) ? btImage.size : CGSizeZero;
    CGFloat y;
    if (!neSceneManager::isPadDisplay()) { // DAT_00187b84 == 0 : phone layout
        y = (displayType == 2) ? 527.0 : 435.0;
        // Retina board (>= 640 x 960): draw the button at half size, nudged down
        // 15pt.
        if (aep.transitionOverlayWidth() > 0x27f && aep.transitionOverlayHeight() > 0x3bf) {
            size.width *= 0.5f;
            size.height *= 0.5f;
            y += 15.0;
        }
    } else { // pad layout
        y = 965.0;
    }

    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(5.0, y, size.width, size.height)];
    // Non-owning: addSubview below takes the retain and the binary then -releases
    // the alloc/init +1 (ARC drops the local `button` at end of scope for the
    // same effect); resultGotoNext later just -removeFromSuperview + nils this
    // slot.
    m_shareButton = (__bridge void *)button;

    // The share sheet attaches the captured result screenshot.
    UIImage *captured = [RootVC() getCapturedImage];
    TwitterUtil *tweeter = [[TwitterUtil alloc] initWithText:tweetText image:captured];
    // Owning +1: UIControl targets are unretained, so this slot keeps the tweeter
    // alive until resultGotoNext transfers it back to ARC and releases it.
    m_tweeter = (__bridge_retained void *)tweeter;

    // Disabled until the bounce-in settles (re-enabled in the final completion
    // below).
    button.userInteractionEnabled = NO;
    [button setBackgroundImage:btImage forState:UIControlStateNormal];
    [button addTarget:tweeter action:@selector(tweet) forControlEvents:UIControlEventTouchUpInside];
    [[RootVC() view] addSubview:button];

    // Bounce-in (Ghidra: FUN_0003f19c / FUN_0003f1d0 / FUN_0003f278 + its
    // completion): grow to 2x over 0.2s, spring back to 1x over 0.5s, then
    // re-enable taps. Both stages pass UIViewAnimationOptionAllowUserInteraction
    // (the literal `2`).
    [UIView animateWithDuration:0.2
        delay:0.0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{
          UIButton *b = (__bridge UIButton *)m_shareButton;
          b.transform = CGAffineTransformMake(2.0, 0.0, 0.0, 2.0, 0.0, 0.0);
        }
        completion:^(BOOL /*finished*/) {
          [UIView animateWithDuration:0.5
              delay:0.0
              options:UIViewAnimationOptionAllowUserInteraction
              animations:^{
                UIButton *b = (__bridge UIButton *)m_shareButton;
                b.transform = CGAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
              }
              completion:^(BOOL /*finished*/) {
                // Ghidra: ResultShareButtonBounceDone_block @ 0x3f2ac
                // Byte-verified Thumb-2: MOVW
                // r1→SEL("setUserInteractionEnabled:"), MOVS r2,#1 (YES), LDR
                // r0,[block+0x14]=self, LDR.W r0,[r0,#0x398]=m_shareButton, B
                // (tail-call) objc_msgSend @ 0x100708. SEL confirmed from
                // __objc_methnames @ 0x00117f7b. Ghidra reported halt_baddata at
                // this address (ARM mode decode of Thumb-2 bytes).
                UIButton *b = (__bridge UIButton *)m_shareButton;
                b.userInteractionEnabled = YES;
              }];
        }];
}

// Ghidra: FUN_0003d690 states 3/5/6 — the treasure-point count-up. State 4 (the
// wait between them) is handled inline in update(). All four SE source ids were
// traced from the disassembly (they index the 11-entry SE array resultSetup
// loaded @ +0x2e4):
//   +0x2fc = +0x2e4[6] "v38"           (case 3 line-in)
//   +0x304 = +0x2e4[8] "se08_bonus_fai" (case 5 tally start)
//   +0x300 = +0x2e4[7] "se07_count"     (case 6 per-step tick)
//   +0x308 = +0x2e4[9] "se09_bonus_cl"  (case 6 finish)
// Verified against disassembly: case 6 total = m_baseBonus (+0x368) +
// m_bonusSubtotal (+0x380) compared against m_pointsCountUp (+0x37c); tick % 5
// via umull 0xcccccccd; every fifth step stops m_countSeInst (+0x32c) then
// replays se07_count; tap snaps m_pointsCountUp to total; finish -> state 7.
// @complete
void PlayResultTask::updateScoreCount(bool tapped) {
    AudioManager *audio = [AudioManager sharedManager];
    switch (m_state) {
    case 3:
        // Play the score line-in SE and start the score-line animation layer.
        [audio playSe:nil resourceId:m_rankSe[6]];
        SeInstancePlay(m_layers[1].get());
        m_state = 4;
        break;
    case 5:
        // Stop the score line, start the count-up layer(s) (the second only on a
        // perfect full-combo), reset the tick counter, and play the bonus-tally
        // start SE.
        SeInstanceStop(m_layers[1].get());
        SeInstancePlay(m_layers[2].get());
        if (m_perfectFullCombo) {
            SeInstancePlay(m_layers[3].get());
        }
        m_tickCounter = 0;
        [audio playSe:nil resourceId:m_rankSe[8]];
        m_state = 6;
        break;
    case 6: {
        // Once the count layer settles, count the treasure total up. Every fifth
        // step retriggers the count SE (stopping the previous instance first); a
        // tap snaps straight to the total. On reaching it, play the clear SE and
        // finish.
        if (SeInstanceIsPlaying(m_layers[2].get())) {
            break;
        }
        const int total = m_baseBonus + m_bonusSubtotal;
        if (m_pointsCountUp < total) {
            if (static_cast<unsigned int>(m_tickCounter) % 5 == 0) {
                [audio stopSe:static_cast<RSND_INSTANCE_ID>(m_countSeInst)];
                m_countSeInst = static_cast<int>([audio playSe:nil resourceId:m_rankSe[7]]);
            }
            m_pointsCountUp += 1;
            m_tickCounter += 1;
            if (tapped) {
                m_pointsCountUp = total; // dismiss tap: jump to the final total
            }
        } else {
            m_pointsCountUp = total;
            [audio playSe:nil resourceId:m_rankSe[9]];
            m_state = 7;
        }
        break;
    }
    default:
        break;
    }
}

// Ghidra: FUN_0003f2e0 — tear the result screen down (freeing exactly what
// resultSetup created) and hand off to the music-select task.
// Verified against disassembly: 11 SEs (+0x2e4) stopSe+releaseSe; releaseSystemSe
// (0x2c6bc), cleanupSe, loadSystemSe (0x2c5c8); portraits +0x28/+0x2c/+0x30 (loop
// 0..2); 10x12 num textures (+0x34..+0x1ec, +0x28 stride); 6 layers +0x214
// unlink (0x2ca9c) + delete; shareButton +0x398, tweeter +0x39c;
// releaseAepTexture(4); kill (+0x24 = 1); new MainTask(0xaa8) @ +0x390 if nil;
// setPriority(3).
// @complete
void PlayResultTask::resultGotoNext() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];

    // Stop + free the 11 rank SEs (@ 0x3f374).
    for (int i = 0; i < 11; i++) {
        RSND_SOURCE_ID se = m_rankSe[i];
        [audio stopSe:se];
        [audio releaseSe:nil resourceId:se];
    }

    // Release the shared system SEs, clean up the mixer, then reload them for the
    // next scene (@ 0x3f3a4..0x3f3e0).
    neSceneManager::shared().releaseSystemSe(); // FUN_0002c6bc
    [audio cleanupSe];
    neSceneManager::shared().loadSystemSe(); // FUN_0002c5c8

    // Release the artwork / name / chara textures (+0x28/+0x2c/+0x30).
    m_artworkTex.reset();
    m_nameTex.reset();
    m_charaTex.reset();

    // Release the 10-lane x 12-array number textures (@ 0x3f414..0x3f4f0).
    std::span<std::unique_ptr<neTextureForiOS>> kNumGroups[12] = {m_numCool,
                                                                  m_numGreat,
                                                                  m_numGood,
                                                                  m_numBad,
                                                                  m_numCom,
                                                                  m_numScore,
                                                                  m_numBonusClear,
                                                                  m_numBonusCombo,
                                                                  m_numBonusRank,
                                                                  m_numBonusPerfect,
                                                                  m_numPoints,
                                                                  m_numPointsBig};
    for (int lane = 0; lane < 10; lane++) {
        for (int g = 0; g < 12; g++) {
            kNumGroups[g][lane].reset();
        }
    }

    // Unlink + release the 6 result layers (+0x214).
    for (int i = 0; i < 6; i++) {
        if (m_layers[i]) {
            m_layers[i]->unlink(); // FUN_0002ca9c
            m_layers[i].reset();
        }
    }

    // Remove the Twitter share button and release the TwitterUtil
    // (+0x398/+0x39c).
    if (m_shareButton) {
        UIButton *shareButton = (__bridge UIButton *)m_shareButton;
        [shareButton removeFromSuperview];
        m_shareButton = nullptr;
    }
    if (m_tweeter) {
        // Held as an unmanaged raw +1 pointer; the binary sends -release, so
        // transfer ownership to ARC and let it drop at the end of this statement.
        (void)(__bridge_transfer id)m_tweeter;
        m_tweeter = nullptr;
    }

    // Drop the result asset group and mark this task dead.
    aep.releaseAepTexture(4); // FUN_0000f988
    kill();                   // +0x24 = 1

    // Spawn (once) the standard music-select task and (re)prioritise it.
    if (m_nextTask == nullptr) {
        m_nextTask = new MainTask(); // operator_new(0xaa8) + FUN_00034d48
    }
    m_nextTask->setPriority(3); // FUN_00027f08
}

// --- Result per-frame draw
// ---------------------------------------------------------
// PlayResultDrawCallback is a free function (the Aep group-4 draw callback), so
// it reaches the result-task data block by cited byte offset, the same
// convention resultSetup uses.
namespace {

// Ghidra: neTextureForiOS_draw (FUN_0000fbcc) -> AepOrderingTable_drawSprite
// (FUN_00011468). Emit one standalone-texture quad. Field mapping per
// FUN_00011468: u/v, x/y, sx/sy, w/h, ex=anchorX, ey=anchorY, colour @ +0x34,
// rotation @ +0x38, blend @ +0x40 (blend0); the wrapper's separate alpha word
// is the +0x42 sub-blend slot (blend1). FUN_0000fbcc forwards caller arg +0x38
// (alpha) and +0x3c (blend0) to the drawSprite stack, exactly as the canonical
// neTextureForiOS_draw bridge in neEngineBridge.mm sets blend1 / blend0.
// Verified against disassembly: FUN_0000fbcc forwards its args to FUN_00011468,
// which writes the command via allocEntry (FUN_00010be0): +0x40 = blend0
// (strh r3 from stack +0x30), +0x42 = blend1 (strh r5 from stack +0x34),
// colour @ +0x34, rotation @ +0x38, colour-multiply @ +0x44 (0xffffff here);
// this helper delegates to the already-verified neTextureForiOS::draw.
// @complete
void drawTexQuad(AepManager &aep,
                 neTextureForiOS *tex,
                 int u,
                 int v,
                 int w,
                 int h,
                 int x,
                 int y,
                 int sx,
                 int sy,
                 int rotation,
                 int anchorX,
                 int anchorY,
                 int color,
                 int alpha,
                 int blend,
                 int priority) {
    if (tex == nullptr) {
        return;
    }
    neSpriteDrawParams p;
    p.u = u;
    p.v = v;
    p.w = w;
    p.h = h;
    p.x = x;
    p.y = y;
    p.sx = sx;
    p.sy = sy;
    p.ex = anchorX;
    p.ey = anchorY;
    p.color = color;
    p.rotation = rotation;
    p.blend0 = (short)blend;
    p.blend1 = (short)alpha;
    p.colorMul = 0xffffff;
    p.priority = priority;
    tex->draw(aep.orderingTable(), p);
}

} // namespace

// Ghidra: FUN_0003f5f0 — the result screen's per-frame draw pass, registered as
// group 4's draw callback (context = the PlayResultTask). It matches `child`
// against the result-data handle tables resultSetup filled and draws the
// corresponding sprite: the tally / score / bonus / treasure digit strips
// (num_* texture rows), the full-combo / rank / difficulty glyphs (atlas
// quads), the jacket / name / chara portraits (standalone textures), and the
// two rank-effect animation layers (with a one-shot screen capture on the last
// frame). The dispatch structure and per-branch geometry are reproduced from
// the binary; leaf per- sprite geometry is delegated to the draw units above /
// AepDrawSpriteHandle / drawLayer.
// Verified against disassembly: dispatch by m_usr[N] (base +0x264, so
// +0x278..+0x2b0); chara portrait source rect w=0x38c h=0x75e (transpose fixed);
// jacket 0x168x0x168, name 0x126x0x20; digit strips use smmul-based %10 and the
// scaleX*dxStep/100 shift (score -0x22/6, judge -0x1c/3, bonus -0x21/4, big
// -0x3f/4); S_POINT strip 4 digits at step -= 0x20 until -0x80, x+0x12 base;
// rank-effect cross-fade idx from effFrame[2] (+0x2dc) vs effLyrFrames[2]
// (+0x2cc) with one-shot screenshot.
// @complete
void PlayResultTask::PlayResultDrawCallback(int child,
                                            int /*frame*/,
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
                                            uint32_t priority,
                                            void *context) {
    AepManager &aep = AepManager::shared();                        // Ghidra: AepManager_shared
    PlayResultTask *self = static_cast<PlayResultTask *>(context); // the PlayResultTask (param_15)

    // Atlas-quad tail (Ghidra: LAB_0003f8d6 -> FUN_0000fcd0): clip is always null
    // here and the ordering-table priority is the callback's `priority` argument
    // (the AEP group-draw callback's 14th arg; Ghidra mislabels it nColorG).
    auto rquad = [&](int handle) {
        AepDrawSpriteHandle(&aep,
                            handle,
                            x,
                            y,
                            scaleX,
                            scaleY,
                            rotation,
                            anchorX,
                            anchorY,
                            color,
                            alpha,
                            blend,
                            0xffffff,
                            nullptr,
                            (int)priority,
                            1);
    };
    // drawDigits only READS its digit row, so borrow the owning num_* slots as a
    // raw view rather than handing the routine a pointer-to-smart-pointer. The
    // returned array outlives the drawDigits call it is passed to (it lives to the
    // end of the enclosing full-expression).
    auto atlasView = []<std::size_t N>(const std::unique_ptr<neTextureForiOS>(&owned)[N]) {
        std::array<neTextureForiOS *, N> view{};
        for (std::size_t i = 0; i < N; i++) {
            view[i] = owned[i].get();
        }
        return view;
    };
    // A right-to-left digit strip: draw `value`'s ones place, then shift left by
    // (scaleX * dxStep)/100 per further digit, stopping once the value is a
    // single digit or `maxDigits` is reached. `row` is the num_* digit-texture
    // row (glyphs 0..9).
    auto drawDigits =
        [&](neTextureForiOS *const *row, int value, int w, int h, int dxStep, int maxDigits) {
            int v = value;
            int cx = x;
            for (int d = 0; d < maxDigits; ++d) {
                neTextureForiOS *tex = row[v % 10];
                drawTexQuad(aep,
                            tex,
                            0,
                            0,
                            w,
                            h,
                            cx,
                            y,
                            scaleX,
                            scaleY,
                            rotation,
                            anchorX,
                            anchorY,
                            color,
                            alpha,
                            (int)blend,
                            (int)priority);
                if (v < 10) {
                    return;
                }
                v /= 10;
                cx += (scaleX * dxStep) / 100;
            }
        };

    // --- Full-combo / perfect stamp (FULLCOMBO user, m_usr[5]) ---
    if (self->m_usr[5] == child) {
        if (self->m_rank == 0) { // rank 0: no stamp
            return;
        }
        int handle;
        if (self->m_perfectFullCombo == 0) { // not perfect full-combo
            if (self->m_cleared == 0) {      // not cleared either
                return;
            }
            handle = self->m_frmA[0]; // FULLCOMBO frame
        } else {
            handle = self->m_frmA[1]; // PERFECT frame
        }
        rquad(handle);
        return;
    }
    // --- Judge tally digit strips (COOL/GREAT/GOOD/BAD/COM, m_usr[6..10]) ---
    if (self->m_usr[6] == child) {
        drawDigits(atlasView(self->m_numCool).data(), (int)self->m_coolCount, 0x1a, 0x1e, -0x1c, 3);
        return;
    }
    if (self->m_usr[7] == child) {
        drawDigits(
            atlasView(self->m_numGreat).data(), (int)self->m_greatCount, 0x1a, 0x1e, -0x1c, 3);
        return;
    }
    if (self->m_usr[8] == child) {
        drawDigits(atlasView(self->m_numGood).data(), (int)self->m_goodCount, 0x1a, 0x1e, -0x1c, 3);
        return;
    }
    if (self->m_usr[9] == child) {
        drawDigits(atlasView(self->m_numBad).data(), (int)self->m_badCount, 0x1a, 0x1e, -0x1c, 3);
        return;
    }
    if (self->m_usr[10] == child) {
        drawDigits(atlasView(self->m_numCom).data(), (int)self->m_maxCombo, 0x1a, 0x1e, -0x1c, 3);
        return;
    }
    // --- Score digit strip (RESULT_SCORE, m_usr[11]) ---
    if (self->m_usr[11] == child) {
        drawDigits(atlasView(self->m_numScore).data(), self->m_score, 0x20, 0x28, -0x22, 6);
        return;
    }

    // --- Jacket / music-name standalone textures (m_usr[4] / m_usr[0]) ---
    if (self->m_usr[4] == child) {
        drawTexQuad(aep,
                    self->m_artworkTex.get(),
                    0,
                    0,
                    0x168,
                    0x168,
                    x,
                    y,
                    scaleX,
                    scaleY,
                    rotation,
                    anchorX,
                    anchorY,
                    color,
                    alpha,
                    (int)blend,
                    (int)priority);
        return;
    }
    if (self->m_usr[0] == child) {
        drawTexQuad(aep,
                    self->m_nameTex.get(),
                    0,
                    0,
                    0x126,
                    0x20,
                    x,
                    y,
                    scaleX,
                    scaleY,
                    rotation,
                    anchorX,
                    anchorY,
                    color,
                    alpha,
                    (int)blend,
                    (int)priority);
        return;
    }
    // --- Character portrait (RESULT_CHARA, m_usr[1]): board-scaled, anchors
    // doubled on phone ---
    if (self->m_usr[1] == child) {
        int ax = anchorX, ay = anchorY;
        if (self->m_padDisplay == 0) { // phone
            ay <<= 1;
            ax <<= 1;
        }
        const int boardScale = self->m_boardScale;
        // Ghidra: the portrait source rect is w=0x38c (908) by h=0x75e (1886) --
        // taller than wide. The decompiler/reconstruction had the w/h transposed
        // (0x75e,0x38c).
        drawTexQuad(aep,
                    self->m_charaTex.get(),
                    0,
                    0,
                    0x38c,
                    0x75e,
                    x,
                    y,
                    boardScale,
                    boardScale,
                    rotation,
                    ax,
                    ay,
                    color,
                    alpha,
                    (int)blend,
                    (int)priority);
        return;
    }

    // --- Difficulty font glyph (DIFFICULTY_FONT, m_usr[12]): selected by played
    // sheet ---
    if (self->m_usr[12] == child) {
        rquad(self->m_frmDifficulty[(int)self->m_sheet]);
        return;
    }
    // --- Bonus board glyph (BONUS_COM_BOARD, m_usr[13]): full-combo vs plain
    // board ---
    if (self->m_usr[13] == child) {
        const int idx = (self->m_cleared == 0) ? 2 : 3; // cleared -> BONUS_FULLCOM_BOARD
        rquad(self->m_frmA[idx]);
        return;
    }
    // --- Bonus / treasure digit strips (m_usr[14..17], m_usr[19]) ---
    if (self->m_usr[14] == child) {
        drawDigits(
            atlasView(self->m_numBonusClear).data(), self->m_clearBonus, 0x1e, 0x22, -0x21, 4);
        return;
    } // clear bonus
    if (self->m_usr[15] == child) {
        drawDigits(
            atlasView(self->m_numBonusCombo).data(), self->m_fullComboBonus, 0x1e, 0x22, -0x21, 4);
        return;
    } // combo bonus
    if (self->m_usr[16] == child) {
        drawDigits(atlasView(self->m_numBonusRank).data(), self->m_rankBonus, 0x1e, 0x22, -0x21, 4);
        return;
    } // rank bonus
    if (self->m_usr[17] == child) {
        drawDigits(
            atlasView(self->m_numBonusPerfect).data(), self->m_perfectBonus, 0x1e, 0x22, -0x21, 4);
        return;
    } // perfect bonus
    if (self->m_usr[19] == child) {
        drawDigits(
            atlasView(self->m_numPointsBig).data(), self->m_pointsCountUp, 0x3c, 0x48, -0x3f, 4);
        return;
    } // total (big)
    // Treasure-point strip (S_POINT_NUM, m_usr[18]): a fixed 4-digit field
    // (capped at 9999), laid out at absolute x offsets, drawn
    // most-significant-last.
    if (self->m_usr[18] == child) {
        int v = self->m_treasurePoint;
        if (v > 9999) {
            v = 9999;
        }
        for (int step = 0; step != -0x80; step -= 0x20) {
            neTextureForiOS *tex = self->m_numPoints[v % 10].get();
            drawTexQuad(aep,
                        tex,
                        0,
                        0,
                        0x22,
                        0x26,
                        step + x + 0x12,
                        y,
                        scaleX,
                        scaleY,
                        rotation,
                        anchorX,
                        anchorY,
                        color,
                        alpha,
                        (int)blend,
                        (int)priority);
            v /= 10;
        }
        return;
    }

    // --- Rank-effect layer A + rank glyph (DIFFICULTY_RUNK_NUMBER_E, m_usr[2])
    // ---
    if (self->m_usr[2] == child) {
        const int rank = (int)self->m_rank;
        if (rank == 0) {
            // Cross-fade the two AAA/AA effect layers: play layer 2 until its counter
            // reaches its length, then layer 3; freeze the backdrop the moment layer
            // 2 ends.
            const int count2 = self->m_effLyrFrames[2]; // effect layer 2 length
            const int counter2 = self->m_effFrame[2];   // effect layer 2 counter
            const int idx = (counter2 < count2) ? 2 : 3;
            const int fcnt = self->m_effFrame[idx];
            aep.drawLayer(self->m_effLyrNo[idx],
                          fcnt,
                          x,
                          y,
                          scaleX,
                          scaleY,
                          0,
                          anchorX,
                          anchorY,
                          color,
                          alpha,
                          1, // loopFlags (binary position 13, after colorHi)
                          0x10,
                          0xffffff,
                          nullptr, // clipRect
                          nullptr, // context (binary: str #0 -> null)
                          priority,
                          1);
            self->m_effFrame[idx] += 1;
            if (counter2 < count2) {
                return;
            }
            MainViewController *vc = RootVC();
            if ([vc getCapturedImage] == nil) {
                [vc screenshot];
            }
            self->m_effFrame[idx] = self->m_effFrame[idx] % self->m_effLyrFrames[idx];
            return;
        }
        // rank != 0: play the ranked effect layer (additively) while the intro
        // layer has settled, then draw the rank number glyph.
        AepLyrCtrl *intro = self->m_layers[0].get();
        if (intro == nullptr || !intro->isAnimating()) {     // FUN_0002cb64 == 0
            if (static_cast<unsigned short>(rank - 1) < 2) { // rank 1 or 2
                const int ei = (rank != 1) ? 1 : 0;
                // Ghidra 0x3fdca: anchorX, anchorY, color=[r7+0x18], colorHi=alpha
                // ([r7+0x1c]), loopFlags=1 -- same order as the m_usr[3] draw below.
                // The args were shifted (colorHi=1, loopFlags=anchorX).
                aep.drawLayer(self->m_effLyrNo[ei],
                              self->m_effFrame[ei],
                              x,
                              y,
                              scaleX,
                              scaleY,
                              rotation,
                              anchorX,
                              anchorY,
                              color,
                              alpha,
                              1,
                              0x200,
                              0xffffff,
                              clipRect,
                              nullptr,
                              static_cast<uint32_t>(priority),
                              1);
                self->m_effFrame[ei] = (self->m_effFrame[ei] + 1) % self->m_effLyrFrames[ei];
            }
            MainViewController *vc = RootVC();
            if ([vc getCapturedImage] == nil) {
                [vc screenshot];
            }
        }
        rquad(self->m_frmRank[rank]); // rank number glyph
        return;
    }
    // --- Rank-effect layer B + rank glyph (DIFFICULTY_RUNK_NUMBER_E2, m_usr[3])
    // ---
    if (self->m_usr[3] == child) {
        const int rank = (int)self->m_rank;
        if (rank == 0) {
            return;
        }
        AepLyrCtrl *intro = self->m_layers[0].get();
        if ((intro == nullptr || !intro->isAnimating()) &&
            static_cast<unsigned short>(rank - 1) < 2) {
            const int ei = (rank != 1) ? 1 : 0;
            aep.drawLayer(self->m_effLyrNo[ei],
                          self->m_effFrame[ei],
                          x,
                          y,
                          scaleX,
                          scaleY,
                          rotation,
                          anchorX,
                          anchorY,
                          color,
                          alpha,
                          1, // loopFlags (binary position 13, after colorHi)
                          0x200,
                          0xffffff,
                          clipRect,
                          nullptr, // context (binary: str #0 -> null)
                          priority,
                          1);
        }
        rquad(self->m_frmRank[rank]); // rank number glyph
        return;
    }
    // Unmatched child: nothing to draw.
}

// Ghidra: FUN_0003d5bc call site in PlayTaskGotoResult (operator_new(0x3a0)).
// @complete
ne::C_TASK *PlayResultCreateTask() {
    return new PlayResultTask();
}
