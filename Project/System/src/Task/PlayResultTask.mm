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

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainViewController.h"
#import "SeInstance.h"
#import "TaskFactory.h"
#import "neEngineBridge.h"
#import "neGraphics.h"

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
        // Set up the result data, then bring the BGM in at the returned fade.
        [audio playBgm:resultSetup()];   // FUN_0003dfe0
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

// Ghidra: FUN_0003d5bc call site in PlayTaskGotoResult (operator_new(0x3a0)).
C_TASK *PlayResultCreateTask() {
    return new PlayResultTask();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
