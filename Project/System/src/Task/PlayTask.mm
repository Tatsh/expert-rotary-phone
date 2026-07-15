//
//  PlayTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (PlayTask_update FUN_0002dc14). The note-play state machine; the verified
//  state flow + the judge hand-off. Field offsets into the play data are cited
//  (see PlayJudge.h).
//

#include <cstring>

#import <Foundation/Foundation.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"
#import "PlayTask.h"
#import "UserSettingData.h"
#import "neEngineBridge.h" // neAppEventCenter / neSceneManager::hitSoundName
#import "neGraphics.h"

// DAT_00178d00 — the play default life-gauge base, read by PlayTask_init +
// playTaskResetState. A data global that is only ever read (never written) and
// stays 0. Kept as the named global.
static int16_t g_wPlayDefaultGauge = 0;

// PlayTaskInit / PlayTaskGotoResult are declared in PlayTask.h (the play-scene
// build + results-transition seams). The play-data work area is now a real
// named-member layout (see PlayTask.h); the former pd()+reinterpret_cast
// accessors are gone.

PlayTask::PlayTask() = default;

// @ 0x2db74 — taskNode_deleteB is the compiler's deleting-destructor thunk
// (caSourceNode_dtor then operator delete). PlayTask's own destructor only
// chains to the C_TASK base (the scene/notes are torn down through
// PlayTaskGotoResult / the scheduler), so there is no per-member teardown here.
PlayTask::~PlayTask() = default;

// @ 0x2fed8 — playTaskResetState. Reset the play scene for a fresh attempt.
void PlayTask::resetState() {
    NoteMng::shared(); // ensure the note manager singleton exists
    reloadChart(1);    // FUN_0002fed8 calls playTaskLoadChart(this, 1)

    // Reset the two animated-layer banks (5 @ +0x84, 11 @ +0x98).
    for (AepLyrCtrl *l : m_comboLayers) {
        if (l) {
            l->reset();
        }
    }
    for (AepLyrCtrl *l : m_sceneLayers) {
        if (l) {
            l->reset();
        }
    }

    m_timingSeInst[0] = -1;
    m_timingSeInst[1] = -1;

    // Zero the 0x3c-entry judge pool (@ +0x3c8, stride 0x18), then stamp each
    // entry's slot index (word 0) and its -1 free sentinel (word 1 ==
    // NoteJudgeState::noteKey).
    std::memset(m_judgePool, 0, sizeof(m_judgePool));
    for (int i = 0; i < 0x3c; i++) {
        m_judgePool[i].layerId = i;
        m_judgePool[i].noteKey = reinterpret_cast<const void *>(-1);
    }

    // Gauge / score scalars.
    m_backTouchId = -1;
    m_gaugeBase = (int16_t)g_wPlayDefaultGauge; // DAT_00178d00
    m_score = 0;
    m_gaugeValue = 0;
    m_gaugeValueSub = 0;
    m_damageAccum = 0;
    m_damagedThisFrame = 0;
}

// @ 0x30720 — playTaskLoadChart. Reload the selected chart into the note
// manager: resolve the picked song + difficulty, then (on a full load, restart
// == 0) restart the BGM decode on a background queue, parse the chosen sheet
// into NoteMng, and load the per-tap hit SE. `restart` != 0 reparses the chart
// only (the mid-play reset path calls reloadChart(1)), skipping the audio work.
void PlayTask::reloadChart(int restart) {
    AudioManager *audio = [AudioManager sharedManager];
    NoteMng &nm = NoteMng::shared();

    MusicData *md;
    int difficulty;
    if (m_isDemoPlay == 0) {
        // Normal play: the picked {musicId, sheet} pair the event center carries (@
        // +0x968).
        const int musicId = m_eventCenter->lastMusic(); // pair[0]
        difficulty = (short)m_eventCenter->lastSheet(); // (short)pair[1]
        md = [[MusicManager getInstance] getMusicData:musicId];
    } else {
        // Tutorial / bundled-demo play (flag @ +0x9c9): the fixed bundled song,
        // normal sheet.
        difficulty = 0;
        md = [MusicData dataWithPath:[MusicManager getPathFromBundle:0] ID:0];
    }

    if (restart == 0) {
        [audio stopBgm:0.0f];
        // @ 0x3119c — decode + start this song's BGM off the main thread so the
        // sheet parse below is not blocked on the audio; flag it ready (@ +0x9c6)
        // when done. Captures the AudioManager + MusicData + this play data
        // (Ghidra: the +0x968/+0x24 block vars).
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
          NSData *bgm = [md music];
          [audio loadBgmData:bgm isLoop:NO];
          [audio setBgmVolume:1.0f];
          m_bgmReady = 1;
        });
    }

    // Pick the chosen difficulty's sheet (0 normal / 1 hyper / 2 ex) and parse it
    // into the global note manager. Ghidra threads a per-note spawn callback (@
    // 0x3122c) and this play data as the two context args; only the play-data
    // context is forwarded here.
    NSData *sheet = (difficulty == 2) ? [md sheetEx] :
                    (difficulty == 1) ? [md sheetHyper] :
                                        [md sheetNormal];
    nm.initPlayDataWithData(sheet, 0, (uint32_t)(uintptr_t)this);

    if (restart == 0) {
        // The per-tap feedback SE: the user's touch-sound kind (@ UserSettingData)
        // -> the scene manager's hit-sound name -> the bundle ".m4a" path, loaded
        // into play data +0x398 at the user's touch-sound volume (@ +0x9b4).
        // Ghidra: getHitSoundName.
        const int kind = [UserSettingData touchSoundKind];
        NSString *name = (__bridge NSString *)neSceneManager::hitSoundName(kind);
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"m4a"];
        m_hitSeId = (int)[audio loadSe:path isLoop:NO callName:nil group:0];
        [audio setSeVolume:m_seVolume groupId:0];
    }
}

// @ 0x312cc — updateGaugeValue. Nudge the life gauge by the per-mode delta and
// clamp it.
void PlayTask::updateGauge(int mode) {
    int16_t &gauge = m_gaugeValue;
    const float *delta = nullptr;
    if ((unsigned)(mode - 2) < 2) { // mode 2 or 3 (great / perfect)
        delta = &m_gaugeGainGreat;
    } else if (mode == 0) { // miss / down
        delta = &m_gaugeLossMiss;
        m_damagedThisFrame = 1; // damaged this frame
    } else if (mode == 1) {     // good
        delta = &m_gaugeGainGood;
    }

    if (delta != nullptr) {
        // gauge += *delta (fixed<->float round-trip in the binary).
        gauge = (int16_t)((float)gauge + *delta);
    }
    if (gauge < 1) {
        gauge = 0;
    }
    if (gauge > 0x400) {
        gauge = 0x400;
    }
}

// Ghidra: PlayTask_update (FUN_0002dc14).
void PlayTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    NoteMng &nm = NoteMng::shared();
    neGraphics &gfx = neGraphics::shared();
    auto *playData = reinterpret_cast<MainTaskPlayData *>(this);

    // Snapshot up to 8 live touches (scaled x/y + their ids) for the judge pass,
    // and detect a "back" tap (a released touch that barely moved).
    float touchXY[16];
    int touchIds[8];
    for (int i = 0; i < 16; i++) {
        touchXY[i] = -1.0f;
    }
    int touchCount = 0;
    bool backTap = false;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) { // a currently-down touch -> feed the judge
            if (touchCount < 8) {
                touchXY[touchCount * 2] = (float)t->x / 65536.0f;
                touchXY[touchCount * 2 + 1] = (float)t->y / 65536.0f;
                touchIds[touchCount] = t->id;
                touchCount++;
            }
        } else if (!backTap && t->released != 0) { // a tap -> maybe the back button
            int dx = t->startX - t->x, dy = t->startY - t->y;
            backTap = (dx < 0 ? -dx : dx) < 0xb && (dy < 0 ? -dy : dy) < 0xb;
        }
    }

    switch (m_state) {
    case 0:
        PlayTaskInit(playData); // FUN_0002e2d8: allocate the play scene
        m_state = 1;
        [[fallthrough]];
    case 1:                          // NoteMng bring-up + fade in + start SEs
        nm.primePlay();              // Ghidra: FUN_0003396c — spawn the lead-in + position the
                                     // notes
        aep.setAepTransitionMode(1); // fade in (fixed 30 frames)
        m_state = 2;
        [[fallthrough]];
    case 2: // ready: on the "go" flag, arm the play clock
        PlayJudge_update(playData, nullptr, nullptr, 0); // draw the field
        return;
    case 3: // retry: after the fade, rebuild the play and restart
        if (aep.isTransitionDone()) {
            aep.setAepTransitionMode(1); // fade back in
            resetState();                // Ghidra: playTaskResetState (FUN_0002fed8)
            m_state = 1;
        }
        break;
    case 4:              // wait for the start SE, then start NoteMng's clock -> playing
        nm.startClock(); // Ghidra: FUN_000344c4 — stamp the play clock, clear
                         // offsets/state
        m_state = 6;
        break;
    case 5:          // pause menu: hit-test resume / retry / quit; draw the pause layer
        nm.update(); // Ghidra: FUN_00033ae4 — keep the notes scrolling behind the
                     // menu
        aep.drawLayer(0 /*+0xf8*/, 0, AepTransform(), 0);
        PlayJudge_update(playData, nullptr, nullptr, 0);
        return;
    case 6: {               // *** PLAYING ***: drive the note engine, then judge/render, gauge,
                            // song-end
        nm.updatePlaying(); // Ghidra: FUN_00033fc0 — spawn/judge/retire/scroll +
                            // BGM drift sync
        PlayJudge_update(playData, touchXY, touchIds, touchCount);

        // Cache the current gauge/score for the end-of-song rank SEs. Ghidra:
        // FUN_0002ff7c.
        m_score = PlayCurrentScore();

        // Song-end: once NoteMng has emitted its last note, latch the end position
        // and, ~1s later, fire the clear + rank SEs exactly once. Ghidra: the
        // FUN_0003181c guard + the +0x9c8/+0x9c9/+0x9f8 bookkeeping in state 6. Per
        // the decompile the one-shot latch is m_endSeFired (@ +0x9c8, set here);
        // the inner gate skips the SE in tutorial/demo mode (m_isDemoPlay @ +0x9c9,
        // set once at init — never written here).
        if (!m_endSeFired && nm.isFinished()) {
            int pos = nm.getCurrentPosition();
            if (m_endPos == 0) {
                m_endPos = pos;
            }
            if (!m_isDemoPlay && (unsigned)(pos - m_endPos) > 999) {
                m_endSeFired = true;
                [audio playSe:nil resourceId:0];    // the song-clear SE
                PlayEndResultSe(playData, m_score); // rank jingles keyed on the score
            }
        }

        if (backTap) { // a held back tap freezes the play and opens the pause menu
            nm.onResignActivePushHook();
            m_state = 5;
            break;
        }

        // ~3s after the song ends, hand off to the fade-out.
        if (m_endPos != 0 && (unsigned)(nm.getCurrentPosition() - m_endPos) >= 3000) {
            m_state = 8;
        }
        break;
    }
    case 7: // quit: stop all audio and fall through to the fade-out
        [audio stopAll];
        m_state = 8;
        break;
    case 8:                          // fade out
        aep.setAepTransitionMode(2); // fade out (fixed 30 frames)
        m_state = 9;
        break;
    case 9:
        if (aep.isTransitionDone()) {
            m_state = 10;
        }
        break;
    case 10: // hand off to the result screen
        if (aep.isTransitionDone()) {
            PlayTaskGotoResult(playData);
        }
        break;
    default:
        break;
    }

    // Per-frame input + draw tail (Ghidra: FUN_0002c924 / FUN_000303fc).
}
