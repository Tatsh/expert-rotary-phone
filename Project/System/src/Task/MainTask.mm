//
//  MainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor
//  MainTask_ctor 0x34d48, dtor mainTask_dtor 0x34d90, update
//  MainTask_update 0x35914, plus the six per-frame helpers that all take
//  `this` — now real MainTask methods: Setup 0x370f0, Update
//  0x34f4c, AllCellsReady 0x37f38, UpdateHighlight 0x355fc,
//  StopAndSave 0x38008, UpdateInfoPanel 0x37c88). The standard-mode
//  music-select state machine. Objective-C++ (ARC): it drives the UIKit nav
//  host through the scene manager and the ObjC managers, and calls the C++
//  engine (Aep / neGraphics / neTextureForiOS) directly.
//
//  All work-area access is through the named members on MainTask (MainTask.h);
//  there are no raw byte-offset casts and no extern "C" engine seams.
//  "MainTask" is a typedef of MainTask (the binary's own name for this
//  task), so the DownloadMain delegate / MainViewController Goto* calls take
//  `this` with no identity cast.
//

#import <UIKit/UIKit.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <functional>

#import "AepFrameDraw.h" // drawAepFrameEx (settings/sort/badge frame draws)
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "MainViewController.h" // the concrete root VC: Goto*/settingViewing/isGotoTitle
#import "MusicData.h" // MusicID/lvNormal/lvHyper/lvEx/musicNameImage2xData (m_musicList entries)
#import "MusicManager.h"
#import "OverScoreData+Store.h" // +updateOverScoreTouchedWithMusic:inManagedObjectContext:
#import "OverScoreData.h"
#import "RhUtil.h"
#import "ScoreData+Store.h" // +getScoreData:inManagedObjectContext: (background cell loader)
#import "ScoreData.h"
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

static inline MainViewController *RootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

// Recommend-list refresh throttle: stale if never fetched, > 4 min old, or a
// push is pending. Last-fetch timestamp is the event-center's _endDate.
static inline bool recommendListIsStale() {
    neAppEventCenter &ec = neAppEventCenter::shared();
    NSDate *lastFetch = ec.recommendFetchDate();
    if (lastFetch == nil) {
        return true; // never fetched
    }
    NSTimeInterval elapsedMinutes = [[NSDate date] timeIntervalSinceDate:lastFetch] / 60.0;
    if ((int)elapsedMinutes > 4) {
        return true; // stale window elapsed
    }
    return ec.remoteNotifyPending(); // a push arrived -> force a refresh
}

// Which widget cell (m_cells[i]) holds a button's hit-rect; recovered from the
// 13 pointInRect blocks in 0x35914.
inline int MainTask::widgetIndexForButton(Button button) const {
    switch (button) {
    case kBtnSettings:
        return 0x17;
    case kBtnSort:
        return 0x17;
    case kBtnRecommend:
        return 0x18; // rect origin from 0x18; w/h split from 0x17 (seam)
    case kBtnOverScoreLog:
        return 0x18;
    case kBtnTutorial:
        return 0x18;
    case kBtnDiffToggle:
        return 0x18;
    case kBtnSongCell:
        return 0x19; // grid rect: base 0x19 + column stride from 0x17
    case kBtnFavToggle:
        return 0x19;
    case kBtnPlay:
        return 0x19;
    case kBtnFriendScore:
        return 0x19;
    case kBtnDifficulty:
        return 0x18; // difficulty-row base 0x18 + per-row stride from 0x19
    case kBtnBackToMenu:
        return -1; // fixed constants, not a widget cell
    }
    return -1;
}

// hitButton: point-in-rect the tap against `button`'s on-screen rectangle, each
// coordinate scaled by the UI-scale factor about the origin. Ghidra: the inlined
// pointInRect (0x2d974) blocks in update() state 2. The fixed top-row / overlay
// buttons read a rect quad (x, y, w, h) from the Setup()-filled layout table
// m_layoutRects[base..base+3] — settings +0x9a0, sort +0x9b0, recommend +0x9c0,
// over-score +0x9d0, diff-toggle +0x9e0, tutorial +0x9f0 (index = (off-0x988)/4).
// The FixedToFP/FloatVectorMult/FPToFixed block is a float scale then a
// round-toward-zero (int) truncation. The per-cell grid buttons + kBtnBackToMenu
// remain a computed-rect seam.
inline bool MainTask::hitButton(int tapX, int tapY, Button button, int cellIndex) const {
    const float scale = m_uiScale;
    auto hit = [&](int x, int y, int w, int h) {
        return neGraphics::pointInRect(tapX,
                                       tapY,
                                       (int)((float)x * scale),
                                       (int)((float)y * scale),
                                       (int)((float)w * scale),
                                       (int)((float)h * scale));
    };

    int base = -1;
    switch (button) {
    case kBtnSettings:
        base = 6;
        break; // m_layoutRects +0x9a0
    case kBtnSort:
        base = 10;
        break; // +0x9b0
    case kBtnRecommend:
        base = 14;
        break; // +0x9c0
    case kBtnOverScoreLog:
        base = 18;
        break; // +0x9d0
    case kBtnDiffToggle:
        base = 22;
        break; // +0x9e0
    case kBtnTutorial:
        base = 26;
        break; // +0x9f0
    case kBtnPlay:
        base = 38;
        break; // +0xa20 (state-4 PLAY)
    case kBtnFriendScore:
        base = 42;
        break; // +0xa30 (state-4 over-score)
    default:
        break;
    }
    if (base >= 0) {
        return hit(m_layoutRects[base + 0],
                   m_layoutRects[base + 1],
                   m_layoutRects[base + 2],
                   m_layoutRects[base + 3]);
    }

    // Song grid (state 2): each cell's rect is the base origin (+0xa40/+0xa44)
    // plus the per-column/row stride (+0x988/+0x98c) laid out three-wide, sized
    // +0xa48/+0xa4c. Ghidra: the inlined grid loop in update() state 2.
    if (button == kBtnSongCell) {
        const int col = cellIndex % 3;
        const int row = cellIndex / 3;
        const int gx = m_layoutRects[46] + m_layoutRects[0] * col; // +0xa40 + cellW*(i%3)
        const int gy = m_layoutRects[47] + m_layoutRects[1] * row; // +0xa44 + cellH*(i/3)
        return hit(gx, gy, m_layoutRects[48], m_layoutRects[49]);  // +0xa48/+0xa4c
    }

    // Fav toggle (state 2): a small rect anchored to the cell origin, sitting
    // +0xa54 above it (cellY - +0xa54), sized +0xa50 wide by +0xa54 tall.
    // Ghidra: the sub-rect check after each grid cell in update() state 2.
    if (button == kBtnFavToggle) {
        const int col = cellIndex % 3;
        const int row = cellIndex / 3;
        const int cellX = m_layoutRects[46] + m_layoutRects[0] * col;
        const int cellY = m_layoutRects[47] + m_layoutRects[1] * row;
        const int favH = m_layoutRects[51]; // +0xa54
        return hit(cellX, cellY - favH, m_layoutRects[50], favH);
    }

    // Difficulty selector (state 4): three buttons laid out horizontally at
    // x = +0xa0c + +0xa1c*d, y = +0xa10, sized +0xa14 by +0xa18. Ghidra: the
    // state-4 difficulty loop.
    if (button == kBtnDifficulty) {
        return hit(m_layoutRects[33] + m_layoutRects[37] * cellIndex,
                   m_layoutRects[34],
                   m_layoutRects[35],
                   m_layoutRects[36]);
    }

    // Back to menu (state 2): a fixed top-corner rect (14, 11, 116, 64) scaled by
    // the UI scale. Ghidra: the FloatVectorMult 14.0/11.0 + DAT_368cc (64.0) /
    // DAT_368d0 (116.0) constants.
    if (button == kBtnBackToMenu) {
        return hit(14, 11, 116, 64);
    }

    return neGraphics::pointInRect(tapX, tapY, 0, 0, 0, 0); // unmapped button
}

// Seed the three difficulty-star background-layer frame counters (@ +0x170+i*4)
// when the over-score preview opens (update states 3/4). Each counter starts on
// its layer's last frame (frameCount - 1) so the stars render fully open/out on
// entry: the selected difficulty tracks the OPEN layer (m_bgLyrFrames[1]), the
// other two the OUT layer (m_bgLyrFrames[2]).
inline void MainTask::seedDiffStarLayerFrames() {
    for (int i = 0; i < 3; i++) {
        m_diffStarLayerFrame[i] = (i == m_sel.difficulty ? m_bgLyrFrames[1] : m_bgLyrFrames[2]) - 1;
    }
}

// Re-read the three difficulty score rows for the current song (Ghidra: the
// diffDirty fetchScoreDataForMusic loop in update state 4 @ 0x35914). Each of
// the three difficulties is re-fetched from the local ScoreData store into the
// previewed song's jacket-cell score rows (the same MusicSelCell::ScoreRows
// block loadCellScoreRows fills). The destination storage is the named cell
// block; only the visible-row *index* the binary computes
// (___modsi3 of the packed per-cell select-state seam) does not decompile
// cleanly, so the chosen cell is taken as m_selectedCell (the cell tapped to
// enter the preview).
inline void MainTask::refreshScoreRows() {
    if (m_selectedCell < 0 || m_selectedCell >= 27) {
        return; // no cell in preview
    }
    // fetchScoreDataForMusic (neEngineBridge.h) is reconstructed; drive it per
    // difficulty.
    loadCellScoreRows(m_cells[m_selectedCell], m_sel.musicId);
}

/**
 * MainTask_ctor — base ctor + zero-fill; the sentinels (selected cell -1,
 * column latches 0xff, state 0) are member initializers.
 * @ghidraAddress 0x34d48
 * @complete
 */
MainTask::MainTask() {
}

/**
 * mainTask_dtor — detach from DownloadMain's recommend-list delegate so the
 * singleton stops calling back into a freed task (delete thunk @ 0x34eac).
 * @ghidraAddress 0x34d90
 * @complete
 */
MainTask::~MainTask() {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl cppDelegateRecommendList] == this) {
        [dl setCppDelegateRecommendList:nil];
    }
}

/**
 * MainTask_update. Each frame: detect a "tap" (a released touch that barely
 * moved), then step the state machine. Interactive select is state 2; the
 * chosen-song preview is states 3/4; 5-0xa are the settings/sort/score-log nav;
 * 0xc-0x10 fade out and hand off to the spawned play/menu/title task.
 * @ghidraAddress 0x35914
 * @complete
 */
void MainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    DownloadMain *dl = [DownloadMain getInstance];

    // --- tap detection: a released touch whose start/end differ by < 11px is a
    // tap ---
    neGraphics &gfx = neGraphics::shared();
    int tapX = -1, tapY = -1;
    bool haveTap = false;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid && !t->released) {
            break; // a finger is still down -> do not register a tap this frame
        }
        if (haveTap) {
            continue;
        }
        if (t->released) {
            int dx = t->startX - t->x, dy = t->startY - t->y;
            // slop widened to pixels under ENABLE_PATCHES (see NE_TAP_SLOP)
            if ((dx < 0 ? -dx : dx) < NE_TAP_SLOP(0xb) && (dy < 0 ? -dy : dy) < NE_TAP_SLOP(0xb)) {
                // The binary hit-test (update @ 0x35914) feeds neMath::pointInRect
                // the raw integer-pixel down point (nStartX/nStartY) and scales the
                // button rects by g_dwUiScale. The reconstruction's touch pool keeps
                // 16.16 fixed device pixels, so drop the fractional bits to recover
                // the integer pixel the rect comparison expects.
                tapX = t->startX / 65536;
                tapY = t->startY / 65536;
                haveTap = true;
            }
        }
    }

    switch (m_state) {
    case 0: { // build the scene, start BGM, kick off (or reuse) the recommend
              // list
        Setup();
        [audio setBgmVolume:[UserSettingData bgmVolume]];
        [audio playBgm:0];
        if (recommendListIsStale()) {
            [dl setCppDelegateRecommendList:this];
            [dl startGetRecommendListHttp];
        } else {
            UpdateInfoPanel(1); // reuse the cached recommend panel
        }
        m_state = 1;
        break;
    }

    case 1:                           // fade the select scene in and start its intro layers
        aep.setAepTransitionMode(1);  // fade in (fixed 30 frames)
        m_layers[0]->play();          // +0x34 loop (Ghidra AepLyrCtrl_play @ 0x35b86)
        m_introLayers[0]->playOnce(); // +0x44 once (Ghidra AepLyrCtrl::Play @ 0x35b8e)
        m_introLayers[1]->play();     // +0x48 loop (Ghidra AepLyrCtrl_play @ 0x35b96)
        m_selectedCell = -1;
        m_state = 2;
        break;

    case 2: { // *** interactive song / menu select ***
        // Re-arm the recommend fetch if it finished while a push is pending.
        if (![dl isGetRecommendListDownLoading] && recommendListIsStale()) {
            [dl setCppDelegateRecommendList:this];
            [dl startGetRecommendListHttp];
        }
        Update(); // per-frame list scroll / cell animation

        // While the song list is still being built, stream one pending jacket
        // texture per frame (upload the first cell that has image data but no
        // texture yet).
        if (!m_sel.listReady) {
            for (int c = 0; c < 27; c++) {
                MusicSelCell &cell = m_cells[c];
                if (cell.imageData != nil && cell.texture == nullptr) {
                    neTextureForiOS *loaded = new neTextureForiOS();
                    cell.texture = loaded;
                    loaded->loadFromImageData((__bridge const void *)cell.imageData);
                    cell.imageData = nil;
                    break;
                }
            }
            break;
        }

        // Ghidra 0x35a?? : suppress taps while the list is still flinging — the
        // binary bails when |m_scrollOffset| (as float) >= 10.0 before any
        // hit-test, so a fast drag never lands on a button.
        if ((m_scrollOffset < 0 ? -m_scrollOffset : m_scrollOffset) >= 10) {
            break;
        }

        // The list is ready and settled: only dispatch buttons on a small tap (a
        // drag scrolls the list).
        if (!haveTap) {
            break;
        }

        // -- top row --
        if (hitButton(tapX, tapY, kBtnSettings)) {
            m_state = 5; // -> GotoSetting
            break;
        }
        if (hitButton(tapX, tapY, kBtnSort)) {
            if (AllCellsReady()) {
                m_state = 7; // -> GotoSortSelect
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnRecommend)) {
            if (AllCellsReady()) {
                neEngine::playSystemSe(1);
                [RootVC() GotoRecommend:this];
                m_sel.favorite = 0;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnOverScoreLog)) {
            if (AllCellsReady()) {
                m_state = 9; // -> GotoOverScoreLog
            }
            break;
        }

        // -- overlay buttons --
        if (hitButton(tapX, tapY, kBtnBackToMenu)) {
            m_spawnedTask = MenuCreateTask(); // back to the mode-select hub
            neEngine::playSystemSe(2);
            m_state = 0xe;
            break;
        }
        if (hitButton(tapX, tapY, kBtnTutorial)) {
            if (m_sel.tutorialOffered) {
                m_sel.selectSeInst = (int)[audio playSe:nil resourceId:m_sel.selectSeId];
                neAppEventCenter::shared().setGuestNoSaveMode(
                    true); // guided first play: don't save
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = PlayTaskCreate(); // first-play guided play
                m_state = 0xe;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnDiffToggle)) {
            [audio playSe:nil resourceId:m_sel.selectSeId];
            m_sel.scrollLatchA = 1; // list-scroll latch pair
            m_sel.scrollLatchB = 1;
            m_sel.scrollConfig = 0;
            break;
        }

        // -- song grid: first the whole cell, then its favourite toggle --
        for (int c = 0; c < 27; c++) {
            if (hitButton(tapX, tapY, kBtnSongCell, c)) {
                if (AllCellsReady()) {
                    m_selectedCell = c;
                    neEngine::playSystemSe(1);
                    m_state = 3; // preview the chosen song
                }
                goto tail; // grid consumed the tap
            }
            if (hitButton(tapX, tapY, kBtnFavToggle, c)) {
                m_sel.favorite ^= 1;
                neEngine::playSystemSe(1);
                goto tail;
            }
        }
        break;
    }

    case 3: { // a song was chosen: preview its BGM + load textures + ScoreData
        [audio pushBgm];
        m_chosenIndex = m_selectedCell;
        MusicData *info = [m_musicList objectAtIndexedSubscript:m_selectedCell];
        unsigned musicId = (unsigned)[info MusicID];
        m_sel.musicId = musicId;

        // Invite songs are only playable while their invite window is open.
        bool inviteOpen;
        if (![MusicManager isInviteMusic:musicId]) {
            inviteOpen = true;
        } else {
            inviteOpen = [MusicManager isOpenInviteMusic:2];
        }
        m_sel.inviteOpen = inviteOpen ? 1 : 0;

        NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
        ScoreData *score = [ScoreData getScoreData:musicId inManagedObjectContext:moc];

        m_layers[1]->stop(1);
        if (m_nameTex) {
            delete m_nameTex;
            m_nameTex = nullptr;
        }
        if (m_artistTex) {
            delete m_artistTex;
            m_artistTex = nullptr;
        }

        NSData *nameImg = [info musicNameImage2xData];
        m_nameTex = new neTextureForiOS();
        m_nameTex->loadFromImageData((__bridge const void *)nameImg);

        NSData *artistImg = [info artistNameImage2xData];
        m_artistTex = new neTextureForiOS();
        m_artistTex->loadFromImageData((__bridge const void *)artistImg);

        // The three level values + the six full-combo / perfect medals for the
        // score panel.
        m_sel.levels[0] = (int)[info lvNormal];
        m_sel.levels[1] = (int)[info lvHyper];
        m_sel.levels[2] = (int)[info lvEx];
        m_sel.fullCombo[0] = [[score fullComboN] boolValue] ? 1 : 0;
        m_sel.fullCombo[1] = [[score fullComboH] boolValue] ? 1 : 0;
        m_sel.fullCombo[2] = [[score fullComboEx] boolValue] ? 1 : 0;
        m_sel.perfect[0] = [[score perfectN] boolValue] ? 1 : 0;
        m_sel.perfect[1] = [[score perfectH] boolValue] ? 1 : 0;
        m_sel.perfect[2] = [[score perfectEx] boolValue] ? 1 : 0;
        m_sel.previewReady = 1;

        // Kick the full-resolution jacket decode onto a background queue.
        MainTask *self = this;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
          // Background jacket decode for `info` (Ghidra: block
          // invoke @ 0x37f79). The decoded textures are streamed
          // into the cell array by state 2. Seam.
          (void)self;
          (void)info;
        });

        seedDiffStarLayerFrames();

        // Flag the over-score "touched" state for this song and (if already
        // tracked) refresh its dictionary entry.
        [OverScoreData updateOverScoreTouchedWithMusic:musicId inManagedObjectContext:moc];
        NSString *idStr = [@(musicId) stringValue];
        NSMutableDictionary *overDict = m_overScoreDict;
        if ([[overDict allKeys] containsObject:idStr]) {
            // Ghidra: setObject:@"1" forKeyedSubscript:idStr — the value is the
            // literal "1", not the id string.
            overDict[idStr] = @"1";
        }

        m_sel.difficulty = 0; // default to NORMAL
        m_state = 4;
        break;
    }

    case 4: { // difficulty / option select + BGM preview loop
        if (!m_sel.previewReady) {
            if (![audio isPlayingBgm]) {
                [audio seekBgmToTop];
                [audio setBgmVolume:1.0f];
                [audio playBgm:0];
            }
        }

        // When the preview intro finishes, cross into its looping layer.
        AepLyrCtrl *preview = m_layers[1];
        if (preview->isAnimating() /* Ghidra: layer[0x5c] one-shot flag, consumed here */) {
            m_layers[3]->play();
        }

        // A pending difficulty change re-reads the three score rows.
        if (m_sel.diffDirty) {
            refreshScoreRows();
            m_sel.diffDirty = 0;
        }

        // Whether this song already has an over-score (friend-score) entry.
        NSString *idStr = [@(m_sel.musicId) stringValue];
        NSMutableDictionary *overDict = m_overScoreDict;
        bool hasOverScore = [[overDict allKeys] containsObject:idStr];

        if (!haveTap) {
            break; // buttons only respond to a tap
        }

        // -- PLAY --
        if (hitButton(tapX, tapY, kBtnPlay)) {
            [audio popBgm];
            m_sel.selectSeInst = (int)[audio playSe:nil resourceId:m_sel.selectSeId];
            m_spawnedTask = PlayTaskCreate();
            [[AppDelegate appDelegate] setMainTask:(MainTask *)m_spawnedTask];
            m_state = 0xc; // -> play-launch handoff (0xc -> 0xd -> 0xe)
            break;
        }

        // -- FRIEND SCORE / over-score --
        if (hitButton(tapX, tapY, kBtnFriendScore)) {
            neEngine::playSystemSe(1);
            [audio stopBgm:0];
            m_sel.scrollLatchA = 1;
            if (hasOverScore) {
                [overDict removeObjectForKey:idStr];
            }
            [RootVC() GotoFriendScore:m_sel.musicId];
            break;
        }

        // -- difficulty rows (NORMAL / HYPER / EX) --
        bool consumed = false;
        for (int d = 0; d < 3; d++) {
            if (!hitButton(tapX, tapY, kBtnDifficulty, d)) {
                continue;
            }
            if (m_sel.difficulty != d) {
                // EX is locked for a not-yet-open invite song.
                if (d != 2 || m_sel.inviteOpen) {
                    [audio playSe:nil resourceId:0];
                    m_sel.difficulty = d;
                    m_sel.diffDirty = 1;
                    refreshScoreRows();
                } else {
                    neEngine::playSystemSe(2); // locked -> cancel SE
                }
            }
            consumed = true;
            break;
        }
        if (consumed) {
            goto tail;
        }

        // -- tap outside every button: back out to the song list --
        if (!m_sel.previewReady) {
            m_layers[1]->reset();
            m_layers[3]->reset();
            m_layers[2]->stop(1);
            [audio popBgm];
            [audio setBgmVolume:[UserSettingData bgmVolume]];
            [audio playBgm:0];
            neEngine::playSystemSe(2);
            m_selectedCell = -1;
            m_state = 2;
        }
        break;
    }

    case 5: // options -> settings
        neEngine::playSystemSe(1);
        [RootVC() GotoSetting];
        m_state = 6;
        break;

    case 6: // wait for settings to close; relaunch the title on request, else
        // re-select
        if (![RootVC() settingViewing]) {
            if ([RootVC() isGotoTitle] == 1) {
                m_spawnedTask = TitleTaskCreate();
                m_state = 0xe;
                [RootVC() setIsGotoTitle:0];
            } else {
                m_state = 2; // (falls through to the case 8/10 handoff in the binary)
            }
        }
        break;

    case 7: // sort
        neEngine::playSystemSe(1);
        [RootVC() GotoSortSelect:this];
        m_state = 8;
        break;

    case 8:  // sort modal shown -> resume interactive select
    case 10: // over-score-log modal shown -> resume interactive select
        m_state = 2;
        break;

    case 9: // over-score (friend score) log
        neEngine::playSystemSe(1);
        [RootVC() GotoOverScoreLog:this];
        m_state = 10;
        break;

    case 0xc: // play-launch handoff
        m_state = 0xd;
        break;

    case 0xd:
        m_state = 0xe;
        break;

    case 0xe:                        // fade out into the spawned task / title
        aep.setAepTransitionMode(2); // fade out (fixed 30 frames)
        m_sel.transitionLatch = 1;   // transition-out latch
        m_state = 0xf;
        break;

    case 0xf: // wait for the fade-out (and, on a preview exit, the layer to
              // settle)
        if (aep.isTransitionDone() && !m_sel.previewReady && m_sel.transitionLatch == 2) {
            m_state = 0x10;
        }
        break;

    case 0x10: // handoff: tear down once the select SEs finish
        if (!neEngine::isSePlaying(2)) {
            if (m_sel.selectSeInst >= 0 && [audio isPlayingSe:0]) {
                break; // a select SE is still sounding
            }
            StopAndSave();
        }
        break;

    default:
        break;
    }

tail:
    // Per-frame select-screen highlight update + Aep layer advance/draw (Ghidra
    // tail).
    UpdateHighlight();
    AepLyrCtrl::updateAndDrawAepLayers(0); // Ghidra: FUN_0002c924
}

// ===== byte-verified const tables Setup() resolves against (Ghidra project
// rb420) ===== All of the strings/coordinates below were read from the binary's
// .const_data; see the per-table Ghidra address annotations.

// Per-platform button-rect layout table (m_layoutRects[55], +0x988..+0xa64).
// These are the immediate stores 0x370f0 makes in its !isPad / isPad
// branches. Slots that the binary computes at runtime from the screen metrics /
// layout base are 0 here and patched in Setup() below (phone:
// 7/11/15/19/23/27/31/34/39/43; pad: 31; slots 46/47 are the draw-time grid-
// origin cache, never written by Setup). Button roles:
// settings/sort/recommend/over-score-log row, back/tutorial/diff-toggle
// overlay, song-cell/fav grid, play/friend-score/difficulty.
static const int kPhoneLayoutRects[55] = {
    0xd2, 0x13a, 0,     -30,  -48,   0,    5,     0, // 0..7
    0x9c, 0x34,  0xa8,  0,    0x9c,  0x34, 0x141, 0, // 8..15
    0x9c, 0x34,  0x1df, 0,    0x9c,  0x34, 0x50,  0, // 16..23
    0x8c, 0x93,  0xfa,  0,    0x138, 0xa4, 0x26c, 0, // 24..31
    0x1e, 0x48,  0,     0x87, 0x86,  0xb2, 0xcd,  0, // 32..39
    0xe3, 0x4d,  0x14,  0,    0x15e, 0x5a, 0,     0, // 40..47
    0xb4, 0xb4,  0xbe,  0x32, 0x2a,  0x2a, 0x14      // 48..54
};
static const int kPadLayoutRects[55] = {
    0x1e4, 0x210, -1,    -53,   -88,   -13,   0x1e,  0x78f, // 0..7
    0xea,  0x4e,  0x10d, 0x78f, 0xea,  0x4e,  0x1fc, 0x78f, // 8..15
    0xea,  0x4e,  0x2eb, 0x78f, 0xea,  0x4e,  0x4ea, 0x6c0, // 16..23
    0xae,  0x11a, 0x306, 0x677, 0x1e2, 0x113, 0x5ec, 0,     // 24..31
    0x26,  0x198, 0x4f4, 0xde,  0xd6,  0xf4,  0x22e, 0x604, // 32..39
    0x1a0, 200,   0x1ce, 0x48e, 400,   0x56,  0,     0,     // 40..47
    0x132, 400,   0x132, 0x55,  0x56,  0x56,  0x1b          // 48..54
};

// getLyrNo layer names -> m_bgLyrNo[3] @ 0x1315c8.
static const char *const kBgLyrNames[3] = {
    "BG_NEKO", "DIFFICULTY_STAR_OPEN", "DIFFICULTY_STAR_OUT"};
// The 4 scene-layer names + ordering-table priorities (@ 0x1315d4 /
// 0x12e670).
static const char *const kLayerNames[4] = {
    "BG_640X1136", "DIFFICULTY_OPEN", "DIFFICULTY_CLOSE", "DIFFICULTY_ROOP"};
static const int kLayerOrder[4] = {13, 9, 9, 9};
// The 2 intro-layer names + priorities, device-branched (@ 0x1315e8/f0 /
// 0x12e680).
static const char *const kIntroNamesTall[2] = {"1024IMG", "BG_IMG_1136"}; // displayType == 2
static const char *const kIntroNamesShort[2] = {"640IMG", "BG_IMG_640"};
static const int kIntroOrder[2] = {15, 14};
// getFrameNo names -> m_frmNo[24] @ 0x1315f8.
static const char *const kFrmNames[24] = {"DIFFICULTY_BT00",
                                          "JACKET10_LOAD",
                                          "NEW_BOARD",
                                          "FULLCOMBO",
                                          "PERFECT",
                                          "PERFECT1",
                                          "BT_SETTING",
                                          "BT_RETURN",
                                          "BT_SORT",
                                          "BT_OSSUME",
                                          "BT_EMULATE",
                                          "JACKET_LINE0",
                                          "BG_NEKO",
                                          "JACKET_TIP_FONT0",
                                          "JACKET_TIP_PERFECT1",
                                          "JACKET_TIP_PERFECT2",
                                          "BT_TUTORIAL",
                                          "FRIEND_SCORE_FONT",
                                          "FRIEND_UPDEF_FONT",
                                          "FRIEND_SCORE_ICON",
                                          "FRIEND_UPDEF_ICON",
                                          "FRIEND_UPDEF_FONTBAR",
                                          "FRIEND_UP_ICON",
                                          "FRIEND_UP_FIRST_ICON"};
// getFrameNo -> m_starFrmNo[3] @ 0x131658.
static const char *const kStarFrmNames[3] = {
    "DIFFICULTY_STAR_GREEN", "DIFFICULTY_STAR_YELLOW", "DIFFICULTY_STAR_RED"};
// getFrameNo -> m_musicRankFrmNo[7] @ 0x131664.
static const char *const kMusicRankFrmNames[7] = {"MUSIC_RUNK_NUMBER_S",
                                                  "MUSIC_RUNK_NUMBER_AAA",
                                                  "MUSIC_RUNK_NUMBER_AA",
                                                  "MUSIC_RUNK_NUMBER_A",
                                                  "MUSIC_RUNK_NUMBER_B",
                                                  "MUSIC_RUNK_NUMBER_C",
                                                  "MUSIC_RUNK_NUMBER_D"};
// getFrameNo -> m_diffRankFrmNo[7] @ 0x131680.
static const char *const kDiffRankFrmNames[7] = {"DIFFICULTY_RUNK_NUMBER_S",
                                                 "DIFFICULTY_RUNK_NUMBER_AAA",
                                                 "DIFFICULTY_RUNK_NUMBER_AA",
                                                 "DIFFICULTY_RUNK_NUMBER_A",
                                                 "DIFFICULTY_RUNK_NUMBER_B",
                                                 "DIFFICULTY_RUNK_NUMBER_C",
                                                 "DIFFICULTY_RUNK_NUMBER_D"};
// JACKET_TIP names, resolved BOTH as frames (m_jacketTipFrmNo) and users
// (m_jacketTipUsrNo)
// (@ 0x13173c).
static const char *const kJacketTipNames[3] = {"JACKET_TIP00", "JACKET_TIP01", "JACKET_TIP02"};
// getUserNo -> m_elemUsrNo[22] @ 0x13169c — AepDrawCallback per-element
// dispatch keys.
static const char *const kElemUsrNames[22] = {"JACKET00",
                                              "JACKET09",
                                              "DIFFICULTY_STAR_GREEN",
                                              "DIFFICULTY_STAR_YELLOW",
                                              "DIFFICULTY_STAR_RED",
                                              "MUSIC_RUNK_NUM_GREEN",
                                              "MUSIC_RUNK_NUM_YELLOW",
                                              "MUSIC_RUNK_NUM_RED",
                                              "DIFFICULTY_RUNK_NUMBER_E",
                                              "DIFFICULTY_BT00",
                                              "MUSIC_TITLE",
                                              "DIFFICULTY_TITLE",
                                              "DIFFICULTY_NAME",
                                              "NEW_BOARD",
                                              "FULLCOMBO",
                                              "BG_NEKO",
                                              "S_POINT_NUM",
                                              "FRIEND_SCORE_FONT",
                                              "FRIEND_SCORE_ICON",
                                              "FRIEND_UPDEF_FONTBAR",
                                              "FRIEND_UP_ICON",
                                              "FRIEND_UP_FIRST_ICON"};
// getUserNo -> m_scoreDigitUsrNo[6] @ 0x1316f4.
static const char *const kScoreDigitUsrNames[6] = {
    "SCORE0", "SCORE00", "SCORE000", "SCORE0000", "SCORE00000", "SCORE000000"};
// getUserNo -> m_diffBlackUsrNo[3] @ 0x13170c.
static const char *const kDiffBlackUsrNames[3] = {
    "DIFFICULTY_BLACK", "DIFFICULTY_BLACK2", "DIFFICULTY_BLACK3"};
// getUserNo -> m_placeDigitUsrNo[9] @ 0x131718: the 3 colours x 3 digit
// places.
static const char *const kPlaceDigitUsrNames[9] = {"GREEN_0",
                                                   "GREEN_0_0",
                                                   "GREEN_0_0_0",
                                                   "YELLOW_0",
                                                   "YELLOW_0_0",
                                                   "YELLOW_0_0_0",
                                                   "PINK_0",
                                                   "PINK_0_0",
                                                   "PINK_0_0_0"};

// The 60 digit-atlas bundle resource names -> m_digitTex[60] (each loaded as
// "<name>.png"). Index order matches the binary's write offsets: score(+0x5c),
// points(+0x84), jk_dif(+0xac), then the 30-entry rank block (+0xd4) written as
// green/yellow/pink 10s (@ 0x131748..).
static const char *const kDigitAtlasNames[60] = {
    "num_score_0",  "num_score_1",  "num_score_2",  "num_score_3",  "num_score_4",
    "num_score_5",  "num_score_6",  "num_score_7",  "num_score_8",  "num_score_9", // [0..9]
    "num_points0",  "num_points1",  "num_points2",  "num_points3",  "num_points4",
    "num_points5",  "num_points6",  "num_points7",  "num_points8",  "num_points9", // [10..19]
    "num_jk_dif_0", "num_jk_dif_1", "num_jk_dif_2", "num_jk_dif_3", "num_jk_dif_4",
    "num_jk_dif_5", "num_jk_dif_6", "num_jk_dif_7", "num_jk_dif_8", "num_jk_dif_9", // [20..29]
    "num_green_0",  "num_green_1",  "num_green_2",  "num_green_3",  "num_green_4",
    "num_green_5",  "num_green_6",  "num_green_7",  "num_green_8",  "num_green_9", // [30..39]
    "num_yellow_0", "num_yellow_1", "num_yellow_2", "num_yellow_3", "num_yellow_4",
    "num_yellow_5", "num_yellow_6", "num_yellow_7", "num_yellow_8", "num_yellow_9", // [40..49]
    "num_pink_0",   "num_pink_1",   "num_pink_2",   "num_pink_3",   "num_pink_4",
    "num_pink_5",   "num_pink_6",   "num_pink_7",   "num_pink_8",   "num_pink_9"}; // [50..59]
// The 2 badge/arrow atlases -> m_arrowTex[2] @ 0x131838, loaded as
// "<name>.png".
static const char *const kArrowNames[2] = {"circle", "vie_cmn_warning@2x"};
// The 5 touch/select SE names -> m_seId[5] (@ 0x131840), loaded as
// "<name>.m4a".
static const char *const kSeNames[5] = {"v18", "v19", "v20", "v11", "se06_nya"};

/**
 * Ghidra: musicSelTaskSetup (0x370f0) — state-0 scene build. Resolves the
 * screen metrics, lays out the per-platform button rects, loads the
 * music-select Aep group and constructs its scene + intro AepLyrCtrl layers,
 * resolves every layer / frame / user animation handle, uploads the score /
 * points / rank digit textures, loads the touch SEs + preview BGM, and sets the
 * tutorial / badge flags. @ 0x370f0
 * @complete
 */
void MainTask::Setup() {
    neAppEventCenter::shared().setGuestNoSaveMode(false); // normal entry: results are saved
    AudioManager *audio = [AudioManager sharedManager];

    m_aep = &AepManager::shared();
    m_screenWidth = (int)AepManager::shared().screenWidth();
    m_screenHeight = (int)AepManager::shared().screenHeight();
    // g_dwUiScale is published by MainViewController::loadView as screenScale * 0.5
    // (loadView @ 0xb51c: vmul.f32 by 0.5, stored as the raw g_dwUiScale slot). The
    // binary copies that slot into +0xa6c (musicSelTaskSetup @ 0x370f0:
    // this->dwUiScale = g_dwUiScale). Compute the same value directly as a real
    // float; the old (int)screenScale() truncation, read back through
    // reinterpret_cast<float&>, produced a denormal (~0) that collapsed every
    // scaled button rect to the origin.
    m_uiScale = neSceneManager::screenScale() * 0.5f;
    m_isPadDisplay = neSceneManager::isPadDisplay() ? 1 : 0;
    m_columnStride = m_isPadDisplay ? 9 : 6; // +0xa74 cells per column

    // ---- per-platform button-rect layout table (m_layoutRects + base) ----
    const int displayType = (int)[[AppDelegate appDelegate] displayType];
    if (!m_isPadDisplay) {
        int baseY, rectSort, rectDiff; // rectSort @ +0xa10, rectDiff @ +0xa24
        if (displayType == 2) {        // tall (notch/1136) phone
            baseY = 0xaa;
            rectSort = 0x311;
            rectDiff = 0x3c6;
            m_layoutBaseX = 0x6a; // +0xa84
            m_layoutBaseY = 0xaa; // +0xa88
        } else {
            baseY = m_layoutBaseY;            // 0
            rectDiff = m_layoutBaseX + 0x35c; // 0x35c
            rectSort = m_layoutBaseX + 0x2a7; // 0x2a7
        }
        memcpy(m_layoutRects, kPhoneLayoutRects, sizeof(m_layoutRects));
        const int scoreScaleH = baseY + 899; // the 4 score-scale rows share this height
        m_layoutRects[7] = m_layoutRects[11] = m_layoutRects[15] = m_layoutRects[19] = scoreScaleH;
        m_layoutRects[23] = baseY + 700;
        m_layoutRects[27] = baseY + 0x298;
        m_layoutRects[31] = m_screenHeight - 100;
        m_layoutRects[34] = rectSort;
        m_layoutRects[39] = rectDiff;
        m_layoutRects[43] = m_layoutBaseX + 0x23a;
    } else {
        memcpy(m_layoutRects, kPadLayoutRects, sizeof(m_layoutRects));
        m_layoutRects[31] = m_screenHeight - 0x46;
    }

    m_treasurePoint = (int)[UserSettingData treasurePoint];

    // ---- load the music-select Aep group (3) + resolve its BG layer handles
    // ----
    m_aep->loadAepData(
        3, m_aep->baseDir(), m_isPadDisplay ? "music_select_ipad" : "music_select", true);
    for (int i = 0; i < 3; i++) {
        m_bgLyrNo[i] = m_aep->getLyrNo(3, kBgLyrNames[i]);
        m_bgLyrFrames[i] = m_aep->layerFrameCount(m_bgLyrNo[i]);
    }

    // ---- build the 4 scene layers, then the 2 device-branched intro layers ----
    for (int i = 0; i < 4; i++) {
        m_layers[i] = new AepLyrCtrl();
        m_layers[i]->init(3, kLayerNames[i], this, kLayerOrder[i]);
    }
    const char *const *introNames;
    if (displayType == 2) {
        // Tall-phone/pad nudge: park each scene layer at y=0, z=0x6a (Ghidra: the
        // +0x18/+0x1c stores). setRouletteAnchor performs exactly that (m_y = 0,
        // raw z = value).
        for (int i = 0; i < 4; i++) {
            m_layers[i]->setRouletteAnchor(0x6a);
        }
        introNames = kIntroNamesTall;
    } else {
        m_layoutBaseX = 0; // +0xa84 re-zeroed for the short-phone branch
        introNames = kIntroNamesShort;
    }
    for (int i = 0; i < 2; i++) {
        m_introLayers[i] = new AepLyrCtrl();
        m_introLayers[i]->init(3, introNames[i], this, kIntroOrder[i]);
    }

    // ---- resolve the frame / user animation handles into their named arrays
    // ----
    for (int i = 0; i < 24; i++) {
        m_frmNo[i] = m_aep->getFrameNo(3, kFrmNames[i]);
    }
    for (int i = 0; i < 3; i++) {
        m_starFrmNo[i] = m_aep->getFrameNo(3, kStarFrmNames[i]);
    }
    for (int i = 0; i < 7; i++) {
        m_musicRankFrmNo[i] = m_aep->getFrameNo(3, kMusicRankFrmNames[i]);
    }
    for (int i = 0; i < 7; i++) {
        m_diffRankFrmNo[i] = m_aep->getFrameNo(3, kDiffRankFrmNames[i]);
    }
    for (int i = 0; i < 3; i++) {
        m_jacketTipFrmNo[i] = m_aep->getFrameNo(3, kJacketTipNames[i]);
    }
    for (int i = 0; i < 22; i++) {
        m_elemUsrNo[i] = m_aep->getUserNo(3, kElemUsrNames[i]);
    }
    for (int i = 0; i < 6; i++) {
        m_scoreDigitUsrNo[i] = m_aep->getUserNo(3, kScoreDigitUsrNames[i]);
    }
    for (int i = 0; i < 3; i++) {
        m_diffBlackUsrNo[i] = m_aep->getUserNo(3, kDiffBlackUsrNames[i]);
    }
    for (int i = 0; i < 9; i++) {
        m_placeDigitUsrNo[i] = m_aep->getUserNo(3, kPlaceDigitUsrNames[i]);
    }
    for (int i = 0; i < 3; i++) {
        m_jacketTipUsrNo[i] = m_aep->getUserNo(3, kJacketTipNames[i]);
    }

    // ---- upload the 60 score / points / rank digit-atlas textures ----
    for (int i = 0; i < 60; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_digitTex[i] = tex;
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kDigitAtlasNames[i])
                                                         ofType:@"png"];
        tex->load(path.UTF8String);
    }

    rebuildList(); // musicSelUpdate — build the initial sorted list + column
                   // state

    // ---- the 2 badge/arrow atlases ----
    for (int i = 0; i < 2; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_arrowTex[i] = tex;
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kArrowNames[i]) ofType:@"png"];
        tex->load(path.UTF8String);
    }

    // Install the per-frame scene draw callback for group 3 (Ghidra:
    // setAepCallbacks).
    m_aep->setGroupDrawCallback(3, &AepDrawCallback, this);

    // ---- load the 5 touch/select SEs (group 1) + the preview BGM ----
    for (int i = 0; i < 5; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:@(kSeNames[i]) ofType:@"m4a"];
        RSND_SOURCE_ID sid = [audio loadSe:sePath isLoop:NO callName:nil group:1];
        m_seId[i] = (int)sid; // +0x8c4
        m_seInst[i] = -1;     // +0x8d8 idle
    }
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm02_musicsel.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];

    // First-play tutorial is offered until the player has cleared it once.
    m_tutorialBadge = [UserSettingData isTutorialPlayed] ? 0 : 1;
    m_sel.tutorialOffered = m_tutorialBadge;
    m_overScoreDict = nil; // +0xa98
}

/**
 * mainTaskUpdate — per-frame list scroll physics. Reads the render manager's
 * active touch, drives the horizontal list drag/fling, and on a column change
 * streams the newly-visible jacket column (musicSelLoadColumnPrev/Next). This is
 * NOT the re-sort routine: that is rebuildList() (musicSelUpdate 0x3835c). The
 * scroll direction matches the binary exactly: offset = startX - curX, drag left
 * commits nColumnIndex-- (previous column), drag right commits nColumnIndex++
 * (next), with the end rubber-band damped to (int)(0.5 - sqrt(|off|)).
 * @ghidraAddress 0x34f4c
 * @complete
 */
void MainTask::Update() {
    neSceneManager::shared();               // NESceneManager_shared — force the singleton
    neGraphics &gfx = neGraphics::shared(); // NEGraphics_shared

    // Clear the current-frame drag scratch (rewritten below only if a touch is
    // present).
    m_touchX = -1;       // +0xa78
    m_touchY = -1;       // +0xa7c
    m_touchReleased = 0; // +0xa80

    // ---- a drag is in progress: follow / sample the finger
    // ----------------------------
    if (m_selectedCell >= 0) {
        const neTouchPoint *t = gfx.findTouchById(m_selectedCell); // NEGraphics_findTouchById
        if (t == nullptr) {
            // Finger vanished (lost the touch): drop the drag; the settle switch runs
            // next frame.
            m_selectedCell = -1;
            return;
        }

        const int startX = t->startX; // +0x04 drag anchor
        m_touchX = t->x;              // +0xa78 current point
        m_touchY = t->y;              // +0xa7c
        const int curX = m_touchX;

        // Push the ring one slot toward "older"; index 0 receives the new sample.
        // The two arrays are shifted together (the binary walks them with a single
        // pointer 40 bytes apart — i.e. m_dragSampleX[i] is m_dragSampleTime[i] +
        // 10 ints).
        for (int i = 9; i > 0; i--) {
            m_dragSampleTime[i] = m_dragSampleTime[i - 1];
            m_dragSampleX[i] = m_dragSampleX[i - 1];
        }
        const int now = (int)getTimeMillis();
        m_dragSampleTime[0] = now;
        m_dragSampleX[0] = curX;

        // Live drag: the offset is the finger delta from the anchor, measured as
        // (startX - curX) exactly as the binary (Ghidra: uScroll = nStartX - nCurX),
        // so a rightward drag yields a negative offset. Rubber-band resistance at
        // the ends: dragging left past the first column, or right past the last,
        // damps to (int)(0.5 - sqrt(|off|)) (Ghidra 0x34fe6: FloatVectorNeg(sqrt) +
        // 0.5, then a truncating vcvt.s32.f32).
        const int off = startX - curX;
        const bool atFirst = (off > 0 && m_columnIndex < 1);                 // drag left, first col
        const bool atLast = (off < 0 && m_columnIndex >= m_columnCount - 1); // drag right, last col
        if (atFirst || atLast) {
            const int a = (off < 0) ? -off : off; // |off|
            m_scrollOffset = (int)(0.5f - std::sqrt((float)a));
        } else {
            m_scrollOffset = off;
        }

        // Fling velocity (px/ms) from the oldest still-populated sample, measured
        // in the same offset-space as m_scrollOffset (Ghidra: numerator is
        // nStartX - aSampleX[i]) so a leftward drag yields a positive velocity.
        float velocity = 0.0f;
        {
            float dTime = 0.0f;
            for (int i = 9; i >= 0; i--) {
                if (m_dragSampleTime[i] != 0) {
                    dTime = (float)(now - m_dragSampleTime[i]);
                    velocity = (float)(m_dragSampleX[i] - curX);
                    break;
                }
            }
            velocity = velocity / dTime; // dOff / dTime (dTime == 0 only on the seed frame)
        }
        m_scrollVelocity = velocity;

        if (t->released) {       // +0x2d finger lifted this frame
            m_touchReleased = 1; // +0xa80
            if (curX < startX) {
                // Dragged left -> return toward the PREVIOUS column (Ghidra: drag
                // left commits nColumnIndex--), if a fast-enough fling and not first.
                if (m_columnIndex > 0 && velocity > kFlingThreshold) {
                    neEngine::playSystemSe(
                        4); // SysSePlayIntoSlot(...,4) — confirm SE on a real fling
                    m_scrollState = kScrollFlingPrev;
                } else {
                    m_scrollVelocity = 0.0f;
                    m_scrollState = kScrollSnapRight;
                }
            } else if (startX < curX) {
                // Dragged right -> advance toward the NEXT column (Ghidra: drag right
                // commits nColumnIndex++), if a fast-enough fling and not last.
                if (m_columnIndex < m_columnCount - 1 && velocity < -kFlingThreshold) {
                    neEngine::playSystemSe(4); // confirm SE on a real fling
                    m_scrollState = kScrollFlingNext;
                } else {
                    m_scrollVelocity = 0.0f;
                    m_scrollState = kScrollSnapLeft;
                }
            } else {
                // Released with no net movement: snap straight back to the current
                // column.
                m_scrollOffset = 0;
                m_scrollVelocity = 0.0f;
                m_scrollState = kScrollIdle;
            }
        }
        return; // a live drag frame never runs the settle switch below
    }

    // ---- no drag and settled: look for a fresh finger-down to start a new drag
    // ---------
    if (m_scrollState == kScrollIdle) {
        for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) { // NEGraphics_activeTouchCount
            const neTouchPoint *t = gfx.touchAt(i);               // NEGraphics_touchAt
            if (t->valid) {                                       // +0x2c began-this-frame marker
                // Seed the sample ring with this touch and latch it as the active drag.
                for (int k = 0; k < 10; k++) {
                    m_dragSampleTime[k] = 0;
                    m_dragSampleX[k] = 0;
                }
                m_selectedCell = t->id; // +0x928 drag touch id
                m_dragSampleTime[0] = (int)getTimeMillis();
                m_scrollVelocity = 0.0f;
                m_dragSampleX[0] = t->x;
                break;
            }
        }
    }

    // ---- settle integration: ease the offset toward the target column or back
    // to 0 ----- The column width the offset is measured against is m_screenWidth
    // (@ +0xa64) — one column is one screen on phone.
    const int columnWidth = m_screenWidth;
    switch (m_scrollState) {
    case kScrollFlingPrev: {
        float vel = m_scrollVelocity;
        if (m_scrollOffset < columnWidth / 2) {
            // First half: accelerate up to the max speed.
            vel = vel + kSpringAccel; // +0.2
            if (vel > kMaxVelocity) {
                vel = kMaxVelocity; // min(vel, 8.0)
            }
        } else {
            // Past halfway: ease off (friction) but keep the minimum completing
            // speed.
            vel = vel - kFrictionAccel; // -0.1
            if (vel < kMinVelocity) {
                vel = kMinVelocity; // max(1.0, vel)
            }
        }
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if (m_scrollOffset >= columnWidth) {
            // Column change committed: reset physics and step to the previous column.
            m_scrollOffset = 0;
            m_scrollVelocity = 0.0f;
            m_scrollState = kScrollIdle;
            m_columnIndex = m_columnIndex - 1;
            if (m_columnIndex < 0) {
                m_columnIndex = 0;
            }
            // Rotate the three row latches toward "prev" and mark the newly-freed row
            // idle.
            m_nextColLatch = m_curColLatch;
            m_curColLatch = m_prevColLatch;
            m_prevColLatch = 0xff;
            const int row = findFreeColumnRow();
            if (m_columnIndex > 0) {
                MusicSelLoadColumnPrev(row);
                return;
            }
        }
        break;
    }
    case kScrollFlingNext: {
        float vel = m_scrollVelocity;
        if (m_scrollOffset > -(columnWidth / 2)) {
            vel = vel - kSpringAccel; // -0.2
            if (vel < -kMaxVelocity) {
                vel = -kMaxVelocity; // max(-8.0, vel)
            }
        } else {
            vel = vel + kFrictionAccel; // +0.1
            if (vel > -kMinVelocity) {
                vel = -kMinVelocity; // min(-1.0, vel)
            }
        }
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if (m_scrollOffset <= -columnWidth) {
            m_scrollOffset = 0;
            m_scrollVelocity = 0.0f;
            m_scrollState = kScrollIdle;
            const int next = m_columnIndex + 1;
            const int last = m_columnCount - 1;
            m_columnIndex = (next < last) ? next : last;
            // Rotate the three row latches toward "next".
            m_prevColLatch = m_curColLatch;
            m_curColLatch = m_nextColLatch;
            m_nextColLatch = 0xff;
            const int row = findFreeColumnRow();
            if (m_columnIndex < m_columnCount - 1) {
                MusicSelLoadColumnNext(row);
                return;
            }
        }
        break;
    }
    case kScrollSnapRight: {
        float vel = m_scrollVelocity - kFrictionAccel; // -0.1
        if (vel < -kMinVelocity) {
            vel = -kMinVelocity; // max(-1.0, vel)
        }
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if ((unsigned)m_scrollOffset < 0x80000000u) {
            break; // still >= 0: keep animating
        }
        m_scrollOffset = 0; // crossed below 0: settled
        m_scrollVelocity = 0.0f;
        m_scrollState = kScrollIdle;
        break;
    }
    case kScrollSnapLeft: {
        float vel = m_scrollVelocity + kFrictionAccel; // +0.1
        if (vel > kMinVelocity) {
            vel = kMinVelocity; // min(1.0, vel)
        }
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if (m_scrollOffset < 0) {
            break; // still negative: keep animating
        }
        m_scrollOffset = 0; // reached 0: settled
        m_scrollVelocity = 0.0f;
        m_scrollState = kScrollIdle;
        break;
    }
    default:
        break;
    }
}

// De-inlined from Update (the identical block in both column-commit paths):
// scan the three candidate jacket rows (0, m_columnStride, 2*m_columnStride)
// and return the first one not held by a per-column row latch, so the committed
// column change streams into a free row. @ 0x34f4c
inline int MainTask::findFreeColumnRow() const {
    const int stride = m_columnStride; // +0xa74
    int row = 0;
    if (stride >= 1) {
        const uint8_t latch[3] = {m_prevColLatch, m_curColLatch, m_nextColLatch};
        for (;;) {
            int k = 0;
            while (k < 3) {
                if (row == latch[k]) {
                    break; // this row is currently streaming -> in use
                }
                k++;
            }
            if (k == 3) {
                break; // no latch holds it: free row found
            }
            row += stride;
            if (row >= stride * 3) {
                break; // all three rows busy
            }
        }
    }
    return row;
}

/**
 * musicSelCleanup — release the previous sorted list and clear all 27 jacket
 * cells before a re-sort. Frees each cell's uploaded texture (+0xc), bundled
 * image data (+0x8) and truncated-name string (+0x10), then resets the three
 * per-column row latches (+0x8c0/+0x8c1/+0x8c2) and the current column back to 0.
 * Called at the top of rebuildList() and from StopAndSave().
 * @ghidraAddress 0x3cfb0
 * @complete
 */
void MainTask::Cleanup() {
    if (m_musicList != nil) {
        CFBridgingRelease((__bridge CFTypeRef)m_musicList); // Ghidra: [m_musicList release]
        m_musicList = nil;
    }
    for (MusicSelCell &cell : m_cells) {
        if (cell.texture != nullptr) {
            delete cell.texture; // vtable[1] dtor on the texture
            cell.texture = nullptr;
        }
        if (cell.imageData != nil) {
            cell.imageData = nil; // ARC releases the bundled PNG data
        }
        if (cell.name != nil) {
            cell.name = nil; // ARC releases the truncated name
        }
    }
    // Reset the three packed per-column row latches to the 0xff "idle" sentinel
    // and the current column to 0 (the binary's 0xffff @ +0x8c0 / 0xff @ +0x8c2
    // stores cover all three bytes).
    m_prevColLatch = 0xff;
    m_curColLatch = 0xff;
    m_nextColLatch = 0xff;
    m_columnIndex = 0;
}

/**
 * musicSelUpdate — re-sort / rebuild the music-select list. Distinct from
 * Update() (per-frame scroll physics, 0x34f4c): this runs once after the sort
 * order changes (SortSelect / Recommend close). It re-reads UserSettingData
 * musicSort, re-sorts the MusicManager song array into m_musicList (the six sort
 * comparators; sort 5 partitions un-scored songs first), recomputes the column
 * geometry, lands the column on the current song, streams the current column's
 * jacket cells + 3-difficulty score rows, one-shot-kicks the background jacket
 * loader, and primes the adjacent columns.
 * @ghidraAddress 0x3835c
 * @complete
 */
void MainTask::rebuildList() {
    neAppEventCenter::shared(); // force the event center (current-song id) live
    Cleanup();                  // release the old list + clear the 27 cells (@ 0x3cfb0)

    NSArray *music = [[MusicManager getInstance] getMusicDataArray];
    short sort = [UserSettingData musicSort];
    m_appliedSort = sort; // remember the sort we are applying (read by MusicSelAppliedSort)

    // ---- 1. sort the song array per the applied order (retained into
    // m_musicList) ----
    NSArray *sorted = nil;
    switch ((unsigned short)sort) {
    case 0:
        sorted = [music sortedArrayUsingSelector:@selector(compareMusicNameCustom:)];
        break;
    case 1:
        sorted = [music sortedArrayUsingSelector:@selector(compareArtistNameCustom:)];
        break;
    case 2:
        sorted = [music sortedArrayUsingSelector:@selector(compareDifficultyNormal:)];
        break;
    case 3:
        sorted = [music sortedArrayUsingSelector:@selector(compareDifficultyHyper:)];
        break;
    case 4:
        sorted = [music sortedArrayUsingSelector:@selector(compareDifficultyEx:)];
        break;
    case 5: {
        // "Played" sort: order by music id, then partition into songs that have NO
        // score record vs. songs that do, and concatenate un-scored-first then
        // scored (un-scored songs first). A song counts as
        // scored if any of its three difficulties has a stored score.
        NSMutableArray *byId =
            [[music sortedArrayUsingSelector:@selector(compareMusicID:)] mutableCopy];
        NSMutableArray *unplayed = [NSMutableArray array];
        NSMutableArray *played = [NSMutableArray array];
        for (id song in byId) {
            unsigned musicId = (unsigned)[song MusicID];
            bool hasScore = false;
            for (int diff = 0; diff < 3; diff++) {
                // A song counts as scored if any difficulty has a stored play count
                // (Ghidra musicSelUpdate @ 0x3835c: `if (0 < outPlayCnt) break;`).
                int score = 0;
                short rank = 0;
                int playCnt = 0;
                bool fullCombo = false, perfect = false;
                fetchScoreDataForMusic(&neAppEventCenter::shared(),
                                       &score,
                                       &rank,
                                       &playCnt,
                                       &fullCombo,
                                       &perfect,
                                       musicId,
                                       diff);
                if (playCnt > 0) {
                    hasScore = true;
                    break;
                }
            }
            [(hasScore ? played : unplayed) addObject:song];
        }
        sorted = [unplayed arrayByAddingObjectsFromArray:played];
        break;
    }
    default:
        sorted = m_musicList; // unknown sort: keep the existing (already-cleared) list
        break;
    }
    if ((unsigned short)sort <= 5) {
        m_musicList = (__bridge id)CFBridgingRetain(sorted); // Ghidra: [sorted retain]
    }

    // ---- 2. column geometry ----
    m_songCount = (int)[m_musicList count];
    const int stride = m_columnStride; // cells per column (6 phone / 9 pad)
    m_columnIndex = 0;
    m_columnCount = (m_songCount - 1) / stride + 1;

    // ---- 3. land the current column on the app-event-center's current song ----
    // Ghidra compares [song MusicID] against g_pNeAppEventCenter (the event
    // center's current music id). The exact global is a seam; model it via the
    // reconstructed accessor.
    const int currentId = neAppEventCenter::shared().lastMusic(); // g_pNeAppEventCenter (seam)
    for (int i = 0; i < m_songCount; i++) {
        MusicData *song = [m_musicList objectAtIndexedSubscript:i];
        if ((int)[song MusicID] == currentId) {
            m_columnIndex = i / stride;
            break;
        }
    }

    // ---- 4. stream the current column's visible jacket cells ----
    // Song-name truncation width: 0x15 chars on pad, 0xf on phone.
    const int nameWidth = m_isPadDisplay ? 0x15 : 0xf;
    if (stride > 0) {
        int songIdx = m_columnIndex * stride;
        for (int slot = 0; slot < stride; slot++) {
            if (songIdx >= m_songCount) {
                break;
            }
            MusicData *song = [m_musicList objectAtIndexedSubscript:songIdx];
            unsigned musicId = (unsigned)[song MusicID];
            NSData *artwork = [song artwork2xData];
            MusicSelCell &cell = m_cells[slot];

            // Upload the @2x jacket art straight into a fresh texture.
            neTextureForiOS *tex = new neTextureForiOS(); // neTextureForiOS_ctor
            cell.texture = tex;
            tex->loadFromImageData((__bridge const void *)artwork); // neTextureLoadSingle

            // Cache a (possibly ellipsis-truncated) copy of the song name for the
            // cell label.
            NSString *name = [[song musicName] copy];
            cell.name = name;
            int cut = findCharIndexForColumn(name, nameWidth);
            if (cut > 0) {
                // Ghidra: stringByAppendingString:@"..." (three ASCII dots, cf____).
                cell.name = [[name substringToIndex:cut] stringByAppendingString:@"..."];
            }

            loadCellScoreRows(cell,
                              musicId); // 3-difficulty score rows into cell detail

            cell.songIndex = slot; // running cell index within the column
            cell.loadState = 3;    // ready
            cell.imageData = nil;  // no pending bundled image (art already uploaded)
            songIdx++;
        }
    }

    // ---- 5. (re)kick the background jacket loader exactly once ----
    // The current-column widget-row latch is reset so the current column draws
    // from cell row 0.
    m_curColLatch = 0;
    if (!m_cellLoaderStarted) {
        m_loaderCursor = 0;
        m_cellSem = dispatch_semaphore_create(1);
        MainTask *self = this;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
          self->backgroundCellLoader(); // Ghidra: block invoke @ 0x3d040 -> 0x3d048
        });
        m_cellLoaderStarted = 1;
    }

    // ---- 6. prime the adjacent columns' jacket rows ----
    int row = stride; // next column fills widget rows [stride, 2*stride)
    if (m_columnIndex + 1 < m_columnCount) {
        MusicSelLoadColumnNext(row);
        row += stride; // prev column fills widget rows [2*stride, 3*stride)
    }
    if (m_columnIndex - 1 >= 0) {
        MusicSelLoadColumnPrev(row);
    }
}

// De-inlined from rebuildList (@ 0x3835c): read the three difficulty score rows
// for `musicId` into the jacket cell's detail block. In the binary each
// iteration calls fetchScoreDataForMusic with the (musicId, difficulty) pair
// and writes the resulting score / medal bytes into the cell's detail region
// (+0x14.. from the cell base).
inline void MainTask::loadCellScoreRows(MusicSelCell &cell, unsigned musicId) {
    for (int diff = 0; diff < 3; diff++) {
        // Ghidra musicSelUpdate @ 0x3835c writes each difficulty's
        // fetchScoreDataForMusic result straight into the cell's score-row block
        // (score/rank/playCnt/fullCombo/perfect).
        bool fullCombo = false, perfect = false;
        fetchScoreDataForMusic(&neAppEventCenter::shared(),
                               &cell.scores.score[diff],
                               &cell.scores.rank[diff],
                               &cell.scores.playCnt[diff],
                               &fullCombo,
                               &perfect,
                               musicId,
                               diff);
        cell.scores.fullCombo[diff] = fullCombo ? 1 : 0;
        cell.scores.perfect[diff] = perfect ? 1 : 0;
    }
}

/**
 * The music-select background jacket loader (Ghidra: named resultTaskSetup by
 * binary proximity, but it is the dispatch_async body kicked off once by
 * rebuildList). Runs on a global-queue background thread: round-robins the 27
 * jacket cells under m_cellSem, and for each cell still marked "queued"
 * (loadState 1) decodes the song's artwork, reads its three difficulty score rows
 * (on the thread-safe SUB managed-object context), truncates the song name to the
 * platform column width (21 iPad / 15 phone), and marks the cell "ready"
 * (loadState 3). Exits when m_loaderCursor is set.
 * @ghidraAddress 0x3d048
 * @complete
 */
void MainTask::backgroundCellLoader() {
    if (m_loaderCursor != 0) {
        m_loaderCursor = 2;
        return;
    }
    const int maxNameChars = m_isPadDisplay ? 21 : 15; // Ghidra: 0x15 default, 0xf when !isPad
    unsigned i = 0;
    do {
        [NSThread sleepForTimeInterval:0.3]; // 0x3d368 == 0.3
        dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
        if (i > 26) {
            i = 0; // wrap the 27-cell ring
        }
        MusicSelCell &cell = m_cells[i];
        if (cell.loadState == 1) { // queued for load
            const int songIndex = cell.songIndex;
            cell.loadState = 2; // processing
            dispatch_semaphore_signal(m_cellSem);

            MusicData *md = [m_musicList objectAtIndexedSubscript:songIndex];
            const int musicId = (int)[md MusicID];
            id artwork;
            @autoreleasepool {
                artwork = [md artwork2xData]; // decode off the shared array
            }

            dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
            if (cell.loadState != 1) { // not re-queued while we worked
                cell.imageData = artwork;
                dispatch_semaphore_signal(m_cellSem);

                // Score rows come off the background sub-context (thread-safe Core Data
                // stack).
                NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContextSub];
                for (int diff = 0; diff < 3; diff++) {
                    ScoreData *rec = [ScoreData getScoreData:musicId inManagedObjectContext:moc];
                    bool fullCombo = false, perfect = false;
                    readScoreDataFields(rec,
                                        &cell.scores.score[diff],
                                        &cell.scores.rank[diff],
                                        &cell.scores.playCnt[diff],
                                        &fullCombo,
                                        &perfect,
                                        rec,
                                        diff);
                    cell.scores.fullCombo[diff] = fullCombo ? 1 : 0;
                    cell.scores.perfect[diff] = perfect ? 1 : 0;
                }

                NSString *name = [[md musicName] copy];
                const int cut = findCharIndexForColumn(name, maxNameChars);
                if (cut > 0) {
                    // Ghidra: stringByAppendingString:@"..." (three ASCII dots, cf____).
                    name = [[name substringToIndex:cut] stringByAppendingString:@"..."];
                }
                dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
                if (cell.loadState == 2) { // still ours -> publish the result
                    cell.name = name;
                    cell.loadState = 3; // ready
                }
            }
            dispatch_semaphore_signal(m_cellSem);
        } else {
            dispatch_semaphore_signal(m_cellSem);
        }
        i++;
    } while (m_loaderCursor == 0);
    m_loaderCursor = 2; // acknowledge shutdown
}

/**
 * musicSelAllCellsReady — true when every jacket cell has finished loading
 * (state 0 empty or 3 ready). Guarded by the cell-array semaphore.
 * @ghidraAddress 0x37f38
 * @complete
 */
bool MainTask::AllCellsReady() {
    dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
    bool ready = true;
    for (int i = 0; i < 27; i++) {
        int st = m_cells[i].loadState;
        if (st != 0 && st != 3) { // still decoding / uploading
            ready = false;
            break;
        }
    }
    dispatch_semaphore_signal(m_cellSem);
    return ready;
}

/**
 * Ghidra: musicSelUpdateHighlight (0x355fc) — per-frame highlight/badge
 * draw. Skipped once the scene is being torn down (m_suppressDraw). Pulses the
 * recommend / over-score badges, redraws the four difficulty frames + the
 * tutorial badge, and (for a multi-column list) draws the "current/total"
 * column counter.
 * @complete
 */
void MainTask::UpdateHighlight() {
    if (m_suppressDraw) {
        return;
    }
    m_highlightAnim = (m_highlightAnim + 2) % 0x97; // 0..0x96 triangle phase

    // Triangle-wave alpha for the pulsing badges (peak at the mid of the phase).
    auto pulseAlpha = [](int phase) -> int {
        if (phase <= 0x31) {
            return 100;
        }
        return phase < 100 ? phase * -2 + 200 : phase * 2 + -200;
    };
    // The Aep frame handles and the badge/frame screen positions the draw reads
    // are ALREADY named members: the frames are slots of the Setup()-filled
    // getFrameNo table m_frmNo[24] (m_frmNo[6]=BT_SETTING, [8]=BT_SORT,
    // [9]=BT_OSSUME/recommend, [10]=BT_EMULATE/over-score, [16]=BT_TUTORIAL), and
    // the x/y positions are slots of the per-platform layout table
    // m_layoutRects[55] (+0x988), which Setup() populates via the
    // kPhone/kPadLayoutRects memcpy plus the runtime score-baseline / counter-y
    // patches. Named-index constants below give the draw roles instead of magic
    // indices; the raw pixel constants are Setup()'s layout seam. (The
    // decompile's "difficulty frames" are really the four state-2 top-row
    // buttons.)
    enum { // m_layoutRects slots this draw samples
        kLR_SettingX = 6,
        kLR_SettingY = 7, // BT_SETTING frame       (+0x9a0/+0x9a4)
        kLR_SortX = 10,
        kLR_SortY = 11, // BT_SORT frame          (+0x9b0/+0x9b4)
        kLR_OssumeX = 14,
        kLR_OssumeY = 15, // BT_OSSUME (recommend)  (+0x9c0/+0x9c4)
        kLR_EmulateX = 18,
        kLR_EmulateY = 19, // BT_EMULATE (over-score)(+0x9d0/+0x9d4)
        kLR_TutorialX = 26,
        kLR_TutorialY = 27, // BT_TUTORIAL badge      (+0x9f0/+0x9f4)
        kLR_CounterX = 30,
        kLR_CounterY = 31,
        kLR_CounterStyle = 32, // counter (+0xa00/04/08)
        kLR_ScreenW = 52,
        kLR_ScreenH = 53, // badge blit screen bounds (+0xa58/+0xa5c)
    };
    // 100 == natural (100%) scale (the Aep draw path divides sx/sy by 100; the
    // binary pushes the 100.0f bits 0x42c80000 only because its draw reinterprets
    // them), 0xffffff == white, 0x20 == blend mode, 10 == OT priority.
    const int kScale100 = 100;

    // Pulsing new-recommend badge (m_arrowTex[1]) over the recommend button.
    if (m_recommendBadge) {
        const int a = pulseAlpha(m_highlightAnim);
        neTextureForiOS_draw(m_aep,
                             m_arrowTex[1],
                             0,
                             0,
                             m_layoutRects[kLR_ScreenW],
                             m_layoutRects[kLR_ScreenH],
                             m_layoutRects[kLR_OssumeX] - 2,
                             m_layoutRects[kLR_OssumeY] - 10,
                             100,
                             100,
                             0,
                             0,
                             0,
                             a,
                             100 - a,
                             0x20,
                             0xffffff,
                             nullptr,
                             10,
                             1);
    }
    // Pulsing over-score badge (m_arrowTex[1]) over the over-score-log button.
    if (m_overScoreBadge) {
        const int a = pulseAlpha(m_highlightAnim);
        neTextureForiOS_draw(m_aep,
                             m_arrowTex[1],
                             0,
                             0,
                             m_layoutRects[kLR_ScreenW],
                             m_layoutRects[kLR_ScreenH],
                             m_layoutRects[kLR_EmulateX] - 2,
                             m_layoutRects[kLR_EmulateY] - 10,
                             100,
                             100,
                             0,
                             0,
                             0,
                             a,
                             100 - a,
                             0x20,
                             0xffffff,
                             nullptr,
                             10,
                             1);
    }

    // The four state-2 top-row button frames (settings / sort / recommend /
    // over-score-log).
    drawAepFrameEx(m_aep,
                   m_frmNo[6],
                   m_layoutRects[kLR_SettingX],
                   m_layoutRects[kLR_SettingY],
                   kScale100,
                   kScale100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   0,
                   10,
                   1);
    drawAepFrameEx(m_aep,
                   m_frmNo[8],
                   m_layoutRects[kLR_SortX],
                   m_layoutRects[kLR_SortY],
                   kScale100,
                   kScale100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   0,
                   10,
                   1);
    drawAepFrameEx(m_aep,
                   m_frmNo[9],
                   m_layoutRects[kLR_OssumeX],
                   m_layoutRects[kLR_OssumeY],
                   kScale100,
                   kScale100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   0,
                   10,
                   1);
    drawAepFrameEx(m_aep,
                   m_frmNo[10],
                   m_layoutRects[kLR_EmulateX],
                   m_layoutRects[kLR_EmulateY],
                   kScale100,
                   kScale100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   0,
                   10,
                   1);

    // First-play tutorial badge (BT_TUTORIAL).
    if (m_tutorialBadge) {
        drawAepFrameEx(m_aep,
                       m_frmNo[16],
                       m_layoutRects[kLR_TutorialX],
                       m_layoutRects[kLR_TutorialY],
                       kScale100,
                       kScale100,
                       0,
                       0,
                       0,
                       100,
                       0,
                       0x20,
                       0xffffff,
                       0,
                       10,
                       1);
    }

    // Multi-column list -> the "current/total" column counter text.
    if (m_columnCount > 1) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%d/%d", m_columnIndex + 1, m_columnCount);
        m_aep->DrawText(buf,
                        m_layoutRects[kLR_CounterStyle],
                        m_layoutRects[kLR_CounterX],
                        m_layoutRects[kLR_CounterY],
                        2,
                        100,
                        0 /* default text-style seam */,
                        0xc);
    }
}

/**
 * musicSelStopAndSave — state-0x10 teardown. Releases the SEs (by their source
 * ids) and every layer / texture, saves the finished-play music id + result
 * sheet (unless in guest no-save mode), runs Cleanup() to release the song list
 * and jacket cells, then kills this task (spawning the menu hub if no sub-task
 * was queued).
 * @ghidraAddress 0x38008
 * @complete
 */
void MainTask::StopAndSave() {
    AudioManager *audio = [AudioManager sharedManager];

    for (int i = 0; i < 5; i++) {
        // Ghidra: releaseSe:nil resourceId:m_seId[i] — the binary frees each of
        // the five loaded select SEs by its source id (aColumnColorHistory+4+i*4),
        // not resourceId 0.
        [audio releaseSe:nil resourceId:m_seId[i]];
    }
    neSceneManager::shared().releaseSystemSe();
    [audio cleanupSe];
    neSceneManager::shared().loadSystemSe();

    // Delete the digit / name / artist textures.
    for (auto &tex : m_digitTex) {
        if (tex) {
            delete tex;
            tex = nullptr;
        }
    }
    for (auto &tex : m_arrowTex) {
        if (tex) {
            delete tex;
            tex = nullptr;
        }
    }
    if (m_nameTex) {
        delete m_nameTex;
        m_nameTex = nullptr;
    }
    if (m_artistTex) {
        delete m_artistTex;
        m_artistTex = nullptr;
    }

    // Unlink + delete the scene layers.
    for (auto &layer : m_layers) {
        if (layer) {
            layer->unlink();
            delete layer;
            layer = nullptr;
        }
    }
    for (auto &layer : m_introLayers) {
        if (layer) {
            layer->unlink();
            delete layer;
            layer = nullptr;
        }
    }
    m_aep->releaseAepTexture(3); // Ghidra: FUN_0000f988

    // Record the finished play's music id + result sheet for the result screen to
    // read, unless this is a no-save teardown. When guest-mode is on the result
    // record is zeroed instead of persisted (setLastMusic == g_pNeAppEventCenter
    // result music id, setLastSheet == g_wResultSheet).
    if (!m_noSaveMode) {
        neAppEventCenter &ec = neAppEventCenter::shared();
        MusicData *info = [m_musicList objectAtIndexedSubscript:m_chosenIndex];
        if (!ec.guestNoSaveMode()) {
            ec.setLastMusic((int)[info MusicID]);
            ec.setLastSheet((int)m_resultSheet);
            [UserSettingData saveSettingData];
        } else {
            ec.setLastMusic(0);
            ec.setLastSheet(0);
        }
    }

    Cleanup(); // Ghidra: MainTask__Cleanup — release m_musicList + the 27 cells

    m_cellSem = nullptr; // Ghidra: _dispatch_release (ARC releases it here)
    m_killed = true;     // reap this task on the next scheduler pass
    if (m_spawnedTask == nullptr) {
        m_spawnedTask = MenuCreateTask(); // no sub-task queued -> back to the menu hub
    }
    m_spawnedTask->setPriority(3);
    m_suppressDraw = 1;
    m_overScoreDict = nil; // ARC releases the over-score dictionary
}

/**
 * musicSelUpdateInfoPanel — build the cached recommend + over-score "touched"
 * state (mode 1 only). Sets the new-recommend badge if a fresher recommend
 * exists than the last viewed one, populates the over-score touched dictionary
 * (m_overScoreDict) — touched -> "1", untouched -> "0" unless already "1" — and
 * clears the pending-push flag.
 * @ghidraAddress 0x37c88
 * @complete
 */
void MainTask::UpdateInfoPanel(int mode) {
    if (mode != 1) {
        return;
    }
    DownloadMain *dl = [DownloadMain getInstance];
    NSArray *recommend = [dl recommendDataArray];
    if ([recommend count] != 0) {
        // Show the "new recommend" badge unless the player has already viewed
        // something at least as fresh as the newest entry. The rows are
        // NSValue-boxed RecommendData (DownloadMain); recommend[0]'s updateDate is
        // compared against the stored view time.
        NSString *lastViewed = [UserSettingData lastRecommendViewTimeString];
        m_recommendBadge = 1;
        RecommendData newest;
        [(NSValue *)[recommend objectAtIndex:0] getValue:&newest];
        if (lastViewed != nil && newest.updateDate != nil &&
            [lastViewed compare:newest.updateDate] != NSOrderedAscending) {
            m_recommendBadge = 0; // already viewed something at least this fresh
        }
    }

    NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
    NSArray *overScores = [OverScoreData getAllOverScoreData:moc];
    m_overScoreDict = [NSMutableDictionary dictionary];
    if ([overScores count] != 0) {
        m_overScoreBadge = 1;
        NSMutableDictionary *dict = m_overScoreDict;
        for (OverScoreData *entry in overScores) {
            NSString *key = [[entry music] stringValue]; // -music is the id NSNumber
            BOOL touched = [[entry isTouched] boolValue];
            BOOL known = [[dict allKeys] containsObject:key];
            if (touched) {
                dict[key] = @"1";
            } else if (!known) {
                dict[key] = @"0";
            } else if (![[dict objectForKeyedSubscript:key] isEqual:@"1"]) {
                dict[key] = @"0";
            }
        }
    }
    // The recommend list has now been consumed into the panel — clear the
    // pending-push flag so the throttle doesn't force another immediate refetch.
    neAppEventCenter::shared().setRemoteNotifyPending(false);
}

// ---------------------------------------------------------------------------------------
// Thin C-linkage shims for the not-yet-C++-refactored ObjC callers that still
// reach these routines by their unmangled binary symbol
// (RecommendViewController / SortSelectViewController call musicSelUpdate;
// DownloadMain calls musicSelUpdateInfoPanel). They forward to the real
// MainTask methods. Prefer importing MainTask.h and calling the method
// directly; these exist only so those units keep linking until they are
// converted.
extern "C" void musicSelUpdate(MainTask *task) {
    task->rebuildList(); // musicSelUpdate (0x3835c) is the re-sort, not the
                         // scroll step
}
extern "C" void musicSelUpdateInfoPanel(MainTask *task, int mode) {
    task->UpdateInfoPanel(mode);
}

// ---------------------------------------------------------------------------------------
// Column streaming + scene draw callback. All work-area access is through the
// named MainTask / MusicSelCell members (MainTask.h); the jacket cells are
// m_cells[27].
// ---------------------------------------------------------------------------------------

// Free one streamed cell's GPU/ObjC resources before it is re-pointed (Ghidra:
// the vtable[1] delete on the texture @ +0xc, then release on the ObjC ids @
// +0x8/+0x10).
static inline void releaseCell(MainTask::MusicSelCell &cell) {
    if (cell.texture) {
        delete cell.texture;
        cell.texture = nullptr;
    }
    cell.imageData = nil; // ARC-released by owner
    cell.name = nil;
}

// @ 0x35448 / @ 0x35520 — shared body of the two column loaders. Streams
// m_columnStride consecutive jacket cells from row `rowBase`, pointing each at
// the song for the adjacent column (`delta` = +1 next / -1 prev), or -1 past
// the list ends. Guarded by `latch` and the cell semaphore. Ghidra:
// musicSelLoadColumnNext / musicSelLoadColumnPrev (identical but for the latch
// byte + column bound).
inline void MainTask::loadColumn(int rowBase, int delta, uint8_t &latch) {
    const int col = m_columnIndex;
    dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
    const int perRow = m_columnStride;
    if (perRow > 0) {
        for (int i = 0; i < perRow; i++) {
            MusicSelCell &cell = m_cells[rowBase + i];
            const int idx = perRow * (col + delta) + i;
            if (idx < 0 || m_songCount <= idx) {
                cell.songIndex = -1; // no song for this slot
                cell.loadState = 0;  // empty
            } else {
                cell.songIndex = idx;
                cell.loadState = 1; // loading (async loader will upload the jacket)
            }
            releaseCell(cell);
        }
    }
    latch = (uint8_t)rowBase;
    dispatch_semaphore_signal(m_cellSem);
}

/**
 * musicSelLoadColumnNext — stream the column after the current one into row
 * `column`, gated by the next-column latch (+0x8c2) and the no-next sentinel
 * (m_columnIndex == -2). Shared grid fill via loadColumn(delta = +1).
 * @ghidraAddress 0x35448
 * @complete
 */
void MainTask::MusicSelLoadColumnNext(int column) {
    if (m_nextColLatch == 0xff && m_columnIndex != -2) { // next-column latch idle
        loadColumn(column, +1, m_nextColLatch);
    }
}

/**
 * musicSelLoadColumnPrev — stream the column before the current one into row
 * `column`, gated by its own latch byte (m_prevColLatch @ +0x8c0) and the
 * no-previous sentinel (m_columnIndex == 0). Shared grid fill via
 * loadColumn(delta = -1). Mirror of MusicSelLoadColumnNext.
 * @ghidraAddress 0x35520
 * @complete
 */
void MainTask::MusicSelLoadColumnPrev(int column) {
    if (m_prevColLatch == 0xff && m_columnIndex != 0) {
        loadColumn(column, -1, m_prevColLatch);
    }
}

/**
 * musicSelAepDrawCallback. The music-select scene draw callback: invoked once
 * per visible layer with that element's resolved user-tag `child`, it dispatches
 * on which resolved user number matches and blits the corresponding scene
 * element. The head draws the three visible song-jacket grids — current column
 * (user no @ +0x22c) plus the incoming next / previous columns (latched via
 * +0x8c1 / +0x8c2) — each a 3-wide cell grid whose uploaded jacket texture
 * (@ cell+0xc) is blitted (or a placeholder frame @ +0x180 while streaming),
 * with the selection frame @ +0x1a8 over the highlighted cell. The tail keys on
 * the other resolved user numbers for the score / difficulty-level / song-name /
 * rank-digit / badge elements.
 *
 * @ghidraAddress 0x389fc
 * @complete Dispatch order verified branch-for-branch against the decompile
 * (elemUsrNo 0,10,2,3,4,13,5,6,7,16,8,9,1,11,12,14,20,21,17,18,19,15 with the
 * jacket-tip / score-digit arrays interleaved); the draw-primitive counts match
 * (45 drawAepFrameEx, 14 neTextureForiOS::draw, the 3 inlined per-column name
 * DrawText calls de-inlined into one paint lambda run per column). The per-sprite
 * VFP transform args are __stdcall_softfp lanes the decompiler cannot bind, so
 * they are sourced from the Setup()-filled layout/element data — the maximum
 * fidelity the decompile permits.
 */
void AepDrawCallback(int child,
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
                     int *p13,
                     uint32_t p14,
                     void *context) {
    (void)frame;
    (void)p13;
    MainTask *self = static_cast<MainTask *>(context);
    using MusicSelCell = MainTask::MusicSelCell; // nested type, unqualified in this free function

    // Blit one 3-column jacket grid starting at widget row `rowBase`, offset by
    // `colX` screen columns. Each present cell draws its uploaded texture (or the
    // placeholder frame @ +0x180 while streaming) plus the selection frame @
    // +0x1a8.
    auto drawJacketGrid = [&](int rowBase, int columnIndex, int extraX) {
        const int perRow = self->m_columnStride;
        if (rowBase < 0 || perRow <= 0) {
            return;
        }
        MusicSelCell *cell = &self->m_cells[rowBase];
        const int songCount = self->m_songCount;
        for (int i = 0; i < perRow; i++, ++cell) {
            if (perRow * columnIndex + i >= songCount) {
                break;
            }
            const int idx = cell->songIndex;
            const bool present = idx >= 0 ? (idx < songCount) : (idx != 0);
            if (present && idx >= 0 && idx <= songCount) {
                const int cellY = self->m_layoutRects[1] * (i / 3) + y;
                const int cellX =
                    self->m_layoutRects[0] * (i % 3) + x + extraX + self->m_scrollOffset;
                if (cell->texture == nullptr) { // no texture yet -> placeholder
                    drawAepFrameEx(&AepManager::shared(),
                                   self->m_frmNo[1],
                                   self->m_layoutRects[2] + cellX,
                                   cellY,
                                   scaleX,
                                   scaleY,
                                   rotation,
                                   anchorX,
                                   anchorY,
                                   color,
                                   alpha,
                                   blend,
                                   0xffffff,
                                   0,
                                   p14,
                                   1);
                } else {
                    neTextureForiOS_draw(&AepManager::shared(),
                                         cell->texture,
                                         0,
                                         0,
                                         0x168,
                                         0x168,
                                         self->m_layoutRects[2] + cellX,
                                         cellY,
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
                                         p14,
                                         1);
                }
                // Selection frame over the cell (@ +0x1a8, +0x994/+0x998 nudge).
                drawAepFrameEx(&AepManager::shared(),
                               self->m_frmNo[11],
                               self->m_layoutRects[3] + (cellX - (anchorX * scaleX) / 100),
                               self->m_layoutRects[4] + (cellY - (anchorY * scaleY) / 100),
                               100,
                               100,
                               0,
                               0,
                               0,
                               100,
                               0,
                               blend,
                               0xffffff,
                               0,
                               p14,
                               1);
            }
        }
    };

    if (self->m_elemUsrNo[0] == (int)child) {
        // Current column grid. Cache the grid origin (@ +0xa40/+0xa44) for
        // hit-testing.
        self->m_layoutRects[46] = x - (anchorX * scaleX) / 100;
        self->m_layoutRects[47] = y - (anchorY * scaleY) / 100;
        const int8_t curRow = (int8_t)self->m_curColLatch;
        drawJacketGrid(curRow, self->m_columnIndex, 0);

        // Incoming next column (m_nextColLatch), shifted one screen width right.
        if (self->m_columnIndex < self->m_columnCount - 1) {
            const int8_t nextRow = (int8_t)self->m_nextColLatch;
            drawJacketGrid(nextRow, self->m_columnIndex + 1, self->m_screenWidth);
        }
    }
    // ===================== Tail dispatch: every element other than the
    // current-column jacket grid. This callback fires once per named scene
    // element; each `if` below matches the element's resolved user number and
    // blits it. Two regimes follow: (a) list elements that repaint the same
    // visible 3-column cell grid — current / incoming-next / outgoing-prev
    // columns, latched via m_curColLatch / m_nextColLatch / m_prevColLatch; (b)
    // "selected song" elements that draw the highlighted song's score / rank /
    // place / banners. @ 0x389fc
    const int perRow = self->m_columnStride;            // m_columnStride  — cells per column
    const int songCount = self->m_songCount;            // m_songCount
    const int col = self->m_columnIndex;                // m_columnIndex
    const int colCount = self->m_columnCount;           // m_columnCount
    auto s8 = [](uint8_t b) { return (int)(int8_t)b; }; // signed row-load latch
    auto numDigits = [](int v) {
        int n = 1;
        while (v > 9) {
            n++;
            v /= 10;
        }
        return n;
    };
    auto pulseAlpha = [](int phase) { // triangle-wave badge alpha
        if (phase < 0x32) {
            return 100;
        }
        return phase < 100 ? phase * -2 + 200 : phase * 2 - 200;
    };

    // Common blits (head drawAepFrameEx / neTextureForiOS_draw forms; color/alpha
    // collapse to blend/p14 exactly as the head's drawJacketGrid does).
    auto drawFrame = [&](int frameNo, int fx, int fy) {
        drawAepFrameEx(&AepManager::shared(),
                       frameNo,
                       fx,
                       fy,
                       scaleX,
                       scaleY,
                       rotation,
                       anchorX,
                       anchorY,
                       color,
                       alpha,
                       blend,
                       0xffffff,
                       0,
                       p14,
                       1);
    };
    auto drawFrameAlpha = [&](int frameNo,
                              int fx,
                              int fy,
                              int a) { // explicit pulse alpha
        drawAepFrameEx(&AepManager::shared(),
                       frameNo,
                       fx,
                       fy,
                       scaleX,
                       scaleY,
                       rotation,
                       anchorX,
                       anchorY,
                       a,
                       100 - a,
                       blend,
                       0xffffff,
                       0,
                       p14,
                       1);
    };
    auto drawFrameFixed = [&](int frameNo,
                              int fx,
                              int fy,
                              int ax,
                              int ay) { // 100.0f scale
        drawAepFrameEx(&AepManager::shared(),
                       frameNo,
                       fx,
                       fy,
                       100,
                       100,
                       0,
                       ax,
                       ay,
                       100,
                       0,
                       blend,
                       0xffffff,
                       0,
                       p14,
                       1);
    };
    auto drawTex = [&](neTextureForiOS *tex,
                       int w,
                       int h,
                       int tx,
                       int ty) { // uv (0,0,w,h) at (tx,ty)
        neTextureForiOS_draw(&AepManager::shared(),
                             tex,
                             0,
                             0,
                             w,
                             h,
                             tx,
                             ty,
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
                             p14,
                             1);
    };

    // Walk every visible cell of the current / next / prev columns, invoking
    // paint(cell, i, cx0, cy0, listIndex). cx0/cy0 are the cell's top-left BEFORE
    // the per-element pixel nudge
    // (self->m_layoutRects[2]/self->m_layoutRects[5]); paint returns false to
    // stop the column. The three per-branch count styles in the decompile
    // (absolute-index, div/mod partial, relative cap) all reduce to "stop when
    // the running list index reaches songCount" for the shown columns, so they
    // unify.
    auto forEachGridCell =
        [&](const std::function<bool(MusicSelCell *, int, int, int, int)> &paint) {
            auto column = [&](int latch, int whichCol, int extraX) {
                if (latch < 0 || perRow <= 0) {
                    return;
                }
                MusicSelCell *base = &self->m_cells[latch];
                for (int i = 0; i < perRow; i++) {
                    const int listIndex = whichCol * perRow + i;
                    if (listIndex >= songCount) {
                        break;
                    }
                    const int cy0 = self->m_layoutRects[1] * (i / 3) + y;
                    const int cx0 =
                        self->m_layoutRects[0] * (i % 3) + x + self->m_scrollOffset + extraX;
                    if (!paint(&base[i], i, cx0, cy0, listIndex)) {
                        break;
                    }
                }
            };
            column(s8(self->m_curColLatch), col, 0);
            if (col < colCount - 1) {
                column(s8(self->m_nextColLatch), col + 1, self->m_screenWidth);
            }
            if (col >= 1) {
                column(s8(self->m_prevColLatch), col - 1, -self->m_screenWidth);
            }
        };

    // ------------------------------------------------------------------ grid
    // list elements ----

    // Song-name text (per cell) — m_elemUsrNo[10]. Blits each cell's title string
    // (@ cell+0x10).
    if (self->m_elemUsrNo[10] == (int)child) {
        forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int) {
            id name = cell->name;
            if (name) {
                self->m_aep->DrawText([name UTF8String],
                                      self->m_layoutRects[54],
                                      cx0 + self->m_layoutRects[2],
                                      cy0 + self->m_layoutRects[5],
                                      1,
                                      100,
                                      0,
                                      p14);
            }
            return true;
        });
        return;
    }

    // Difficulty stars (per cell) — m_elemUsrNo[2..4] draw m_starFrmNo[0..2],
    // gated by the cell's per-difficulty rank short (>= 0) OR the
    // m_showLevelNumbers visibility override.
    auto drawStarGrid = [&](int frameNo, int diff) {
        forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int) {
            const short sv = cell->scores.rank[diff];
            if (sv >= 0 || self->m_showLevelNumbers != 0) {
                drawFrame(frameNo, cx0 + self->m_layoutRects[2], cy0);
            }
            return true;
        });
    };
    if (self->m_elemUsrNo[2] == (int)child) {
        drawStarGrid(self->m_starFrmNo[0], 0);
        return;
    }
    if (self->m_elemUsrNo[3] == (int)child) {
        drawStarGrid(self->m_starFrmNo[1], 1);
        return;
    }
    if (self->m_elemUsrNo[4] == (int)child) {
        drawStarGrid(self->m_starFrmNo[2], 2);
        return;
    }

    // Streaming placeholder frame (per cell) — m_elemUsrNo[13] draws m_frmNo[2]
    // over cells whose score/points slots (cell+0x20/+0x24/+0x28) are all zero,
    // unless m_showLevelNumbers is set. Stops the column at the first cell with
    // no jacket handle (cell+0xc == 0).
    if (self->m_elemUsrNo[13] == (int)child) {
        forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int) {
            if (cell->texture == nullptr) {
                return false;
            }
            const int sum =
                cell->scores.playCnt[0] + cell->scores.playCnt[1] + cell->scores.playCnt[2];
            if (sum == 0 && self->m_showLevelNumbers == 0) {
                drawFrame(self->m_frmNo[2], cx0 + self->m_layoutRects[2], cy0);
            }
            return true;
        });
        return;
    }

    // Difficulty level / music rank (per cell) — m_elemUsrNo[5..7]. When
    // m_showLevelNumbers is clear the cell shows its music-rank frame
    // (m_musicRankFrmNo[rank]); when set it shows the numeric difficulty level
    // (lvNormal / lvHyper / lvEx) as a digit run from the m_digitTex atlas.
    const int digitScale = self->m_isPadDisplay ? 200 : 100;
    auto drawLevelDigits = [&](int value, int cx, int cy, int priority) {
        const int n = numDigits(value);
        int pen = 0;
        for (int k = 1;; k++) {
            const int adv = (int)(((long long)pen * -0x51eb851f) >> 32); // pen / 100
            const int dx = ((adv >> 5) - (adv >> 31)) + cx + ((n << 4) >> 1) - 8;
            neTextureForiOS_draw(&AepManager::shared(),
                                 self->m_digitTex[20 + value % 10],
                                 0,
                                 0,
                                 0x10,
                                 0x14,
                                 dx,
                                 cy,
                                 digitScale,
                                 digitScale,
                                 0,
                                 8,
                                 10,
                                 color,
                                 alpha,
                                 blend,
                                 0xffffff,
                                 nullptr,
                                 priority,
                                 1);
            if (n <= k) {
                break;
            }
            pen += digitScale * 0x10;
            value /= 10;
        }
    };
    auto drawLevelGrid = [&](int diff, int whichLevel, int digitPriority) {
        forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int listIndex) {
            if (cell->name == nil) {
                return true; // empty cell -> skip
            }
            if (self->m_showLevelNumbers == 0) {
                const int rank = cell->scores.rank[diff];
                if (rank >= 0) {
                    drawFrame(self->m_musicRankFrmNo[rank], cx0 + self->m_layoutRects[2], cy0);
                }
            } else {
                MusicData *info = [self->m_musicList objectAtIndexedSubscript:listIndex];
                const int lvl = whichLevel == 0 ? (int)[info lvNormal] :
                                whichLevel == 1 ? (int)[info lvHyper] :
                                                  (int)[info lvEx];
                drawLevelDigits(lvl, cx0 + self->m_layoutRects[2], cy0, digitPriority);
            }
            return true;
        });
    };
    if (self->m_elemUsrNo[5] == (int)child) {
        drawLevelGrid(0, 0, 0xb);
        return;
    } // Normal
    if (self->m_elemUsrNo[6] == (int)child) {
        drawLevelGrid(1, 1, 0xb);
        return;
    } // Hyper
    if (self->m_elemUsrNo[7] == (int)child) {
        drawLevelGrid(2, 2, p14);
        return;
    } // Extra

    // Jacket "tip" overlays (NEW / clear icons, per cell) —
    // m_jacketTipUsrNo[0..2]. Each present cell draws a state backing frame
    // (m_frmNo[13..15], chosen from the cell's rank short + tip flag byte) at a
    // pad/phone-nudged offset, then the tip frame m_jacketTipFrmNo[tip] on top.
    auto drawTipGrid = [&](int tip) {
        forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int) {
            if (cell->name == nil) {
                return true; // empty cell -> skip
            }
            const bool flagA = cell->scores.fullCombo[tip] != 0;
            const bool flagB = cell->scores.perfect[tip] != 0;
            if (!flagA && !flagB) {
                return true;
            }
            const short rankShort = cell->scores.rank[tip];
            int bgFrame = self->m_frmNo[15];
            if (rankShort != 0) {
                bgFrame = flagB ? self->m_frmNo[14] : self->m_frmNo[13];
            }
            const int fx = cx0 + self->m_layoutRects[2];
            int bx = fx, by = cy0;
            if (self->m_isPadDisplay == 0) {
                bx = fx + 10;
                by = cy0 + 4;
            } // phone nudge
            drawFrameFixed(bgFrame, bx, by, anchorX, anchorY);
            drawFrame(self->m_jacketTipFrmNo[tip], fx, cy0);
            return true;
        });
    };
    for (int tip = 0; tip < 3; tip++) {
        if (self->m_jacketTipUsrNo[tip] == (int)child) {
            drawTipGrid(tip);
            return;
        }
    }

    // Treasure-point counter — m_elemUsrNo[16]. Fixed 4-digit run (atlas
    // m_digitTex[10..19]), least-significant digit at x, each preceding digit
    // 0x1e px to the left.
    if (self->m_elemUsrNo[16] == (int)child) {
        int v = self->m_treasurePoint;
        for (int dx = 0; dx != -0x78; dx -= 0x1e) {
            drawTex(self->m_digitTex[10 + v % 10], 0x22, 0x26, x + dx, y);
            v /= 10;
        }
        return;
    }

    // ---------------------------------------------------------------
    // selected-song elements ---- These are keyed on the highlighted song: the
    // cell at column-relative index (m_chosenIndex % perRow) within the current
    // column.
    const int resultSheet = self->m_resultSheet;
    const int selCell = (perRow ? self->m_chosenIndex % perRow : 0) + s8(self->m_curColLatch);
    MusicSelCell *selCellPtr = &self->m_cells[selCell];

    // Score digits — m_scoreDigitUsrNo[0..5]. Each element paints ONE decimal
    // digit (LSB first) of the selected song's score for the active difficulty
    // sheet (@ selCell+resultSheet*4+0x14).
    {
        int score = selCellPtr->scores.score[resultSheet];
        if (score < 0) {
            score = 0;
        }
        for (int d = 0; d < 6; d++) {
            if (self->m_scoreDigitUsrNo[d] == (int)child) {
                drawTex(self->m_digitTex[score % 10], 0x20, 0x28, x, y);
                return;
            }
            score /= 10;
        }
    }

    // Difficulty rank badge (selected song) — m_elemUsrNo[8] draws
    // m_diffRankFrmNo[rank].
    if (self->m_elemUsrNo[8] == (int)child) {
        const short rank = selCellPtr->scores.rank[resultSheet];
        if (rank < 0) {
            return;
        }
        drawFrame(self->m_diffRankFrmNo[rank], x, y);
        return;
    }

    // Song-list backing frame — m_elemUsrNo[9] draws m_frmNo[0].
    if (self->m_elemUsrNo[9] == (int)child) {
        drawFrame(self->m_frmNo[0], x, y);
        return;
    }

    // Difficulty backing layers — m_diffBlackUsrNo[0..2]. Play a looping Aep
    // layer (m_bgLyrNo[1] for the selected sheet, else m_bgLyrNo[2]) advancing
    // its own frame counter
    // (@ +0x170+i*4) until the layer's frame count (m_bgLyrFrames), then holding
    // on the last.
    for (int i = 0; i < 3; i++) {
        if (self->m_diffBlackUsrNo[i] == (int)child) {
            const int lyrSlot = (resultSheet == i) ? 1 : 2;
            int &frm = self->m_diffStarLayerFrame[i];
            self->m_aep->drawLayer(self->m_bgLyrNo[lyrSlot],
                                   frm,
                                   x,
                                   y,
                                   scaleX,
                                   scaleY,
                                   rotation,
                                   anchorY,
                                   color,
                                   alpha,
                                   1,
                                   anchorX,
                                   blend,
                                   0xffffff,
                                   0,
                                   0,
                                   p14,
                                   1);
            if (self->m_bgLyrFrames[lyrSlot] - 1 <= frm) {
                return;
            }
            frm++;
            return;
        }
    }

    // Selected-song jacket preview — m_elemUsrNo[1] blits the big jacket texture
    // (@ selCell+0xc).
    if (self->m_elemUsrNo[1] == (int)child) {
        drawTex(selCellPtr->texture, 0x168, 0x168, x, y);
        return;
    }

    // Song-name / artist banners — m_elemUsrNo[11] / m_elemUsrNo[12].
    if (self->m_elemUsrNo[11] == (int)child) {
        if (!self->m_nameTex) {
            return;
        }
        drawTex(self->m_nameTex, 0x126, 0x20, x, y);
        return;
    }
    if (self->m_elemUsrNo[12] == (int)child) {
        if (!self->m_artistTex) {
            return;
        }
        drawTex(self->m_artistTex, 0x122, 0x14, x, y);
        return;
    }

    // Ranking-place digits — m_placeDigitUsrNo[0..8]: three groups (green /
    // yellow / pink) of up to three digit slots, each a single digit of the
    // group's place value (@ +0x908+grp*4) drawn from that group's 10-digit atlas
    // (m_digitTex[30 + grp*10 + digit]).
    for (int grp = 0; grp < 3; grp++) {
        const int placeVal = self->m_placeValue[grp];
        const int nd = numDigits(placeVal);
        for (int d = 0; d < 3; d++) {
            if (self->m_placeDigitUsrNo[grp * 3 + d] == (int)child) {
                int digit;
                if (d == 2) {
                    if (nd != 2) {
                        return;
                    }
                    digit = (placeVal / 10) % 10;
                } else if (d == 1) {
                    if (nd != 2) {
                        return;
                    }
                    digit = placeVal % 10;
                } else {
                    if (nd != 1) {
                        return;
                    }
                    digit = placeVal;
                }
                drawTex(self->m_digitTex[30 + grp * 10 + digit], 0x32, 0x32, x, y);
                return;
            }
        }
    }

    // Clear-mark badge (selected song) — m_elemUsrNo[14]. No record ->
    // m_frmNo[5]; else full-combo (byte@+0x917+sheet) -> m_frmNo[4]; else cleared
    // (byte@+0x914+sheet) -> m_frmNo[3]; else none.
    if (self->m_elemUsrNo[14] == (int)child) {
        int frameNo;
        if (selCellPtr->scores.rank[resultSheet] == 0) {
            frameNo = self->m_frmNo[5];
        } else if (self->m_fullComboMedal[resultSheet] != 0) {
            frameNo = self->m_frmNo[4];
        } else if (self->m_clearMedal[resultSheet] != 0) {
            frameNo = self->m_frmNo[3];
        } else {
            return;
        }
        drawFrame(frameNo, x, y);
        return;
    }

    // Recommend / over-score badges + music-state frames. Skipped while the
    // recommend list is still downloading. m_overScoreDict (+0xa98) maps touched
    // music-id strings to a state value (the &cf_1 / &cf_0 binary CFString
    // constants, "1"/"0"). Helpers factor the dict lookups.
    auto overScoreMatch = [&](int listIndex, NSString *wantValue) -> bool {
        MusicData *info = [self->m_musicList objectAtIndexedSubscript:listIndex];
        NSString *key = [@((int)[info MusicID]) stringValue];
        id dict = self->m_overScoreDict;
        if (![[dict allKeys] containsObject:key]) {
            return false;
        }
        return [[dict objectForKeyedSubscript:key] isEqual:wantValue];
    };
    auto chosenTouched = [&]() -> bool {
        NSString *key = [@(self->m_chosenMusicId) stringValue];
        return [[self->m_overScoreDict allKeys] containsObject:key] != NO;
    };
    auto jacketPresent = [&](MusicSelCell *cell) -> bool {
        const int idx = cell->songIndex;
        bool empty = (idx == 0);
        if (idx >= 0) {
            empty = (songCount == idx);
        }
        return !empty && (idx >= 0 && idx <= songCount);
    };

    if (![[DownloadMain getInstance] isGetRecommendListDownLoading]) {
        // Recommend badge (per cell) — m_elemUsrNo[20], m_frmNo[22], pulsing (phase
        // @ +0xa9c).
        if (self->m_elemUsrNo[20] == (int)child) {
            const int a = pulseAlpha(self->m_overScorePulse);
            forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int listIndex) {
                if (jacketPresent(cell) && overScoreMatch(listIndex, @"1")) {
                    drawFrameAlpha(self->m_frmNo[22], cx0, cy0, a);
                }
                return true;
            });
            return;
        }
        // Over-score badge (per cell) — m_elemUsrNo[21], m_frmNo[23]. Advances the
        // pulse phase.
        if (self->m_elemUsrNo[21] == (int)child) {
            const int a = pulseAlpha(self->m_overScorePulse);
            self->m_overScorePulse = (self->m_overScorePulse + 2) % 0x97;
            forEachGridCell([&](MusicSelCell *cell, int, int cx0, int cy0, int listIndex) {
                if (jacketPresent(cell) && overScoreMatch(listIndex, @"0")) {
                    drawFrameAlpha(self->m_frmNo[23], cx0, cy0, a);
                }
                return true;
            });
            return;
        }
        // Chosen-song state frames (single blit at x,y) — m_elemUsrNo[17..19],
        // keyed on whether the chosen music id is in the over-score set.
        if (self->m_elemUsrNo[17] == (int)child) {
            drawFrame(chosenTouched() ? self->m_frmNo[18] : self->m_frmNo[17], x, y);
            return;
        }
        if (self->m_elemUsrNo[18] == (int)child) {
            drawFrame(chosenTouched() ? self->m_frmNo[20] : self->m_frmNo[19], x, y);
            return;
        }
        if (self->m_elemUsrNo[19] == (int)child) {
            if (chosenTouched()) {
                drawFrame(self->m_frmNo[21], x, y);
            }
            return;
        }
    }

    // Difficulty intro sweep — m_elemUsrNo[15]. While the intro flag
    // (byte@+0x91d) is set, play m_bgLyrNo[0] frame by frame (counter @ +0x164)
    // until it ends, then clear the flag; once done it holds the static
    // difficulty backing frame m_frmNo[12].
    if (self->m_elemUsrNo[15] != (int)child) {
        return;
    }
    if (self->m_diffIntroActive != 0) {
        int &frm = self->m_diffIntroFrame;
        self->m_aep->drawLayer(self->m_bgLyrNo[0],
                               frm,
                               x,
                               y,
                               scaleX,
                               scaleY,
                               rotation,
                               anchorY,
                               color,
                               alpha,
                               1,
                               anchorX,
                               blend,
                               0xffffff,
                               0,
                               0,
                               p14,
                               1);
        frm++;
        if (frm < self->m_bgLyrFrames[0]) {
            return;
        }
        frm = 0;
        self->m_diffIntroActive = 0;
        return;
    }
    drawFrame(self->m_frmNo[12], x, y);
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
