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
#import "neTextureForiOS.h"

// The root nav host (MainViewController) the menu drives.
static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

// The menu's baseline Y (the screen height cached in the Aep manager @ +0x7f3b00);
// the top-row button rects are placed relative to it. Ghidra: FUN_0000f4a4.
static int AepBaselineY(AepManager &aep) {
    return *reinterpret_cast<int *>(reinterpret_cast<char *>(&aep) + 0x7f3b00);
}

// The per-frame menu overlay pass (Ghidra: FUN_0006d428): the friend-request warning
// badge, the "new music pack" / event badges, and the always-on mode-button labels,
// each pulsed by a triangle-wave phase counter at +0xec. Task fields are reached by
// raw offset, matching hitButton()'s reinterpret_cast<char *>(this) convention.
static void MenuDrawOverlay(MenuMainTask *self) {
    char *base = reinterpret_cast<char *>(self);
    auto I = [&](int off) -> int { return *reinterpret_cast<int *>(base + off); };
    auto B = [&](int off) -> bool { return *reinterpret_cast<unsigned char *>(base + off) != 0; };

    if (B(0xb4)) {   // +0xb4: overlay suppressed while the task is tearing down
        return;
    }
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];

    // Attention pulse: 100 for the first 0x32 frames, then a triangle wave; the phase
    // at +0xec advances by 2 modulo 0x97 each frame.
    int phase = I(0xec);
    int pulse = phase < 0x32 ? 100 : (phase < 100 ? 200 - phase * 2 : phase * 2 - 200);
    *reinterpret_cast<int *>(base + 0xec) = (phase + 2) % 0x97;

    // Friend-request warning badge (a bundled texture at +0x4c, not an Aep layer):
    // drawn straight into the ordering table, faded by the pulse.
    if ([dl friendRequestedCnt] > 0) {
        neTextureForiOS *warn = *reinterpret_cast<neTextureForiOS **>(base + 0x4c);
        neSpriteDrawParams p;
        p.x = I(0x120); p.y = I(0x124);
        p.sx = I(0xac); p.sy = I(0xb0);
        p.color = pulse;
        p.priority = 0xc;
        warn->draw(aep.orderingTable(), p);
    }

    // The Aep frame-sprite badges/labels. Their handles (group << 16 | index) were
    // resolved in setup(); position comes from the matching rect field, priority 0xc
    // for the pulsing badges and 0xd for the static button labels. In the engine the
    // pulse feeds each sprite's colour (Ghidra: FUN_0000fcd0's fade args).
    AepTransform xform;

    if ([dl isNewMusicPackReleased]) {              // "new music pack" badge (+0x38)
        xform.x = I(0x108); xform.y = I(0x10c); xform.priority = 0xc;
        aep.drawLayer(I(0x38), 0, xform, 0);
    }
    if (B(0xb7) && B(0xb5)) {                        // treasure-event badge (+0x48)
        xform.x = I(0x110); xform.y = I(0x114); xform.priority = 0xc;
        aep.drawLayer(I(0x48), 0, xform, 0);
    }
    if (B(0xb8) && B(0xb5)) {                        // game-event badge (+0x48)
        xform.x = I(0x118); xform.y = I(0x11c); xform.priority = 0xc;
        aep.drawLayer(I(0x48), 0, xform, 0);
    }

    xform.x = I(0x88); xform.y = I(0x84); xform.priority = 0xd;   // settings label (+0x3c)
    aep.drawLayer(I(0x3c), 0, xform, 0);
    xform.x = I(0x8c); xform.y = I(0x84); xform.priority = 0xd;   // store label (+0x40)
    aep.drawLayer(I(0x40), 0, xform, 0);
    if (B(0xb6)) {                                                // gift label (+0x44)
        xform.x = I(0x90); xform.y = I(0x84); xform.priority = 0xd;
        aep.drawLayer(I(0x44), 0, xform, 0);
    }
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

// Ghidra: FUN_0006c6a4 — build the menu scene: pick the device layout, fill every
// per-button screen rect + SE id, then load the mode-select Aep group and its three
// animated layers, the warning texture and the menu BGM. Undeclared task fields are
// written by raw offset, matching hitButton()'s reinterpret_cast<char *>(this) style.
void MenuMainTask::setup() {
    char *base = reinterpret_cast<char *>(this);
    auto rect = [&](int off) -> int & { return *reinterpret_cast<int *>(base + off); };

    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    const int baseY = AepBaselineY(aep);

    m_tutorialSkip = [UserSettingData isTutorialPlayed];   // +0xb5

    // The scene-manager device flag (DAT_00187b84) splits phone vs iPad; within phone,
    // displayType 2 (the tall 1136 screen) shifts several rects down by 0x50 px.
    const bool isPad = neSceneManager::isPadDisplay();
    const char *layerNames[3];
    const char *sceneGroup;

    if (!isPad) {
        const bool tall = (AppDelegate.appDelegate.displayType == 2);
        const int yoff = tall ? 0x50 : 0;
        rect(0xe8) = yoff;
        rect(0x84) = baseY - 0x3c; rect(0x88) = 8;         rect(0x8c) = 0xa6;  rect(0x90) = 0x144;
        rect(0xa4) = 0xa3;         rect(0xa8) = 0x4b;
        rect(0x94) = baseY - 0x4b; rect(0x98) = 0;         rect(0x9c) = 0xa3;  rect(0xa0) = 0x146;
        rect(0xf4) = 0x5b;         rect(0xf8) = 0xb;       rect(0xfc) = 0x21e; rect(0x100) = 100;
        rect(0x104) = 0x14;        rect(0x108) = 0x1b;
        rect(0x10c) = yoff + 0x2d4; rect(0x110) = 0x15c;   rect(0x114) = yoff + 0x11c;
        rect(0x118) = 0x30;        rect(0x11c) = yoff | 0x8c;
        rect(0x128) = 0x30;        rect(0x12c) = yoff + 0x39; rect(0x130) = 0x132; rect(0x134) = 300;
        rect(0x138) = 0x1f;        rect(0x13c) = yoff + 0x262; rect(0x140) = 0xc9; rect(0x144) = 0xd2;
        rect(0x148) = 0xff;        rect(0x14c) = yoff + 0x1f2; rect(0x150) = 0xca; rect(0x154) = 0xcc;
        rect(0x158) = 0x16c;       rect(0x15c) = yoff + 0xe8;  rect(0x160) = 0xfa; rect(0x164) = 0x14e;
        rect(0x168) = 0x16c;       rect(0x16c) = yoff | 0x2d;  rect(0x170) = 0xfa; rect(0x174) = 0xb9;
        rect(0x178) = 0xe;         rect(0x17c) = yoff + 0x16f; rect(0x180) = 0xf6; rect(0x184) = 0xe3;
        rect(0x188) = 0xf1;        rect(0x18c) = yoff + 0x2df; rect(0x190) = 0x99; rect(0x194) = 0x99;
        rect(0x198) = 0x1a1;       rect(0x19c) = yoff + 0x24a; rect(0x1a0) = 0xe7; rect(0x1a4) = 0xdf;
        rect(0x120) = 0x18b;       rect(0x124) = yoff | 0x206;
        rect(0xac) = 0x2a;         rect(0xb0) = 0x2a;
        sceneGroup    = "mode_select";
        layerNames[0] = tall ? "BG_IMG_1136_OPEN" : "BG_IMG_640_OPEN";
        layerNames[1] = tall ? "BG_IMG_1136_ROOP" : "BG_IMG_640_ROOP";
        layerNames[2] = tall ? "TRY_1136" : "TRY_960";
    } else {
        rect(0xe8) = 0;
        rect(0x84) = baseY - 0x71; rect(0x88) = 0x1e;      rect(0x8c) = 0x10d; rect(0x90) = 0x1fc;
        rect(0xa4) = 0xef;         rect(0xa8) = 0x82;
        rect(0x94) = baseY - 0x80; rect(0x98) = 0x14;      rect(0x9c) = 0x103; rect(0xa0) = 0x1f2;
        rect(0xf4) = 0x80;         rect(0xf8) = 0xb;       rect(0xfc) = 0x540; rect(0x100) = 100;
        rect(0x104) = 0x37;        rect(0x108) = 0x348;    rect(0x10c) = 0x492; rect(0x110) = 0x2da;
        rect(0x114) = 0x172;       rect(0x118) = 0x76;     rect(0x11c) = 0x118;
        rect(0x128) = 0x76;        rect(0x12c) = 0x5a;     rect(0x130) = 0x284; rect(0x134) = 0x272;
        rect(0x138) = 0x326;       rect(0x13c) = 0x3ac;    rect(0x140) = 0x1cc; rect(0x144) = 0x1c2;
        rect(0x148) = 0x118;       rect(0x14c) = 0x2d4;    rect(0x150) = 500;   rect(0x154) = 0x1de;
        rect(0x158) = 0x310;       rect(0x15c) = 0x1ac;    rect(0x160) = 0x244; rect(0x164) = 0x1f8;
        rect(0x168) = 0x3f0;       rect(0x16c) = 0x57b;    rect(0x170) = 0x202; rect(0x174) = 0x15a;
        rect(0x178) = 0x22;        rect(0x17c) = 0x4d4;    rect(0x180) = 0x226; rect(0x184) = 0x20d;
        rect(0x188) = 0x4a8;       rect(0x18c) = 0x52;     rect(0x190) = 0x188; rect(0x194) = 0x154;
        rect(0x198) = 0x24d;       rect(0x19c) = 0x5b4;    rect(0x1a0) = 0x1a4; rect(0x1a4) = 0x1bd;
        rect(0x120) = 0x274;       rect(0x124) = 0x2e8;
        rect(0xac) = 0x56;         rect(0xb0) = 0x56;
        sceneGroup    = "mode_select_ipad";
        layerNames[0] = "BG_IMG_PAD_OPEN";
        layerNames[1] = "BG_IMG_PAD_ROOP";
        layerNames[2] = "TRY_PAD";
    }

    // Load the mode-select Aep group into slot 2 and bring up its three animated
    // layers: [0] intro (+0x28), [1] looping background (+0x2c), [2] prompt (+0x30).
    AepLoadGroup(&aep, 2, sceneGroup);
    for (int i = 0; i < 3; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        layer->init(2, layerNames[i]);
        *reinterpret_cast<AepLyrCtrl **>(base + 0x28 + i * 4) = layer;
    }

    // Overlay handles the draw pass reads: the NEWS ticker (+0x34) plus five badge /
    // button-label frame sprites (+0x38..+0x48). (Ghidra resolves these via getUsrNo /
    // getFrmNo; getLyrNo yields the same group<<16|index handle drawLayer consumes.)
    static const char *const kBadgeNames[5] = {
        "NEWS", "BT_SETTING", "NEW_STORE", "BT_GIFT", "BT_FEATU",
    };
    rect(0x34) = aep.getLyrNo(2, "NEWS");
    for (int i = 0; i < 5; i++) {
        rect(0x38 + i * 4) = aep.getLyrNo(2, kBadgeNames[i]);
    }

    // The friend-request warning texture (a bundled PNG drawn straight into the OT).
    neTextureForiOS *warn = new neTextureForiOS();
    *reinterpret_cast<neTextureForiOS **>(base + 0x4c) = warn;
    NSString *warnPath = [[NSBundle mainBundle] pathForResource:@"vie_cmn_warning@2x"
                                                         ofType:@"png"];
    warn->load([warnPath UTF8String]);

    // Menu BGM (looping) at the saved volume.
    NSString *bgmPath = [[AppDelegate appAppSupportDirectory]
        stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];

    // The six UI SEs (group 1): keep each source id at +0x50.. and clear its playing
    // instance slot at +0x68.. (RSND_INSTANCE_ID_ERROR).
    static const char *const kSeNames[6] = { "v13", "v14", "v15", "v16", "v17", "v12" };
    for (int i = 0; i < 6; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:@(kSeNames[i]) ofType:@"m4a"];
        RSND_SOURCE_ID sid = [audio loadSe:sePath isLoop:NO callName:nil group:1];
        rect(0x50 + i * 4) = static_cast<int>(sid);
        rect(0x68 + i * 4) = static_cast<int>(RSND_INSTANCE_ID_ERROR);
    }

    // The news-text array copy, reward-banner query, and treasure/game-event unlock
    // scan follow in FUN_0006c6a4; they belong to the news / reward seam and populate
    // the +0xc0.. news cache and the +0xb7/+0xb8 event flags the draw pass reads.
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

    // Per-frame menu UI update + draw, run after every state (Ghidra tail: FUN_0002c924
    // then FUN_0006d428). First advance + enqueue every live Aep layer — the three menu
    // layers this task linked into the global list via AepLyrCtrl::init — then emit the
    // menu's own overlay sprites through the AepManager.
    for (int i = 0; i < 3; i++) {   // +0x28 intro / +0x2c loop bg / +0x30 prompt
        AepLyrCtrl *layer =
            *reinterpret_cast<AepLyrCtrl **>(reinterpret_cast<char *>(this) + 0x28 + i * 4);
        if (layer != nullptr && layer->isVisible()) {
            layer->draw();   // Ghidra: FUN_0002c924 per-layer advance + enqueue
        }
    }
    MenuDrawOverlay(this);   // Ghidra: FUN_0006d428
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
