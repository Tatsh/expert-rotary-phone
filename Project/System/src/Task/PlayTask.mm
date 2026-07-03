//
//  PlayTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (PlayTask_update
//  FUN_0002dc14). The note-play state machine; the verified state flow + the judge
//  hand-off. Field offsets into the play data are cited (see PlayJudge.h).
//

#import "AepManager.h"
#import "AudioManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"
#import "PlayTask.h"
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
