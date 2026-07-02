//
//  PlayResultTask.mm
//  pop'n rhythmin
//
//  See PlayResultTask.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (ctor FUN_0003d5bc, update FUN_0003d690). update() is reconstructed in pieces: the
//  fade/BGM intro, the wait states and the fade-out hand-off are here; the three
//  intricate blocks (result-data setup, the Twitter share button + rank-jingle cue, and
//  the score count-up) are their own methods (declared in the header; each fires a
//  result SE whose source id the decompiler could not trace to a field, so they are
//  reconstructed separately). Progress tracked in STUBS.md.
//

#import "PlayResultTask.h"

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
#import "OverScoreData.h"
#import "SeInstance.h"
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host (MainViewController) the result screen drives.
static MainViewController *RootVC() {
    return (__bridge MainViewController *)neSceneManager::rootViewController();
}

// Ghidra: FUN_0003d5bc — base C_TASK ctor, set the vtable, and zero the 0x378-byte
// result-data block (already done by m_data's initialiser and the base ctor).
PlayResultTask::PlayResultTask() {}

// Ghidra: FUN_0003d690 — the result-screen state machine.
void PlayResultTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];
    AudioManager *audio = [AudioManager sharedManager];
    neGraphics &gfx = neGraphics::shared();

    // Dismiss-tap detection: a released touch that barely moved (< 11 on both axes).
    bool tapped = false;
    int tapX = -1, tapY = -1;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->released != 0) {
            int dx = t->startX - t->x;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx < 11) {
                int dy = t->startY - t->y;
                if (dy < 0) {
                    dy = -dy;
                }
                if (dy < 11) {
                    tapped = true;
                    tapX = t->x;
                    tapY = t->y;
                    break;
                }
            }
        }
    }

    const int displayType = [[AppDelegate appDelegate] displayType];

    switch (state()) {
    case 0:
        // Set up the result data + load the result BGM, then start it. (The playBgm
        // fade argument is clobbered in the decompile by the preceding void call; 0.5
        // matches the fade the app's other playBgm sites use.)
        resultSetup();   // FUN_0003dfe0
        [audio playBgm:0.5f];
        state() = 1;
        break;
    case 1:
        // Fade the screen in and start the intro animation layers; drop the play scene's
        // captured backdrop now that this scene owns the display.
        aep.playTransition(1, 30, 0);
        SeInstancePlay(field<void *>(0x214));
        if (field<char>(0x356)) {
            field<AepLyrCtrl *>(0x228)->play();
        }
        if (field<char>(0x352)) {
            SeInstancePlay(field<void *>(0x224));
        }
        [RootVC() releaseCapturedImage];
        state() = 2;
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
        if (!SeInstanceIsPlaying(field<void *>(0x218))) {
            if (field<short>(0x35c) != 6) {
                state() = 5;
                break;
            }
            if (tapped) {   // rank 6 falls into the case-7 dismiss wait
                state() = 8;
            }
        }
        break;
    case 7:
        if (tapped) {
            state() = 8;
        }
        break;
    case 8:
        // Show the "communicating" overlay while the score upload is still in flight.
        if ([dl isSaveScoreDownLoading]) {
            [RootVC() InsertCommunicating];
            state() = 9;
        } else {
            state() = 10;
        }
        break;
    case 9:
        if (![dl isSaveScoreDownLoading]) {
            [RootVC() DeleteCommunicating];
            state() = 10;
        }
        break;
    case 10:
        aep.playTransition(2, 30, 0);   // fade out
        state() = 0xb;
        break;
    case 0xb:
        if (aep.isTransitionDone()) {
            state() = 0xc;
        }
        break;
    case 0xc:
        resultGotoNext();   // FUN_0003f2e0 — tear down + spawn the next scene
        break;
    default:
        break;
    }

    // Advance + draw every active animation layer this frame.
    AepLyrCtrlUpdateAll(0);   // FUN_0002c924
}

// Ghidra: FUN_0003dfe0 — build the whole result screen: snapshot the finished
// play's global result vars (the neAppEventCenter singleton fields, DAT_00187bxx),
// commit + upload the score, delete stale over-score records, compute the treasure
// bonuses, build the 6 animation layers + the ~130 number/artwork/chara textures,
// load the 11 rank SEs and the result BGM.
void PlayResultTask::resultSetup() {
    AepManager &aep = AepManager::shared();
    neAppEventCenter &evt = neAppEventCenter::shared();
    DownloadMain *dl = [DownloadMain getInstance];

    // Cache the fade-quad extents this scene draws its transition through.
    field<int>(0x33c) = aep.transitionOverlayWidth();    // FUN_0000f498
    field<int>(0x340) = aep.transitionOverlayHeight();   // FUN_0000f4a4

    // --- Snapshot the just-finished play's result (neAppEventCenter fields) ---
    field<int>(0x344)   = evt.playScore();     // DAT_00187bc8 score
    field<short>(0x350) = evt.maxCombo();      // DAT_00187bd0 max combo
    field<short>(0x348) = evt.coolCount();     // DAT_00187bc0 low  COOL tally
    field<short>(0x34a) = evt.greatCount();    // DAT_00187bc0 high GREAT tally
    field<short>(0x34c) = evt.goodCount();     // DAT_00187bc4 low  GOOD tally
    field<short>(0x34e) = evt.badCount();      // DAT_00187bc4 high BAD tally
    field<unsigned char>(0x352) = evt.isNewRecord() ? 1 : 0;  // DAT_00187bea new-record flag
    const bool cleared = evt.isCleared();      // DAT_00187bd4
    field<unsigned char>(0x354) = cleared ? 1 : 0;

    // +0x353: perfect full-combo == cleared with no GOOD and no BAD.
    field<unsigned char>(0x353) =
        (cleared && evt.goodCount() == 0 && evt.badCount() == 0) ? 1 : 0;

    field<short>(0x358) = (short)evt.lastSheet();  // DAT_00187bbc difficulty index
    field<short>(0x35c) = evt.playRank();          // DAT_00187bcc rank (0 best .. 6 fail)

    const short treasureStart = [UserSettingData treasurePoint];
    field<int>(0x360) = treasureStart;   // starting treasure point (for the count-up)
    field<int>(0x364) = treasureStart;   // running treasure point

    const int   music = evt.lastMusic();   // DAT_00187bb8
    const short sheet = field<short>(0x358);
    const short rank  = field<short>(0x35c);
    field<int>(0x38c) = music;

    // Pad-vs-phone display flag (scene manager DAT_00187b84).
    neSceneManager::shared();
    field<unsigned char>(0x355) = neSceneManager::isPadDisplay() ? 1 : 0;

    // --- Decide + post the score save (FUN_0003dfe0 @ 0x3e12c..0x3e604) ---
    int   stScore = 0;   short stRank = 0;   int stPlayCnt = 0;
    bool  stFullCombo = false, stPerfect = false;
    evt.readStoredResult(&stScore, &stRank, &stPlayCnt, &stFullCombo, &stPerfect);  // FUN_000293c4
    evt.commitResultToScoreData();   // FUN_00028ca0 — write the new local best

    const short charaId       = [UserSettingData charaId];
    const short charaIdServer = [UserSettingData charaIdServer];
    const bool  charaChanged  = (charaId != charaIdServer);
    if (charaChanged) {
        [UserSettingData saveCharaIdServer:[UserSettingData charaId]];
    }

    // Medal for the current play: 2 = perfect full-combo, else the cleared flag.
    const int medalCur = field<unsigned char>(0x353) ? 2 : field<unsigned char>(0x354);

    bool improved = false;
    if (stScore < field<int>(0x344) || rank < stRank || (!stFullCombo && cleared)) {
        improved = true;   // beat the stored score / rank, or first clear
    } else if (!stPerfect) {
        improved = (charaChanged || field<unsigned char>(0x353));  // new record / char resync
    } else {
        improved = charaChanged;
    }

    if (improved) {
        [UserSettingData addUncompleteSaveMusic:music sheet:sheet];
        [dl startSaveScoreHttp:music
                         sheet:sheet
                         score:field<int>(0x344)
                         medal:medalCur
                       charaId:[UserSettingData charaId]];
    } else {
        // Not improved: flush a previously-queued uncomplete-save entry if one
        // exists, otherwise re-sync this chart's stored score.
        NSArray *pendMusic = [UserSettingData uncompleteSaveMusic];
        NSArray *pendSheet = [UserSettingData uncompleteSaveSheet];
        if (pendMusic && pendSheet && pendMusic.count && pendSheet.count) {
            const int   pMusic = (int)[[pendMusic objectAtIndex:0] longValue];
            const short pSheet = (short)[[pendSheet objectAtIndex:0] intValue];
            int  rScore = 0; short rRank = 0; int rPlay = 0; bool rFC = false, rPerfect = false;
            evt.readStoredResult(&rScore, &rRank, &rPlay, &rFC, &rPerfect);  // re-read stored
            const int medalPend = rPerfect ? 2 : field<unsigned char>(0x354);
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
            field<unsigned char>(0x356) = 1;
        }
    }

    // --- Treasure-point bonuses ---
    // Base award by stored play count (newer songs award more).
    int treasureGain;
    if (stPlayCnt < 5)       treasureGain = 100;
    else if (stPlayCnt < 7)  treasureGain = 70;
    else if (stPlayCnt < 9)  treasureGain = 50;
    else if (stPlayCnt < 11) treasureGain = 30;
    else                     treasureGain = 20;
    field<int>(0x368) = treasureGain;
    if (field<unsigned char>(0x356)) {   // event-song bonus
        treasureGain += 100;
        field<int>(0x368) = treasureGain;
    }
    field<int>(0x37c) = treasureGain;

    // Clear bonus (20), zero on a wash-out (rank 6).
    field<int>(0x36c) = (rank == 6) ? 0 : 20;

    // Full-combo bonus, scaled by chart note count (only on a non-fail clear).
    if (field<unsigned char>(0x354) && rank != 6) {
        const int notes = NoteMng::shared().totalNoteCount();   // FUN_0000b278 / DAT_00178ccc
        int fcBonus;
        if (notes < 0x33)       fcBonus = 10;
        else if (notes < 0x65)  fcBonus = 11;
        else if (notes < 0x97)  fcBonus = 12;
        else if (notes < 0xc9)  fcBonus = 13;
        else if (notes < 0xfb)  fcBonus = 14;
        else if (notes < 0x12d) fcBonus = 15;
        else if (notes < 0x15f) fcBonus = 16;
        else if (notes < 0x191) fcBonus = 18;
        else                    fcBonus = 20;
        field<int>(0x370) = fcBonus;
    }

    // Rank bonus (S..fail). The default (rank > 6) leaves +0x374 unchanged.
    switch (rank) {
    case 0: field<int>(0x374) = 50; break;
    case 1: field<int>(0x374) = 40; break;
    case 2: field<int>(0x374) = 30; break;
    case 3: field<int>(0x374) = 20; break;
    case 4: field<int>(0x374) = 10; break;
    case 5: field<int>(0x374) = 5;  break;
    case 6: field<int>(0x374) = 0;  break;
    default: break;
    }

    // Perfect-full-combo bonus (10) and the total, then persist (capped at 9999).
    field<int>(0x378) = field<unsigned char>(0x353) ? 10 : 0;
    field<int>(0x380) =
        field<int>(0x378) + field<int>(0x36c) + field<int>(0x370) + field<int>(0x374);
    const short treasureTotal =
        (short)(field<int>(0x380) + field<int>(0x360) + field<int>(0x368));
    [UserSettingData saveTreasurePoint:(treasureTotal < 9999 ? treasureTotal : 9999)];

    // Board scale for the result layout (100 on pad, 50 on phone).
    field<int>(0x384) = field<unsigned char>(0x355) ? 100 : 50;

    // --- Load the result asset group + build the animation layers ---
    const bool pad = (field<unsigned char>(0x355) != 0);
    AepLoadGroup(&aep, 4, pad ? "result_ipad" : "result");   // FUN_0000f758

    // 4 effect layers resolved to raw layer handles + their frame counts.
    static const char *const kEffLayers[4] = {
        "DIFFICULTY_AAA_EFF", "DIFFICULTY_AA_EFF", "PERFECT_EFF_IN", "PERFECT_EFF_ROOP"
    };
    for (int i = 0; i < 4; i++) {
        const int lyr = aep.getLyrNo(4, kEffLayers[i]);          // FUN_0000fac8
        field<int>(0x2b4 + i * 4) = lyr;
        field<int>(0x2c4 + i * 4) = aep.layerFrameCount(lyr);    // FUN_0000fb8c
    }

    // The 6 AepLyrCtrl overlay layers (device-branched names; per-layer order value
    // from the static table @ 0x12e698; owner = this task).
    static const char *const kLayerPhone[6] = {
        "640IMG", "BONUS_FAILED_640", "BONUS_CLEAR_640",
        "BONUS_PERFECT_640", "NEW_RECORD_640", "BONUS_EVENT"
    };
    static const char *const kLayerPad[6] = {
        "1136IMG", "BONUS_FAILED_1136", "BONUS_CLEAR_1136",
        "BONUS_PERFECT_1136", "NEW_RECORD_1136", "BONUS_EVENT"
    };
    static const int kLayerOrder[6] = { 12, 9, 9, 9, 10, 11 };
    const int displayType = [[AppDelegate appDelegate] displayType];
    const char *const *layerNames = (displayType == 2) ? kLayerPad : kLayerPhone;
    for (int i = 0; i < 6; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();                    // operator_new(0x60) + FUN_0002c7d8
        field<AepLyrCtrl *>(0x214 + i * 4) = layer;
        layer->init(4, layerNames[i], this, kLayerOrder[i]);     // FUN_0002c834
    }

    // Frame/sprite handles resolved by name (getFrmNo).
    static const char *const kFrmA[4] = {
        "FULLCOMBO", "PERFECT", "BONUS_COM_BOARD", "BONUS_FULLCOM_BOARD"
    };
    for (int i = 0; i < 4; i++) {
        field<int>(0x22c + i * 4) = aep.getFrameNo(4, kFrmA[i]);   // FUN_0000f9cc
    }
    static const char *const kFrmB[3] = {
        "DIFFICULTY_NORMAL_FONT", "DIFFICULTY_HYPER_FONT", "DIFFICULTY_EX_FONT"
    };
    for (int i = 0; i < 3; i++) {
        field<int>(0x23c + i * 4) = aep.getFrameNo(4, kFrmB[i]);
    }
    // Note: entries 0 and 1 are both "..._AAA" in the binary (the AAA rank glyph is
    // referenced twice); reproduced faithfully.
    static const char *const kFrmC[7] = {
        "DIFFICULTY_RUNK_NUMBER_AAA", "DIFFICULTY_RUNK_NUMBER_AAA",
        "DIFFICULTY_RUNK_NUMBER_AA",  "DIFFICULTY_RUNK_NUMBER_A",
        "DIFFICULTY_RUNK_NUMBER_B",   "DIFFICULTY_RUNK_NUMBER_C",
        "DIFFICULTY_RUNK_NUMBER_D"
    };
    for (int i = 0; i < 7; i++) {
        field<int>(0x248 + i * 4) = aep.getFrameNo(4, kFrmC[i]);
    }

    // User-frame handles resolved by name (getUsrNo).
    static const char *const kUsr[20] = {
        "MUSIC_TITLE", "RESULT_CHARA", "DIFFICULTY_RUNK_NUMBER_E",
        "DIFFICULTY_RUNK_NUMBER_E2", "JACKET00", "FULLCOMBO", "COOL_0", "GREAT_0",
        "GOOD_0", "BAD_0", "COM_0", "RESULT_SCORE", "DIFFICULTY_FONT",
        "BONUS_COM_BOARD", "BONUS_CLEAR", "BONUS_COM", "BONUS_RANK",
        "BONUS_PERFECT", "S_POINT_NUM", "S_POINT_NUM_BIG"
    };
    for (int i = 0; i < 20; i++) {
        field<int>(0x264 + i * 4) = aep.getUserNo(4, kUsr[i]);    // FUN_0000fb40
    }

    // --- Artwork / name-image / chara textures ---
    MusicManager *mm = [MusicManager getInstance];
    [mm getMusicDataArray];                       // ensure the catalog cache is built
    MusicData *md = [mm getMusicData:music];

    neTextureForiOS *artTex = new neTextureForiOS();          // operator_new(0x18) + FUN_00011818
    field<neTextureForiOS *>(0x28) = artTex;
    artTex->loadFromImageData((__bridge const void *)[md artwork2xData]);       // FUN_00011cbc

    neTextureForiOS *nameTex = new neTextureForiOS();
    field<neTextureForiOS *>(0x2c) = nameTex;
    nameTex->loadFromImageData((__bridge const void *)[md musicNameImage2xData]);

    // Difficulty level for the played sheet (other sheet ids leave +0x35a as is).
    switch (sheet) {
    case 0: field<short>(0x35a) = (short)[md lvNormal]; break;
    case 1: field<short>(0x35a) = (short)[md lvHyper];  break;
    case 2: field<short>(0x35a) = (short)[md lvEx];     break;
    default: break;
    }

    neTextureForiOS *charaTex = new neTextureForiOS();
    field<neTextureForiOS *>(0x30) = charaTex;
    NSString *charaFile =
        [NSString stringWithFormat:@"result_chara%03d@2x.png", (int)[UserSettingData charaId]];
    NSString *charaPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
    charaTex->load([charaPath UTF8String]);        // FUN_00011a2c

    loadNumberTextures();

    // Install this scene's per-frame draw pass for group 4.
    aep.setGroupDrawCallback(4, &PlayResultDrawCallback, this);   // FUN_0000f9b0 (cb FUN_0003f5f0)

    // --- 11 rank SEs + the result BGM ---
    AudioManager *audio = [AudioManager sharedManager];
    // Entry 10 is a null pointer in the static image (a runtime-bound CFString that
    // could not be resolved statically); the loop still issues 11 loads, matching
    // the binary, so it stays as nil here.
    static NSString *const kRankSe[11] = {
        @"v31", @"v32", @"v33", @"v34", @"v35", @"v36", @"v38",
        @"se07_count", @"se08_bonus_fai", @"se09_bonus_cl", nil
    };
    for (int i = 0; i < 11; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:kRankSe[i] ofType:@"m4a"];
        field<RSND_SOURCE_ID>(0x2e4 + i * 4) =
            [audio loadSe:sePath isLoop:NO callName:nil group:1];
    }

    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm03_result.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];
}

// Ghidra: FUN_0003dfe0 inner double loop @ 0x3ea84..0x3ef9e — load the 10 digit
// glyphs (0..9) of each of the 12 number groups into the per-lane texture arrays.
void PlayResultTask::loadNumberTextures() {
    // {field-array base, resource-name prefix}. The digit 0..9 is appended to the
    // prefix; note the underscore is present/absent exactly as in the binary
    // (byte-verified: e.g. num_bonus_clear<d> and num_points<d> have no separator).
    struct NumGroup { int base; const char *prefix; };
    static const NumGroup kGroups[12] = {
        {0x34,  "num_cool_"},          {0x5c,  "num_great_"},
        {0x84,  "num_good_"},          {0xac,  "num_bad_"},
        {0xd4,  "num_com_"},           {0xfc,  "num_score_"},
        {0x124, "num_bonus_clear"},    {0x14c, "num_bonus_combo"},
        {0x174, "num_bonus_rank"},     {0x19c, "num_bonus_perfect"},
        {0x1c4, "num_points"},         {0x1ec, "num_pointb_"},
    };
    NSBundle *bundle = [NSBundle mainBundle];
    for (int lane = 0; lane < 10; lane++) {
        for (int g = 0; g < 12; g++) {
            const int off = kGroups[g].base + lane * 4;
            neTextureForiOS *tex = new neTextureForiOS();       // operator_new(0x18) + FUN_00011818
            field<neTextureForiOS *>(off) = tex;
            NSString *name = [NSString stringWithFormat:@"%s%d", kGroups[g].prefix, lane];
            NSString *path = [bundle pathForResource:name ofType:@"png"];
            tex->load([path UTF8String]);                       // FUN_00011a2c
        }
    }
}

// Ghidra: FUN_0003d690 case 2 — the results presentation. While the intro effect layer
// (+0x214) is still animating, fire the score-tally count SE (se07_count @ +0x2e4[7]) on
// its cue frames and the perfect jingle (v32 @ +0x2e4[1]) at frame 0x46; once it settles,
// build the Twitter share button (once the GL backdrop has been captured) and wait for a
// dismiss tap outside the button to advance to the count-up (state 3). All SE ids and the
// frame cues traced from the disassembly.
void PlayResultTask::updateResultPresent(bool tapped, int tapX, int tapY, int displayType) {
    AudioManager *audio = [AudioManager sharedManager];
    SeInstance *intro = reinterpret_cast<SeInstance *>(field<void *>(0x214));

    if (SeInstanceIsPlaying(intro)) {
        const int frame = (int)intro->cursor;   // +0x214 play head (+0x40)
        if (frame == 0x18 || frame == 0x28 || frame == 0x30 || frame == 0x38 || frame == 0x40) {
            [audio stopSe:static_cast<RSND_INSTANCE_ID>(field<int>(0x32c))];
            field<int>(0x32c) =
                static_cast<int>([audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x300)]);
        } else if (frame == 0x46 && field<unsigned char>(0x353) && field<short>(0x35c) != 0) {
            // Perfect full-combo (non-zero rank): the celebratory jingle (v32 @ +0x2e4[1]).
            [audio stopSe:static_cast<RSND_INSTANCE_ID>(field<int>(0x32c))];
            field<int>(0x32c) =
                static_cast<int>([audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x2e8)]);
        }
        return;
    }

    // Intro settled. Once the GL view has captured the backdrop, lay out the share button
    // (only once). Then a tap outside the button's area dismisses the presentation.
    if ([RootVC() getCapturedImage] != nil && field<void *>(0x398) == nullptr) {
        buildShareButton(displayType);
    }
    if (tapped) {
        const int bottomEdge = (displayType == 2) ? 0x370 : 0x30c;
        if (tapX > 0xdc || tapY < bottomEdge) {
            state() = 3;
            UIButton *shareButton = (__bridge UIButton *)field<void *>(0x398);
            if (shareButton != nil) {
                [shareButton setUserInteractionEnabled:NO];
            }
        }
    }
}

// Ghidra: FUN_0003d690 states 3/5/6 — the treasure-point count-up. State 4 (the wait
// between them) is handled inline in update(). All four SE source ids were traced from
// the disassembly (they index the 11-entry SE array resultSetup loaded @ +0x2e4):
//   +0x2fc = +0x2e4[6] "v38"           (case 3 line-in)
//   +0x304 = +0x2e4[8] "se08_bonus_fai" (case 5 tally start)
//   +0x300 = +0x2e4[7] "se07_count"     (case 6 per-step tick)
//   +0x308 = +0x2e4[9] "se09_bonus_cl"  (case 6 finish)
void PlayResultTask::updateScoreCount(bool tapped) {
    AudioManager *audio = [AudioManager sharedManager];
    switch (state()) {
    case 3:
        // Play the score line-in SE and start the score-line animation layer.
        [audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x2fc)];
        SeInstancePlay(field<void *>(0x218));
        state() = 4;
        break;
    case 5:
        // Stop the score line, start the count-up layer(s) (the second only on a perfect
        // full-combo), reset the tick counter, and play the bonus-tally start SE.
        SeInstanceStop(field<void *>(0x218));
        SeInstancePlay(field<void *>(0x21c));
        if (field<unsigned char>(0x353)) {
            SeInstancePlay(field<void *>(0x220));
        }
        field<int>(0x388) = 0;
        [audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x304)];
        state() = 6;
        break;
    case 6: {
        // Once the count layer settles, count the treasure total up. Every fifth step
        // retriggers the count SE (stopping the previous instance @ +0x32c first); a tap
        // snaps straight to the total. On reaching it, play the clear SE and finish.
        if (SeInstanceIsPlaying(field<void *>(0x21c))) {
            break;
        }
        const int total = field<int>(0x368) + field<int>(0x380);
        if (field<int>(0x37c) < total) {
            if (field<unsigned int>(0x388) % 5 == 0) {
                [audio stopSe:static_cast<RSND_INSTANCE_ID>(field<int>(0x32c))];
                field<int>(0x32c) =
                    static_cast<int>([audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x300)]);
            }
            field<int>(0x37c) += 1;
            field<unsigned int>(0x388) += 1;
            if (tapped) {
                field<int>(0x37c) = total;   // dismiss tap: jump to the final total
            }
        } else {
            field<int>(0x37c) = total;
            [audio playSe:nil resourceId:field<RSND_SOURCE_ID>(0x308)];
            state() = 7;
        }
        break;
    }
    default:
        break;
    }
}

// Ghidra: FUN_0003f2e0 — tear the result screen down (freeing exactly what
// resultSetup created) and hand off to the music-select task.
void PlayResultTask::resultGotoNext() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];

    // Stop + free the 11 rank SEs (@ 0x3f374).
    for (int i = 0; i < 11; i++) {
        RSND_SOURCE_ID se = field<RSND_SOURCE_ID>(0x2e4 + i * 4);
        [audio stopSe:se];
        [audio releaseSe:nil resourceId:se];
    }

    // Release the shared system SEs, clean up the mixer, then reload them for the
    // next scene (@ 0x3f3a4..0x3f3e0).
    neSceneManager::shared().releaseSystemSe();   // FUN_0002c6bc
    [audio cleanupSe];
    neSceneManager::shared().loadSystemSe();       // FUN_0002c5c8

    // Delete the artwork / name / chara textures (+0x28/+0x2c/+0x30).
    for (int i = 0; i < 3; i++) {
        neTextureForiOS *tex = field<neTextureForiOS *>(0x28 + i * 4);
        if (tex) {
            delete tex;
            field<neTextureForiOS *>(0x28 + i * 4) = nullptr;
        }
    }

    // Delete the 10-lane x 12-array number textures (@ 0x3f414..0x3f4f0).
    static const int kNumOffsets[12] = {
        0x34, 0x5c, 0x84, 0xac, 0xd4, 0xfc,
        0x124, 0x14c, 0x174, 0x19c, 0x1c4, 0x1ec
    };
    for (int lane = 0; lane < 10; lane++) {
        for (int g = 0; g < 12; g++) {
            const int off = kNumOffsets[g] + lane * 4;
            neTextureForiOS *tex = field<neTextureForiOS *>(off);
            if (tex) {
                delete tex;
                field<neTextureForiOS *>(off) = nullptr;
            }
        }
    }

    // Unlink + delete the 6 result layers (+0x214).
    for (int i = 0; i < 6; i++) {
        AepLyrCtrl *layer = field<AepLyrCtrl *>(0x214 + i * 4);
        if (layer) {
            layer->unlink();     // FUN_0002ca9c
            delete layer;
            field<AepLyrCtrl *>(0x214 + i * 4) = nullptr;
        }
    }

    // Remove the Twitter share button and release the TwitterUtil (+0x398/+0x39c).
    if (field<void *>(0x398)) {
        UIButton *shareButton = (__bridge UIButton *)field<void *>(0x398);
        [shareButton removeFromSuperview];
        field<void *>(0x398) = nullptr;
    }
    if (field<void *>(0x39c)) {
        // Held as an unmanaged raw +1 pointer; the binary sends -release, so transfer
        // ownership to ARC and let it drop at the end of this statement.
        (void)(__bridge_transfer id)field<void *>(0x39c);
        field<void *>(0x39c) = nullptr;
    }

    // Drop the result asset group and mark this task dead.
    AepUnloadGroup(&aep, 4);   // FUN_0000f988
    kill();                    // +0x24 = 1

    // Spawn (once) the standard music-select task and (re)prioritise it.
    if (field<void *>(0x390) == nullptr) {
        MainTask *next = new MainTask();      // operator_new(0xaa8) + FUN_00034d48
        field<void *>(0x390) = next;
    }
    static_cast<C_TASK *>(field<void *>(0x390))->setPriority(3);   // FUN_00027f08
}

// --- Result per-frame draw ---------------------------------------------------------
// PlayResultDrawCallback is a free function (the Aep group-4 draw callback), so it reaches
// the result-task data block by cited byte offset, the same convention resultSetup uses.
namespace {

inline int   rcI(void *p, int off)  { return *reinterpret_cast<int *>(reinterpret_cast<char *>(p) + off); }
inline short rcS(void *p, int off)  { return *reinterpret_cast<short *>(reinterpret_cast<char *>(p) + off); }
inline unsigned char rcB(void *p, int off) { return *reinterpret_cast<unsigned char *>(reinterpret_cast<char *>(p) + off); }
inline void *rcP(void *p, int off)  { return *reinterpret_cast<void **>(reinterpret_cast<char *>(p) + off); }
inline int  &rcIR(void *p, int off) { return *reinterpret_cast<int *>(reinterpret_cast<char *>(p) + off); }

// Ghidra: neTextureForiOS_draw (FUN_0000fbcc) -> AepOrderingTable_drawSprite (FUN_00011468).
// Emit one standalone-texture quad. Field mapping per FUN_00011468: u/v, x/y, sx/sy, w/h,
// ex=anchorX, ey=anchorY, colour @ +0x34, rotation @ +0x38, blend @ +0x3c; the wrapper's
// separate alpha word rides the +0x42 sub-blend slot (its exact home in this path is not
// fully pinned — best-effort so the fade survives).
void drawTexQuad(AepManager &aep, neTextureForiOS *tex, int u, int v, int w, int h,
                 int x, int y, int sx, int sy, int rotation, int anchorX, int anchorY,
                 int color, int alpha, int blend, int priority) {
    if (tex == nullptr) {
        return;
    }
    neSpriteDrawParams p;
    p.u = u; p.v = v; p.w = w; p.h = h;
    p.x = x; p.y = y; p.sx = sx; p.sy = sy;
    p.ex = anchorX; p.ey = anchorY;
    p.color = color; p.rotation = rotation;
    p.blend0 = (short)blend; p.blend1 = (short)alpha;
    p.colorMul = 0xffffff; p.priority = priority;
    tex->draw(aep.orderingTable(), p);
}

}  // namespace

// Ghidra: FUN_0003f5f0 — the result screen's per-frame draw pass, registered as group 4's
// draw callback (context = the PlayResultTask). It matches `child` against the result-data
// handle tables resultSetup filled and draws the corresponding sprite: the tally / score /
// bonus / treasure digit strips (num_* texture rows), the full-combo / rank / difficulty
// glyphs (atlas quads), the jacket / name / chara portraits (standalone textures), and the
// two rank-effect animation layers (with a one-shot screen capture on the last frame). The
// dispatch structure and per-branch geometry are reproduced from the binary; leaf per-
// sprite geometry is delegated to the draw units above / AepDrawSpriteHandle / drawLayer.
void PlayResultDrawCallback(int child, int /*frame*/, int x, int y, int scaleX, int scaleY,
                            int anchorX, int anchorY, int color, int alpha, int rotation,
                            uint32_t blend, int *clipRect, uint32_t p17, void *context) {
    AepManager &aep = AepManager::shared();   // Ghidra: AepManager_shared
    void *pd = context;                       // the PlayResultTask (param_15)

    // Atlas-quad tail (Ghidra: LAB_0003f8d6 -> FUN_0000fcd0): clip is always null here and
    // the priority is the incoming p17.
    auto rquad = [&](int handle) {
        AepDrawSpriteHandle(&aep, handle, x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                            color, alpha, blend, 0xffffff, nullptr, (int)p17, 1);
    };
    // A right-to-left digit strip: draw `value`'s ones place, then shift left by
    // (scaleX * dxStep)/100 per further digit, stopping once the value is a single digit
    // or `maxDigits` is reached. `base` is the num_* texture row.
    auto drawDigits = [&](int base, int value, int w, int h, int dxStep, int maxDigits) {
        int v = value;
        int cx = x;
        for (int d = 0; d < maxDigits; ++d) {
            neTextureForiOS *tex =
                reinterpret_cast<neTextureForiOS *>(rcP(pd, base + (v % 10) * 4));
            drawTexQuad(aep, tex, 0, 0, w, h, cx, y, scaleX, scaleY, rotation, anchorX, anchorY,
                        color, alpha, (int)blend, (int)p17);
            if (v < 10) {
                return;
            }
            v /= 10;
            cx += (scaleX * dxStep) / 100;
        }
    };

    // --- Full-combo / perfect stamp (FULLCOMBO user, +0x278) ---
    if (rcI(pd, 0x278) == child) {
        if (rcS(pd, 0x35c) == 0) {           // rank 0: no stamp
            return;
        }
        int handle;
        if (rcB(pd, 0x353) == 0) {           // not perfect full-combo
            if (rcB(pd, 0x354) == 0) {       // not cleared either
                return;
            }
            handle = rcI(pd, 0x22c);         // FULLCOMBO frame
        } else {
            handle = rcI(pd, 0x230);         // PERFECT frame
        }
        rquad(handle);
        return;
    }
    // --- Judge tally digit strips (COOL/GREAT/GOOD/BAD/COM, +0x27c..+0x28c) ---
    if (rcI(pd, 0x27c) == child) { drawDigits(0x34, (int)rcS(pd, 0x348), 0x1a, 0x1e, -0x1c, 3); return; }
    if (rcI(pd, 0x280) == child) { drawDigits(0x5c, (int)rcS(pd, 0x34a), 0x1a, 0x1e, -0x1c, 3); return; }
    if (rcI(pd, 0x284) == child) { drawDigits(0x84, (int)rcS(pd, 0x34c), 0x1a, 0x1e, -0x1c, 3); return; }
    if (rcI(pd, 0x288) == child) { drawDigits(0xac, (int)rcS(pd, 0x34e), 0x1a, 0x1e, -0x1c, 3); return; }
    if (rcI(pd, 0x28c) == child) { drawDigits(0xd4, (int)rcS(pd, 0x350), 0x1a, 0x1e, -0x1c, 3); return; }
    // --- Score digit strip (RESULT_SCORE, +0x290) ---
    if (rcI(pd, 0x290) == child) { drawDigits(0xfc, rcI(pd, 0x344), 0x20, 0x28, -0x22, 6); return; }

    // --- Jacket / music-name standalone textures (+0x274 / +0x264) ---
    if (rcI(pd, 0x274) == child) {
        drawTexQuad(aep, reinterpret_cast<neTextureForiOS *>(rcP(pd, 0x28)), 0, 0, 0x168, 0x168,
                    x, y, scaleX, scaleY, rotation, anchorX, anchorY, color, alpha, (int)blend, (int)p17);
        return;
    }
    if (rcI(pd, 0x264) == child) {
        drawTexQuad(aep, reinterpret_cast<neTextureForiOS *>(rcP(pd, 0x2c)), 0, 0, 0x126, 0x20,
                    x, y, scaleX, scaleY, rotation, anchorX, anchorY, color, alpha, (int)blend, (int)p17);
        return;
    }
    // --- Character portrait (RESULT_CHARA, +0x268): board-scaled, anchors doubled on phone ---
    if (rcI(pd, 0x268) == child) {
        int ax = anchorX, ay = anchorY;
        if (rcB(pd, 0x355) == 0) {           // phone
            ay <<= 1;
            ax <<= 1;
        }
        const int boardScale = rcI(pd, 0x384);
        drawTexQuad(aep, reinterpret_cast<neTextureForiOS *>(rcP(pd, 0x30)), 0, 0, 0x75e, 0x38c,
                    x, y, boardScale, boardScale, rotation, ax, ay, color, alpha, (int)blend, (int)p17);
        return;
    }

    // --- Difficulty font glyph (DIFFICULTY_FONT, +0x294): selected by played sheet ---
    if (rcI(pd, 0x294) == child) {
        rquad(rcI(pd, 0x23c + (int)rcS(pd, 0x358) * 4));
        return;
    }
    // --- Bonus board glyph (BONUS_COM_BOARD, +0x298): full-combo vs plain board ---
    if (rcI(pd, 0x298) == child) {
        const int idx = (rcB(pd, 0x354) == 0) ? 2 : 3;   // cleared -> BONUS_FULLCOM_BOARD
        rquad(rcI(pd, 0x22c + idx * 4));
        return;
    }
    // --- Bonus / treasure digit strips (+0x29c..+0x2b0) ---
    if (rcI(pd, 0x29c) == child) { drawDigits(0x124, rcI(pd, 0x36c), 0x1e, 0x22, -0x21, 4); return; }  // clear bonus
    if (rcI(pd, 0x2a0) == child) { drawDigits(0x14c, rcI(pd, 0x370), 0x1e, 0x22, -0x21, 4); return; }  // combo bonus
    if (rcI(pd, 0x2a4) == child) { drawDigits(0x174, rcI(pd, 0x374), 0x1e, 0x22, -0x21, 4); return; }  // rank bonus
    if (rcI(pd, 0x2a8) == child) { drawDigits(0x19c, rcI(pd, 0x378), 0x1e, 0x22, -0x21, 4); return; }  // perfect bonus
    if (rcI(pd, 0x2b0) == child) { drawDigits(0x1ec, rcI(pd, 0x37c), 0x3c, 0x48, -0x3f, 4); return; }  // total (big)
    // Treasure-point strip (S_POINT_NUM, +0x2ac): a fixed 4-digit field (capped at 9999),
    // laid out at absolute x offsets, drawn most-significant-last.
    if (rcI(pd, 0x2ac) == child) {
        int v = rcI(pd, 0x364);
        if (v > 9999) {
            v = 9999;
        }
        for (int step = 0; step != -0x80; step -= 0x20) {
            neTextureForiOS *tex =
                reinterpret_cast<neTextureForiOS *>(rcP(pd, 0x1c4 + (v % 10) * 4));
            drawTexQuad(aep, tex, 0, 0, 0x22, 0x26, step + x + 0x12, y, scaleX, scaleY, rotation,
                        anchorX, anchorY, color, alpha, (int)blend, (int)p17);
            v /= 10;
        }
        return;
    }

    // --- Rank-effect layer A + rank glyph (DIFFICULTY_RUNK_NUMBER_E, +0x26c) ---
    if (rcI(pd, 0x26c) == child) {
        const int rank = (int)rcS(pd, 0x35c);
        if (rank == 0) {
            // Cross-fade the two AAA/AA effect layers: play layer 2 until its counter
            // reaches its length, then layer 3; freeze the backdrop the moment layer 2 ends.
            const int count2 = rcI(pd, 0x2cc);          // effect layer 2 length
            const int counter2 = rcI(pd, 0x2dc);        // effect layer 2 counter
            const int idx = (counter2 < count2) ? 2 : 3;
            const int fcnt = rcI(pd, 0x2d4 + idx * 4);
            aep.drawLayer(rcI(pd, 0x2b4 + idx * 4), fcnt, x, y, scaleX, scaleY, 0,
                          1, anchorX, anchorY, color, alpha, 0x10,
                          0xffffff, nullptr, reinterpret_cast<void *>((intptr_t)p17), 0, 1);
            rcIR(pd, 0x2d4 + idx * 4) += 1;
            if (counter2 < count2) {
                return;
            }
            MainViewController *vc = RootVC();
            if ([vc getCapturedImage] == nil) {
                [vc screenshot];
            }
            rcIR(pd, 0x2d4 + idx * 4) = rcI(pd, 0x2d4 + idx * 4) % rcI(pd, 0x2c4 + idx * 4);
            return;
        }
        // rank != 0: play the ranked effect layer (additively) while the intro layer has
        // settled, then draw the rank number glyph.
        AepLyrCtrl *intro = reinterpret_cast<AepLyrCtrl *>(rcP(pd, 0x214));
        if (intro == nullptr || !intro->isAnimating()) {   // FUN_0002cb64 == 0
            if (static_cast<unsigned short>(rank - 1) < 2) {   // rank 1 or 2
                const int b = (rank != 1) ? 4 : 0;
                aep.drawLayer(rcI(pd, 0x2b4 + b), rcI(pd, 0x2d4 + b), x, y, scaleX, scaleY, rotation,
                              static_cast<uint32_t>(anchorX), anchorY, color, alpha, 1, 0x200,
                              0xffffff, clipRect, nullptr, static_cast<uint32_t>(p17), 1);
                rcIR(pd, 0x2d4 + b) = (rcI(pd, 0x2d4 + b) + 1) % rcI(pd, 0x2c4 + b);
            }
            MainViewController *vc = RootVC();
            if ([vc getCapturedImage] == nil) {
                [vc screenshot];
            }
        }
        rquad(rcI(pd, 0x248 + rank * 4));   // rank number glyph
        return;
    }
    // --- Rank-effect layer B + rank glyph (DIFFICULTY_RUNK_NUMBER_E2, +0x270) ---
    if (rcI(pd, 0x270) == child) {
        const int rank = (int)rcS(pd, 0x35c);
        if (rank == 0) {
            return;
        }
        AepLyrCtrl *intro = reinterpret_cast<AepLyrCtrl *>(rcP(pd, 0x214));
        if ((intro == nullptr || !intro->isAnimating()) &&
            static_cast<unsigned short>(rank - 1) < 2) {
            const int b = (rank != 1) ? 4 : 0;
            aep.drawLayer(rcI(pd, 0x2b4 + b), rcI(pd, 0x2d4 + b), x, y, scaleX, scaleY, rotation,
                          1, anchorX, anchorY, color, alpha, 0x200,
                          0xffffff, clipRect, reinterpret_cast<void *>((intptr_t)p17), 0, 1);
        }
        rquad(rcI(pd, 0x248 + rank * 4));   // rank number glyph
        return;
    }
    // Unmatched child: nothing to draw.
}

// Ghidra: FUN_0003d5bc call site in PlayTaskGotoResult (operator_new(0x3a0)).
C_TASK *PlayResultCreateTask() {
    return new PlayResultTask();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
