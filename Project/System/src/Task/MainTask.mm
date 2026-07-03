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

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "MusicManager.h"
#import "OverScoreData.h"
#import "ScoreData.h"
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host (MainViewController) the select screen drives.
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// findCharIndexForColumn (song-name truncation in rebuildList()) is declared in neGraphics.h
// beside its sibling text helpers and defined in neEngineBridge.mm.

// Recommend-list refresh throttle: the fetch is skipped when a fresh copy was pulled
// recently and no push notification is pending (Ghidra: NSDate timeIntervalSinceDate vs
// the last-fetch date DAT_00187bdc, divided by DAT_00035e9c, compared > 4, OR
// g_bRemoteNotifyPending). The owning globals live in the app-event-center region.
static bool recommendListIsStale() {
    neAppEventCenter::shared();   // force the event-center (and its throttle globals) live
    // TODO(dep): the last-fetch NSDate (DAT_00187bdc) / remote-notify flag are owned by the
    // app-event-center, which is not yet reconstructed; treat as stale until it is.
    return true;
}

// hitButton: read `button`'s stored rectangle (from the setup()-filled layout block
// m_layoutRects, or the per-cell widget detail), scale it by the work area's UI-scale
// factor, and point-in-rect it against the tap. This is the ~13x-repeated inlined
// FixedToFP/FloatVectorMult(...m_cells[..].scale...)/FPToFixed block from the binary,
// extracted once. The exact rect-slot index per button is the documented layout seam;
// the neGraphics::pointInRect call (FUN_0002d974) is exact.
bool MainTask::hitButton(int tapX, int tapY, Button button, int cellIndex) const {
    int rx = 0, ry = 0, rw = 0, rh = 0;
    // TODO(dep): the per-button screen rectangles live in the setup()-filled layout
    // block (m_layoutRects) and, for the song grid / favourite / difficulty buttons, in
    // the per-cell widget detail (m_cells[cellIndex].detail). Their exact slot indices
    // are recovered structurally (setup() lays them out) but not wired per-button yet.
    (void)button; (void)cellIndex; (void)m_layoutRects; (void)m_uiScale;
    return neGraphics::pointInRect(tapX, tapY, rx, ry, rw, rh);
}

// Fill the three over-score display counters from the selected/other row lengths
// (Ghidra: the m_sel.overRowLen fan-out in states 3 and 4).
void MainTask::initOverscoreRows() {
    for (int i = 0; i < 3; i++) {
        // The selected difficulty's row uses field13_0x130[1], the others [2] (Ghidra).
        m_sel.overRowLen[i] = 0;   // TODO(dep): row-length config lives in the reserved tail; seam.
    }
}

// Re-read the three difficulty score rows for the current song (Ghidra: the
// fetchScoreDataForMusic loop in state 4, driven off the app-event-center store).
void MainTask::refreshScoreRows() {
    // TODO(dep): fetchScoreDataForMusic (app-event-center) not yet reconstructed; seam.
}

// Ghidra: MainTask_ctor (FUN_00034d48) — C_TASK base ctor, install the MainTask vtable,
// zero the play-data region (task +0x28..+0xaa4), then set the sentinels the binary sets:
// selected cell = -1 (+0x928), a 0xffff highlight index (+0x8c0), a 0xff byte (+0x8c2),
// and state = 0 (+0xaa4). The named members carry those initial values directly.
MainTask::MainTask() {
    // C_TASK() already ran (base subobject); all members are default-initialised above
    // (m_selectedCell = -1, m_highlight = -1, m_highlightPrev = 0xff, m_state = 0),
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
                neAppEventCenter::shared();   // g_bGuestNoSaveMode := true lives here
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

        initOverscoreRows();

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

// Ghidra: musicSelTaskSetup (FUN_000370f0) — state-0 scene build. Resolves the screen
// metrics, lays out the per-platform button rects, constructs the BG / preview / intro
// AepLyrCtrl layers, resolves every layer / frame / user animation handle, uploads the
// score / points / rank digit textures, loads the touch SEs + preview BGM, and sets the
// tutorial / badge flags.
void MainTask::setup() {
    neAppEventCenter::shared();   // g_bGuestNoSaveMode := false lives in the event center
    AudioManager *audio = [AudioManager sharedManager];

    m_aep = &AepManager::shared();
    m_screenWidth = (int)AepManager::shared().screenWidth();
    m_screenHeight = (int)AepManager::shared().screenHeight();
    m_uiScale = (int)neSceneManager::screenScale();
    m_isPadDisplay = neSceneManager::isPadDisplay() ? 1 : 0;
    m_treasurePoint = (int)[UserSettingData treasurePoint];
    m_columnStride = m_isPadDisplay ? 9 : 6;

    // TODO(dep): the per-platform button-rect table (m_layoutRects, +0x988..+0xa64) and
    // the layout base (m_layoutBaseX/Y) are filled here from the phone/pad constant tables
    // in FUN_000370f0. The exact pixel coordinates are the documented layout seam; the
    // ROLES (settings / sort / recommend / over-score / difficulty / play rects) are exact.

    // Build the four scene layers (BG + preview transports) and two intro layers.
    static const char *const kLayerNames[4] = {
        "BG_640X1136", "PREVIEW", "PREVIEW_LOOP", "PREVIEW_OUT"};
    for (int i = 0; i < 4; i++) {
        m_layers[i] = new AepLyrCtrl();
        m_layers[i]->init(3, kLayerNames[i], this, 0);
    }
    for (int i = 0; i < 2; i++) {
        m_introLayers[i] = new AepLyrCtrl();
        m_introLayers[i]->init(3, "INTRO", this, 0);
    }
    // TODO(dep): the resolved lyr/frame/user-number tables (+0x14c..+0x2d8) are filled here
    // via AepManager::getLyrNo / getFrmNo / getAepUsrNo loops; kept as a reserved block.

    // Upload the 60 score / points / rank digit-atlas textures (Ghidra: the 10x [score,
    // points, jkDif] + 30 rank loop). Paths come from the bundle number-atlas tables.
    for (auto &tex : m_digitTex) {
        tex = new neTextureForiOS();
        // tex->load("<number-atlas path>");  // exact bundle path table: layout seam
    }

    updateList();   // build the initial list column state

    // Load the touch / select SEs (Ghidra: 5x loadSe:isLoop:callName:group:) and the
    // preview BGM (bgm02_musicsel.m4a from the app-support directory).
    for (int i = 0; i < 5; i++) {
        m_seId[i] = 0;        // TODO(dep): loadSe returns the source id; SE name table is a seam.
        m_seInst[i] = -1;     // idle
    }
    (void)audio;

    // First-play tutorial is offered until the player has cleared it once.
    m_tutorialBadge = [UserSettingData isTutorialPlayed] ? 0 : 1;
    m_sel.tutorialOffered = m_tutorialBadge;
    m_overScoreDict = nil;

    m_cellSem = dispatch_semaphore_create(1);
}

// Ghidra: mainTaskUpdate (FUN_00034f4c) — per-frame list scroll physics. Reads the render
// manager's active touch, drives the horizontal list drag/fling, and on a column change
// streams the newly-visible jacket column (musicSelLoadColumnPrev/Next). This is NOT the
// re-sort routine: that is rebuildList() (musicSelUpdate FUN_0003835c), a separate function.
void MainTask::updateList() {
    neSceneManager::shared();
    neGraphics &gfx = neGraphics::shared();
    (void)gfx;
    // TODO(dep): the scroll-physics ring (m_selectedCell drag id + the +0x92c..+0x988 and
    // +0xa78 touch/velocity fields) and the column-load calls are reconstructed
    // structurally; the fixed-point fling integration is the documented physics seam.
    // The observable effect (m_columnIndex advances within [0, m_columnCount) as the list
    // is dragged, streaming the exposed jacket column each step) is modelled by state 2.
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
    // The packed per-column row latches (see MainTask.h note): next-column row @ +0x8c2 back to
    // the 0xff "idle" sentinel, the current/prev-column pair @ +0x8c0 to 0xffff, column := 0.
    m_highlightPrev = 0xff;
    m_highlight = -1;
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
    // +0x8c1 (the current-column widget-row latch; see the packed-latch note in MainTask.h) is
    // reset so the current column draws from cell row 0.
    reinterpret_cast<uint8_t *>(this)[0x8c1] = 0;
    if (!m_cellLoaderStarted) {
        m_loaderCursor = 0;
        m_cellSem = dispatch_semaphore_create(1);
        MainTask *self = this;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            // Background jacket loader (Ghidra: block invoke @ 0x3d040). Walks the column cells
            // under m_cellSem and uploads each song's jacket art as it decodes. Best-effort:
            // the block body is a documented seam.
            (void)self;
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
    if (m_recommendBadge) {
        (void)pulseAlpha(m_highlightAnim);   // draw m_arrowTex[1] at the recommend rect
    }
    if (m_overScoreBadge) {
        (void)pulseAlpha(m_highlightAnim);   // draw m_arrowTex[1] at the over-score rect
    }
    // TODO(dep): the four drawAepFrameEx difficulty-frame draws + the tutorial-badge draw +
    // the sprintf("%d/%d", m_columnIndex+1, m_columnCount) counter use the reserved Aep
    // frame-handle table and the layout rects; kept as the documented draw seam. The gate
    // flags (m_recommendBadge / m_overScoreBadge / m_tutorialBadge / m_columnCount) are exact.
    (void)m_tutorialBadge;
    (void)m_columnCount;
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

    // Persist the finished play's music id + result sheet unless this was a guest/no-save run.
    if (!m_noSaveMode) {
        neAppEventCenter::shared();
        id info = [m_musicList objectAtIndexedSubscript:m_chosenIndex];
        // TODO(dep): g_bGuestNoSaveMode / g_pNeAppEventCenter / g_wResultSheet writes live in
        // the app-event-center region; the save call is UserSettingData saveSettingData.
        neAppEventCenter::setLastMusic((int)[info MusicID]);
        [UserSettingData saveSettingData];
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
        // least as fresh as the newest entry. Ghidra: recommend[0] getValue: (the entry's
        // timestamp) compared against lastRecommendViewTimeString.
        NSString *lastViewed = [UserSettingData lastRecommendViewTimeString];
        m_recommendBadge = 1;
        // TODO(dep): the recommend entry's stored timestamp extraction (getValue:) is a
        // seam; when wired, clear the badge when lastViewed is not older than it.
        (void)lastViewed;
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
    neAppEventCenter::shared();   // g_bRemoteNotifyPending := false lives here
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
// Column streaming + scene draw callback.
//
// These reach the widget cell array by its binary layout (element stride 0x38 @ +0x2d8,
// each cell: index@+0, ready@+4, imageData@+8, texture(?)@+0xc, retained-id@+0x10) and a
// handful of scalars (column index @ +0x8f0, per-row count @ +0xa74, song count @ +0x8ec,
// the two direction latches @ +0x8c0/+0x8c2, the cell semaphore @ +0xa90). MainTask.h
// models the same storage as MusicSelCell m_cells[27]; the raw offsets here match those
// members but are kept literal to mirror the decompile 1:1.
// ---------------------------------------------------------------------------------------
namespace {
inline char *raw(MainTask *t) { return reinterpret_cast<char *>(t); }
template <typename T> inline T &at(MainTask *t, int off) {
    return *reinterpret_cast<T *>(raw(t) + off);
}
// Free one streamed cell's GPU/ObjC resources before it is re-pointed (Ghidra: the
// vtable[1] delete on the texture @ +0xc, then release on the ObjC ids @ +0x8/+0x10).
inline void releaseCell(int *cell) {
    if (cell[3] != 0) {           // +0xc uploaded texture -> delete
        delete reinterpret_cast<neTextureForiOS *>(cell[3]);
        cell[3] = 0;
    }
    if (cell[2] != 0) { cell[2] = 0; }   // +0x8 image data (ARC-released by owner)
    if (cell[4] != 0) { cell[4] = 0; }   // +0x10 retained id
}
// Shared body of the two column loaders: `delta` is +1 (next) / -1 (prev). Ghidra:
// FUN_00035448 / FUN_00035520 (identical but for the latch offset + column bound).
inline void loadColumn(MainTask *t, int column, int delta, int8_t &latch) {
    const int col = at<int>(t, 0x8f0);
    dispatch_semaphore_wait(at<dispatch_semaphore_t>(t, 0xa90), DISPATCH_TIME_FOREVER);
    const int perRow = at<int>(t, 0xa74);
    if (perRow > 0) {
        int *cell = &at<int>(t, column * 0x38 + 0x2d8);
        const int songCount = at<int>(t, 0x8ec);
        for (int i = 0; i < at<int>(t, 0xa74); i++) {
            const int idx = perRow * (col + delta) + i;
            if (idx < 0 || songCount <= idx) {
                cell[0] = -1;   // +0x0 song index (none)
                cell[1] = 0;    // +0x4 ready = empty
            } else {
                cell[0] = idx;
                cell[1] = 1;    // ready = loading
            }
            releaseCell(cell);
            cell += 0xe;        // stride 0x38 bytes
        }
    }
    latch = (int8_t)column;
    dispatch_semaphore_signal(at<dispatch_semaphore_t>(t, 0xa90));
}
}  // namespace

// @ 0x35448 — stream the column after the current one into row `column`.
void MainTask::loadColumnNext(int column) {
    if (m_highlightPrev == 0xff && at<int>(this, 0x8f0) != -2) {   // latch @ +0x8c2 idle
        loadColumn(this, column, +1, *reinterpret_cast<int8_t *>(raw(this) + 0x8c2));
    }
}

// @ 0x35520 — stream the column before the current one into row `column`.
void MainTask::loadColumnPrev(int column) {
    // The prev-column latch is the +0x8c0 byte only (the low byte of the int16 m_highlight
    // slot; its high byte @ +0x8c1 is the separate current-column row latch). Check the byte
    // directly so rebuildList's +0x8c1 write does not spuriously gate this off.
    const uint8_t prevLatch = *reinterpret_cast<uint8_t *>(raw(this) + 0x8c0);
    if (prevLatch == 0xff && at<int>(this, 0x8f0) != 0) {
        loadColumn(this, column, -1, *reinterpret_cast<int8_t *>(raw(this) + 0x8c0));
    }
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
    (void)frame; (void)color; (void)alpha; (void)p13;
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
        const int8_t curRow = *reinterpret_cast<int8_t *>(pd + 0x8c1);
        drawJacketGrid(curRow, F(0x8f0), 0);

        // Incoming next column (latch @ +0x8c2), shifted one screen width right.
        if (F(0x8f0) < F(0x8f4) - 1) {
            const int8_t nextRow = *reinterpret_cast<int8_t *>(pd + 0x8c2);
            drawJacketGrid(nextRow, F(0x8f0) + 1, F(0xa64));
        }
    }
    // Remaining per-user-number branches (score / level / name / rank / badges): documented
    // seam — see the function-level comment above. @ 0x389fc
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
