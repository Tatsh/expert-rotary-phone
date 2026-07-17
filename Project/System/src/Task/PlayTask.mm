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
#include <span>

#import <Foundation/Foundation.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"
#import "PlayTask.h"
#import "RhUtil.h" // pointInCircle / getTimeMillis (the pause hit-circle)
#import "UserSettingData.h"
#import "neEngineBridge.h" // neAppEventCenter / neSceneManager::hitSoundName
#import "neGraphics.h"

// DAT_00178d00 — the play default life-gauge base, read by PlayTask_init +
// playTaskResetState. A data global that is only ever read (never written) and
// stays 0. Kept as the named global.
static int16_t g_wPlayDefaultGauge = 0;

// The global attract-mode flag the title's demo playback sets; PlayTask_update
// state 6 branches on it (auto-advance in demo mode vs the pause hit-circle in
// normal play). Defined here as the shared global (defaults false = normal play).
bool g_bDemoPlayMode = false;

// PlayTaskInit / PlayTaskGotoResult are declared in PlayTask.h (the play-scene
// build + results-transition seams). The play-data work area is now a real
// named-member layout (see PlayTask.h); the former pd()+reinterpret_cast
// accessors are gone.

PlayTask::PlayTask() = default;

// @ 0x2db74 — taskNode_deleteB is the compiler's deleting-destructor thunk
// (caSourceNode_dtor then operator delete). PlayTask's own destructor only
// chains to the C_TASK base (the scene/notes are torn down through
// PlayTaskGotoResult / the scheduler), so there is no per-member teardown here.
// @complete
PlayTask::~PlayTask() = default;

// @ 0x2fed8 — playTaskResetState. Reset the play scene for a fresh attempt.
// @complete
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
    // NoteJudgeState::noteId).
    std::memset(m_judgePool, 0, sizeof(m_judgePool));
    for (int i = 0; i < 0x3c; i++) {
        m_judgePool[i].layerId = i;
        m_judgePool[i].noteId = 0xffffffffu;
    }

    // Gauge / score scalars.
    m_backTouchId = -1;
    m_gaugeBase = (int16_t)g_wPlayDefaultGauge; // DAT_00178d00
    m_score = 0;
    m_gaugeValue = 0;
    m_comboMilestoneGuard = 0;
    m_damageAccum = 0;
    m_damagedThisFrame = 0;
}

// @ 0x30720 — playTaskLoadChart. Reload the selected chart into the note
// manager: resolve the picked song + difficulty, then (on a full load, restart
// == 0) restart the BGM decode on a background queue, parse the chosen sheet
// into NoteMng, and load the per-tap hit SE. `restart` != 0 reparses the chart
// only (the mid-play reset path calls reloadChart(1)), skipping the audio work.
// @complete
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
    // into the global note manager, registering the miss callback (@ 0x3122c,
    // PlayApplyMissGauge) with this play data — detectMiss fires it to drain the
    // gauge when a note scrolls past un-tapped.
    NSData *sheet = (difficulty == 2) ? [md sheetEx] :
                    (difficulty == 1) ? [md sheetHyper] :
                                        [md sheetNormal];
    nm.initPlayDataWithData(sheet, PlayApplyMissGauge, this);

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
// @complete
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

// Ghidra: PlayTask::DrawHud (FUN_000303fc) — the per-frame note-play HUD:
// score/best/combo gauges keyed to the beat phase, the fever gauge, the
// gauge-overflow band and the eased scrub/gauge bar. A literal translation of
// the decompile's arithmetic + gate order; each HUD layer is drawn at its
// current frame through AepManager::drawLayer with the default transform. Field
// offsets (verified against 0x303fc): +0x9c9 m_isDemoPlay, +0x9e5 m_optEffectOn,
// +0x9e7 m_optOldHardware, +0x9ca m_isPadDisplay gate the HUD tiers; the layer
// ids/frame counts live in the +0x154/+0x168 (m_scoreBpm*) and +0xe4/+0x11c
// (m_effectState*) tables.
// @complete
void PlayTask::DrawHud() {
    NoteMng &nm = NoteMng::shared();
    AepManager &aep = AepManager::shared();

    // Beat phase: the current play position modulo the beat interval (both in ms).
    // 0x30428 casts NoteBeatIntervalMs() straight to int (vcvt.s32.f32, no scale).
    const int beat = (int)NoteBeatIntervalMs();
    const unsigned beatMod = (unsigned)beat;
    const int phase = (beat != 0) ? (int)((unsigned)nm.getCurrentPosition() % beatMod) : 0;
    const auto beatFrame = [&](int frmCount) -> int {
        return (beat != 0) ? (int)((unsigned)((frmCount - 1) * phase) / beatMod) : 0;
    };

    // Score gauge (skipped in the auto-demo), best gauge (effect-on only), combo gauge.
    if (!m_isDemoPlay) { // +0x9c9
        aep.drawLayer(m_scoreBpmLyr[0], beatFrame(m_scoreBpmFrames[0]), AepTransform(), 0);
    }
    if (m_optEffectOn) { // +0x9e5
        aep.drawLayer(m_scoreBpmLyr[1], beatFrame(m_scoreBpmFrames[1]), AepTransform(), 0);
    }
    aep.drawLayer(m_scoreBpmLyr[2], beatFrame(m_scoreBpmFrames[2]), AepTransform(), 0);

    if (!m_optEffectOn) {
        return;
    }
    if (m_optOldHardware) { // +0x9e7
        return;
    }

    // Fever gauge: below 70000 the lo layer's frame tracks the score; above it the
    // hi layer's frame tracks the beat phase. 0x30562 compares against 69999 with a
    // signed bgt (hi when score > 69999, i.e. score >= 70000).
    if (m_score < 70000) {
        aep.drawLayer(
            m_scoreBpmLyr[3], ((m_scoreBpmFrames[3] - 1) * m_score) / 70000, AepTransform(), 0);
    } else {
        aep.drawLayer(m_scoreBpmLyr[4], beatFrame(m_scoreBpmFrames[4]), AepTransform(), 0);
    }

    if (!m_optEffectOn) {
        return;
    }
    if (m_optOldHardware) {
        return;
    }

    // Gauge-overflow band once the score passes 10000, clamped to the last frame.
    if (m_score >= 10000) {
        const int last = m_effectStateFrames[9] - 1;
        int f = (last * (m_score - 10000)) / 60000;
        if (last < f) {
            f = last;
        }
        aep.drawLayer(m_effectStateLyr[9], f, AepTransform(), 0);
        if (!m_optEffectOn) {
            return;
        }
    }
    if (m_optOldHardware) {
        return;
    }
    if (m_isPadDisplay) { // +0x9ca — the scrub bar is phone-only
        return;
    }

    // Scrub / gauge bar: step m_scrubBarFrame one frame toward the gauge-derived
    // target (22.10 fixed), clamped to [0, last].
    const int last = m_effectStateFrames[10] - 1;
    const int target = (last * m_gaugeValue) >> 10;
    if (m_scrubBarFrame < target) {
        const int c = m_scrubBarFrame + 1;
        m_scrubBarFrame = (c < last) ? c : last;
    } else if (target < m_scrubBarFrame) {
        const int c = m_scrubBarFrame - 1;
        m_scrubBarFrame = (c < 0) ? 0 : c;
    }
    aep.drawLayer(m_effectStateLyr[10], m_scrubBarFrame, AepTransform(), 0);

    // Advance the fever-loop frame counter.
    m_cdColorFrame = (m_cdColorFrame + 1) % (m_effectStateFrames[11] - 1);
}

// Ghidra: PlayTask_update (FUN_0002dc14).
// @complete
void PlayTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    NoteMng &nm = NoteMng::shared();
    neGraphics &gfx = neGraphics::shared();

    // Snapshot up to 8 live touches (their x/y + ids) for the judge pass, and
    // detect a "back" tap (a released touch that barely moved).
    float touchXY[16];
    int touchIds[8];
    // 0x2dc70 memsets the 0x40-byte touchXY block to 0xff (each float becomes the
    // 0xffffffff sentinel), so unfilled lanes carry that pattern into the judge.
    std::memset(touchXY, 0xff, sizeof(touchXY));
    auto touchCount = 0uz;
    bool backTap = false;
    int backTapStartY = 0; // the back-tap's nStartY (Ghidra local_8c), used by the pause menu
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) { // a currently-down touch -> feed the judge
            if (touchCount < 8) {
                // The judge is fed each touch's current point (the +0x0c/+0x10 match
                // key). 0x2dc98/0x2dca0 load [+0xc]/[+0x10] and 0x2dca4/0x2dca8
                // convert them straight to float (vcvt.f32.s32, no fixed-point scale),
                // so the raw coordinates are stored as floats.
                touchXY[touchCount * 2] = (float)t->x;
                touchXY[touchCount * 2 + 1] = (float)t->y;
                touchIds[touchCount] = t->id;
                touchCount++;
            }
        } else if (!backTap && t->released != 0) { // a tap -> maybe the back button
            int dx = t->startX - t->x, dy = t->startY - t->y;
            backTap = (dx < 0 ? -dx : dx) < 0xb && (dy < 0 ? -dy : dy) < 0xb;
            if (backTap) {
                // 0x2dcee stores [+0x10] (t->y, the current point), not nStartY.
                backTapStartY = t->y;
            }
        }
    }

    switch (m_state) {
    case 0:
        PlayTaskInit(this); // FUN_0002e2d8: allocate the play scene
        m_state = 1;
        [[fallthrough]];
    case 1:                          // NoteMng bring-up + fade in + pause the intro layers
        nm.primePlay();              // Ghidra: NoteMng::ResetPlayback (FUN_0003396c)
        aep.setAepTransitionMode(1); // fade in (fixed 30 frames)
        m_comboLayers[4]->pause();   // Ghidra: AepLyrCtrl::Pause(pAepLyrMain[4])
        m_sceneLayers[3]->pause();   // Ghidra: AepLyrCtrl::Pause(pAepLyrSub[3])
        m_state = 2;
        [[fallthrough]];
    case 2:               // ready: reset playback + draw the field; on BGM-ready, cue the start
        if (m_bgmReady) { // +0x9c6 async BGM decode done
            [audio playSe:nil resourceId:m_playSeIds[0]]; // the "go" voice SE
            m_comboLayers[3]->stop(1); // Ghidra: AepLyrCtrl::Stop(pAepLyrMain[3])
            m_state = 4;
        }
        nm.primePlay();               // Ghidra: NoteMng::ResetPlayback
        playJudgeUpdate(nullptr, {}); // draw the field
        break;
    case 3: // retry: after the fade, rebuild the play and restart
        if (aep.isTransitionDone()) {
            aep.setAepTransitionMode(1); // fade back in
            resetState();                // Ghidra: playTaskResetState (FUN_0002fed8)
            m_state = 1;
        }
        break;
    case 4: // wait for the intro layer to finish, then start the clock -> playing
        if (!m_comboLayers[3]->isAnimating()) { // Ghidra: !AepLyrCtrl::IsPlaying(pAepLyrMain[3])
            nm.startClock();                    // Ghidra: NoteMng::ResetTiming (FUN_000344c4)
            m_state = 6;
        } else {
            nm.primePlay(); // Ghidra: NoteMng::ResetPlayback
            playJudgeUpdate(nullptr, {});
        }
        break;
    case 5: { // pause menu: hit-test resume / retry / quit, then draw the menu + field
        if (backTap) {
            const float scale = m_uiScale;
            // 0x2de40 halves the pause-menu x origin (+0x978), not the UI scale.
            const int half = m_pauseOriginX / 2;
            const float tapY = (float)backTapStartY / 65536.0f;
            // Each stacked button spans [pos + half, pos + half + width], scaled by
            // the UI scale, and is hit-tested against the tap's start Y (Ghidra:
            // FixedToFP(pos + half) * scale <= FixedToFP(local_8c)).
            const auto inBand = [&](int pos) -> bool {
                const float lo = (float)(pos + half) / 65536.0f * scale;
                const float hi = (float)(pos + half + m_pauseBtnWidth) / 65536.0f * scale;
                return lo <= tapY && tapY <= hi;
            };
            if (inBand(m_pauseBtnResumeX)) { // resume: unpause and resume play
                nm.togglePause();            // Ghidra: NoteMng::TogglePause
                m_state = 6;                 // the decompile re-enters state 6 at once
                break;
            }
            if (inBand(m_pauseBtnRetryX)) { // retry: fade out and rebuild the play
                aep.setAepTransitionMode(2);
                m_state = 3;
                break;
            }
            if (inBand(m_pauseBtnQuitX)) { // quit: stop audio and go to results
                m_state = 7;
                break;
            }
        }
        aep.drawLayer(0 /*+0xf8*/, 0, AepTransform(), 0); // the pause-menu layer
        nm.update(); // Ghidra: NoteMng::Update — keep the notes scrolling behind
        playJudgeUpdate(nullptr, {});
        break;
    }
    case 6: {               // *** PLAYING ***: drive the note engine, then judge/render, gauge,
                            // song-end
        nm.updatePlaying(); // Ghidra: FUN_00033fc0 — spawn/judge/retire/scroll +
                            // BGM drift sync
        playJudgeUpdate(touchXY, {touchIds, touchCount});

        // Cache the current gauge/score for the end-of-song rank SEs. Ghidra:
        // FUN_0002ff7c.
        m_score = PlayCurrentScore();

        // Advance the fever-hi HUD frame (wraps at its length, +0x138).
        if (m_effectStateFrames[7] != 0) {
            m_barStarFrame = (m_barStarFrame + 1) % m_effectStateFrames[7];
        }

        // Song-end: once every note has been judged (isFinished), latch the end
        // position and, ~1s later, fire the score-tier voice SE + the rank cascade
        // exactly once (m_endSeFired latch, +0x9c8; skipped in the auto-demo).
        if (!m_endSeFired && nm.isFinished()) {
            int pos = nm.getCurrentPosition();
            if (m_endPos == 0) {
                m_endPos = pos;
            }
            if (!m_isDemoPlay && (unsigned)(pos - m_endPos) > 999) {
                m_endSeFired = true;
                // The score-tier voice: below 70000 the low voice (+0x3b0), else the
                // high voice (+0x3ac).
                const int voice = (m_score < 70000) ? m_playSeIds[2] : m_playSeIds[1];
                [audio playSe:nil resourceId:voice];
                PlayEndResultSe(this, m_score); // the rank / clear jingle cascade
            }
        }

        // Advance the CD-jacket HUD frame by two (wraps at its length, +0x14c).
        {
            int f = m_cdFrame + 2;
            if (m_effectStateFrames[12] <= f) {
                f = 0;
            }
            m_cdFrame = f;
        }

        if (!g_bDemoPlayMode) {
            // Normal play: pause by pressing the pause hit-circle and holding ~500ms.
            if (m_backTouchId == -1) {
                if (touchCount > 0) {
                    const float scale = m_uiScale;
                    const int cx = (int)((float)m_pauseTapCenterX * scale);
                    const int cy = (int)((float)m_pauseTapCenterY * scale);
                    const int r = (int)((float)m_pauseTapRadius * scale);
                    // 0x2e278/0x2e264 convert touchXY[0]/[1] straight back to int
                    // (vcvt.s32.f32, no fixed-point scale) to match the raw floats
                    // stored in the snapshot above.
                    const int tx = (int)touchXY[0];
                    const int ty = (int)touchXY[1];
                    if (pointInCircle(tx, ty, cx, cy, r)) {
                        m_backTouchId = touchIds[0];
                        m_backTouchTime = (int)getTimeMillis();
                    }
                }
            } else if (gfx.findTouchById(m_backTouchId) == nullptr) {
                m_backTouchId = -1; // the finger lifted before the hold completed
            } else if ((unsigned)((int)getTimeMillis() - m_backTouchTime) > 500) {
                m_backTouchId = -1;
                nm.onResignActivePushHook(); // freeze the notes
                m_state = 5;                 // open the pause menu
            }
            break;
        }

        // Auto-demo (title attract): hand off to the fade-out ~3s after the song ends.
        if (m_endPos != 0 && (unsigned)(nm.getCurrentPosition() - m_endPos) >= 3000) {
            m_state = 8;
        }
        break;
    }
    case 7: // quit: stop all audio, latch the stopped flag, and fall through to the
        // fade-out. 0x2df7a stores 1 to m_stopped (+0x9e8) after stopAll.
        [audio stopAll];
        m_stopped = 1;
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
            PlayTaskGotoResult(this);
        }
        break;
    default:
        break;
    }

    // Per-frame tail (Ghidra 0x2dc14): advance + draw the AEP layers (draw-only
    // while the pause menu is up, state 5), then draw the HUD unless the task is
    // already tearing down (m_suppressHud, +0x9c7).
    AepLyrCtrl::updateAndDrawAepLayers(m_state == 5 ? 1 : 0); // Ghidra: FUN_0002c924
    if (!m_suppressHud) {
        DrawHud();
    }
}
