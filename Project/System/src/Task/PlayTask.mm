//
//  PlayTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (PlayTask_update
//  FUN_0002dc14). The note-play state machine; the verified state flow + the judge
//  hand-off. Field offsets into the play data are cited (see PlayJudge.h).
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
#import "neEngineBridge.h"   // neAppEventCenter / neSceneManager::hitSoundName
#import "neGraphics.h"

// PlayTaskInit / PlayTaskGotoResult are declared in PlayTask.h (the play-scene
// build + results-transition seams).

namespace {
inline char *pd(PlayTask *t) { return reinterpret_cast<char *>(t); }
inline int &state(PlayTask *t) {   // play-data state @ +0x9fc
    return *reinterpret_cast<int *>(pd(t) + 0x9fc);
}
inline int &score(PlayTask *t)        { return *reinterpret_cast<int *>(pd(t) + 0x9b0); }  // gauge/score readout
inline bool &endStarted(PlayTask *t)  { return *reinterpret_cast<bool *>(pd(t) + 0x9c8); } // song has ended
inline bool &endSePlayed(PlayTask *t) { return *reinterpret_cast<bool *>(pd(t) + 0x9c9); } // clear/rank SE fired
inline int &endPos(PlayTask *t)       { return *reinterpret_cast<int *>(pd(t) + 0x9f8); }  // position at song end
}

PlayTask::PlayTask() = default;

// @ 0x2db74 — taskNode_deleteB is the compiler's deleting-destructor thunk
// (caSourceNode_dtor then operator delete). PlayTask's own destructor only chains to the
// C_TASK base (the scene/notes are torn down through PlayTaskGotoResult / the scheduler),
// so there is no per-member teardown here.
PlayTask::~PlayTask() = default;

// @ 0x2fed8 — playTaskResetState. Reset the play scene for a fresh attempt.
void PlayTask::resetState() {
    NoteMng::shared();               // ensure the note manager singleton exists
    reloadChart(1);                  // FUN_0002fed8 calls playTaskLoadChart(this, 1)

    // Reset the two animated-layer banks (5 @ +0x84, 11 @ +0x98).
    for (int i = 0; i < 5; i++) {
        if (AepLyrCtrl *l = *reinterpret_cast<AepLyrCtrl **>(pd(this) + 0x84 + i * 4)) {
            l->reset();
        }
    }
    for (int i = 0; i < 0xb; i++) {
        if (AepLyrCtrl *l = *reinterpret_cast<AepLyrCtrl **>(pd(this) + 0x98 + i * 4)) {
            l->reset();
        }
    }

    *reinterpret_cast<int *>(pd(this) + 0x3a0) = -1;
    *reinterpret_cast<int *>(pd(this) + 0x3a4) = -1;

    // Zero the 0x3c-entry judge pool (@ +0x3c8, stride 0x18 == 6 words), then stamp each
    // entry's index (word 0) and its -1 sentinel (word 1).
    std::memset(pd(this) + 0x3c8, 0, 0x5a0);
    int *entry = reinterpret_cast<int *>(pd(this) + 0x3c8);
    for (int i = 0; i < 0x3c; i++) {
        entry[0] = i;
        entry[1] = -1;
        entry += 6;              // 0x18 bytes
    }

    // Gauge / score scalars.
    *reinterpret_cast<int *>(pd(this) + 0x9ec)      = -1;
    *reinterpret_cast<int16_t *>(pd(this) + 0x9ac)  = (int16_t)g_wPlayDefaultGauge; // DAT_00178d00
    *reinterpret_cast<int *>(pd(this) + 0x9b0)      = 0;
    *reinterpret_cast<int16_t *>(pd(this) + 0x9c0)  = 0;   // gauge value
    *reinterpret_cast<int16_t *>(pd(this) + 0x9c2)  = 0;
    *reinterpret_cast<int *>(pd(this) + 0x9d8)      = 0;
    *reinterpret_cast<unsigned char *>(pd(this) + 0x9dc) = 0;
}

// @ 0x30720 — playTaskLoadChart. Reload the selected chart into the note manager:
// resolve the picked song + difficulty, then (on a full load, restart == 0) restart the
// BGM decode on a background queue, parse the chosen sheet into NoteMng, and load the
// per-tap hit SE. `restart` != 0 reparses the chart only (the mid-play reset path calls
// reloadChart(1)), skipping the audio work.
void PlayTask::reloadChart(int restart) {
    AudioManager *audio = [AudioManager sharedManager];
    NoteMng &nm = NoteMng::shared();

    MusicData *md;
    int difficulty;
    if (*reinterpret_cast<unsigned char *>(pd(this) + 0x9c9) == 0) {
        // Normal play: the picked {musicId, sheet} pair the event center carries (@ +0x968).
        neAppEventCenter *evc = *reinterpret_cast<neAppEventCenter **>(pd(this) + 0x968);
        const int musicId = evc->lastMusic();           // pair[0]
        difficulty = (short)evc->lastSheet();           // (short)pair[1]
        md = [[MusicManager getInstance] getMusicData:musicId];
    } else {
        // Tutorial / bundled-demo play (flag @ +0x9c9): the fixed bundled song, normal sheet.
        difficulty = 0;
        md = [MusicData dataWithPath:[MusicManager getPathFromBundle:0] ID:0];
    }

    if (restart == 0) {
        [audio stopBgm:0.0f];
        // @ 0x3119c — decode + start this song's BGM off the main thread so the sheet parse
        // below is not blocked on the audio; flag it ready (@ +0x9c6) when done. Captures
        // the AudioManager + MusicData + this play data (Ghidra: the +0x968/+0x24 block vars).
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *bgm = [md music];
            [audio loadBgmData:bgm isLoop:NO];
            [audio setBgmVolume:1.0f];
            *reinterpret_cast<unsigned char *>(pd(this) + 0x9c6) = 1;
        });
    }

    // Pick the chosen difficulty's sheet (0 normal / 1 hyper / 2 ex) and parse it into the
    // global note manager. Ghidra threads a per-note spawn callback (@ 0x3122c) and this
    // play data as the two context args; only the play-data context is forwarded here.
    NSData *sheet = (difficulty == 2) ? [md sheetEx]
                  : (difficulty == 1) ? [md sheetHyper]
                                      : [md sheetNormal];
    nm.initPlayDataWithData(sheet, 0, (uint32_t)(uintptr_t)this);

    if (restart == 0) {
        // The per-tap feedback SE: the user's touch-sound kind (@ UserSettingData) -> the
        // scene manager's hit-sound name -> the bundle ".m4a" path, loaded into play data
        // +0x398 at the user's touch-sound volume (@ +0x9b4). Ghidra: getHitSoundName.
        const int kind = [UserSettingData touchSoundKind];
        NSString *name = (__bridge NSString *)neSceneManager::hitSoundName(kind);
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"m4a"];
        *reinterpret_cast<int *>(pd(this) + 0x398) =
            (int)[audio loadSe:path isLoop:NO callName:nil group:0];
        [audio setSeVolume:*reinterpret_cast<short *>(pd(this) + 0x9b4) groupId:0];
    }
}

// @ 0x312cc — updateGaugeValue. Nudge the life gauge by the per-mode delta and clamp it.
void PlayTask::updateGauge(int mode) {
    int16_t &gauge = *reinterpret_cast<int16_t *>(pd(this) + 0x9c0);
    const float *delta = nullptr;
    if ((unsigned)(mode - 2) < 2) {          // mode 2 or 3 (great / perfect)
        delta = reinterpret_cast<float *>(pd(this) + 0x9cc);
    } else if (mode == 0) {                   // miss / down
        delta = reinterpret_cast<float *>(pd(this) + 0x9d4);
        *reinterpret_cast<unsigned char *>(pd(this) + 0x9dc) = 1;   // damaged this frame
    } else if (mode == 1) {                   // good
        delta = reinterpret_cast<float *>(pd(this) + 0x9d0);
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

    // Snapshot up to 8 live touches (scaled x/y + their ids) for the judge pass, and
    // detect a "back" tap (a released touch that barely moved).
    float touchXY[16];
    int touchIds[8];
    for (int i = 0; i < 16; i++) { touchXY[i] = -1.0f; }
    int touchCount = 0;
    bool backTap = false;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) {              // a currently-down touch -> feed the judge
            if (touchCount < 8) {
                touchXY[touchCount * 2] = (float)t->prevX / 65536.0f;
                touchXY[touchCount * 2 + 1] = (float)t->prevY / 65536.0f;
                touchIds[touchCount] = t->id;
                touchCount++;
            }
        } else if (!backTap && t->released != 0) {   // a tap -> maybe the back button
            int dx = t->x - t->prevX, dy = t->y - t->startY;
            backTap = (dx < 0 ? -dx : dx) < 0xb && (dy < 0 ? -dy : dy) < 0xb;
        }
    }

    switch (state(this)) {
    case 0:
        PlayTaskInit(playData);   // FUN_0002e2d8: allocate the play scene
        state(this) = 1;
        [[fallthrough]];
    case 1:   // NoteMng bring-up + fade in + start SEs
        nm.primePlay();   // Ghidra: FUN_0003396c — spawn the lead-in + position the notes
        aep.playTransition(1, 1, 0);
        state(this) = 2;
        [[fallthrough]];
    case 2:   // ready: on the "go" flag, arm the play clock
        PlayJudge_update(playData, nullptr, nullptr, 0);   // draw the field
        return;
    case 3:   // retry: after the fade, rebuild the play and restart
        if (aep.isTransitionDone()) {
            state(this) = 1;
        }
        break;
    case 4:   // wait for the start SE, then start NoteMng's clock -> playing
        nm.startClock();   // Ghidra: FUN_000344c4 — stamp the play clock, clear offsets/state
        state(this) = 6;
        break;
    case 5:   // pause menu: hit-test resume / retry / quit; draw the pause layer
        nm.update();   // Ghidra: FUN_00033ae4 — keep the notes scrolling behind the menu
        aep.drawLayer(0 /*+0xf8*/, 0, AepTransform(), 0);
        PlayJudge_update(playData, nullptr, nullptr, 0);
        return;
    case 6: {   // *** PLAYING ***: drive the note engine, then judge/render, gauge, song-end
        nm.updatePlaying();   // Ghidra: FUN_00033fc0 — spawn/judge/retire/scroll + BGM drift sync
        PlayJudge_update(playData, touchXY, touchIds, touchCount);

        // Cache the current gauge/score for the end-of-song rank SEs. Ghidra: FUN_0002ff7c.
        score(this) = PlayCurrentScore();

        // Song-end: once NoteMng has emitted its last note, latch the end position and,
        // ~1s later, fire the clear + rank SEs exactly once. Ghidra: the FUN_0003181c
        // guard + the +0x9c8/+0x9c9/+0x9f8 bookkeeping in state 6.
        if (!endStarted(this) && nm.isFinished()) {
            int pos = nm.getCurrentPosition();
            if (endPos(this) == 0) {
                endPos(this) = pos;
            }
            if (!endSePlayed(this) && (unsigned)(pos - endPos(this)) > 999) {
                endSePlayed(this) = true;
                [audio playSe:nil resourceId:0];         // the song-clear SE
                PlayEndResultSe(playData, score(this));  // rank jingles keyed on the score
            }
        }

        if (backTap) {   // a held back tap freezes the play and opens the pause menu
            nm.onResignActivePushHook();
            state(this) = 5;
            break;
        }

        // ~3s after the song ends, hand off to the fade-out.
        if (endPos(this) != 0 &&
            (unsigned)(nm.getCurrentPosition() - endPos(this)) >= 3000) {
            state(this) = 8;
        }
        break;
    }
    case 7:   // quit: stop all audio and fall through to the fade-out
        [audio stopAll];
        state(this) = 8;
        break;
    case 8:   // fade out
        aep.playTransition(2, 1, 0);
        state(this) = 9;
        break;
    case 9:
        if (aep.isTransitionDone()) {
            state(this) = 10;
        }
        break;
    case 10:   // hand off to the result screen
        if (aep.isTransitionDone()) {
            PlayTaskGotoResult(playData);
        }
        break;
    default:
        break;
    }

    // Per-frame input + draw tail (Ghidra: FUN_0002c924 / FUN_000303fc).
}
