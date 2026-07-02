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

// The result screen this play hands off to (its own unit). Ghidra: FUN_0003003c.
extern void PlayTaskGotoResult(void *playData);
// Build the play scene — Aep layers, gauge, note field (Ghidra: PlayTask_init
// FUN_0002e2d8). Its own reconstruction unit.
extern void PlayTaskInit(void *playData);

namespace {
inline int &state(PlayTask *t) {   // play-data state @ +0x9fc
    return *reinterpret_cast<int *>(reinterpret_cast<char *>(t) + 0x9fc);
}
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
        state(this) = 6;
        break;
    case 5:   // pause menu: hit-test resume / retry / quit; draw the pause layer
        aep.drawLayer(0 /*+0xf8*/, 0, AepTransform(), 0);
        PlayJudge_update(playData, nullptr, nullptr, 0);
        return;
    case 6: {   // *** PLAYING ***: run the note judge/render pass, then combo SE etc.
        PlayJudge_update(playData, touchXY, touchIds, touchCount);
        // Combo-milestone SEs, gauge update, and song-end detection follow (they read
        // the current position via NoteMng::getCurrentPosition and the tally).
        (void)nm; (void)audio;
        if (backTap) {   // pause: freeze the play and open the menu
            NoteMng::shared().onResignActivePushHook();
            state(this) = 5;
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

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
