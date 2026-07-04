//
//  MainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor MainTask_ctor
//  FUN_00034d48, dtor mainTask_dtor FUN_00034d90, update MainTask_update FUN_00035914,
//  plus the six per-frame helpers that all take `this` — now real MainTask methods:
//  setup FUN_000370f0, updateList FUN_00034f4c, allCellsReady FUN_00037f38,
//  updateHighlight FUN_000355fc, stopAndSave FUN_00038008, updateInfoPanel FUN_00037c88).
//  The standard-mode music-select state machine. Objective-C++ (ARC): it drives the
//  UIKit nav host through the scene manager and the ObjC managers, and calls the C++
//  engine (Aep / neGraphics / neTextureForiOS) directly.
//
//  All work-area access is through the named members on MainTask (MainTask.h); there
//  are no raw byte-offset casts and no extern "C" engine seams. "MusicSelTask" is a
//  typedef of MainTask (the binary's own name for this task), so the DownloadMain
//  delegate / MainViewController Goto* calls take `this` with no identity cast.
//

#import <UIKit/UIKit.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <functional>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "MusicManager.h"
#import "OverScoreData.h"
#import "ScoreData.h"
#import "ScoreData+Store.h"   // +getScoreData:inManagedObjectContext: (background cell loader)
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "RhUtil.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host (MainViewController) the select screen drives.
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// findCharIndexForColumn (song-name truncation in rebuildList()) is declared in neGraphics.h
// beside its sibling text helpers and defined in neEngineBridge.mm.

// Recommend-list refresh throttle: refetch when the list has never been pulled, when more than
// 4 minutes have elapsed since the last fetch (DAT_00035e9c == 60.0 divisor -> seconds/60 > 4),
// or when a push notification is pending. The last-fetch timestamp is the event-center's
// _endDate (stamped by setEndDate at the end of the recommend download).
static bool recommendListIsStale() {
    neAppEventCenter &ec = neAppEventCenter::shared();
    NSDate *lastFetch = ec.recommendFetchDate();
    if (lastFetch == nil) {
        return true;   // never fetched
    }
    NSTimeInterval elapsedMinutes = [[NSDate date] timeIntervalSinceDate:lastFetch] / 60.0;
    if ((int)elapsedMinutes > 4) {
        return true;   // stale window elapsed
    }
    return ec.remoteNotifyPending();   // a push arrived -> force a refresh
}

// widgetIndexForButton: which layout widget cell (m_cells[i]) holds a button's hit-rect.
// Recovered from the 13 pointInRect blocks in FUN_00035914 (the constant cell indices each
// block reads through field26_0x2b0[i].field4_0x10). The music-select scene reuses the four
// trailing entries of the 27-cell jacket array (indices 0x17..0x1a, i.e. cells 23..26) as
// packed UI/layout widgets; m_cells[0x1a] additionally holds the shared UI scale every test
// multiplies by. Mapping (button -> cell, decompile pointInRect line, on-hit action):
//
//   kBtnSettings     0x17   @294   -> m_state = 5 (GotoSetting)
//   kBtnSort         0x17   @327   -> allCellsReady -> m_state = 7 (GotoSortSelect)
//   kBtnRecommend    0x18   @361   -> allCellsReady -> GotoRecommend   (w/h read from 0x17)
//   kBtnOverScoreLog 0x18   @406   -> allCellsReady -> m_state = 9 (GotoOverScoreLog)
//   kBtnBackToMenu   (none) @425   -> MenuTask, SE 2, m_state = 0xe    (fixed screen consts)
//   kBtnTutorial     0x18   @472   -> tutorialOffered -> PlayTask, m_state = 0xe
//   kBtnDiffToggle   0x18   @529   -> scrollLatchA/B = 1, scrollConfig = 0
//   kBtnSongCell     0x19   @591   -> allCellsReady -> select cell, m_state = 3 (grid: base
//                                     m_cells[0x19], column stride m_cells[0x17], per cellIndex)
//   kBtnFavToggle    0x19   @631   -> favorite ^= 1                    (grid, per cellIndex)
//   kBtnPlay         0x19   @972   -> popBgm, PlayTask, m_state = 0xc
//   kBtnFriendScore  0x19   @1026  -> GotoFriendScore (a 2nd, over-score-only rect @1050 too)
//   kBtnDifficulty   0x18   @1084  -> select difficulty (row base m_cells[0x18], per-row
//                                     stride/offset m_cells[0x19], iterated by cellIndex d)
int MainTask::widgetIndexForButton(Button button) const {
    switch (button) {
    case kBtnSettings:     return 0x17;
    case kBtnSort:         return 0x17;
    case kBtnRecommend:    return 0x18;   // rect origin from 0x18; w/h split from 0x17 (seam)
    case kBtnOverScoreLog: return 0x18;
    case kBtnTutorial:     return 0x18;
    case kBtnDiffToggle:   return 0x18;
    case kBtnSongCell:     return 0x19;   // grid rect: base 0x19 + column stride from 0x17
    case kBtnFavToggle:    return 0x19;
    case kBtnPlay:         return 0x19;
    case kBtnFriendScore:  return 0x19;
    case kBtnDifficulty:   return 0x18;   // difficulty-row base 0x18 + per-row stride from 0x19
    case kBtnBackToMenu:   return -1;     // fixed constants (DAT_000368cc/d0), not a widget cell
    }
    return -1;
}

// hitButton: map `button` to its layout widget cell (widgetIndexForButton), read that cell's
// stored rect from the detail region (WidgetRect view), scale it by the shared UI-scale factor
// about the origin, and point-in-rect it against the tap. This is the ~13x-repeated inlined
// FixedToFP/FloatVectorMult(...scale...)/FPToFixed block from FUN_00035914, extracted once
// and modelled as ordinary float rounding (the 16.16 Q-format helpers are the pixel-math seam).
// The neGraphics::pointInRect call (FUN_0002d974) is exact.
//
// Wired: the button -> widget-cell mapping above (all 12 buttons routed). Residual seams,
// left as precise notes rather than fabricated: (a) the exact WidgetRect *slot* within a
// shared cell (Settings vs Sort in 0x17; OverScoreLog/Tutorial/DiffToggle in 0x18) — the
// binary packs several rects per cell at 16-bit sub-offsets, so only the representative
// slot is read here; (b) the procedural grid math for kBtnSongCell/kBtnFavToggle/
// kBtnDifficulty (base+stride+cellIndex); (c) kBtnBackToMenu's fixed screen constants.
bool MainTask::hitButton(int tapX, int tapY, Button button, int cellIndex) const {
    const int widget = widgetIndexForButton(button);
    if (widget < 0) {
        // kBtnBackToMenu: FUN_00035914 builds this rect from immediates (14.0f/11.0f) and the
        // globals DAT_000368cc/DAT_000368d0, not a widget cell. Its constants are unresolved,
        // so the button is left un-wired (no-hit) here rather than faked. Seam.
        return neGraphics::pointInRect(tapX, tapY, 0, 0, 0, 0);
    }

    // The shared UI scale every hit-test multiplies by. Ghidra sources it from the trailing
    // layout cell (pMVar26 = &field26_0x2b0[0x1a].field4_0x10; scale = pMVar26->field0_0x0),
    // which setup() mirrors from g_dwUiScale — the same value the work area caches in m_uiScale.
    const float scale = reinterpret_cast<const float &>(m_uiScale);

    // The button's stored rect: slot 0 of its widget cell's packed detail. The per-cell grid
    // buttons (kBtnSongCell / kBtnFavToggle / kBtnDifficulty) additionally offset this rect by
    // their column/row position (cellIndex); that grid arithmetic is a documented seam.
    //
    // Reconciliation seam: setup() (FUN_000370f0) fills a parallel per-platform coordinate
    // table m_layoutRects (+0x988..+0xa64) with the real button x/w/y/h constants (e.g. Sort @
    // m_layoutRects[34], DiffToggle @ [39]); FUN_00035914's hit-tests instead read the widget
    // cells at +0x2d8 (field26_0x2b0[i]). setup() does not itself write those cells, so the copy
    // of m_layoutRects into the widget-cell detail happens elsewhere (musicSelUpdate / draw) — the
    // exact table->cell linkage, and thus the concrete per-button coordinates, is unresolved.
    const MusicSelCell::WidgetRect &r = m_cells[widget].widget;
    (void)cellIndex; (void)m_layoutRects;

    // Scale the rect about the origin (the FixedToFP -> FloatVectorMult(scale) -> FPToFixed
    // round block, ~13x-inlined in FUN_00035914; modelled here as float multiply + round).
    const int rx = (int)lroundf((float)r.x * scale);
    const int ry = (int)lroundf((float)r.y * scale);
    const int rw = (int)lroundf((float)r.w * scale);
    const int rh = (int)lroundf((float)r.h * scale);
    return neGraphics::pointInRect(tapX, tapY, rx, ry, rw, rh);
}

// Seed the three difficulty-star background-layer frame counters (@ +0x170+i*4) when the
// over-score preview opens (update states 3/4). Ghidra: the loop in FUN_00035914 writes
//   field15_0x148[i] = field13_0x130[(i == selected) ? 1 : 2] - 1
// De-aliased: field13_0x130 is at absolute +0x158, which is exactly m_bgLyrFrames (both name
// the same bytes — the "packed select-state seam"), and field15_0x148 is at +0x170, the star-
// layer frame counters the BG draw advances (see musicSelBgDraw's +0x170+i*4 counter). So the
// "rowConfig" values are just the star layers' own frame counts: the selected difficulty tracks
// the OPEN layer (m_bgLyrFrames[1]), the other two the OUT layer (m_bgLyrFrames[2]); each counter
// starts on that layer's LAST frame (count - 1) so the stars render fully open/out on entry.
// (The binary reads the selected index from the difficulty-toggle widget cell m_cells[21];
// m_sel.difficulty is the faithful reconstructed equivalent. Historical note: this was mislabeled
// "initOverscoreRows / overRowLen" before the +0x158/+0x170 alias was resolved.)
void MainTask::seedDiffStarLayerFrames() {
    int *starFrame = reinterpret_cast<int *>(reinterpret_cast<char *>(this) + 0x170);
    for (int i = 0; i < 3; i++) {
        starFrame[i] = (i == m_sel.difficulty ? m_bgLyrFrames[1] : m_bgLyrFrames[2]) - 1;
    }
}

// Re-read the three difficulty score rows for the current song (Ghidra: the diffDirty
// fetchScoreDataForMusic loop in update state 4 @ 0x35914). Each of the three difficulties
// is re-fetched from the local ScoreData store into the previewed song's jacket-cell score
// rows (the same MusicSelCell::ScoreRows block loadCellScoreRows fills). The destination
// storage is the named cell block; only the visible-row *index* the binary computes
// (___modsi3 of the packed per-cell select-state seam) does not decompile cleanly, so the
// chosen cell is taken as m_selectedCell (the cell tapped to enter the preview).
void MainTask::refreshScoreRows() {
    if (m_selectedCell < 0 || m_selectedCell >= 27) {
        return;   // no cell in preview
    }
    // fetchScoreDataForMusic (neEngineBridge.h) is reconstructed; drive it per difficulty.
    loadCellScoreRows(m_cells[m_selectedCell], m_sel.musicId);
}

// Ghidra: MainTask_ctor (FUN_00034d48) — C_TASK base ctor, install the MainTask vtable,
// zero the play-data region (task +0x28..+0xaa4), then set the sentinels the binary sets:
// selected cell = -1 (+0x928), the packed column-row latches idle (0xffff @ +0x8c0 covers the
// prev/current latch bytes, 0xff @ +0x8c2 the next latch), and state = 0 (+0xaa4). The named
// members carry those initial values directly.
MainTask::MainTask() {
    // C_TASK() already ran (base subobject); all members are default-initialised above
    // (m_selectedCell = -1, m_prevColLatch = m_curColLatch = m_nextColLatch = 0xff, m_state = 0),
    // matching the memset + sentinel stores in the binary ctor.
}

// Ghidra: mainTask_dtor (FUN_00034d90) — re-install the vtable, de-register this task as
// DownloadMain's recommend-list delegate (only if it is still us), then the C_TASK base
// dtor runs. MusicSelTask == MainTask, so the delegate compares directly against `this`.
// The compiler's deleting-destructor thunk mainTask_delete (@ 0x34eac: this dtor +
// operator delete) is glue over this body. @ 0x34eac
MainTask::~MainTask() {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl cppDelegateRecommendList] == this) {
        [dl setCppDelegateRecommendList:nil];
    }
    // ~C_TASK() (caSourceNode_dtor) runs implicitly after this body.
}

// Ghidra: MainTask_update (FUN_00035914). Each frame: detect a "tap" (a released touch
// that barely moved), then step the state machine. Interactive select is state 2; the
// chosen-song preview is states 3/4.
void MainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    DownloadMain *dl = [DownloadMain getInstance];

    // --- tap detection: a released touch whose start/end differ by < 11px is a tap ---
    neGraphics &gfx = neGraphics::shared();
    int tapX = -1, tapY = -1;
    bool haveTap = false;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid && !t->released) {
            break;   // a finger is still down -> do not register a tap this frame
        }
        if (haveTap) {
            continue;
        }
        if (t->released) {
            int dx = t->startX - t->x, dy = t->startY - t->y;
            if ((dx < 0 ? -dx : dx) < 0xb && (dy < 0 ? -dy : dy) < 0xb) {
                tapX = t->x;
                tapY = t->y;
                haveTap = true;
            }
        }
    }

    switch (m_state) {
    case 0: {   // build the scene, start BGM, kick off (or reuse) the recommend list
        setup();
        [audio setBgmVolume:[UserSettingData bgmVolume]];
        [audio playBgm:0];
        if (recommendListIsStale()) {
            [dl setCppDelegateRecommendList:this];
            [dl startGetRecommendListHttp];
        } else {
            updateInfoPanel(1);   // reuse the cached recommend panel
        }
        m_state = 1;
        break;
    }

    case 1:   // fade the select scene in and start its intro layers
        aep.playTransition(1, 1, 0);
        m_layers[0]->play();
        m_introLayers[0]->play();
        m_introLayers[1]->play();
        m_selectedCell = -1;
        m_state = 2;
        break;

    case 2: {   // *** interactive song / menu select ***
        // Re-arm the recommend fetch if it finished while a push is pending.
        if (![dl isGetRecommendListDownLoading] && recommendListIsStale()) {
            [dl setCppDelegateRecommendList:this];
            [dl startGetRecommendListHttp];
        }
        updateList();   // per-frame list scroll / cell animation

        // While the song list is still being built, stream one pending jacket texture per
        // frame (upload the first cell that has image data but no texture yet).
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

        // The list is ready: only dispatch buttons on a small tap (a drag scrolls the list).
        if (!haveTap) {
            break;
        }

        // -- top row --
        if (hitButton(tapX, tapY, kBtnSettings)) {
            m_state = 5;   // -> GotoSetting
            break;
        }
        if (hitButton(tapX, tapY, kBtnSort)) {
            if (allCellsReady()) {
                m_state = 7;   // -> GotoSortSelect
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnRecommend)) {
            if (allCellsReady()) {
                neEngine::playSystemSe(1);
                [RootVC() GotoRecommend:this];
                m_sel.favorite = 0;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnOverScoreLog)) {
            if (allCellsReady()) {
                m_state = 9;   // -> GotoOverScoreLog
            }
            break;
        }

        // -- overlay buttons --
        if (hitButton(tapX, tapY, kBtnBackToMenu)) {
            m_spawnedTask = MenuCreateTask();   // back to the mode-select hub
            neEngine::playSystemSe(2);
            m_state = 0xe;
            break;
        }
        if (hitButton(tapX, tapY, kBtnTutorial)) {
            if (m_sel.tutorialOffered) {
                m_sel.selectSeInst = (int)[audio playSe:nil resourceId:m_sel.selectSeId];
                neAppEventCenter::shared().setGuestNoSaveMode(true);   // guided first play: don't save
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = PlayTaskCreate();   // first-play guided play
                m_state = 0xe;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnDiffToggle)) {
            [audio playSe:nil resourceId:m_sel.selectSeId];
            m_sel.scrollLatchA = 1;   // list-scroll latch pair (field15_0x148)
            m_sel.scrollLatchB = 1;
            m_sel.scrollConfig = 0;
            break;
        }

        // -- song grid: first the whole cell, then its favourite toggle --
        for (int c = 0; c < 27; c++) {
            if (hitButton(tapX, tapY, kBtnSongCell, c)) {
                if (allCellsReady()) {
                    m_selectedCell = c;
                    neEngine::playSystemSe(1);
                    m_state = 3;   // preview the chosen song
                }
                goto tail;   // grid consumed the tap
            }
            if (hitButton(tapX, tapY, kBtnFavToggle, c)) {
                m_sel.favorite ^= 1;
                neEngine::playSystemSe(1);
                goto tail;
            }
        }
        break;
    }

    case 3: {   // a song was chosen: preview its BGM + load textures + ScoreData
        [audio pushBgm];
        m_chosenIndex = m_selectedCell;
        id info = [m_musicList objectAtIndexedSubscript:m_selectedCell];
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

        // The three level values + the six full-combo / perfect medals for the score panel.
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
            // Background jacket decode for `info` (Ghidra: block invoke @ 0x37f79). The
            // decoded textures are streamed into the cell array by state 2. Seam.
            (void)self;
            (void)info;
        });

        seedDiffStarLayerFrames();

        // Flag the over-score "touched" state for this song and (if already tracked)
        // refresh its dictionary entry.
        [OverScoreData updateOverScoreTouchedWithMusic:musicId inManagedObjectContext:moc];
        NSString *idStr = [@(musicId) stringValue];
        NSMutableDictionary *overDict = m_overScoreDict;
        if ([[overDict allKeys] containsObject:idStr]) {
            overDict[idStr] = idStr;   // re-touch (Ghidra: setObject:forKeyedSubscript: &cf_1)
        }

        m_sel.difficulty = 0;   // default to NORMAL
        m_state = 4;
        break;
    }

    case 4: {   // difficulty / option select + BGM preview loop
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
            break;   // buttons only respond to a tap
        }

        // -- PLAY --
        if (hitButton(tapX, tapY, kBtnPlay)) {
            [audio popBgm];
            m_sel.selectSeInst = (int)[audio playSe:nil resourceId:m_sel.selectSeId];
            m_spawnedTask = PlayTaskCreate();
            [[AppDelegate appDelegate] setMainTask:(MainTask *)m_spawnedTask];
            m_state = 0xc;   // -> play-launch handoff (0xc -> 0xd -> 0xe)
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
                    neEngine::playSystemSe(2);   // locked -> cancel SE
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

    case 5:   // options -> settings
        neEngine::playSystemSe(1);
        [RootVC() GotoSetting];
        m_state = 6;
        break;

    case 6:   // wait for settings to close; relaunch the title on request, else re-select
        if (![RootVC() settingViewing]) {
            if ([RootVC() isGotoTitle] == 1) {
                m_spawnedTask = TitleTaskCreate();
                m_state = 0xe;
                [RootVC() setIsGotoTitle:0];
            } else {
                m_state = 2;   // (falls through to the case 8/10 handoff in the binary)
            }
        }
        break;

    case 7:   // sort
        neEngine::playSystemSe(1);
        [RootVC() GotoSortSelect:this];
        m_state = 8;
        break;

    case 8:   // sort modal shown -> resume interactive select
    case 10:  // over-score-log modal shown -> resume interactive select
        m_state = 2;
        break;

    case 9:   // over-score (friend score) log
        neEngine::playSystemSe(1);
        [RootVC() GotoOverScoreLog:this];
        m_state = 10;
        break;

    case 0xc:   // play-launch handoff
        m_state = 0xd;
        break;

    case 0xd:
        m_state = 0xe;
        break;

    case 0xe:   // fade out into the spawned task / title
        aep.playTransition(2, 1, 0);
        m_sel.transitionLatch = 1;   // transition-out latch (element[0x1a].field3_0x1c+2)
        m_state = 0xf;
        break;

    case 0xf:   // wait for the fade-out (and, on a preview exit, the layer to settle)
        if (aep.isTransitionDone() && !m_sel.previewReady && m_sel.transitionLatch == 2) {
            m_state = 0x10;
        }
        break;

    case 0x10:  // handoff: tear down once the select SEs finish
        if (!neEngine::isSePlaying(2)) {
            if (m_sel.selectSeInst >= 0 && [audio isPlayingSe:0]) {
                break;   // a select SE is still sounding
            }
            stopAndSave();
        }
        break;

    default:
        break;
    }

tail:
    // Per-frame select-screen highlight update + Aep layer advance/draw (Ghidra tail).
    updateHighlight();
    AepLyrCtrlUpdateAll(0);
}

// ===== byte-verified const tables setup() resolves against (Ghidra project rb420) =====
// All of the strings/coordinates below were read from the binary's .const_data; see the
// per-table Ghidra address annotations.

// Per-platform button-rect layout table (m_layoutRects[55], +0x988..+0xa64). These are the
// immediate stores FUN_000370f0 makes in its !isPad / isPad branches. Slots that the binary
// computes at runtime from the screen metrics / layout base are 0 here and patched in setup()
// below (phone: 7/11/15/19/23/27/31/34/39/43; pad: 31; slots 46/47 are the draw-time grid-
// origin cache, never written by setup). Button roles: settings/sort/recommend/over-score-log
// row, back/tutorial/diff-toggle overlay, song-cell/fav grid, play/friend-score/difficulty.
static const int kPhoneLayoutRects[55] = {
    0xd2, 0x13a, 0,     -30,   -48,   0,     5,     0,      // 0..7
    0x9c, 0x34,  0xa8,  0,     0x9c,  0x34,  0x141, 0,      // 8..15
    0x9c, 0x34,  0x1df, 0,     0x9c,  0x34,  0x50,  0,      // 16..23
    0x8c, 0x93,  0xfa,  0,     0x138, 0xa4,  0x26c, 0,      // 24..31
    0x1e, 0x48,  0,     0x87,  0x86,  0xb2,  0xcd,  0,      // 32..39
    0xe3, 0x4d,  0x14,  0,     0x15e, 0x5a,  0,     0,      // 40..47
    0xb4, 0xb4,  0xbe,  0x32,  0x2a,  0x2a,  0x14           // 48..54
};
static const int kPadLayoutRects[55] = {
    0x1e4, 0x210, -1,    -53,   -88,   -13,   0x1e,  0x78f,  // 0..7
    0xea,  0x4e,  0x10d, 0x78f, 0xea,  0x4e,  0x1fc, 0x78f,  // 8..15
    0xea,  0x4e,  0x2eb, 0x78f, 0xea,  0x4e,  0x4ea, 0x6c0,  // 16..23
    0xae,  0x11a, 0x306, 0x677, 0x1e2, 0x113, 0x5ec, 0,      // 24..31
    0x26,  0x198, 0x4f4, 0xde,  0xd6,  0xf4,  0x22e, 0x604,  // 32..39
    0x1a0, 200,   0x1ce, 0x48e, 400,   0x56,  0,     0,      // 40..47
    0x132, 400,   0x132, 0x55,  0x56,  0x56,  0x1b           // 48..54
};

// getLyrNo layer names -> m_bgLyrNo[3] (@ DAT_001315c8).
static const char *const kBgLyrNames[3] = {
    "BG_NEKO", "DIFFICULTY_STAR_OPEN", "DIFFICULTY_STAR_OUT"};
// The 4 scene-layer names + ordering-table priorities (@ DAT_001315d4 / DAT_0012e670).
static const char *const kLayerNames[4] = {
    "BG_640X1136", "DIFFICULTY_OPEN", "DIFFICULTY_CLOSE", "DIFFICULTY_ROOP"};
static const int kLayerOrder[4] = {13, 9, 9, 9};
// The 2 intro-layer names + priorities, device-branched (@ DAT_001315e8/f0 / DAT_0012e680).
static const char *const kIntroNamesTall[2]  = {"1024IMG", "BG_IMG_1136"};  // displayType == 2
static const char *const kIntroNamesShort[2] = {"640IMG",  "BG_IMG_640"};
static const int kIntroOrder[2] = {15, 14};
// getFrameNo names -> m_frmNo[24] (@ DAT_001315f8).
static const char *const kFrmNames[24] = {
    "DIFFICULTY_BT00", "JACKET10_LOAD", "NEW_BOARD", "FULLCOMBO", "PERFECT", "PERFECT1",
    "BT_SETTING", "BT_RETURN", "BT_SORT", "BT_OSSUME", "BT_EMULATE", "JACKET_LINE0",
    "BG_NEKO", "JACKET_TIP_FONT0", "JACKET_TIP_PERFECT1", "JACKET_TIP_PERFECT2",
    "BT_TUTORIAL", "FRIEND_SCORE_FONT", "FRIEND_UPDEF_FONT", "FRIEND_SCORE_ICON",
    "FRIEND_UPDEF_ICON", "FRIEND_UPDEF_FONTBAR", "FRIEND_UP_ICON", "FRIEND_UP_FIRST_ICON"};
// getFrameNo -> m_starFrmNo[3] (@ DAT_00131658).
static const char *const kStarFrmNames[3] = {
    "DIFFICULTY_STAR_GREEN", "DIFFICULTY_STAR_YELLOW", "DIFFICULTY_STAR_RED"};
// getFrameNo -> m_musicRankFrmNo[7] (@ DAT_00131664).
static const char *const kMusicRankFrmNames[7] = {
    "MUSIC_RUNK_NUMBER_S", "MUSIC_RUNK_NUMBER_AAA", "MUSIC_RUNK_NUMBER_AA", "MUSIC_RUNK_NUMBER_A",
    "MUSIC_RUNK_NUMBER_B", "MUSIC_RUNK_NUMBER_C", "MUSIC_RUNK_NUMBER_D"};
// getFrameNo -> m_diffRankFrmNo[7] (@ DAT_00131680).
static const char *const kDiffRankFrmNames[7] = {
    "DIFFICULTY_RUNK_NUMBER_S", "DIFFICULTY_RUNK_NUMBER_AAA", "DIFFICULTY_RUNK_NUMBER_AA",
    "DIFFICULTY_RUNK_NUMBER_A", "DIFFICULTY_RUNK_NUMBER_B", "DIFFICULTY_RUNK_NUMBER_C",
    "DIFFICULTY_RUNK_NUMBER_D"};
// JACKET_TIP names, resolved BOTH as frames (m_jacketTipFrmNo) and users (m_jacketTipUsrNo)
// (@ PTR_s_JACKET_TIP00_0013173c).
static const char *const kJacketTipNames[3] = {"JACKET_TIP00", "JACKET_TIP01", "JACKET_TIP02"};
// getUserNo -> m_elemUsrNo[22] (@ DAT_0013169c) — MusicSelAepDraw per-element dispatch keys.
static const char *const kElemUsrNames[22] = {
    "JACKET00", "JACKET09", "DIFFICULTY_STAR_GREEN", "DIFFICULTY_STAR_YELLOW",
    "DIFFICULTY_STAR_RED", "MUSIC_RUNK_NUM_GREEN", "MUSIC_RUNK_NUM_YELLOW", "MUSIC_RUNK_NUM_RED",
    "DIFFICULTY_RUNK_NUMBER_E", "DIFFICULTY_BT00", "MUSIC_TITLE", "DIFFICULTY_TITLE",
    "DIFFICULTY_NAME", "NEW_BOARD", "FULLCOMBO", "BG_NEKO", "S_POINT_NUM", "FRIEND_SCORE_FONT",
    "FRIEND_SCORE_ICON", "FRIEND_UPDEF_FONTBAR", "FRIEND_UP_ICON", "FRIEND_UP_FIRST_ICON"};
// getUserNo -> m_scoreDigitUsrNo[6] (@ DAT_001316f4).
static const char *const kScoreDigitUsrNames[6] = {
    "SCORE0", "SCORE00", "SCORE000", "SCORE0000", "SCORE00000", "SCORE000000"};
// getUserNo -> m_diffBlackUsrNo[3] (@ DAT_0013170c).
static const char *const kDiffBlackUsrNames[3] = {
    "DIFFICULTY_BLACK", "DIFFICULTY_BLACK2", "DIFFICULTY_BLACK3"};
// getUserNo -> m_placeDigitUsrNo[9] (@ DAT_00131718): the 3 colours x 3 digit places.
static const char *const kPlaceDigitUsrNames[9] = {
    "GREEN_0", "GREEN_0_0", "GREEN_0_0_0", "YELLOW_0", "YELLOW_0_0", "YELLOW_0_0_0",
    "PINK_0", "PINK_0_0", "PINK_0_0_0"};

// The 60 digit-atlas bundle resource names -> m_digitTex[60] (each loaded as "<name>.png").
// Index order matches the binary's write offsets: score(+0x5c), points(+0x84), jk_dif(+0xac),
// then the 30-entry rank block (+0xd4) written as green/yellow/pink 10s (@ 0x131748..).
static const char *const kDigitAtlasNames[60] = {
    "num_score_0", "num_score_1", "num_score_2", "num_score_3", "num_score_4",
    "num_score_5", "num_score_6", "num_score_7", "num_score_8", "num_score_9",   // [0..9]
    "num_points0", "num_points1", "num_points2", "num_points3", "num_points4",
    "num_points5", "num_points6", "num_points7", "num_points8", "num_points9",   // [10..19]
    "num_jk_dif_0", "num_jk_dif_1", "num_jk_dif_2", "num_jk_dif_3", "num_jk_dif_4",
    "num_jk_dif_5", "num_jk_dif_6", "num_jk_dif_7", "num_jk_dif_8", "num_jk_dif_9", // [20..29]
    "num_green_0", "num_green_1", "num_green_2", "num_green_3", "num_green_4",
    "num_green_5", "num_green_6", "num_green_7", "num_green_8", "num_green_9",     // [30..39]
    "num_yellow_0", "num_yellow_1", "num_yellow_2", "num_yellow_3", "num_yellow_4",
    "num_yellow_5", "num_yellow_6", "num_yellow_7", "num_yellow_8", "num_yellow_9", // [40..49]
    "num_pink_0", "num_pink_1", "num_pink_2", "num_pink_3", "num_pink_4",
    "num_pink_5", "num_pink_6", "num_pink_7", "num_pink_8", "num_pink_9"};         // [50..59]
// The 2 badge/arrow atlases -> m_arrowTex[2] (@ DAT_00131838), loaded as "<name>.png".
static const char *const kArrowNames[2] = {"circle", "vie_cmn_warning@2x"};
// The 5 touch/select SE names -> m_seId[5] (@ PTR_cf_v18_00131840), loaded as "<name>.m4a".
static const char *const kSeNames[5] = {"v18", "v19", "v20", "v11", "se06_nya"};

// Ghidra: musicSelTaskSetup (FUN_000370f0) — state-0 scene build. Resolves the screen
// metrics, lays out the per-platform button rects, loads the music-select Aep group and
// constructs its scene + intro AepLyrCtrl layers, resolves every layer / frame / user
// animation handle, uploads the score / points / rank digit textures, loads the touch SEs +
// preview BGM, and sets the tutorial / badge flags. @ 0x370f0
void MainTask::setup() {
    neAppEventCenter::shared().setGuestNoSaveMode(false);   // normal entry: results are saved
    AudioManager *audio = [AudioManager sharedManager];

    m_aep = &AepManager::shared();
    m_screenWidth = (int)AepManager::shared().screenWidth();
    m_screenHeight = (int)AepManager::shared().screenHeight();
    m_uiScale = (int)neSceneManager::screenScale();
    m_isPadDisplay = neSceneManager::isPadDisplay() ? 1 : 0;
    m_columnStride = m_isPadDisplay ? 9 : 6;   // +0xa74 cells per column

    // ---- per-platform button-rect layout table (m_layoutRects + base) ----
    const int displayType = (int)[[AppDelegate appDelegate] displayType];
    if (!m_isPadDisplay) {
        int baseY, rectSort, rectDiff;   // iVar16 / iVar13 (+0xa10) / iVar14 (+0xa24)
        if (displayType == 2) {          // tall (notch/1136) phone
            baseY = 0xaa;
            rectSort = 0x311;
            rectDiff = 0x3c6;
            m_layoutBaseX = 0x6a;        // +0xa84
            m_layoutBaseY = 0xaa;        // +0xa88
        } else {
            baseY = m_layoutBaseY;               // 0
            rectDiff = m_layoutBaseX + 0x35c;    // 0x35c
            rectSort = m_layoutBaseX + 0x2a7;    // 0x2a7
        }
        memcpy(m_layoutRects, kPhoneLayoutRects, sizeof(m_layoutRects));
        const int scoreScaleH = baseY + 899;     // the 4 score-scale rows share this height
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

    // ---- load the music-select Aep group (3) + resolve its BG layer handles ----
    m_aep->loadAepData(3, m_aep->baseDir(),
                       m_isPadDisplay ? "music_select_ipad" : "music_select", true);
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
        // Tall-phone/pad nudge: park each scene layer at y=0, z=0x6a (Ghidra: the +0x18/+0x1c
        // stores). setRouletteAnchor performs exactly that (m_y = 0, raw z = value).
        for (int i = 0; i < 4; i++) {
            m_layers[i]->setRouletteAnchor(0x6a);
        }
        introNames = kIntroNamesTall;
    } else {
        m_layoutBaseX = 0;               // +0xa84 re-zeroed for the short-phone branch
        introNames = kIntroNamesShort;
    }
    for (int i = 0; i < 2; i++) {
        m_introLayers[i] = new AepLyrCtrl();
        m_introLayers[i]->init(3, introNames[i], this, kIntroOrder[i]);
    }

    // ---- resolve the frame / user animation handles into their named arrays ----
    for (int i = 0; i < 24; i++) m_frmNo[i]        = m_aep->getFrameNo(3, kFrmNames[i]);
    for (int i = 0; i < 3;  i++) m_starFrmNo[i]    = m_aep->getFrameNo(3, kStarFrmNames[i]);
    for (int i = 0; i < 7;  i++) m_musicRankFrmNo[i] = m_aep->getFrameNo(3, kMusicRankFrmNames[i]);
    for (int i = 0; i < 7;  i++) m_diffRankFrmNo[i] = m_aep->getFrameNo(3, kDiffRankFrmNames[i]);
    for (int i = 0; i < 3;  i++) m_jacketTipFrmNo[i] = m_aep->getFrameNo(3, kJacketTipNames[i]);
    for (int i = 0; i < 22; i++) m_elemUsrNo[i]    = m_aep->getUserNo(3, kElemUsrNames[i]);
    for (int i = 0; i < 6;  i++) m_scoreDigitUsrNo[i] = m_aep->getUserNo(3, kScoreDigitUsrNames[i]);
    for (int i = 0; i < 3;  i++) m_diffBlackUsrNo[i] = m_aep->getUserNo(3, kDiffBlackUsrNames[i]);
    for (int i = 0; i < 9;  i++) m_placeDigitUsrNo[i] = m_aep->getUserNo(3, kPlaceDigitUsrNames[i]);
    for (int i = 0; i < 3;  i++) m_jacketTipUsrNo[i] = m_aep->getUserNo(3, kJacketTipNames[i]);

    // ---- upload the 60 score / points / rank digit-atlas textures ----
    for (int i = 0; i < 60; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_digitTex[i] = tex;
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kDigitAtlasNames[i]) ofType:@"png"];
        tex->load(path.UTF8String);
    }

    rebuildList();   // musicSelUpdate — build the initial sorted list + column state

    // ---- the 2 badge/arrow atlases ----
    for (int i = 0; i < 2; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_arrowTex[i] = tex;
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kArrowNames[i]) ofType:@"png"];
        tex->load(path.UTF8String);
    }

    // Install the per-frame scene draw callback for group 3 (Ghidra: setAepCallbacks).
    m_aep->setGroupDrawCallback(3, reinterpret_cast<AepGroupDrawFn>(&MusicSelAepDraw), this);

    // ---- load the 5 touch/select SEs (group 1) + the preview BGM ----
    for (int i = 0; i < 5; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:@(kSeNames[i]) ofType:@"m4a"];
        RSND_SOURCE_ID sid = [audio loadSe:sePath isLoop:NO callName:nil group:1];
        m_seId[i] = (int)sid;   // +0x8c4
        m_seInst[i] = -1;       // +0x8d8 idle
    }
    NSString *bgmPath = [[AppDelegate appAppSupportDirectory]
        stringByAppendingPathComponent:@"bgm02_musicsel.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];

    // First-play tutorial is offered until the player has cleared it once.
    m_tutorialBadge = [UserSettingData isTutorialPlayed] ? 0 : 1;
    m_sel.tutorialOffered = m_tutorialBadge;
    m_overScoreDict = nil;   // +0xa98
}

// Ghidra: mainTaskUpdate (FUN_00034f4c) — per-frame list scroll physics. Reads the render
// manager's active touch, drives the horizontal list drag/fling, and on a column change
// streams the newly-visible jacket column (musicSelLoadColumnPrev/Next). This is NOT the
// re-sort routine: that is rebuildList() (musicSelUpdate FUN_0003835c), a separate function.
void MainTask::updateList() {
    // @ 0x34f4c
    neSceneManager::shared();                    // NESceneManager_shared — force the singleton
    neGraphics &gfx = neGraphics::shared();      // NEGraphics_shared

    // Clear the current-frame drag scratch (rewritten below only if a touch is present).
    m_touchX = -1;                               // +0xa78
    m_touchY = -1;                               // +0xa7c
    m_touchReleased = 0;                         // +0xa80

    // ---- a drag is in progress: follow / sample the finger ----------------------------
    if (m_selectedCell >= 0) {
        const neTouchPoint *t = gfx.findTouchById(m_selectedCell);   // NEGraphics_findTouchById
        if (t == nullptr) {
            // Finger vanished (lost the touch): drop the drag; the settle switch runs next frame.
            m_selectedCell = -1;
            return;
        }

        const int startX = t->startX;            // +0x04 drag anchor
        m_touchX = t->x;                          // +0xa78 current point
        m_touchY = t->y;                          // +0xa7c
        const int curX = m_touchX;

        // Push the ring one slot toward "older"; index 0 receives the new sample. The two
        // arrays are shifted together (the binary walks them with a single pointer 40 bytes
        // apart — i.e. m_dragSampleX[i] is m_dragSampleTime[i] + 10 ints).
        for (int i = 9; i > 0; i--) {
            m_dragSampleTime[i] = m_dragSampleTime[i - 1];
            m_dragSampleX[i]    = m_dragSampleX[i - 1];
        }
        const int now = (int)getTimeMillis();
        m_dragSampleTime[0] = now;
        m_dragSampleX[0]    = curX;

        // Live drag: the offset tracks the finger delta, sqrt-damped at the list ends.
        const int delta = curX - startX;
        const bool atRightEnd = (delta > 0 && m_columnIndex < 1);                    // first column
        const bool atLeftEnd  = (delta < 0 && m_columnIndex >= m_columnCount - 1);   // last column
        if (atRightEnd || atLeftEnd) {
            const int a = (delta < 0) ? -delta : delta;   // |delta|
            // Rubber-band resistance at the ends: FixedToFP(|delta|) -> -SQRT -> +0.5 -> FPToFixed.
            // The sqrt-damped SHAPE is exact; the 16.16 Q-format scaling around the sqrt (the
            // VCVT #fbits pixel conversions) is the documented pixel-math seam that sets the true
            // sign/magnitude — modelled here as identity.
            const float damped = 0.5f - std::sqrt((float)a);
            m_scrollOffset = (int)damped;
        } else {
            m_scrollOffset = delta;
        }

        // Fling velocity (px/ms) from the oldest still-populated sample.
        float velocity = 0.0f;
        {
            float dTime = 0.0f;
            for (int i = 9; i >= 0; i--) {
                if (m_dragSampleTime[i] != 0) {
                    dTime    = (float)(now - m_dragSampleTime[i]);
                    velocity = (float)(curX - m_dragSampleX[i]);
                    break;
                }
            }
            velocity = velocity / dTime;   // dPos / dTime (dTime == 0 only on the seed frame)
        }
        m_scrollVelocity = velocity;

        if (t->released) {                        // +0x2d finger lifted this frame
            m_touchReleased = 1;                  // +0xa80
            if (curX < startX) {
                // Dragged left -> advance toward the NEXT column, if a fast-enough fling and not last.
                if (m_columnIndex < m_columnCount - 1 && velocity < -kFlingThreshold) {
                    neEngine::playSystemSe(4);    // SysSePlayIntoSlot(...,4) — confirm SE on a real fling
                    m_scrollState = kScrollFlingNext;
                } else {
                    m_scrollVelocity = 0.0f;
                    m_scrollState = kScrollSnapLeft;
                }
            } else if (startX < curX) {
                // Dragged right -> return toward the PREVIOUS column, if a fast-enough fling and not first.
                if (m_columnIndex > 0 && velocity > kFlingThreshold) {
                    neEngine::playSystemSe(4);    // confirm SE on a real fling
                    m_scrollState = kScrollFlingPrev;
                } else {
                    m_scrollVelocity = 0.0f;
                    m_scrollState = kScrollSnapRight;
                }
            } else {
                // Released with no net movement: snap straight back to the current column.
                m_scrollOffset = 0;
                m_scrollVelocity = 0.0f;
                m_scrollState = kScrollIdle;
            }
        }
        return;   // a live drag frame never runs the settle switch below
    }

    // ---- no drag and settled: look for a fresh finger-down to start a new drag ---------
    if (m_scrollState == kScrollIdle) {
        for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {   // NEGraphics_activeTouchCount
            const neTouchPoint *t = gfx.touchAt(i);                 // NEGraphics_touchAt
            if (t->valid) {                       // +0x2c began-this-frame marker
                // Seed the sample ring with this touch and latch it as the active drag.
                for (int k = 0; k < 10; k++) {
                    m_dragSampleTime[k] = 0;
                    m_dragSampleX[k]    = 0;
                }
                m_selectedCell = t->id;           // +0x928 drag touch id
                m_dragSampleTime[0] = (int)getTimeMillis();
                m_scrollVelocity = 0.0f;
                m_dragSampleX[0] = t->x;
                break;
            }
        }
    }

    // ---- settle integration: ease the offset toward the target column or back to 0 -----
    // The column width the offset is measured against is m_screenWidth (@ +0xa64) — one
    // column is one screen on phone.
    const int columnWidth = m_screenWidth;
    switch (m_scrollState) {
    case kScrollFlingPrev: {
        float vel = m_scrollVelocity;
        if (m_scrollOffset < columnWidth / 2) {
            // First half: accelerate up to the max speed.
            vel = vel + kSpringAccel;                       // +0.2
            if (vel > kMaxVelocity) vel = kMaxVelocity;     // min(vel, 8.0)
        } else {
            // Past halfway: ease off (friction) but keep the minimum completing speed.
            vel = vel - kFrictionAccel;                     // -0.1
            if (vel < kMinVelocity) vel = kMinVelocity;     // max(1.0, vel)
        }
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if (m_scrollOffset >= columnWidth) {
            // Column change committed: reset physics and step to the previous column.
            m_scrollOffset = 0;
            m_scrollVelocity = 0.0f;
            m_scrollState = kScrollIdle;
            m_columnIndex = m_columnIndex - 1;
            if (m_columnIndex < 0) m_columnIndex = 0;
            // Rotate the three row latches toward "prev" and mark the newly-freed row idle.
            m_nextColLatch = m_curColLatch;
            m_curColLatch  = m_prevColLatch;
            m_prevColLatch = 0xff;
            const int row = findFreeColumnRow();
            if (m_columnIndex > 0) {
                loadColumnPrev(row);
                return;
            }
        }
        break;
    }
    case kScrollFlingNext: {
        float vel = m_scrollVelocity;
        if (m_scrollOffset > -(columnWidth / 2)) {
            vel = vel - kSpringAccel;                        // -0.2
            if (vel < -kMaxVelocity) vel = -kMaxVelocity;    // max(-8.0, vel)
        } else {
            vel = vel + kFrictionAccel;                      // +0.1
            if (vel > -kMinVelocity) vel = -kMinVelocity;    // min(-1.0, vel)
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
            m_curColLatch  = m_nextColLatch;
            m_nextColLatch = 0xff;
            const int row = findFreeColumnRow();
            if (m_columnIndex < m_columnCount - 1) {
                loadColumnNext(row);
                return;
            }
        }
        break;
    }
    case kScrollSnapRight: {
        float vel = m_scrollVelocity - kFrictionAccel;       // -0.1
        if (vel < -kMinVelocity) vel = -kMinVelocity;         // max(-1.0, vel)
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if ((unsigned)m_scrollOffset < 0x80000000u) break;    // still >= 0: keep animating
        m_scrollOffset = 0;                                   // crossed below 0: settled
        m_scrollVelocity = 0.0f;
        m_scrollState = kScrollIdle;
        break;
    }
    case kScrollSnapLeft: {
        float vel = m_scrollVelocity + kFrictionAccel;        // +0.1
        if (vel > kMinVelocity) vel = kMinVelocity;           // min(1.0, vel)
        m_scrollVelocity = vel;
        m_scrollOffset = (int)((float)m_scrollOffset + vel * kFrameStepMs);
        if (m_scrollOffset < 0) break;                        // still negative: keep animating
        m_scrollOffset = 0;                                   // reached 0: settled
        m_scrollVelocity = 0.0f;
        m_scrollState = kScrollIdle;
        break;
    }
    default:
        break;
    }
}

// De-inlined from updateList (the identical block in both column-commit paths): scan the three
// candidate jacket rows (0, m_columnStride, 2*m_columnStride) and return the first one not held
// by a per-column row latch, so the committed column change streams into a free row. @ 0x34f4c
int MainTask::findFreeColumnRow() const {
    const int stride = m_columnStride;   // +0xa74
    int row = 0;
    if (stride >= 1) {
        const uint8_t latch[3] = { m_prevColLatch, m_curColLatch, m_nextColLatch };
        for (;;) {
            int k = 0;
            while (k < 3) {
                if (row == latch[k]) break;   // this row is currently streaming -> in use
                k++;
            }
            if (k == 3) break;                // no latch holds it: free row found
            row += stride;
            if (row >= stride * 3) break;     // all three rows busy
        }
    }
    return row;
}

// Ghidra: musicSelCleanup (FUN_0003cfb0) — release the previous sorted list and clear all 27
// jacket cells before a re-sort. Frees each cell's uploaded texture (+0xc), bundled image
// data (+0x8) and truncated-name string (+0x10), then resets the three per-column row latches
// (+0x8c0/+0x8c1/+0x8c2) and the current column back to 0. Called at the top of rebuildList().
// @ 0x3cfb0
void MainTask::cleanup() {
    if (m_musicList != nil) {
        CFBridgingRelease((__bridge CFTypeRef)m_musicList);   // Ghidra: [m_musicList release]
        m_musicList = nil;
    }
    for (MusicSelCell &cell : m_cells) {
        if (cell.texture != nullptr) {
            delete cell.texture;                              // vtable[1] dtor on the texture
            cell.texture = nullptr;
        }
        if (cell.imageData != nil) {
            cell.imageData = nil;                             // ARC releases the bundled PNG data
        }
        if (cell.name != nil) {
            cell.name = nil;                                  // ARC releases the truncated name
        }
    }
    // Reset the three packed per-column row latches to the 0xff "idle" sentinel and the current
    // column to 0 (the binary's 0xffff @ +0x8c0 / 0xff @ +0x8c2 stores cover all three bytes).
    m_prevColLatch = 0xff;
    m_curColLatch = 0xff;
    m_nextColLatch = 0xff;
    m_columnIndex = 0;
}

// Ghidra: musicSelUpdate (FUN_0003835c) — re-sort / rebuild the music-select list. Distinct
// from updateList() (per-frame scroll physics, FUN_00034f4c): this runs once after the sort
// order changes (SortSelect / Recommend close). It re-reads UserSettingData musicSort, re-sorts
// the MusicManager song array into m_musicList, recomputes the column geometry, streams the
// current column's jacket cells + score rows, (re)kicks the background jacket loader, and
// primes the adjacent columns. @ 0x3835c
void MainTask::rebuildList() {
    neAppEventCenter::shared();   // force the event center (current-song id) live
    cleanup();                    // release the old list + clear the 27 cells (@ 0x3cfb0)

    NSArray *music = [[MusicManager getInstance] getMusicDataArray];
    short sort = [UserSettingData musicSort];
    m_appliedSort = sort;         // remember the sort we are applying (read by MusicSelAppliedSort)

    // ---- 1. sort the song array per the applied order (retained into m_musicList) ----
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
        // "Played" sort: order by music id, then partition into songs that have NO score
        // record vs. songs that do, and concatenate un-scored-first then scored (Ghidra: the
        // local_140 ++ local_13c order). A song counts as scored if any of its three
        // difficulties has a stored score.
        NSMutableArray *byId =
            [[music sortedArrayUsingSelector:@selector(compareMusicID:)] mutableCopy];
        NSMutableArray *unplayed = [NSMutableArray array];
        NSMutableArray *played = [NSMutableArray array];
        for (id song in byId) {
            unsigned musicId = (unsigned)[song MusicID];
            bool hasScore = false;
            for (int diff = 0; diff < 3; diff++) {
                // A song counts as scored if any difficulty has a stored play count (Ghidra
                // musicSelUpdate @ 0x3835c: `if (0 < outPlayCnt) break;`).
                int score = 0; short rank = 0; int playCnt = 0;
                bool fullCombo = false, perfect = false;
                fetchScoreDataForMusic(&neAppEventCenter::shared(), &score, &rank, &playCnt,
                                       &fullCombo, &perfect, musicId, diff);
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
        sorted = m_musicList;   // unknown sort: keep the existing (already-cleared) list
        break;
    }
    if ((unsigned short)sort <= 5) {
        m_musicList = (__bridge id)CFBridgingRetain(sorted);   // Ghidra: [sorted retain]
    }

    // ---- 2. column geometry ----
    m_songCount = (int)[m_musicList count];
    const int stride = m_columnStride;                 // cells per column (6 phone / 9 pad)
    m_columnIndex = 0;
    m_columnCount = (m_songCount - 1) / stride + 1;

    // ---- 3. land the current column on the app-event-center's current song ----
    // Ghidra compares [song MusicID] against g_pNeAppEventCenter (the event center's current
    // music id). The exact global is a seam; model it via the reconstructed accessor.
    const int currentId = neAppEventCenter::shared().lastMusic();   // g_pNeAppEventCenter (seam)
    for (int i = 0; i < m_songCount; i++) {
        id song = [m_musicList objectAtIndexedSubscript:i];
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
            id song = [m_musicList objectAtIndexedSubscript:songIdx];
            unsigned musicId = (unsigned)[song MusicID];
            NSData *artwork = [song artwork2xData];
            MusicSelCell &cell = m_cells[slot];

            // Upload the @2x jacket art straight into a fresh texture.
            neTextureForiOS *tex = new neTextureForiOS();   // neTextureForiOS_ctor
            cell.texture = tex;
            tex->loadFromImageData((__bridge const void *)artwork);   // neTextureLoadSingle

            // Cache a (possibly ellipsis-truncated) copy of the song name for the cell label.
            NSString *name = [[song musicName] copy];
            cell.name = name;
            int cut = findCharIndexForColumn(name, nameWidth);
            if (cut > 0) {
                cell.name = [[name substringToIndex:cut] stringByAppendingString:@"…"];
            }

            loadCellScoreRows(cell, musicId);   // 3-difficulty score rows into cell detail

            cell.songIndex = slot;   // running cell index within the column
            cell.loadState = 3;      // ready
            cell.imageData = nil;    // no pending bundled image (art already uploaded)
            songIdx++;
        }
    }

    // ---- 5. (re)kick the background jacket loader exactly once ----
    // The current-column widget-row latch is reset so the current column draws from cell row 0.
    m_curColLatch = 0;
    if (!m_cellLoaderStarted) {
        m_loaderCursor = 0;
        m_cellSem = dispatch_semaphore_create(1);
        MainTask *self = this;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            self->backgroundCellLoader();   // Ghidra: block invoke @ 0x3d040 -> 0x3d048
        });
        m_cellLoaderStarted = 1;
    }

    // ---- 6. prime the adjacent columns' jacket rows ----
    int row = stride;   // next column fills widget rows [stride, 2*stride)
    if (m_columnIndex + 1 < m_columnCount) {
        loadColumnNext(row);
        row += stride;   // prev column fills widget rows [2*stride, 3*stride)
    }
    if (m_columnIndex - 1 >= 0) {
        loadColumnPrev(row);
    }
}

// De-inlined from rebuildList (@ 0x3835c): read the three difficulty score rows for `musicId`
// into the jacket cell's detail block. In the binary each iteration calls fetchScoreDataForMusic
// with the (musicId, difficulty) pair and writes the resulting score / medal bytes into the
// cell's detail region (+0x14.. from the cell base).
void MainTask::loadCellScoreRows(MusicSelCell &cell, unsigned musicId) {
    for (int diff = 0; diff < 3; diff++) {
        // Ghidra musicSelUpdate @ 0x3835c writes each difficulty's fetchScoreDataForMusic result
        // straight into the cell's score-row block (score/rank/playCnt/fullCombo/perfect).
        bool fullCombo = false, perfect = false;
        fetchScoreDataForMusic(&neAppEventCenter::shared(),
                               &cell.scores.score[diff], &cell.scores.rank[diff],
                               &cell.scores.playCnt[diff], &fullCombo, &perfect,
                               musicId, diff);
        cell.scores.fullCombo[diff] = fullCombo ? 1 : 0;
        cell.scores.perfect[diff] = perfect ? 1 : 0;
    }
}

// @ 0x3d048  (Ghidra: resultTaskSetup — mislabeled by binary proximity; it is the music-select
// background jacket loader, the dispatch_async body kicked off once by rebuildList). Runs on a
// global-queue background thread: round-robins the 27 jacket cells under m_cellSem, and for each
// cell still marked "queued" (loadState 1) decodes the song's artwork, reads its three difficulty
// score rows (on the thread-safe SUB managed-object context), truncates the song name to the
// platform column width, and marks the cell "ready" (loadState 3). Exits when m_loaderCursor is set.
void MainTask::backgroundCellLoader() {
    if (m_loaderCursor != 0) {
        m_loaderCursor = 2;
        return;
    }
    const int maxNameChars = m_isPadDisplay ? 15 : 21;   // phone 0x15 / iPad 0xf
    unsigned i = 0;
    do {
        [NSThread sleepForTimeInterval:0.3];             // DAT_0003d368 == 0.3
        dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
        if (i > 26) {
            i = 0;                                       // wrap the 27-cell ring
        }
        MusicSelCell &cell = m_cells[i];
        if (cell.loadState == 1) {                       // queued for load
            const int songIndex = cell.songIndex;
            cell.loadState = 2;                          // processing
            dispatch_semaphore_signal(m_cellSem);

            id md = [m_musicList objectAtIndexedSubscript:songIndex];
            const int musicId = (int)[md MusicID];
            id artwork;
            @autoreleasepool {
                artwork = [md artwork2xData];            // decode off the shared array
            }

            dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
            if (cell.loadState != 1) {                   // not re-queued while we worked
                cell.imageData = artwork;
                dispatch_semaphore_signal(m_cellSem);

                // Score rows come off the background sub-context (thread-safe Core Data stack).
                NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContextSub];
                for (int diff = 0; diff < 3; diff++) {
                    ScoreData *rec = [ScoreData getScoreData:musicId inManagedObjectContext:moc];
                    bool fullCombo = false, perfect = false;
                    readScoreDataFields(rec, &cell.scores.score[diff], &cell.scores.rank[diff],
                                        &cell.scores.playCnt[diff], &fullCombo, &perfect, rec, diff);
                    cell.scores.fullCombo[diff] = fullCombo ? 1 : 0;
                    cell.scores.perfect[diff] = perfect ? 1 : 0;
                }

                NSString *name = [[md musicName] copy];
                const int cut = findCharIndexForColumn(name, maxNameChars);
                if (cut > 0) {
                    name = [[name substringToIndex:cut] stringByAppendingString:@"…"];
                }
                dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
                if (cell.loadState == 2) {               // still ours -> publish the result
                    cell.name = name;
                    cell.loadState = 3;                  // ready
                }
            }
            dispatch_semaphore_signal(m_cellSem);
        } else {
            dispatch_semaphore_signal(m_cellSem);
        }
        i++;
    } while (m_loaderCursor == 0);
    m_loaderCursor = 2;                                  // acknowledge shutdown
}

// Ghidra: musicSelAllCellsReady (FUN_00037f38) — true when every jacket cell has finished
// loading (state 0 empty or 3 ready). Guarded by the cell-array semaphore.
bool MainTask::allCellsReady() {
    dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
    bool ready = true;
    for (int i = 0; i < 27; i++) {
        int st = m_cells[i].loadState;
        if (st != 0 && st != 3) {   // still decoding / uploading
            ready = false;
            break;
        }
    }
    dispatch_semaphore_signal(m_cellSem);
    return ready;
}

// Ghidra: musicSelUpdateHighlight (FUN_000355fc) — per-frame highlight/badge draw. Skipped
// once the scene is being torn down (m_suppressDraw). Pulses the recommend / over-score
// badges, redraws the four difficulty frames + the tutorial badge, and (for a multi-column
// list) draws the "current/total" column counter.
void MainTask::updateHighlight() {
    if (m_suppressDraw) {
        return;
    }
    m_highlightAnim = (m_highlightAnim + 2) % 0x97;   // 0..0x96 triangle phase

    // Triangle-wave alpha for the pulsing badges (peak at the mid of the phase).
    auto pulseAlpha = [](int phase) -> int {
        if (phase <= 0x31) return 100;
        return phase < 100 ? phase * -2 + 200 : phase * 2 + -200;
    };
    // The Aep frame handles and the badge/frame screen positions the draw reads are ALREADY
    // named members: the frames are slots of the setup()-filled getFrameNo table m_frmNo[24]
    // (m_frmNo[6]=BT_SETTING, [8]=BT_SORT, [9]=BT_OSSUME/recommend, [10]=BT_EMULATE/over-score,
    // [16]=BT_TUTORIAL), and the x/y positions are slots of the per-platform layout table
    // m_layoutRects[55] (+0x988), which setup() populates via the kPhone/kPadLayoutRects memcpy
    // plus the runtime score-baseline / counter-y patches. Named-index constants below give the
    // draw roles instead of magic indices; the raw pixel constants are setup()'s layout seam.
    // (The decompile's "difficulty frames" are really the four state-2 top-row buttons.)
    enum {                                   // m_layoutRects slots this draw samples
        kLR_SettingX = 6,  kLR_SettingY = 7,       // BT_SETTING frame       (+0x9a0/+0x9a4)
        kLR_SortX    = 10, kLR_SortY    = 11,      // BT_SORT frame          (+0x9b0/+0x9b4)
        kLR_OssumeX  = 14, kLR_OssumeY  = 15,      // BT_OSSUME (recommend)  (+0x9c0/+0x9c4)
        kLR_EmulateX = 18, kLR_EmulateY = 19,      // BT_EMULATE (over-score)(+0x9d0/+0x9d4)
        kLR_TutorialX = 26, kLR_TutorialY = 27,    // BT_TUTORIAL badge      (+0x9f0/+0x9f4)
        kLR_CounterX = 30, kLR_CounterY = 31, kLR_CounterStyle = 32,  // counter (+0xa00/04/08)
        kLR_ScreenW  = 52, kLR_ScreenH  = 53,      // badge blit screen bounds (+0xa58/+0xa5c)
    };
    // 0x42c80000 == 100.0f scale, 0xffffff == white, 0x20 == blend mode, 10 == OT priority.
    const int kScale100 = 0x42c80000;

    // Pulsing new-recommend badge (m_arrowTex[1]) over the recommend button.
    if (m_recommendBadge) {
        const int a = pulseAlpha(m_highlightAnim);
        neTextureForiOS_draw(m_aep, m_arrowTex[1], 0, 0,
                             m_layoutRects[kLR_ScreenW], m_layoutRects[kLR_ScreenH],
                             m_layoutRects[kLR_OssumeX] - 2, m_layoutRects[kLR_OssumeY] - 10,
                             100, 100, 0, 0, 0, a, 100 - a, 0x20, 0xffffff, 0, 10, 1);
    }
    // Pulsing over-score badge (m_arrowTex[1]) over the over-score-log button.
    if (m_overScoreBadge) {
        const int a = pulseAlpha(m_highlightAnim);
        neTextureForiOS_draw(m_aep, m_arrowTex[1], 0, 0,
                             m_layoutRects[kLR_ScreenW], m_layoutRects[kLR_ScreenH],
                             m_layoutRects[kLR_EmulateX] - 2, m_layoutRects[kLR_EmulateY] - 10,
                             100, 100, 0, 0, 0, a, 100 - a, 0x20, 0xffffff, 0, 10, 1);
    }

    // The four state-2 top-row button frames (settings / sort / recommend / over-score-log).
    drawAepFrameEx(m_aep, m_frmNo[6],  m_layoutRects[kLR_SettingX], m_layoutRects[kLR_SettingY],
                   kScale100, kScale100, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 10, 1);
    drawAepFrameEx(m_aep, m_frmNo[8],  m_layoutRects[kLR_SortX],    m_layoutRects[kLR_SortY],
                   kScale100, kScale100, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 10, 1);
    drawAepFrameEx(m_aep, m_frmNo[9],  m_layoutRects[kLR_OssumeX],  m_layoutRects[kLR_OssumeY],
                   kScale100, kScale100, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 10, 1);
    drawAepFrameEx(m_aep, m_frmNo[10], m_layoutRects[kLR_EmulateX], m_layoutRects[kLR_EmulateY],
                   kScale100, kScale100, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 10, 1);

    // First-play tutorial badge (BT_TUTORIAL).
    if (m_tutorialBadge) {
        drawAepFrameEx(m_aep, m_frmNo[16], m_layoutRects[kLR_TutorialX], m_layoutRects[kLR_TutorialY],
                       kScale100, kScale100, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 10, 1);
    }

    // Multi-column list -> the "current/total" column counter text.
    if (m_columnCount > 1) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%d/%d", m_columnIndex + 1, m_columnCount);
        drawAepManagerText(m_aep, buf, m_layoutRects[kLR_CounterStyle],
                           m_layoutRects[kLR_CounterX], m_layoutRects[kLR_CounterY],
                           2, 100, 0 /* &DAT_00181818 default text-style seam */, 0xc);
    }
}

// Ghidra: musicSelStopAndSave (FUN_00038008) — state-0x10 teardown. Releases the SEs and
// every layer / texture, saves the finished-play music id + result sheet (unless in guest
// no-save mode), tears down the scene, and kills this task (spawning the menu hub if no
// sub-task was queued).
void MainTask::stopAndSave() {
    AudioManager *audio = [AudioManager sharedManager];

    for (int i = 0; i < 5; i++) {
        [audio releaseSe:nil resourceId:0];   // release the 5 loaded select SEs
    }
    neSceneManager::shared().releaseSystemSe();
    [audio cleanupSe];
    neSceneManager::shared().loadSystemSe();

    // Delete the digit / name / artist textures.
    for (auto &tex : m_digitTex) {
        if (tex) { delete tex; tex = nullptr; }
    }
    for (auto &tex : m_arrowTex) {
        if (tex) { delete tex; tex = nullptr; }
    }
    if (m_nameTex) { delete m_nameTex; m_nameTex = nullptr; }
    if (m_artistTex) { delete m_artistTex; m_artistTex = nullptr; }

    // Unlink + delete the scene layers.
    for (auto &layer : m_layers) {
        if (layer) { layer->unlink(); delete layer; layer = nullptr; }
    }
    for (auto &layer : m_introLayers) {
        if (layer) { layer->unlink(); delete layer; layer = nullptr; }
    }
    m_aep->unloadGroup(3);   // releaseAepTexture(aep, 3)

    // Record the finished play's music id + result sheet for the result screen to read, unless
    // this is a no-save teardown. When guest-mode is on the result record is zeroed instead of
    // persisted (setLastMusic == g_pNeAppEventCenter result music id, setLastSheet == g_wResultSheet).
    if (!m_noSaveMode) {
        neAppEventCenter &ec = neAppEventCenter::shared();
        id info = [m_musicList objectAtIndexedSubscript:m_chosenIndex];
        if (!ec.guestNoSaveMode()) {
            ec.setLastMusic((int)[info MusicID]);
            ec.setLastSheet((int)m_resultSheet);
            [UserSettingData saveSettingData];
        } else {
            ec.setLastMusic(0);
            ec.setLastSheet(0);
        }
    }

    m_cellSem = nullptr;                     // Ghidra: _dispatch_release (ARC releases it here)
    m_killed = true;                         // reap this task on the next scheduler pass
    if (m_spawnedTask == nullptr) {
        m_spawnedTask = MenuCreateTask();    // no sub-task queued -> back to the menu hub
    }
    m_spawnedTask->setPriority(3);
    m_suppressDraw = 1;
    m_overScoreDict = nil;                   // ARC releases the over-score dictionary
}

// Ghidra: musicSelUpdateInfoPanel (FUN_00037c88) — build the cached recommend + over-score
// "touched" state (mode 1 only). Sets the new-recommend badge if a fresher recommend exists
// than the last viewed one, and populates the over-score touched dictionary (m_overScoreDict).
void MainTask::updateInfoPanel(int mode) {
    if (mode != 1) {
        return;
    }
    DownloadMain *dl = [DownloadMain getInstance];
    NSArray *recommend = [dl recommendDataArray];
    if ([recommend count] != 0) {
        // Show the "new recommend" badge unless the player has already viewed something at
        // least as fresh as the newest entry. The rows are NSValue-boxed RecommendData
        // (DownloadMain); recommend[0]'s updateDate is compared against the stored view time.
        NSString *lastViewed = [UserSettingData lastRecommendViewTimeString];
        m_recommendBadge = 1;
        RecommendData newest;
        [(NSValue *)[recommend objectAtIndex:0] getValue:&newest];
        if (lastViewed != nil && newest.updateDate != nil &&
            [lastViewed compare:newest.updateDate] != NSOrderedAscending) {
            m_recommendBadge = 0;   // already viewed something at least this fresh
        }
    }

    NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
    NSArray *overScores = [OverScoreData getAllOverScoreData:moc];
    m_overScoreDict = [NSMutableDictionary dictionary];
    if ([overScores count] != 0) {
        m_overScoreBadge = 1;
        NSMutableDictionary *dict = m_overScoreDict;
        for (id entry in overScores) {
            NSString *key = [[[entry music] MusicID] stringValue];
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
    // The recommend list has now been consumed into the panel — clear the pending-push flag so
    // the throttle doesn't force another immediate refetch.
    neAppEventCenter::shared().setRemoteNotifyPending(false);
}

// ---------------------------------------------------------------------------------------
// Thin C-linkage shims for the not-yet-C++-refactored ObjC callers that still reach these
// routines by their unmangled binary symbol (RecommendViewController / SortSelectViewController
// call musicSelUpdate; DownloadMain calls musicSelUpdateInfoPanel). They forward to the real
// MainTask methods. Prefer importing MainTask.h and calling the method directly; these exist
// only so those units keep linking until they are converted.
extern "C" void musicSelUpdate(MainTask *task) {
    task->rebuildList();   // musicSelUpdate (FUN_0003835c) is the re-sort, not the scroll step
}
extern "C" void musicSelUpdateInfoPanel(MainTask *task, int mode) {
    task->updateInfoPanel(mode);
}

// ---------------------------------------------------------------------------------------
// Column streaming + scene draw callback. All work-area access is through the named
// MainTask / MusicSelCell members (MainTask.h); the jacket cells are m_cells[27].
// ---------------------------------------------------------------------------------------

// Free one streamed cell's GPU/ObjC resources before it is re-pointed (Ghidra: the vtable[1]
// delete on the texture @ +0xc, then release on the ObjC ids @ +0x8/+0x10).
static void releaseCell(MainTask::MusicSelCell &cell) {
    if (cell.texture) {
        delete cell.texture;
        cell.texture = nullptr;
    }
    cell.imageData = nil;   // ARC-released by owner
    cell.name = nil;
}

// @ 0x35448 / @ 0x35520 — shared body of the two column loaders. Streams m_columnStride
// consecutive jacket cells from row `rowBase`, pointing each at the song for the adjacent
// column (`delta` = +1 next / -1 prev), or -1 past the list ends. Guarded by `latch` and the
// cell semaphore. Ghidra: musicSelLoadColumnNext / musicSelLoadColumnPrev (identical but for
// the latch byte + column bound).
void MainTask::loadColumn(int rowBase, int delta, uint8_t &latch) {
    const int col = m_columnIndex;
    dispatch_semaphore_wait(m_cellSem, DISPATCH_TIME_FOREVER);
    const int perRow = m_columnStride;
    if (perRow > 0) {
        for (int i = 0; i < perRow; i++) {
            MusicSelCell &cell = m_cells[rowBase + i];
            const int idx = perRow * (col + delta) + i;
            if (idx < 0 || m_songCount <= idx) {
                cell.songIndex = -1;   // no song for this slot
                cell.loadState = 0;    // empty
            } else {
                cell.songIndex = idx;
                cell.loadState = 1;    // loading (async loader will upload the jacket)
            }
            releaseCell(cell);
        }
    }
    latch = (uint8_t)rowBase;
    dispatch_semaphore_signal(m_cellSem);
}

// @ 0x35448 — stream the column after the current one into row `column`.
void MainTask::loadColumnNext(int column) {
    if (m_nextColLatch == 0xff && m_columnIndex != -2) {   // next-column latch idle
        loadColumn(column, +1, m_nextColLatch);
    }
}

// @ 0x35520 — stream the column before the current one into row `column`. Gated by its own
// latch byte (m_prevColLatch @ +0x8c0), independent of the current-column latch @ +0x8c1 that
// rebuildList clears.
void MainTask::loadColumnPrev(int column) {
    if (m_prevColLatch == 0xff && m_columnIndex != 0) {
        loadColumn(column, -1, m_prevColLatch);
    }
}

// @ 0x2aad4 (inlined in OverScoreLogViewController -endCloseAnimation) — launch a play of the
// chosen song. Shared by the list view controllers (over-score log / recommend) and mirrors the
// in-scene state-4 PLAY handoff (@ 0x35914 case 4). Find `musicId` in m_musicList; on a match,
// stash the selection, pop the menu BGM, fire the confirm SE, spawn the PlayTask and register it
// with the app delegate, then hand off to the play-launch state (0xc). If the song is not
// installed, drive the not-found state (2) and report failure.
bool MainTask::launchPlayForMusicId(int musicId, int sheet) {
    id musicList = m_musicList;
    NSUInteger count = [musicList count];
    for (NSUInteger i = 0; i < count; i++) {
        id info = [musicList objectAtIndexedSubscript:i];
        if ([info MusicID] == musicId) {
            m_chosenIndex = (int)i;
            m_chosenMusicId = musicId;
            m_resultSheet = sheet;
            AudioManager *audio = [AudioManager sharedManager];
            [audio popBgm];
            m_seInst[3] = (int)[audio playSe:nil resourceId:0];
            m_spawnedTask = PlayTaskCreate();
            [[AppDelegate appDelegate] setMainTask:(MainTask *)m_spawnedTask];
            m_state = 0xc;   // -> play-launch handoff (0xc -> 0xd -> 0xe)
            return true;
        }
    }
    m_state = 2;   // not installed
    return false;
}

// @ 0x389fc — musicSelAepDrawCallback. The music-select scene draw callback. This is a
// ~98 KB routine that dispatches on the drawn layer's resolved user number and blits the
// matching scene element. The head (recovered below) draws the three visible song-jacket
// grids — current column (user no @ +0x22c), and the incoming next / previous columns
// (latched via +0x8c1 / +0x8c2) — each a 3-wide grid of cells whose uploaded jacket
// texture (@ cell+0xc) is blitted (or a placeholder frame @ +0x180 when not yet ready),
// with the selection frame @ +0x1a8 over the highlighted cell. The long tail of the
// function (score / difficulty-level / song-name / rank-digit / badge branches, keyed on
// the other resolved user numbers) follows the same per-user-number dispatch and is a
// documented seam here per rule 7 (best-effort: the geometry constants and the remaining
// element blits are not fully transcribed).
void MusicSelAepDraw(unsigned child, int frame, int x, int y, int scaleX, int scaleY,
                     int anchorX, int anchorY, int color, int alpha, short rotation,
                     int blend, int p13, int p14, void *context) {
    (void)frame; (void)p13;
    MainTask *self = static_cast<MainTask *>(context);
    char *pd = reinterpret_cast<char *>(self);
    auto F = [&](int off) -> int { return *reinterpret_cast<int *>(pd + off); };

    // Blit one 3-column jacket grid starting at widget row `rowBase`, offset by `colX`
    // screen columns. Each present cell draws its uploaded texture (or the placeholder
    // frame @ +0x180 while streaming) plus the selection frame @ +0x1a8.
    auto drawJacketGrid = [&](int rowBase, int columnIndex, int extraX) {
        const int perRow = F(0xa74);
        if (rowBase < 0 || perRow <= 0) {
            return;
        }
        int *cell = reinterpret_cast<int *>(pd + rowBase * 0x38 + 0x2d8);
        const int songCount = F(0x8ec);
        for (int i = 0; i < perRow; i++) {
            if (perRow * columnIndex + i >= songCount) {
                break;
            }
            const int idx = cell[0];                 // +0x0 song index
            const bool present = idx >= 0 ? (idx < songCount) : (idx != 0);
            if (present && idx >= 0 && idx <= songCount) {
                const int cellY = F(0x98c) * (i / 3) + y;
                const int cellX = F(0x988) * (i % 3) + x + extraX + F(0x980);
                if (cell[3] == 0) {                  // +0xc no texture yet -> placeholder
                    drawAepFrameEx(&AepManager::shared(), F(0x180), F(0x990) + cellX, cellY,
                                   scaleX, scaleY, rotation, anchorX, anchorY, blend, p14,
                                   0xffffff, 0, p14, 1);
                } else {
                    neTextureForiOS_draw(&AepManager::shared(), *reinterpret_cast<void **>(cell + 3),
                                         0, 0, 0x168, 0x168, F(0x990) + cellX, cellY, scaleX, scaleY,
                                         rotation, anchorX, anchorY, blend, p14, 0xffffff, 0, p14, 1);
                }
                // Selection frame over the cell (@ +0x1a8, +0x994/+0x998 nudge).
                drawAepFrameEx(&AepManager::shared(), F(0x1a8),
                               F(0x994) + (cellX - (anchorX * scaleX) / 100),
                               F(0x998) + (cellY - (anchorY * scaleY) / 100),
                               0x42c80000, 0x42c80000, 0, 0, 0, 100, 0, blend, 0xffffff, 0, p14, 1);
            }
            cell += 0xe;
        }
    };

    if (F(0x22c) == (int)child) {
        // Current column grid. Cache the grid origin (@ +0xa40/+0xa44) for hit-testing.
        *reinterpret_cast<int *>(pd + 0xa40) = x - (anchorX * scaleX) / 100;
        *reinterpret_cast<int *>(pd + 0xa44) = y - (anchorY * scaleY) / 100;
        const int8_t curRow = (int8_t)self->m_curColLatch;
        drawJacketGrid(curRow, F(0x8f0), 0);

        // Incoming next column (m_nextColLatch), shifted one screen width right.
        if (F(0x8f0) < F(0x8f4) - 1) {
            const int8_t nextRow = (int8_t)self->m_nextColLatch;
            drawJacketGrid(nextRow, F(0x8f0) + 1, F(0xa64));
        }
    }
    // ===================== Tail dispatch: every element other than the current-column jacket
    // grid. This callback fires once per named scene element; each `if` below matches the
    // element's resolved user number and blits it. Two regimes follow: (a) list elements that
    // repaint the same visible 3-column cell grid — current / incoming-next / outgoing-prev
    // columns, latched via m_curColLatch / m_nextColLatch / m_prevColLatch; (b) "selected song"
    // elements that draw the highlighted song's score / rank / place / banners. @ 0x389fc
    const int perRow    = F(0xa74);   // m_columnStride  — cells per column
    const int songCount = F(0x8ec);   // m_songCount
    const int col       = F(0x8f0);   // m_columnIndex
    const int colCount  = F(0x8f4);   // m_columnCount
    auto s8 = [](uint8_t b) { return (int)(int8_t)b; };            // signed row-load latch
    auto numDigits = [](int v) { int n = 1; while (v > 9) { n++; v /= 10; } return n; };
    auto pulseAlpha = [](int phase) {                             // triangle-wave badge alpha
        if (phase < 0x32) return 100;
        return phase < 100 ? phase * -2 + 200 : phase * 2 - 200;
    };

    // Common blits (head drawAepFrameEx / neTextureForiOS_draw forms; color/alpha collapse to
    // blend/p14 exactly as the head's drawJacketGrid does).
    auto drawFrame = [&](int frameNo, int fx, int fy) {
        drawAepFrameEx(&AepManager::shared(), frameNo, fx, fy, scaleX, scaleY, rotation,
                       anchorX, anchorY, blend, p14, 0xffffff, 0, p14, 1);
    };
    auto drawFrameAlpha = [&](int frameNo, int fx, int fy, int a) {   // explicit pulse alpha
        drawAepFrameEx(&AepManager::shared(), frameNo, fx, fy, scaleX, scaleY, rotation,
                       anchorX, anchorY, a, 100 - a, blend, 0xffffff, 0, p14, 1);
    };
    auto drawFrameFixed = [&](int frameNo, int fx, int fy, int ax, int ay) {   // 100.0f scale
        drawAepFrameEx(&AepManager::shared(), frameNo, fx, fy, 0x42c80000, 0x42c80000, 0,
                       ax, ay, 100, 0, blend, 0xffffff, 0, p14, 1);
    };
    auto drawTex = [&](void *tex, int w, int h, int tx, int ty) {   // uv (0,0,w,h) at (tx,ty)
        neTextureForiOS_draw(&AepManager::shared(), tex, 0, 0, w, h, tx, ty, scaleX, scaleY,
                             rotation, anchorX, anchorY, blend, p14, 0xffffff, 0, p14, 1);
    };

    // Walk every visible cell of the current / next / prev columns, invoking
    // paint(cell, i, cx0, cy0, listIndex). cx0/cy0 are the cell's top-left BEFORE the per-element
    // pixel nudge (F(0x990)/F(0x99c)); paint returns false to stop the column. The three per-branch
    // count styles in the decompile (absolute-index, div/mod partial, relative cap) all reduce to
    // "stop when the running list index reaches songCount" for the shown columns, so they unify.
    auto forEachGridCell = [&](const std::function<bool(char *, int, int, int, int)> &paint) {
        auto column = [&](int latch, int whichCol, int extraX) {
            if (latch < 0 || perRow <= 0) {
                return;
            }
            char *base = pd + latch * 0x38 + 0x2d8;
            for (int i = 0; i < perRow; i++) {
                const int listIndex = whichCol * perRow + i;
                if (listIndex >= songCount) {
                    break;
                }
                const int cy0 = F(0x98c) * (i / 3) + y;
                const int cx0 = F(0x988) * (i % 3) + x + F(0x980) + extraX;
                if (!paint(base + i * 0x38, i, cx0, cy0, listIndex)) {
                    break;
                }
            }
        };
        column(s8(self->m_curColLatch),  col,     0);
        if (col < colCount - 1) column(s8(self->m_nextColLatch), col + 1,  F(0xa64));
        if (col >= 1)           column(s8(self->m_prevColLatch), col - 1, -F(0xa64));
    };

    // ------------------------------------------------------------------ grid list elements ----

    // Song-name text (per cell) — m_elemUsrNo[10]. Blits each cell's title string (@ cell+0x10).
    if (self->m_elemUsrNo[10] == (int)child) {
        forEachGridCell([&](char *cell, int, int cx0, int cy0, int) {
            id name = *reinterpret_cast<__unsafe_unretained id *>(cell + 0x10);
            if (name) {
                drawAepManagerText(self->m_aep, [name UTF8String], F(0xa60),
                                   cx0 + F(0x990), cy0 + F(0x99c), 1, 100, 0, p14);
            }
            return true;
        });
        return;
    }

    // Difficulty stars (per cell) — m_elemUsrNo[2..4] draw m_starFrmNo[0..2], gated by the cell's
    // per-difficulty rank short (>= 0) OR the _rsvd_91c visibility override.
    auto drawStarGrid = [&](int frameNo, int shortOff) {
        forEachGridCell([&](char *cell, int, int cx0, int cy0, int) {
            const short sv = *reinterpret_cast<short *>(cell + shortOff);
            if (sv >= 0 || *reinterpret_cast<uint8_t *>(pd + 0x91c) != 0) {
                drawFrame(frameNo, cx0 + F(0x990), cy0);
            }
            return true;
        });
    };
    if (self->m_elemUsrNo[2] == (int)child) { drawStarGrid(self->m_starFrmNo[0], 0x2c); return; }
    if (self->m_elemUsrNo[3] == (int)child) { drawStarGrid(self->m_starFrmNo[1], 0x2e); return; }
    if (self->m_elemUsrNo[4] == (int)child) { drawStarGrid(self->m_starFrmNo[2], 0x30); return; }

    // Streaming placeholder frame (per cell) — m_elemUsrNo[13] draws m_frmNo[2] over cells whose
    // score/points slots (cell+0x20/+0x24/+0x28) are all zero, unless _rsvd_91c is set. Stops the
    // column at the first cell with no jacket handle (cell+0xc == 0).
    if (self->m_elemUsrNo[13] == (int)child) {
        forEachGridCell([&](char *cell, int, int cx0, int cy0, int) {
            if (*reinterpret_cast<int *>(cell + 0xc) == 0) {
                return false;
            }
            const int sum = *reinterpret_cast<int *>(cell + 0x20)
                          + *reinterpret_cast<int *>(cell + 0x24)
                          + *reinterpret_cast<int *>(cell + 0x28);
            if (sum == 0 && *reinterpret_cast<uint8_t *>(pd + 0x91c) == 0) {
                drawFrame(self->m_frmNo[2], cx0 + F(0x990), cy0);
            }
            return true;
        });
        return;
    }

    // Difficulty level / music rank (per cell) — m_elemUsrNo[5..7]. When _rsvd_91c is clear the
    // cell shows its music-rank frame (m_musicRankFrmNo[rank]); when set it shows the numeric
    // difficulty level (lvNormal / lvHyper / lvEx) as a digit run from the m_digitTex atlas.
    const int digitScale = self->m_isPadDisplay ? 200 : 100;
    auto drawLevelDigits = [&](int value, int cx, int cy, int priority) {
        const int n = numDigits(value);
        int pen = 0;
        for (int k = 1;; k++) {
            const int adv = (int)(((long long)pen * -0x51eb851f) >> 32);   // pen / 100
            const int dx = ((adv >> 5) - (adv >> 31)) + cx + ((n << 4) >> 1) - 8;
            neTextureForiOS_draw(&AepManager::shared(), self->m_digitTex[20 + value % 10],
                                 0, 0, 0x10, 0x14, dx, cy, digitScale, digitScale, 0, 8, 10,
                                 blend, p14, 0xffffff, 0, priority, 1);
            if (n <= k) {
                break;
            }
            pen += digitScale * 0x10;
            value /= 10;
        }
    };
    auto drawLevelGrid = [&](int shortOff, int whichLevel, int digitPriority) {
        forEachGridCell([&](char *cell, int, int cx0, int cy0, int listIndex) {
            if (*reinterpret_cast<int *>(cell + 0x10) == 0) {
                return true;                                          // empty cell -> skip
            }
            if (*reinterpret_cast<uint8_t *>(pd + 0x91c) == 0) {
                const int rank = *reinterpret_cast<short *>(cell + shortOff);
                if (rank >= 0) {
                    drawFrame(self->m_musicRankFrmNo[rank], cx0 + F(0x990), cy0);
                }
            } else {
                id info = [self->m_musicList objectAtIndexedSubscript:listIndex];
                const int lvl = whichLevel == 0 ? (int)[info lvNormal]
                              : whichLevel == 1 ? (int)[info lvHyper] : (int)[info lvEx];
                drawLevelDigits(lvl, cx0 + F(0x990), cy0, digitPriority);
            }
            return true;
        });
    };
    if (self->m_elemUsrNo[5] == (int)child) { drawLevelGrid(0x2c, 0, 0xb);  return; }  // Normal
    if (self->m_elemUsrNo[6] == (int)child) { drawLevelGrid(0x2e, 1, 0xb);  return; }  // Hyper
    if (self->m_elemUsrNo[7] == (int)child) { drawLevelGrid(0x30, 2, p14);  return; }  // Extra

    // Jacket "tip" overlays (NEW / clear icons, per cell) — m_jacketTipUsrNo[0..2]. Each present
    // cell draws a state backing frame (m_frmNo[13..15], chosen from the cell's rank short + tip
    // flag byte) at a pad/phone-nudged offset, then the tip frame m_jacketTipFrmNo[tip] on top.
    auto drawTipGrid = [&](int tip) {
        forEachGridCell([&](char *cell, int, int cx0, int cy0, int) {
            if (*reinterpret_cast<int *>(cell + 0x10) == 0) {
                return true;                                          // empty cell -> skip
            }
            const bool flagA = *reinterpret_cast<uint8_t *>(cell + 0x32 + tip) != 0;
            const bool flagB = *reinterpret_cast<uint8_t *>(cell + 0x35 + tip) != 0;
            if (!flagA && !flagB) {
                return true;
            }
            const short rankShort = *reinterpret_cast<short *>(cell + 0x2c + tip * 2);
            int bgFrame = self->m_frmNo[15];
            if (rankShort != 0) {
                bgFrame = flagB ? self->m_frmNo[14] : self->m_frmNo[13];
            }
            const int fx = cx0 + F(0x990);
            int bx = fx, by = cy0;
            if (self->m_isPadDisplay == 0) { bx = fx + 10; by = cy0 + 4; }   // phone nudge
            drawFrameFixed(bgFrame, bx, by, anchorX, anchorY);
            drawFrame(self->m_jacketTipFrmNo[tip], fx, cy0);
            return true;
        });
    };
    for (int tip = 0; tip < 3; tip++) {
        if (self->m_jacketTipUsrNo[tip] == (int)child) { drawTipGrid(tip); return; }
    }

    // Treasure-point counter — m_elemUsrNo[16]. Fixed 4-digit run (atlas m_digitTex[10..19]),
    // least-significant digit at x, each preceding digit 0x1e px to the left.
    if (self->m_elemUsrNo[16] == (int)child) {
        int v = self->m_treasurePoint;
        for (int dx = 0; dx != -0x78; dx -= 0x1e) {
            drawTex(self->m_digitTex[10 + v % 10], 0x22, 0x26, x + dx, y);
            v /= 10;
        }
        return;
    }

    // --------------------------------------------------------------- selected-song elements ----
    // These are keyed on the highlighted song: the cell at column-relative index
    // (m_chosenIndex % perRow) within the current column.
    const int resultSheet = self->m_resultSheet;
    const int selCell = (perRow ? self->m_chosenIndex % perRow : 0) + s8(self->m_curColLatch);
    char *selBase = pd + selCell * 0x38 + 0x2d8;

    // Score digits — m_scoreDigitUsrNo[0..5]. Each element paints ONE decimal digit (LSB first)
    // of the selected song's score for the active difficulty sheet (@ selCell+resultSheet*4+0x14).
    {
        int score = *reinterpret_cast<int *>(selBase + resultSheet * 4 + 0x14);
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

    // Difficulty rank badge (selected song) — m_elemUsrNo[8] draws m_diffRankFrmNo[rank].
    if (self->m_elemUsrNo[8] == (int)child) {
        const short rank = *reinterpret_cast<short *>(selBase + resultSheet * 2 + 0x2c);
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

    // Difficulty backing layers — m_diffBlackUsrNo[0..2]. Play a looping Aep layer
    // (m_bgLyrNo[1] for the selected sheet, else m_bgLyrNo[2]) advancing its own frame counter
    // (@ +0x170+i*4) until the layer's frame count (m_bgLyrFrames), then holding on the last.
    for (int i = 0; i < 3; i++) {
        if (self->m_diffBlackUsrNo[i] == (int)child) {
            const int lyrSlot = (resultSheet == i) ? 1 : 2;
            int &frm = *reinterpret_cast<int *>(pd + 0x170 + i * 4);
            self->m_aep->drawLayer(self->m_bgLyrNo[lyrSlot], frm, x, y, scaleX, scaleY, rotation,
                                   anchorX, anchorY, color, alpha, 1, blend, 0xffffff, 0, 0, p14, 1);
            if (self->m_bgLyrFrames[lyrSlot] - 1 <= frm) {
                return;
            }
            frm++;
            return;
        }
    }

    // Selected-song jacket preview — m_elemUsrNo[1] blits the big jacket texture (@ selCell+0xc).
    if (self->m_elemUsrNo[1] == (int)child) {
        drawTex(*reinterpret_cast<void **>(selBase + 0xc), 0x168, 0x168, x, y);
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

    // Ranking-place digits — m_placeDigitUsrNo[0..8]: three groups (green / yellow / pink) of up
    // to three digit slots, each a single digit of the group's place value (@ +0x908+grp*4) drawn
    // from that group's 10-digit atlas (m_digitTex[30 + grp*10 + digit]).
    for (int grp = 0; grp < 3; grp++) {
        const int placeVal = F(0x908 + grp * 4);
        const int nd = numDigits(placeVal);
        for (int d = 0; d < 3; d++) {
            if (self->m_placeDigitUsrNo[grp * 3 + d] == (int)child) {
                int digit;
                if (d == 2) {
                    if (nd != 2) { return; }
                    digit = (placeVal / 10) % 10;
                } else if (d == 1) {
                    if (nd != 2) { return; }
                    digit = placeVal % 10;
                } else {
                    if (nd != 1) { return; }
                    digit = placeVal;
                }
                drawTex(self->m_digitTex[30 + grp * 10 + digit], 0x32, 0x32, x, y);
                return;
            }
        }
    }

    // Clear-mark badge (selected song) — m_elemUsrNo[14]. No record -> m_frmNo[5]; else full-combo
    // (byte@+0x917+sheet) -> m_frmNo[4]; else cleared (byte@+0x914+sheet) -> m_frmNo[3]; else none.
    if (self->m_elemUsrNo[14] == (int)child) {
        int frameNo;
        if (*reinterpret_cast<short *>(selBase + resultSheet * 2 + 0x2c) == 0) {
            frameNo = self->m_frmNo[5];
        } else if (*reinterpret_cast<uint8_t *>(pd + resultSheet + 0x917) != 0) {
            frameNo = self->m_frmNo[4];
        } else if (*reinterpret_cast<uint8_t *>(pd + resultSheet + 0x914) != 0) {
            frameNo = self->m_frmNo[3];
        } else {
            return;
        }
        drawFrame(frameNo, x, y);
        return;
    }

    // Recommend / over-score badges + music-state frames. Skipped while the recommend list is
    // still downloading. m_overScoreDict (+0xa98) maps touched music-id strings to a state value
    // (the &cf_1 / &cf_0 binary CFString constants, "1"/"0"). Helpers factor the dict lookups.
    auto overScoreMatch = [&](int listIndex, NSString *wantValue) -> bool {
        id info = [self->m_musicList objectAtIndexedSubscript:listIndex];
        NSString *key = [[[[NSNumber alloc] initWithInt:(int)[info MusicID]] autorelease] stringValue];
        id dict = self->m_overScoreDict;
        if (![[dict allKeys] containsObject:key]) {
            return false;
        }
        return [[dict objectForKeyedSubscript:key] isEqual:wantValue];
    };
    auto chosenTouched = [&]() -> bool {
        NSString *key = [[[[NSNumber alloc] initWithInt:self->m_chosenMusicId] autorelease] stringValue];
        return [[self->m_overScoreDict allKeys] containsObject:key] != NO;
    };
    auto jacketPresent = [&](char *cell) -> bool {
        const int idx = *reinterpret_cast<int *>(cell);
        bool empty = (idx == 0);
        if (idx >= 0) {
            empty = (songCount == idx);
        }
        return !empty && (idx >= 0 && idx <= songCount);
    };

    if (![[DownloadMain getInstance] isGetRecommendListDownLoading]) {
        // Recommend badge (per cell) — m_elemUsrNo[20], m_frmNo[22], pulsing (phase @ +0xa9c).
        if (self->m_elemUsrNo[20] == (int)child) {
            const int a = pulseAlpha(F(0xa9c));
            forEachGridCell([&](char *cell, int, int cx0, int cy0, int listIndex) {
                if (jacketPresent(cell) && overScoreMatch(listIndex, @"1")) {
                    drawFrameAlpha(self->m_frmNo[22], cx0, cy0, a);
                }
                return true;
            });
            return;
        }
        // Over-score badge (per cell) — m_elemUsrNo[21], m_frmNo[23]. Advances the pulse phase.
        if (self->m_elemUsrNo[21] == (int)child) {
            const int a = pulseAlpha(F(0xa9c));
            *reinterpret_cast<int *>(pd + 0xa9c) = (F(0xa9c) + 2) % 0x97;
            forEachGridCell([&](char *cell, int, int cx0, int cy0, int listIndex) {
                if (jacketPresent(cell) && overScoreMatch(listIndex, @"0")) {
                    drawFrameAlpha(self->m_frmNo[23], cx0, cy0, a);
                }
                return true;
            });
            return;
        }
        // Chosen-song state frames (single blit at x,y) — m_elemUsrNo[17..19], keyed on whether
        // the chosen music id is in the over-score set.
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

    // Difficulty intro sweep — m_elemUsrNo[15]. While the intro flag (byte@+0x91d) is set, play
    // m_bgLyrNo[0] frame by frame (counter @ +0x164) until it ends, then clear the flag; once done
    // it holds the static difficulty backing frame m_frmNo[12].
    if (self->m_elemUsrNo[15] != (int)child) {
        return;
    }
    if (*reinterpret_cast<uint8_t *>(pd + 0x91d) != 0) {
        int &frm = *reinterpret_cast<int *>(pd + 0x164);
        self->m_aep->drawLayer(self->m_bgLyrNo[0], frm, x, y, scaleX, scaleY, rotation,
                               anchorX, anchorY, color, alpha, 1, blend, 0xffffff, 0, 0, p14, 1);
        frm++;
        if (frm < self->m_bgLyrFrames[0]) {
            return;
        }
        frm = 0;
        *reinterpret_cast<uint8_t *>(pd + 0x91d) = 0;
        return;
    }
    drawFrame(self->m_frmNo[12], x, y);
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
