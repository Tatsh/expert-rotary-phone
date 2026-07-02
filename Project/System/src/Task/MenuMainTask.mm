//
//  MenuMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (MenuMainTask_update
//  FUN_0006ad88). The interactive mode-select hub. Objective-C++ (drives UIKit nav
//  through the root view controller and the ObjC managers).
//
//  Scope: the verified ~20-state control flow and the mode-button dispatch. The
//  per-button screen rectangles (task fields +0x94..+0x19c) and the individual
//  play/tutorial/arcade/sugoroku sub-task constructors are referenced as seams —
//  each is its own reconstruction unit (see HANDOFF).
//

#import <UIKit/UIKit.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "MenuMainTask.h"
#import "MusicManager.h"
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"

// The root nav host (MainViewController) the menu drives.
static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

// The play / tutorial / arcade / sugoroku sub-tasks the menu launches come from the
// task factory; the menu button hit-test and input-mode set come from the engine
// bridge. (TaskFactory.h / neEngineBridge.h imported above.)

// Ghidra: MenuMainTask_ctor (FUN_0006aba0) — base C_TASK ctor + zeroed fields.
MenuMainTask::MenuMainTask() = default;

// Ghidra: MenuMainTask_setInfoFlag (FUN_0006d194) @ +0x1ac.
void MenuMainTask::setInfoFlag(bool shown) {
    m_infoFlag = shown;
}

// Ghidra: FUN_0006c6a4 — build the menu scene (title/menu AepLyrCtrl layers, button
// rectangles, SE ids). Modelled as a seam; the layer + rect setup is its own unit.
void MenuMainTask::setup() {
    // (Loads the menu Aep layers into +0x28/+0x2c/+0x30 and fills the button rects.)
}

// Ghidra: MenuMainTask_update (FUN_0006ad88). Each frame: find a tapped touch, then
// step the state machine. The interactive menu lives in state 0xc.
void MenuMainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];
    AudioManager *audio = [AudioManager sharedManager];
    UIViewController *root = RootVC();

    // A released touch that barely moved is a tap (its scaled position is logged).
    neGraphics &gfx = neGraphics::shared();
    int touchId = -1;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t == nullptr || t->released == 0) {
            continue;
        }
        int dx = t->startX - t->x, dy = t->startY - t->y;
        if ((dx < 0 ? -dx : dx) < 0xb && (dy < 0 ? -dy : dy) < 0xb) {
            touchId = t->id;
            break;
        }
    }

    switch (m_state) {
    case 0:   // build the scene, start BGM, fetch news if it is stale
        setup();
        [audio playBgm:0];
        if (/* NEAppEventCenter last news date */ true) {
            [dl setCppDelegateNews:this];
            [dl startNewsHttp];
        }
        m_state = 1;
        break;
    case 1:   // fade in, request the player record, play the menu layer
        aep.playTransition(1, 1, 0);
        [dl startPlayerGetHttp];
        if (!m_tutorialSkip) {
            // AepLyrCtrl at +0x30 plays here (menu intro).
        }
        m_state = 2;
        break;
    case 2:   // await the player record, then branch on whether a name is set
        if (![dl isPlayerGetDownLoading]) {
            [root DeleteCommunicating];
            BOOL needName = [UserSettingData playerId] == nil ||
                            [UserSettingData playerName] == nil ||
                            [dl errorGetPlayer] == 1;
            m_state = needName ? 3 : 4;
        }
        break;
    case 3:   // no player name yet -> the name-entry screen
        [root GotoInPlayerName];
        m_state = 4;
        break;
    case 4:   // hand the reward network its session parameters
        // RewardNetwork setSessionParameters:url:method: (ad/reward SDK — neutralized).
        m_state = 5;
        break;
    case 5:   // wait for the intro SE, then reveal the menu
        m_state = 8;
        break;
    case 6:   // unlock gates: invite present, bemani-collabo music, etc.
        // (Grants chara tickets / opens collabo + invite music per UserSettingData
        // counters, shows a CommonAlertView, then falls through to state 7.)
        m_state = 7;
        break;
    case 8:   // once-a-day official-info web view, then login-bonus check
        m_state = m_infoFlag ? 10 : 6;
        break;
    case 10:  // login bonus (LoginBonusView / RandomLoginBonusView), then interactive
        m_state = 6;
        break;
    case 0xc: {   // *** interactive main menu — hit-test the mode buttons ***
        if (touchId < 0) {
            break;
        }
        // Play (standard): launch the tutorial task on a first play, else the play
        // task; the exact rect is at +0x128 (seam).
        if (hitButton(touchId, 0x128, 300)) {
            [audio playSe:0 resourceId:0];
            if (!m_tutorialSkip) {
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = TutorialTaskCreate();
            } else {
                m_spawnedTask = MainTaskCreate();
            }
            m_state = 0x12;
        } else if (hitButton(touchId, 0x158, 0x15c)) {   // arcade
            m_spawnedTask = AcMainTaskCreate();
            m_state = 0x12;
        } else if (hitButton(touchId, 0x148, 0x14c)) {   // friend
            [root GotoFriendManage];
            m_state = 0x11;
        } else if (hitButton(touchId, 0x138, 0x13c)) {   // store
            [[DownloadMain getInstance] setIsNewMusicPackReleased:NO];
            [root GotoStoreButton];
            m_state = 0x11;
        } else if (hitButton(touchId, 0x168, 0x16c)) {   // pop'n link
            [root GotoPopnLink];
            m_state = 0x11;
        } else if (hitButton(touchId, 0x178, 0x17c)) {   // invite
            neEngine::setInputMode([UserSettingData playerName] != nil ? 0 : 2);
            [root GotoInviteCode];
            m_state = 0x11;
        } else if (hitButton(touchId, 0x188, 0x18c)) {   // present box / arcade search
            neEngine::setInputMode(1);
            [root GotoPresentBox];
            m_state = 0x11;
        } else if (hitButton(touchId, 0x198, 0x19c)) {   // sugoroku / map
            m_spawnedTask = SugorokuMainTaskCreate();
            m_state = 0x12;
        } else if (hitButton(touchId, 0x98, 0x94)) {     // settings
            m_state = 0xd;
        }
        break;
    }
    case 0xd:   // settings screen
        neEngine::setInputMode(1);
        [root GotoSetting];
        m_state = 0xe;
        break;
    case 0xe:   // wait for settings to close; relaunch the title on request
        if (![root settingViewing]) {
            if ([root isGotoTitle] == 1) {
                m_spawnedTask = TitleTaskCreate();       // spawn a fresh TitleTask
                m_state = 0x12;
            } else {
                m_state = 0xc;
            }
        }
        break;
    case 0x11:  // wait for the pushed screen to close, then re-enter the menu
        if (![root IsPresentBoxEnable] && ![root IsInviteCodeEnable] &&
            ![root IsArcadeSearchEnable] && ![root IsStoreEnable] &&
            ![root IsPopnLinkEnable] && ![root IsFriendManageEnable]) {
            m_state = 0xc;
        }
        break;
    case 0x12:  // fade out into the launched sub-task
        aep.playTransition(2, 1, 0);
        m_state = 0x13;
        break;
    case 0x13:
        if (aep.isTransitionDone()) {
            m_state = 0x14;
        }
        break;
    case 0x14:  // hand off: kill this task once its SEs finish and the sub-task runs
        // (When no menu SE is still playing, tear down via FUN_0006d1f0.)
        break;
    default:
        break;
    }

    // Per-frame menu UI update + draw (Ghidra tail: FUN_0002c924 / FUN_0006d428).
}

// Ghidra: FUN_0002d974 — hit-test a button whose screen rectangle (4 ints: x,y,w,h)
// and enable flag live at byte offsets rectField / enableField within this task.
bool MenuMainTask::hitButton(int touchId, int rectField, int enableField) {
    const char *base = reinterpret_cast<const char *>(this);
    const int *rect = reinterpret_cast<const int *>(base + rectField);
    const int *enable = reinterpret_cast<const int *>(base + enableField);
    return neEngine::menuButtonHit(&neGraphics::shared(), touchId, rect, enable);
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
