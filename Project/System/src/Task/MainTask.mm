//
//  MainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (MainTask_update
//  FUN_00035914). Structural reconstruction of the standard-mode music-select state
//  machine — the verified state flow, manager calls, and navigation.
//

#import <UIKit/UIKit.h>

#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "DownloadMain.h"
#import "MainTask.h"
#import "TaskFactory.h"
#import "MusicManager.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"

static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

// PlayTaskCreate / TutorialTaskCreate come from TaskFactory.h.

// Ghidra: MainTask_ctor (FUN_00034d48) — base C_TASK ctor + zeroed 0xaa8 play data.
MainTask::MainTask() = default;

// Ghidra: MainTask_update (FUN_00035914) — the standard-mode music-select machine.
void MainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    DownloadMain *dl = [DownloadMain getInstance];
    UIViewController *root = RootVC();

    switch (m_state) {
    case 0:   // setup: BGM at the saved volume + kick off the recommend-list fetch
        [audio setBgmVolume:[UserSettingData bgmVolume]];
        [audio playBgm:0];
        [dl setCppDelegateRecommendList:this];
        [dl startGetRecommendListHttp];
        m_state = 1;
        break;
    case 1:   // fade in the select scene
        aep.playTransition(1, 1, 0);
        m_state = 2;
        break;
    case 2:   // interactive song / menu select: on a tap, launch a song's play task
        //   (tutorial on first play), or open the recommend list.
        if (![dl isGetRecommendListDownLoading]) {
            // Hit-test the song/menu buttons (Ghidra FUN_0002d974) and dispatch:
            //   - a song row -> preview + state 3
            //   - the recommend button -> [root GotoRecommend:...]
            //   - first play -> saveIsTutorialPlayed + spawn TutorialTaskCreate.
        }
        break;
    case 3:   // a song was chosen: preview its BGM + load the player's ScoreData
        [audio pushBgm];
        // MusicManager isInviteMusic:/isOpenInviteMusic: gate; ScoreData fetched via
        // getScoreData:inManagedObjectContext: for the best-score display.
        m_state = 4;
        break;
    case 4:   // difficulty/option select + BGM preview loop
        if (![audio isPlayingBgm]) {
            [audio seekBgmToTop];
            [audio setBgmVolume:[UserSettingData bgmVolume]];
            [audio playBgm:0];
        }
        // On the play button: spawn the note-play task and fade out (state 0xe).
        break;
    case 5:   // options -> settings
        neSceneSetInputMode(1);
        [root GotoSetting];
        m_state = 6;
        break;
    case 6:   // wait for settings to close; relaunch title on request
        if (![root settingViewing]) {
            m_state = ([root isGotoTitle] == 1) ? 0xe : 2;
        }
        break;
    case 7:   // sort
        [root GotoSortSelect:nullptr];
        m_state = 2;
        break;
    case 9:   // over-score (friend score) log
        [root GotoOverScoreLog:nullptr];
        m_state = 2;
        break;
    case 0xe:   // fade out into the spawned task / title
        aep.playTransition(2, 1, 0);
        m_state = 0xf;
        break;
    case 0xf:
        if (aep.isTransitionDone()) {
            m_state = 0x10;
        }
        break;
    case 0x10:  // handoff: tear down once the select SEs finish
        break;
    default:
        break;
    }

    // Per-frame select-screen UI update + draw (Ghidra tail).
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
