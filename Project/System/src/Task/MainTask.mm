//
//  MainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor MainTask_ctor
//  FUN_00034d48, dtor mainTask_dtor FUN_00034d90, update MainTask_update FUN_00035914).
//  The standard-mode music-select state machine. Objective-C++ (ARC): it drives the
//  UIKit nav host through the scene manager and the ObjC managers, and calls the C++
//  engine (Aep / neGraphics / neTextureForiOS) directly.
//
//  Scope: the verified ~17-state control flow, the state-2 button dispatch (top-row
//  Settings/Sort/Recommend/OverScoreLog, the Back-to-menu + first-play tutorial +
//  difficulty-toggle overlay, and the song grid), and the state-3/4 preview + ScoreData
//  load + difficulty select + play-task spawn. The per-song geometry rectangles live in
//  the packed work-area tail and are reached through hitButton() (a documented seam); the
//  spawned sub-tasks come from the task factory.
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

// The engine point-in-rect primitive (Ghidra FUN_0002d974): true when (x,y) lies inside
// the rect (rx,ry,rw,rh). This is the same primitive the bridge exposes for menu buttons
// (neEngine::menuButtonHit); MainTask_update calls it directly with pre-scaled corners.
extern "C" bool pointInRect(int x, int y, int rx, int ry, int rw, int rh);

// AepLyrCtrl transport helpers used by the preview transitions (Ghidra free functions):
// aepLyrCtrlReset rewinds a layer, aepLyrCtrlStop stops it (arg = keep-visible flag).
extern "C" void aepLyrCtrlReset(AepLyrCtrl *layer);
extern "C" void aepLyrCtrlStop(AepLyrCtrl *layer, int keepVisible);

// Is the scene manager's system-SE slot still sounding? Ghidra: isSePlaying(&scene, slot).
extern "C" bool neSceneSePlaying(int slot);

// The music-select support routines (their own reconstruction units — called, not
// reimplemented here). Ghidra addresses noted.
extern "C" void musicSelTaskSetup(MainTask *self);           // FUN_000370f0  state 0 scene build
extern "C" void mainTaskUpdate(MainTask *self);              // FUN_00034f4c  per-frame list update
extern "C" bool musicSelAllCellsReady(MainTask *self);       // FUN_00037f38  all jackets loaded?
extern "C" void musicSelUpdateHighlight(MainTask *self);     // FUN_000355fc  per-frame highlight
extern "C" void musicSelStopAndSave(MainTask *self);         // FUN_00038008  state 0x10 teardown
extern "C" void musicSelUpdateInfoPanel(MainTask *self, int mode);  // FUN_00037c88 cached panel

// Per-frame Aep layer advance + enqueue for every live layer (Ghidra: updateAndDrawAepLayers,
// == AepLyrCtrlUpdateAll declared in AepLyrCtrl.h). drawOnly = 0 here (advance + draw).

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

// ---------------------------------------------------------------------------------------
// Byte offsets into the MusicSelTask work area (task base `this`). C_TASK base ends at
// 0x28; the play data runs 0x28..0xaa8. The WorkStruct HEAD offsets below are exact
// (recovered from the struct layout); the packed SCALAR TAIL offsets are best-effort — the
// setup() pass fills the real UI-layout block, so those are a seam. Field ROLES and the
// control flow reading them are exact.
namespace {
// -- verified (ctor stores + update state field) --
constexpr int kOffSpawnedTask   = 0xaa0;   // C_TASK*   the launched sub-task
constexpr int kOffState         = 0xaa4;   // int       state field (ctor: param_1[0x2a9] = 0)
constexpr int kOffSelectedCell  = 0x928;   // int       chosen grid cell (ctor: -1)
constexpr int kOffHighlight     = 0x8c0;   // int16     highlight index (ctor: 0xffff)
// -- WorkStruct head (exact) --
constexpr int kOffMusicList     = 0x30;    // NSArray<MusicInfo*>* (id)
constexpr int kOffLayers        = 0x34;    // AepLyrCtrl*[4]  (intro / preview transport)
constexpr int kOffIntroLayers   = 0x44;    // AepLyrCtrl*[2]
constexpr int kOffNameTex       = 0x54;    // neTextureForiOS*  song-name banner
constexpr int kOffArtistTex     = 0x58;    // neTextureForiOS*  artist-name banner
constexpr int kOffCells         = 0x2d8;   // jacket cell array (stride 0x38, count 0x1b)
constexpr int kCellStride       = 0x38;
constexpr int kCellCount        = 0x1b;
constexpr int kCellImageData    = 0x08;    // id  bundled PNG data (released after upload)
constexpr int kCellTexture      = 0x0c;    // neTextureForiOS*  uploaded jacket
// -- packed scalar tail (roles exact, sub-offsets approximate: seam) --
constexpr int kOffListReady     = 0x8a0;   // bool  song list built (else stream textures)
constexpr int kOffMusicId       = 0x8b0;   // unsigned  current song id
constexpr int kOffDifficulty    = 0x8b4;   // int   selected difficulty (0 N / 1 H / 2 EX)
constexpr int kOffInviteOpen    = 0x8b8;   // bool  EX unlocked for this invite song
constexpr int kOffPreviewReady  = 0x8b9;   // bool  jackets + score loaded (state 4 gate)
constexpr int kOffDiffDirty     = 0x8ba;   // bool  difficulty changed -> refresh score rows
constexpr int kOffFavorite      = 0x8bb;   // bool  favourite toggle
constexpr int kOffTutorialAvail = 0x8bc;   // bool  first-play tutorial offered
constexpr int kOffSelectSeId    = 0x8d0;   // int   select-SE source id
constexpr int kOffSelectSeInst  = 0x8d4;   // int   select-SE playing instance (for stop)
constexpr int kOffOverScoreDict = 0x9f0;   // NSMutableDictionary*  over-score "touched" set
}  // namespace

// Typed raw-offset accessors over the work area (mirrors MenuMainTask's reinterpret_cast
// convention).
template <typename T>
static inline T &Field(const MainTask *self, int off) {
    return *reinterpret_cast<T *>(reinterpret_cast<uintptr_t>(self) + off);
}
static inline AepLyrCtrl *Layer(const MainTask *self, int base, int i) {
    return Field<AepLyrCtrl *>(self, base + i * 4);
}

// hitButton: read `button`'s stored rectangle from the packed tail, scale it by the work
// area's UI-scale factor, and point-in-rect it against the tap. The rectangle lookup is
// the packed-tail seam; the pointInRect call (FUN_0002d974) is exact.
bool MainTask::hitButton(int tapX, int tapY, Button button, int cellIndex) const {
    int rx = 0, ry = 0, rw = 0, rh = 0;
    // TODO(dep): the per-button screen rectangles live in the setup()-filled UI-layout
    // block (task +0xaa8..). Their exact sub-offsets are not yet recovered; wire this to
    // the recovered rect table when setup() (FUN_000370f0) is reconstructed.
    (void)button; (void)cellIndex;
    return pointInRect(tapX, tapY, rx, ry, rw, rh);
}

// Fill the three over-score display counters from the selected/other row lengths
// (Ghidra: the field13_0x130[1]/[2] fan-out in states 3 and 4).
void MainTask::initOverscoreRows() {
    // TODO(dep): the row-length config lives in the packed tail; seam.
}

// Re-read the three difficulty score rows for the current song (Ghidra: the
// fetchScoreDataForMusic loop in state 4, driven off the app-event-center store).
void MainTask::refreshScoreRows() {
    // TODO(dep): fetchScoreDataForMusic (app-event-center) not yet reconstructed; seam.
}

// Ghidra: MainTask_ctor (FUN_00034d48) — C_TASK base ctor, install the MainTask vtable,
// zero the 0xa7c-byte play-data region (task +0x28..+0xaa4), then set the sentinels the
// binary sets: selected cell = -1 (+0x928), a 0xffff highlight index (+0x8c0), a 0xff
// byte (+0x8c2), and state = 0 (+0xaa4).
MainTask::MainTask() {
    // C_TASK() already ran (base subobject); m_pad0/m_state/m_spawnedTask are zero-init.
    Field<int>(this, kOffSelectedCell) = -1;         // param_1[0x24a] = 0xffffffff
    Field<int16_t>(this, kOffHighlight) = -1;        // *(short*)(this + 0x8c0) = 0xffff
    Field<uint8_t>(this, 0x8c2) = 0xff;              // *(byte*)(this + 0x8c2) = 0xff
    m_state = 0;                                      // param_1[0x2a9] = 0
}

// Ghidra: mainTask_dtor (FUN_00034d90) — re-install the vtable, de-register this task as
// DownloadMain's recommend-list delegate (only if it is still us), then the C_TASK base
// dtor runs.
MainTask::~MainTask() {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl cppDelegateRecommendList] == reinterpret_cast<MusicSelTask *>(this)) {
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
        musicSelTaskSetup(this);
        [audio setBgmVolume:[UserSettingData bgmVolume]];
        [audio playBgm:0];
        if (recommendListIsStale()) {
            [dl setCppDelegateRecommendList:reinterpret_cast<MusicSelTask *>(this)];
            [dl startGetRecommendListHttp];
        } else {
            musicSelUpdateInfoPanel(this, 1);   // reuse the cached recommend panel
        }
        m_state = 1;
        break;
    }

    case 1:   // fade the select scene in and start its intro layers
        aep.playTransition(1, 1, 0);
        Layer(this, kOffLayers, 0)->play();
        Layer(this, kOffIntroLayers, 0)->play();
        Layer(this, kOffIntroLayers, 1)->play();
        Field<int>(this, kOffSelectedCell) = -1;
        m_state = 2;
        break;

    case 2: {   // *** interactive song / menu select ***
        // Re-arm the recommend fetch if it finished while a push is pending.
        if (![dl isGetRecommendListDownLoading] && recommendListIsStale()) {
            [dl setCppDelegateRecommendList:reinterpret_cast<MusicSelTask *>(this)];
            [dl startGetRecommendListHttp];
        }
        mainTaskUpdate(this);   // per-frame list scroll / cell animation

        // While the song list is still being built, stream one pending jacket texture per
        // frame (upload the first cell that has image data but no texture yet).
        if (!Field<uint8_t>(this, kOffListReady)) {
            for (int c = 0; c < kCellCount; c++) {
                uintptr_t cell = reinterpret_cast<uintptr_t>(this) + kOffCells + c * kCellStride;
                id imageData = *reinterpret_cast<__unsafe_unretained id *>(cell + kCellImageData);
                neTextureForiOS *tex = *reinterpret_cast<neTextureForiOS **>(cell + kCellTexture);
                if (imageData != nil && tex == nullptr) {
                    neTextureForiOS *loaded = new neTextureForiOS();
                    *reinterpret_cast<neTextureForiOS **>(cell + kCellTexture) = loaded;
                    loaded->loadFromImageData((__bridge const void *)imageData);
                    *reinterpret_cast<__unsafe_unretained id *>(cell + kCellImageData) = nil;
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
            if (musicSelAllCellsReady(this)) {
                m_state = 7;   // -> GotoSortSelect
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnRecommend)) {
            if (musicSelAllCellsReady(this)) {
                neEngine::playSystemSe(1);
                [RootVC() GotoRecommend:reinterpret_cast<MusicSelTask *>(this)];
                Field<uint8_t>(this, kOffFavorite) = 0;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnOverScoreLog)) {
            if (musicSelAllCellsReady(this)) {
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
            if (Field<uint8_t>(this, kOffTutorialAvail)) {
                Field<int>(this, kOffSelectSeInst) =
                    (int)[audio playSe:nil resourceId:Field<int>(this, kOffSelectSeId)];
                neAppEventCenter::shared();   // g_bGuestNoSaveMode := true lives here
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = PlayTaskCreate();   // first-play guided play
                m_state = 0xe;
            }
            break;
        }
        if (hitButton(tapX, tapY, kBtnDiffToggle)) {
            [audio playSe:nil resourceId:Field<int>(this, kOffSelectSeId)];
            Field<uint8_t>(this, 0x8a1) = 1;   // list-scroll latch (field15_0x148 pair)
            Field<uint8_t>(this, 0x8a2) = 1;
            Field<int>(this, 0x13c + 0x28) = 0;
            break;
        }

        // -- song grid: first the whole cell, then its favourite toggle --
        for (int c = 0; c < kCellCount; c++) {
            if (hitButton(tapX, tapY, kBtnSongCell, c)) {
                if (musicSelAllCellsReady(this)) {
                    Field<int>(this, kOffSelectedCell) = c;
                    neEngine::playSystemSe(1);
                    m_state = 3;   // preview the chosen song
                }
                goto tail;   // grid consumed the tap
            }
            if (hitButton(tapX, tapY, kBtnFavToggle, c)) {
                Field<uint8_t>(this, kOffFavorite) ^= 1;
                neEngine::playSystemSe(1);
                goto tail;
            }
        }
        break;
    }

    case 3: {   // a song was chosen: preview its BGM + load textures + ScoreData
        [audio pushBgm];
        id info = [Field<__unsafe_unretained id>(this, kOffMusicList)
                      objectAtIndexedSubscript:Field<int>(this, kOffSelectedCell)];
        unsigned musicId = (unsigned)[info MusicID];
        Field<unsigned>(this, kOffMusicId) = musicId;

        // Invite songs are only playable while their invite window is open.
        bool inviteOpen;
        if (![MusicManager isInviteMusic:musicId]) {
            inviteOpen = true;
        } else {
            inviteOpen = [MusicManager isOpenInviteMusic:2];
        }
        Field<uint8_t>(this, kOffInviteOpen) = inviteOpen ? 1 : 0;

        NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
        ScoreData *score = [ScoreData getScoreData:musicId inManagedObjectContext:moc];

        aepLyrCtrlStop(Layer(this, kOffLayers, 1), 1);
        if (neTextureForiOS *t = Field<neTextureForiOS *>(this, kOffNameTex)) {
            delete t;
            Field<neTextureForiOS *>(this, kOffNameTex) = nullptr;
        }
        if (neTextureForiOS *t = Field<neTextureForiOS *>(this, kOffArtistTex)) {
            delete t;
            Field<neTextureForiOS *>(this, kOffArtistTex) = nullptr;
        }

        NSData *nameImg = [info musicNameImage2xData];
        neTextureForiOS *nameTex = new neTextureForiOS();
        Field<neTextureForiOS *>(this, kOffNameTex) = nameTex;
        nameTex->loadFromImageData((__bridge const void *)nameImg);

        NSData *artistImg = [info artistNameImage2xData];
        neTextureForiOS *artistTex = new neTextureForiOS();
        Field<neTextureForiOS *>(this, kOffArtistTex) = artistTex;
        artistTex->loadFromImageData((__bridge const void *)artistImg);

        // The three level values + the six full-combo / perfect medals for the score panel.
        Field<int>(this, 0x8e0) = (int)[info lvNormal];
        Field<int>(this, 0x8e4) = (int)[info lvHyper];
        Field<int>(this, 0x8e8) = (int)[info lvEx];
        Field<uint8_t>(this, 0x8ec) = [[score fullComboN] boolValue] ? 1 : 0;
        Field<uint8_t>(this, 0x8ed) = [[score fullComboH] boolValue] ? 1 : 0;
        Field<uint8_t>(this, 0x8ee) = [[score fullComboEx] boolValue] ? 1 : 0;
        Field<uint8_t>(this, 0x8ef) = [[score perfectN] boolValue] ? 1 : 0;
        Field<uint8_t>(this, 0x8f0) = [[score perfectH] boolValue] ? 1 : 0;
        Field<uint8_t>(this, 0x8f1) = [[score perfectEx] boolValue] ? 1 : 0;
        Field<uint8_t>(this, kOffPreviewReady) = 1;

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
        NSMutableDictionary *overDict = Field<__unsafe_unretained NSMutableDictionary *>(
            this, kOffOverScoreDict);
        if ([[overDict allKeys] containsObject:idStr]) {
            overDict[idStr] = idStr;   // re-touch (Ghidra: setObject:forKeyedSubscript: &cf_1)
        }

        Field<int>(this, kOffDifficulty) = 0;   // default to NORMAL
        m_state = 4;
        break;
    }

    case 4: {   // difficulty / option select + BGM preview loop
        if (!Field<uint8_t>(this, kOffPreviewReady)) {
            if (![audio isPlayingBgm]) {
                [audio seekBgmToTop];
                [audio setBgmVolume:1.0f];
                [audio playBgm:0];
            }
        }

        // When the preview intro finishes, cross into its looping layer.
        AepLyrCtrl *preview = Layer(this, kOffLayers, 1);
        if (preview->isAnimating() /* Ghidra: layer[0x5c] one-shot flag, consumed here */) {
            Layer(this, kOffLayers, 3)->play();
        }

        // A pending difficulty change re-reads the three score rows.
        if (Field<uint8_t>(this, kOffDiffDirty)) {
            refreshScoreRows();
            Field<uint8_t>(this, kOffDiffDirty) = 0;
        }

        // Whether this song already has an over-score (friend-score) entry.
        NSString *idStr = [@(Field<unsigned>(this, kOffMusicId)) stringValue];
        NSMutableDictionary *overDict = Field<__unsafe_unretained NSMutableDictionary *>(
            this, kOffOverScoreDict);
        bool hasOverScore = [[overDict allKeys] containsObject:idStr];

        if (!haveTap) {
            break;   // buttons only respond to a tap
        }

        // -- PLAY --
        if (hitButton(tapX, tapY, kBtnPlay)) {
            [audio popBgm];
            Field<int>(this, kOffSelectSeInst) =
                (int)[audio playSe:nil resourceId:Field<int>(this, kOffSelectSeId)];
            m_spawnedTask = PlayTaskCreate();
            [[AppDelegate appDelegate] setMainTask:(MainTask *)m_spawnedTask];
            m_state = 0xc;   // -> play-launch handoff (0xc -> 0xd -> 0xe)
            break;
        }

        // -- FRIEND SCORE / over-score --
        if (hitButton(tapX, tapY, kBtnFriendScore)) {
            neEngine::playSystemSe(1);
            [audio stopBgm:0];
            Field<uint8_t>(this, 0x8a1) = 1;
            if (hasOverScore) {
                [overDict removeObjectForKey:idStr];
            }
            [RootVC() GotoFriendScore:Field<unsigned>(this, kOffMusicId)];
            break;
        }

        // -- difficulty rows (NORMAL / HYPER / EX) --
        bool consumed = false;
        for (int d = 0; d < 3; d++) {
            if (!hitButton(tapX, tapY, kBtnDifficulty, d)) {
                continue;
            }
            if (Field<int>(this, kOffDifficulty) != d) {
                // EX is locked for a not-yet-open invite song.
                if (d != 2 || Field<uint8_t>(this, kOffInviteOpen)) {
                    [audio playSe:nil resourceId:0];
                    Field<int>(this, kOffDifficulty) = d;
                    Field<uint8_t>(this, kOffDiffDirty) = 1;
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
        if (!Field<uint8_t>(this, kOffPreviewReady)) {
            aepLyrCtrlReset(Layer(this, kOffLayers, 1));
            aepLyrCtrlReset(Layer(this, kOffLayers, 3));
            aepLyrCtrlStop(Layer(this, kOffLayers, 2), 1);
            [audio popBgm];
            [audio setBgmVolume:[UserSettingData bgmVolume]];
            [audio playBgm:0];
            neEngine::playSystemSe(2);
            Field<int>(this, kOffSelectedCell) = -1;
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
        [RootVC() GotoSortSelect:reinterpret_cast<MusicSelTask *>(this)];
        m_state = 8;
        break;

    case 8:   // sort modal shown -> resume interactive select
    case 10:  // over-score-log modal shown -> resume interactive select
        m_state = 2;
        break;

    case 9:   // over-score (friend score) log
        neEngine::playSystemSe(1);
        [RootVC() GotoOverScoreLog:reinterpret_cast<MusicSelTask *>(this)];
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
        Field<int>(this, 0x8f8) = 1;   // transition-out latch (field3_0x1c+2)
        m_state = 0xf;
        break;

    case 0xf:   // wait for the fade-out (and, on a preview exit, the layer to settle)
        if (aep.isTransitionDone() &&
            !Field<uint8_t>(this, kOffPreviewReady) &&
            Field<int>(this, 0x8f8) == 2) {
            m_state = 0x10;
        }
        break;

    case 0x10:  // handoff: tear down once the select SEs finish
        if (!neSceneSePlaying(2)) {
            if (Field<int>(this, kOffSelectSeInst) >= 0 && [audio isPlayingSe:0]) {
                break;   // a select SE is still sounding
            }
            musicSelStopAndSave(this);
        }
        break;

    default:
        break;
    }

tail:
    // Per-frame select-screen highlight update + Aep layer advance/draw (Ghidra tail).
    musicSelUpdateHighlight(this);
    AepLyrCtrlUpdateAll(0);
}
