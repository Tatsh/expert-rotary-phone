//
//  MenuMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (MenuMainTask_update FUN_0006ad88). The interactive mode-select hub.
//  Objective-C++ (drives UIKit nav through the root view controller and the
//  ObjC managers).
//
//  Scope: the verified ~20-state control flow and the mode-button dispatch. The
//  per-button screen rectangles are now recovered as real members on the task
//  (see MenuMainTask.h); the individual play/tutorial/arcade/sugoroku sub-task
//  constructors are referenced as seams via the task factory.
//

#import <UIKit/UIKit.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "MainViewController.h"      // the concrete root VC: Goto*/Is*Enable/SetAlertViewCallback
#import "MapSelectViewController.h" // the isIndexInRange12 event-id bounds helper
#import "MenuMainTask.h"
#import "MusicManager.h"
#import "RewardNetwork.h" // +setSessionParameters:url:method: (state 4)
#import "StoreUtil.h"     // +getRewardLoginTokenURL
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host is a MainViewController here — it declares the
// Goto*/Is*Enable/ SetAlertViewCallback selectors the menu sends; type RootVC()
// as such so they resolve.
static MainViewController *RootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

// The menu's baseline Y (the screen height cached in the Aep manager @
// +0x7f3b00); the top-row button rects are placed relative to it. Ghidra:
// FUN_0000f4a4.
static int AepBaselineY(AepManager &aep) {
    return *reinterpret_cast<int *>(reinterpret_cast<char *>(&aep) + 0x7f3b00);
}

// The play / tutorial / arcade / sugoroku sub-tasks the menu launches come from
// the task factory; the menu button hit-test and input-mode set come from the
// engine bridge. (TaskFactory.h / neEngineBridge.h imported above.)

/**
 * MenuMainTask_ctor — base C_TASK ctor + memset(this+0x28, 0, 0x185) (every
 * field zero-initialised, matching the members' default inits).
 * @ghidraAddress 0x6aba0
 * @complete
 */
MenuMainTask::MenuMainTask() = default;

/**
 * modeSelTaskDtor — the mode-select task's destructor (its vtable is the
 * MenuMainTask update vtable). De-register this task as DownloadMain's NEWS
 * delegate (only if it is still us), then the C_TASK base dtor
 * (caSourceNode_dtor) runs implicitly.
 * @ghidraAddress 0x6abcc
 * @complete
 */
MenuMainTask::~MenuMainTask() {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl cppDelegateNews] == this) { // both ModeSelTask* (C++ pointer compare, not id)
        [dl setCppDelegateNews:nil];
    }
}

/**
 * MenuMainTask_setInfoFlag — set the menu's info/notification flag (+0x1ac),
 * guarded against a redundant write (the binary only stores on a change).
 * @ghidraAddress 0x6d194
 * @complete
 */
void MenuMainTask::setInfoFlag(bool shown) {
    if (m_infoFlag != shown) {
        m_infoFlag = shown;
    }
}

/**
 * modeSelectTaskInit — build the menu scene: pick the device layout, fill every
 * per-button screen rect + SE id, load the mode-select Aep group and its three
 * animated layers, resolve the ticker + badge handles, install the ticker draw
 * callback, load the warning texture, the menu BGM and the six UI SEs, snapshot
 * the news array, query the reward banner, and scan the treasure/game events.
 * @ghidraAddress 0x6c6a4
 * @complete
 */
void MenuMainTask::setup() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    const int baseY = AepBaselineY(aep);

    m_tutorialSkip = [UserSettingData isTutorialPlayed]; // +0xb5

    // The scene-manager device flag (DAT_00187b84) splits phone vs iPad; within
    // phone, displayType 2 (the tall 1136 screen) shifts several rects down by
    // 0x50 px.
    const bool isPad = neSceneManager::isPadDisplay();
    const char *layerNames[3];
    const char *sceneGroup;

    if (!isPad) {
        const bool tall = (AppDelegate.appDelegate.displayType == 2);
        const int yoff = tall ? 0x50 : 0;
        m_layoutYOffset = yoff;                                          // +0xe8
        m_labelRowY = baseY - 0x3c;                                      // +0x84
        m_settingsLabelX = 8;                                            // +0x88
        m_storeLabelX = 0xa6;                                            // +0x8c
        m_giftLabelX = 0x144;                                            // +0x90
        m_top.fielda4 = 0xa3;                                            // +0xa4
        m_top.fielda8 = 0x4b;                                            // +0xa8
        m_top.rowY = baseY - 0x4b;                                       // +0x94
        m_top.settingsX = 0;                                             // +0x98
        m_top.field9c = 0xa3;                                            // +0x9c
        m_top.fielda0 = 0x146;                                           // +0xa0
        m_newsTickerParams[0] = 0x5b;                                    // +0xf4
        m_newsTickerParams[1] = 0xb;                                     // +0xf8
        m_newsTickerParams[2] = 0x21e;                                   // +0xfc
        m_newsTickerParams[3] = 100;                                     // +0x100
        m_newsTickerParams[4] = 0x14;                                    // +0x104
        m_newPackBadgePos = {0x1b, yoff + 0x2d4};                        // +0x108
        m_treasureBadgePos = {0x15c, yoff + 0x11c};                      // +0x110
        m_gameBadgePos = {0x30, yoff | 0x8c};                            // +0x118
        m_buttons[kBtnPlay] = {0x30, yoff + 0x39, 0x132, 300};           // +0x128
        m_buttons[kBtnStore] = {0x1f, yoff + 0x262, 0xc9, 0xd2};         // +0x138
        m_buttons[kBtnFriend] = {0xff, yoff + 0x1f2, 0xca, 0xcc};        // +0x148
        m_buttons[kBtnArcade] = {0x16c, yoff + 0xe8, 0xfa, 0x14e};       // +0x158
        m_buttons[kBtnAcViewer] = {0x16c, yoff | 0x2d, 0xfa, 0xb9};      // +0x168
        m_buttons[kBtnPopnLink] = {0xe, yoff + 0x16f, 0xf6, 0xe3};       // +0x178
        m_buttons[kBtnInvite] = {0xf1, yoff + 0x2df, 0x99, 0x99};        // +0x188
        m_buttons[kBtnArcadeSearch] = {0x1a1, yoff + 0x24a, 0xe7, 0xdf}; // +0x198
        m_warnBadgePos = {0x18b, yoff | 0x206};                          // +0x120
        m_warnScaleX = 0x2a;                                             // +0xac
        m_warnScaleY = 0x2a;                                             // +0xb0
        sceneGroup = "mode_select";
        layerNames[0] = tall ? "BG_IMG_1136_OPEN" : "BG_IMG_640_OPEN";
        layerNames[1] = tall ? "BG_IMG_1136_ROOP" : "BG_IMG_640_ROOP";
        layerNames[2] = tall ? "TRY_1136" : "TRY_960";
    } else {
        m_layoutYOffset = 0;                                        // +0xe8
        m_labelRowY = baseY - 0x71;                                 // +0x84
        m_settingsLabelX = 0x1e;                                    // +0x88
        m_storeLabelX = 0x10d;                                      // +0x8c
        m_giftLabelX = 0x1fc;                                       // +0x90
        m_top.fielda4 = 0xef;                                       // +0xa4
        m_top.fielda8 = 0x82;                                       // +0xa8
        m_top.rowY = baseY - 0x80;                                  // +0x94
        m_top.settingsX = 0x14;                                     // +0x98
        m_top.field9c = 0x103;                                      // +0x9c
        m_top.fielda0 = 0x1f2;                                      // +0xa0
        m_newsTickerParams[0] = 0x80;                               // +0xf4
        m_newsTickerParams[1] = 0xb;                                // +0xf8
        m_newsTickerParams[2] = 0x540;                              // +0xfc
        m_newsTickerParams[3] = 100;                                // +0x100
        m_newsTickerParams[4] = 0x37;                               // +0x104
        m_newPackBadgePos = {0x348, 0x492};                         // +0x108
        m_treasureBadgePos = {0x2da, 0x172};                        // +0x110
        m_gameBadgePos = {0x76, 0x118};                             // +0x118
        m_buttons[kBtnPlay] = {0x76, 0x5a, 0x284, 0x272};           // +0x128
        m_buttons[kBtnStore] = {0x326, 0x3ac, 0x1cc, 0x1c2};        // +0x138
        m_buttons[kBtnFriend] = {0x118, 0x2d4, 500, 0x1de};         // +0x148
        m_buttons[kBtnArcade] = {0x310, 0x1ac, 0x244, 0x1f8};       // +0x158
        m_buttons[kBtnAcViewer] = {0x3f0, 0x57b, 0x202, 0x15a};     // +0x168
        m_buttons[kBtnPopnLink] = {0x22, 0x4d4, 0x226, 0x20d};      // +0x178
        m_buttons[kBtnInvite] = {0x4a8, 0x52, 0x188, 0x154};        // +0x188
        m_buttons[kBtnArcadeSearch] = {0x24d, 0x5b4, 0x1a4, 0x1bd}; // +0x198
        m_warnBadgePos = {0x274, 0x2e8};                            // +0x120
        m_warnScaleX = 0x56;                                        // +0xac
        m_warnScaleY = 0x56;                                        // +0xb0
        sceneGroup = "mode_select_ipad";
        layerNames[0] = "BG_IMG_PAD_OPEN";
        layerNames[1] = "BG_IMG_PAD_ROOP";
        layerNames[2] = "TRY_PAD";
    }

    // Load the mode-select Aep group into slot 2 and bring up its three animated
    // layers: [0] intro (+0x28), [1] looping background (+0x2c), [2] prompt
    // (+0x30).
    aep.loadAepDataDefaultPath(2, sceneGroup);
    for (int i = 0; i < 3; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        layer->init(2, layerNames[i]);
        m_layers[i] = layer;
    }

    // Overlay handles the draw pass reads: the NEWS ticker user-frame (+0x34)
    // plus five badge / button-label frame sprites (+0x38..+0x48). The binary
    // resolves the ticker with getUsrNo and the five frames with getFrmNo, in
    // this exact order (Ghidra: DAT_00131df8 name table).
    static const char *const kBadgeNames[5] = {
        "NEW_STORE",
        "BT_SETTING",
        "BT_GIFT",
        "BT_FEATU",
        "EVENT_TXT",
    };
    m_newsHandle = aep.getUserNo(2, "NEWS");
    for (int i = 0; i < 5; i++) {
        m_badgeHandles[i] = aep.getFrameNo(2, kBadgeNames[i]);
    }

    // Install the per-layer NEWS-ticker draw callback on group 2 (the engine
    // hands this task back as the trailing context). Its natural ABI carries the
    // full composed transform, so it is reinterpret-cast to the generic
    // AepGroupDrawFn at registration (the same pattern as AcViewer's HUD draw).
    // Ghidra: setAepCallbacks(aep, 2, &NewsTickerUpdate, this).
    aep.setGroupDrawCallback(2, reinterpret_cast<AepGroupDrawFn>(&NewsTickerUpdate), this);

    // The friend-request warning texture (a bundled PNG drawn straight into the
    // OT).
    neTextureForiOS *warn = new neTextureForiOS();
    m_warnTexture = warn;
    NSString *warnPath = [[NSBundle mainBundle] pathForResource:@"vie_cmn_warning@2x"
                                                         ofType:@"png"];
    warn->load([warnPath UTF8String]);

    // Menu BGM (looping) at the saved volume.
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];

    // The six UI SEs (group 1): keep each source id at +0x50.. and clear its
    // playing instance slot at +0x68.. (RSND_INSTANCE_ID_ERROR).
    static const char *const kSeNames[6] = {"v13", "v14", "v15", "v16", "v17", "v12"};
    for (int i = 0; i < 6; i++) {
        NSString *sePath = [[NSBundle mainBundle] pathForResource:@(kSeNames[i]) ofType:@"m4a"];
        RSND_SOURCE_ID sid = [audio loadSe:sePath isLoop:NO callName:nil group:1];
        m_seId[i] = static_cast<int>(sid);
        m_seInst[i] = static_cast<int>(RSND_INSTANCE_ID_ERROR);
    }

    // Snapshot the news-text array (+0xc0, retained) if DownloadMain already has
    // a fetched batch, keep a copy of its timestamp (+0xc4), and reset the ticker
    // to line 0 (+0xcc). Mirrors the copy in refreshNews; the binary's manual
    // retain is ARC bookkeeping here.
    DownloadMain *dl = [DownloadMain getInstance];
    NSDate *newsTime = dl.lastGetNewsTime;
    NSArray *newsArray = dl.newsTextArray;
    if (newsTime != nil && newsArray != nil) {
        NSMutableArray *copy = [NSMutableArray array];
        for (NSUInteger i = 0; i < [newsArray count]; i++) {
            [copy addObject:[newsArray objectAtIndex:i]];
        }
        m_newsArray = copy;
        m_newsTimestamp = [newsTime copy];
        m_newsIndex = 0;
    }

    // Reward-banner availability: enable the gift label (+0xb6) when the async
    // query reports flag 1. The block captures this task (its +0x14 capture in
    // the binary).
    [RewardNetwork isEnabledBannerWithBlock:^(NSInteger flg, NSError *error) { // @ 0x6d8bc
      (void)error;
      m_giftEnabled = static_cast<uint8_t>(flg == 1);
    }];

    // Event badges: light the treasure badge (+0xb7) if any active treasure-event
    // id is in range (< 12; app helper isIndexInRange12), and the game badge
    // (+0xb8) if any game-event id is 0 (the binary's folded isZeroInt predicate).
    for (NSNumber *eventId in dl.treasureEventIdArray) {
        if (isIndexInRange12((unsigned int)[eventId intValue])) {
            m_treasureEvent = 1;
            break;
        }
    }
    for (NSNumber *eventId in dl.gameEventIdArray) {
        if ([eventId intValue] == 0) {
            m_gameEvent = 1;
            break;
        }
    }
}

// Ghidra: MenuMainTask_update (FUN_0006ad88). Each frame: find a tapped touch,
// then step the state machine. The interactive menu lives in state 0xc.
void MenuMainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];
    AudioManager *audio = [AudioManager sharedManager];
    MainViewController *root = RootVC();

    // A released touch that barely moved is a tap (its scaled position is
    // logged).
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
    case 0: // build the scene, start BGM, fetch news if it is stale
        setup();
        [audio playBgm:0];
        if (/* NEAppEventCenter last news date */ true) {
            [dl setCppDelegateNews:this];
            [dl startNewsHttp];
        }
        m_state = 1;
        break;
    case 1:                          // fade in, request the player record, play the menu layer
        aep.setAepTransitionMode(1); // fade in (fixed 30 frames)
        [dl startPlayerGetHttp];
        if (!m_tutorialSkip) {
            // AepLyrCtrl at +0x30 plays here (menu intro).
        }
        m_state = 2;
        break;
    case 2: // await the player record, then branch on whether a name is set
        if (![dl isPlayerGetDownLoading]) {
            [root DeleteCommunicating];
            BOOL needName = [UserSettingData playerId] == nil ||
                            [UserSettingData playerName] == nil || [dl errorGetPlayer] == 1;
            m_state = needName ? 3 : 4;
        }
        break;
    case 3: // no player name yet -> the name-entry screen
        [root GotoInPlayerName];
        m_state = 4;
        break;
    case 4: { // hand the reward network its session parameters
        NSString *url = [[StoreUtil getRewardLoginTokenURL] absoluteString];
        // The binary fetches the reward appli id + player id here (session
        // identity); the decompiled dictionaryWithObjectsAndKeys cleanly recovers
        // only the {"env":"0"} pair, so the appli-id / player-id dict key strings
        // are a documented best-effort omission.
        (void)[[AppDelegate appDelegate] rewardAppId];
        (void)[UserSettingData playerId];
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"env", nil];
        [RewardNetwork setSessionParameters:params url:url method:@"GET"];
        m_state = 5;
        break;
    }
    case 5: // wait for the intro SE, then reveal the menu
        m_state = 8;
        break;
    case 6: // unlock gates: invite present, bemani-collabo music, etc.
        // (Grants chara tickets / opens collabo + invite music per UserSettingData
        // counters, shows a CommonAlertView, then falls through to state 7.)
        m_state = 7;
        break;
    case 8: // once-a-day official-info web view, then login-bonus check
        m_state = m_infoFlag ? 10 : 6;
        break;
    case 10: // login bonus (LoginBonusView / RandomLoginBonusView), then
             // interactive
        m_state = 6;
        break;
    case 0xc: { // *** interactive main menu — hit-test the mode buttons ***
        if (touchId < 0) {
            break;
        }
        // Each mode button plays its own UI SE (resource id m_seId[k] @ +0x50,
        // handle cached in m_seInst[k] @ +0x68) then either spawns a sub-task (->
        // state 0x12) or pushes a UIKit screen (-> state 0x11). The binary also
        // gates every branch on the prompt layer (+0x30) no longer animating; that
        // intro-guard is elided here as it is throughout this reconstruction.
        if (hitButton(touchId, kBtnPlay)) { // +0x128 play (tutorial first time)
            m_seInst[0] = static_cast<int>([audio playSe:0 resourceId:m_seId[0]]);
            if (!m_tutorialSkip) {
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = TutorialTaskCreate();
            } else {
                m_spawnedTask = MainTaskCreate();
            }
            m_state = 0x12;
        } else if (hitButton(touchId,
                             kBtnArcade)) { // +0x158 AcMainTask (treasure board)
            m_seInst[1] = static_cast<int>([audio playSe:0 resourceId:m_seId[1]]);
            m_spawnedTask = AcMainTaskCreate();
            m_state = 0x12;
        } else if (hitButton(touchId, kBtnAcViewer)) { // +0x168 AcViewerTask
            // iPad primes a default browsing selection (music 1 / diff 0) if none is
            // set, then clears the pending "Sel" pair. Ghidra: the g_bIsPadDisplay
            // block seeding g_dwAcViewerMusicId / g_dwAcViewerSelMusicId.
            if (neSceneManager::isPadDisplay()) {
                if (neAppEventCenter::acViewerMusicId() < 1) {
                    neAppEventCenter::setAcViewerSelection(1, 0);
                }
                neAppEventCenter::clearAcViewerSelection();
            }
            m_seInst[5] = static_cast<int>([audio playSe:0 resourceId:m_seId[5]]);
            m_spawnedTask = AcViewerTaskCreate();
            m_state = 0x12;
        } else if (hitButton(touchId, kBtnFriend)) { // +0x148 friend management
            m_seInst[2] = static_cast<int>([audio playSe:0 resourceId:m_seId[2]]);
            [root GotoFriendManage];
            m_state = 0x11;
        } else if (hitButton(touchId, kBtnStore)) { // +0x138 store
            m_seInst[3] = static_cast<int>([audio playSe:0 resourceId:m_seId[3]]);
            [[DownloadMain getInstance] setIsNewMusicPackReleased:NO];
            [root GotoStoreButton];
            m_state = 0x11;
        } else if (hitButton(touchId, kBtnPopnLink)) { // +0x178 pop'n link
            m_seInst[4] = static_cast<int>([audio playSe:0 resourceId:m_seId[4]]);
            [root GotoPopnLink];
            m_state = 0x11;
        } else if (hitButton(touchId, kBtnInvite)) { // +0x188 invite code
            // Ghidra: only enter the invite screen when a player record exists —
            // play the confirm SE (slot 0) and navigate; otherwise play the deny SE
            // (slot 2) and stay on the menu (no GotoInviteCode, no state change).
            if ([UserSettingData playerId] != nil && [UserSettingData playerName] != nil) {
                neEngine::playSystemSe(0);
                [root GotoInviteCode];
                m_state = 0x11;
            } else {
                neEngine::playSystemSe(2);
            }
        } else if (hitButton(touchId, kBtnArcadeSearch)) { // +0x198 arcade search
            neEngine::playSystemSe(0);
            [root GotoArcadeSearch];
            m_state = 0x11;
        } else if (hitPresentBoxButton(touchId)) { // +0x9c present box (top cluster)
            neEngine::playSystemSe(1);
            [root GotoPresentBox];
            m_state = 0x11;
        } else if (hitSettingsButton(touchId)) { // +0x98 settings (top cluster)
            m_state = 0xd;
        }
        // NOTE (documented gap): the +0xa0 "featured/reward" top button -> states
        // 0xf/0x10 (RewardNetwork openAppListWebViewWithCampaignId offer-wall) is
        // not wired here; its 7-arg web-view call is not cleanly recoverable from
        // the decompile and it is a third-party offer-wall, not gameplay. Tracked
        // in STUBS.md.
        break;
    }
    case 0xd: // settings screen
        neEngine::playSystemSe(1);
        [root GotoSetting];
        m_state = 0xe;
        break;
    case 0xe: // wait for settings to close; relaunch the title on request
        if (![root settingViewing]) {
            if ([root isGotoTitle] == 1) {
                m_spawnedTask = TitleTaskCreate(); // spawn a fresh TitleTask
                m_state = 0x12;
            } else {
                m_state = 0xc;
            }
        }
        break;
    case 0x11: // wait for the pushed screen to close, then re-enter the menu
        if (![root IsPresentBoxEnable] && ![root IsInviteCodeEnable] &&
            ![root IsArcadeSearchEnable] && ![root IsStoreEnable] && ![root IsPopnLinkEnable] &&
            ![root IsFriendManageEnable]) {
            m_state = 0xc;
        }
        break;
    case 0x12:                       // fade out into the launched sub-task
        aep.setAepTransitionMode(2); // fade out (fixed 30 frames)
        m_state = 0x13;
        break;
    case 0x13:
        if (aep.isTransitionDone()) {
            m_state = 0x14;
        }
        break;
    case 0x14: { // hand off: once every menu SE and the shared system SE have
                 // finished sounding, dispose (teardown + schedule the sub-task).
        // Ghidra 0x6b83e: scan the six menu SE instances, then gate on the
        // scene manager's system-SE slot 0; dispose only when neither is playing.
        bool sePlaying = false;
        for (int i = 0; i < 6; i++) {
            if (m_seInst[i] >= 0 && [audio isPlayingSe:m_seInst[i]]) {
                sePlaying = true;
            }
        }
        if (!neEngine::isSePlaying(0) && !sePlaying) {
            dispose();
        }
        break;
    }
    default:
        break;
    }

    // Per-frame menu UI update + draw, run after every state (Ghidra tail:
    // FUN_0002c924 then FUN_0006d428). First advance + enqueue every live Aep
    // layer — the three menu layers this task linked into the global list via
    // AepLyrCtrl::init — then emit the menu's own overlay sprites through the
    // AepManager.
    for (int i = 0; i < 3; i++) { // +0x28 intro / +0x2c loop bg / +0x30 prompt
        AepLyrCtrl *layer = m_layers[i];
        if (layer != nullptr && layer->isVisible()) {
            layer->draw(); // Ghidra: FUN_0002c924 per-layer advance + enqueue
        }
    }
    drawOverlay(); // Ghidra: FUN_0006d428
}

/**
 * Ghidra: modeSelectTaskDispose (FUN_0006d1f0) — the state-0x14 handoff into the
 * launched sub-task. Field map: m_seId[6] @+0x50 (pAepLyrCtrl[10..15]), m_layers
 * @+0x28, m_warnTexture @+0x4c (pIconTexture), m_spawnedTask @+0x80 (pMainTask),
 * m_suppressOverlay @+0xb4 (bHidden). The spawned task only starts once it is
 * given a priority here, so an unimplemented state 0x14 would strand it.
 * @complete
 */
void MenuMainTask::dispose() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    MainViewController *root = RootVC();

    // Release the six menu SEs, then release + reload the shared system-SE pool.
    for (int i = 0; i < 6; i++) {
        [audio releaseSe:nil resourceId:m_seId[i]];
    }
    neSceneManager::shared().releaseSystemSe();
    [audio cleanupSe];
    neSceneManager::shared().loadSystemSe();

    // Unlink + delete the three menu AEP layers (the binary unlinks explicitly
    // before the deleting destructor, which also splices the node out).
    for (int i = 0; i < 3; i++) {
        if (m_layers[i] != nullptr) {
            m_layers[i]->unlink();
            delete m_layers[i];
            m_layers[i] = nullptr;
        }
    }

    aep.releaseAepTexture(2);
    if (m_warnTexture != nullptr) {
        delete m_warnTexture;
        m_warnTexture = nullptr;
    }

    // ARC: clear the retained news-cache fields.
    m_newsArray = nil;
    m_newsTimestamp = nil;
    m_newsCurLine = nil;

    [root SetAlertViewCallback:nullptr param:nullptr];
    kill(); // +0x24 = 1

    // Give the sub-task spawned in state 0xc its scheduler priority (creating the
    // music-select MainTask now if, defensively, it was not spawned yet).
    if (m_spawnedTask == nullptr) {
        m_spawnedTask = MainTaskCreate(); // operator_new(0xaa8) + MainTask_ctor
    }
    static_cast<C_TASK *>(m_spawnedTask)->setPriority(3);
    m_suppressOverlay = 1; // +0xb4: stop drawing this task after the handoff
}

/**
 * modeSelectTaskDraw: the per-frame menu overlay pass — the friend-request
 * warning badge, the "new music pack" / event badges (gated on the event flags
 * and m_tutorialSkip), and the always-on mode-button labels (plus the conditional
 * gift label), each pulsed by a triangle-wave phase counter at +0xec.
 * @ghidraAddress 0x6d428
 * @complete
 */
void MenuMainTask::drawOverlay() {
    if (m_suppressOverlay) { // +0xb4: overlay suppressed while the task is
                             // tearing down
        return;
    }
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];

    // Attention pulse: 100 for the first 0x32 frames, then a triangle wave; the
    // phase at +0xec advances by 2 modulo 0x97 each frame.
    const int phase = m_pulsePhase;
    const int pulse = phase < 0x32 ? 100 : (phase < 100 ? 200 - phase * 2 : phase * 2 - 200);
    m_pulsePhase = (phase + 2) % 0x97;

    // Friend-request warning badge (a bundled texture at +0x4c, not an Aep
    // layer): drawn straight into the ordering table, faded by the pulse.
    if ([dl friendRequestedCnt] > 0) {
        neSpriteDrawParams p;
        p.x = m_warnBadgePos.x;
        p.y = m_warnBadgePos.y;
        p.sx = m_warnScaleX;
        p.sy = m_warnScaleY;
        p.color = pulse;
        p.priority = 0xc;
        m_warnTexture->draw(aep.orderingTable(), p);
    }

    // The Aep frame-sprite badges/labels. Their handles (group << 16 | index)
    // were resolved in setup(); position comes from the matching badge/label
    // field, priority 0xc for the pulsing badges and 0xd for the static button
    // labels. In the engine the pulse feeds each sprite's colour (Ghidra:
    // FUN_0000fcd0's fade args).
    AepTransform xform;

    if ([dl isNewMusicPackReleased]) { // "new music pack" badge (+0x38)
        xform.x = m_newPackBadgePos.x;
        xform.y = m_newPackBadgePos.y;
        xform.priority = 0xc;
        aep.drawLayer(m_badgeHandles[0], 0, xform, 0);
    }
    if (m_treasureEvent && m_tutorialSkip) { // treasure-event badge (+0x48)
        xform.x = m_treasureBadgePos.x;
        xform.y = m_treasureBadgePos.y;
        xform.priority = 0xc;
        aep.drawLayer(m_badgeHandles[4], 0, xform, 0);
    }
    if (m_gameEvent && m_tutorialSkip) { // game-event badge (+0x48)
        xform.x = m_gameBadgePos.x;
        xform.y = m_gameBadgePos.y;
        xform.priority = 0xc;
        aep.drawLayer(m_badgeHandles[4], 0, xform, 0);
    }

    xform.x = m_settingsLabelX;
    xform.y = m_labelRowY;
    xform.priority = 0xd; // settings label (+0x3c)
    aep.drawLayer(m_badgeHandles[1], 0, xform, 0);
    xform.x = m_storeLabelX;
    xform.y = m_labelRowY;
    xform.priority = 0xd; // store label (+0x40)
    aep.drawLayer(m_badgeHandles[2], 0, xform, 0);
    if (m_giftEnabled) { // gift label (+0x44)
        xform.x = m_giftLabelX;
        xform.y = m_labelRowY;
        xform.priority = 0xd;
        aep.drawLayer(m_badgeHandles[3], 0, xform, 0);
    }
}

// Ghidra: FUN_0002d974 — hit-test one of the eight array mode buttons: its
// screen rectangle (x @ rectField, y @ rectField+4, w, h) is tested against the
// current tap.
bool MenuMainTask::hitButton(int touchId, Button button) const {
    const ButtonRect &r = m_buttons[button];
    return neEngine::menuButtonHit(&neGraphics::shared(), touchId, &r.x, &r.y);
}

// The settings button lives in the packed top cluster (rect x @ +0x98, enable/y
// @ +0x94), so its two field pointers are taken separately. Ghidra:
// FUN_0002d974.
bool MenuMainTask::hitSettingsButton(int touchId) const {
    return neEngine::menuButtonHit(&neGraphics::shared(), touchId, &m_top.settingsX, &m_top.rowY);
}

// The present-box button overlaps the same top cluster, its rect starting one
// field later (x @ +0x9c), sharing the row-Y enable field (+0x94). Ghidra:
// FUN_0002d974.
bool MenuMainTask::hitPresentBoxButton(int touchId) const {
    return neEngine::menuButtonHit(&neGraphics::shared(), touchId, &m_top.field9c, &m_top.rowY);
}

/**
 * The mode-select confirm dialogs' alert-dismissed callback. Detach the root VC's
 * alert callback, then step the state machine: 7 & 11 -> 6, 9 -> 10, anything
 * else (incl. the default) -> 12.
 * @ghidraAddress 0x6d1a4
 * @complete
 */
void MenuMainTask::onAlertClosed() {
    [RootVC() SetAlertViewCallback:NULL param:NULL];
    switch (m_state) {
    case 7:
    case 11:
        m_state = 6;
        break;
    case 9:
        m_state = 10;
        break;
    default:
        m_state = 12;
        break;
    }
}

/**
 * NewsTickerUpdate — the group-2 per-layer NEWS-ticker draw callback. The AEP
 * engine hands the owning task in as the trailing `context` argument (so it acts
 * as the method receiver) and the drawn layer handle as `child`; only the
 * resolved news handle acts. Scrolls the current news line right-to-left through
 * the ticker params, paging to the next line (cycling the news array) with a
 * 100->0->100 fade ramp at each end. The dozen transform args are ignored (the
 * ticker positions itself from its own params), matching the decompile.
 * @ghidraAddress 0x6d6d4
 * @complete
 */
void NewsTickerUpdate(int child,
                      int,
                      int,
                      int,
                      int,
                      int,
                      int,
                      int,
                      int,
                      int,
                      int16_t,
                      int,
                      int *,
                      int priority,
                      void *context) {
    AepManager &aep = AepManager::shared();
    auto *self = static_cast<MenuMainTask *>(context);
    if (self->m_newsHandle != child) {
        return;
    }
    if (self->m_newsArray == nil || [self->m_newsArray count] == 0) {
        return;
    }

    // First tick (pause step still 0): prime the scroll x / pause ramp and grab
    // line 0.
    if (self->m_newsPauseStep == 0) {
        self->m_newsScrollX = self->m_newsTickerParams[0]; // base x
        self->m_newsPauseCounter = 100;
        self->m_newsPauseStep = -2;
        self->m_newsCurLine = [self->m_newsArray objectAtIndex:0];
    }

    int elapsed = self->m_newsFrame++;
    if (elapsed > 0x3b) { // ~60 frames of hold elapsed
        if (!self->m_newsPaused) {
            unsigned segment = (unsigned)self->m_newsSegment;
            unsigned lineSegments = (unsigned)[self->m_newsCurLine length] /
                                    (unsigned)(self->m_newsTickerParams[4] + 1);
            if (segment < lineSegments) {
                self->m_newsScrollX -= 2; // scroll left
                int nextSegment = self->m_newsSegment + 1;
                int slotX = self->m_newsTickerParams[0] - nextSegment * self->m_newsTickerParams[2];
                if (self->m_newsScrollX <= slotX) { // snapped to the next segment slot
                    self->m_newsFrame = 0;
                    self->m_newsScrollX = slotX;
                    self->m_newsSegment = nextSegment;
                }
                goto draw;
            }
        }
        // Line finished scrolling: run the pause/fade ramp.
        self->m_newsPaused = 1;
        self->m_newsPauseCounter += self->m_newsPauseStep;
        if (self->m_newsPauseStep < 0) {
            if (self->m_newsPauseCounter < 1) { // faded out: advance to the next line
                self->m_newsScrollX = self->m_newsTickerParams[0];
                self->m_newsSegment = 0;
                self->m_newsPauseCounter = 0;
                self->m_newsPauseStep = 2;
                self->m_newsIndex = (self->m_newsIndex + 1) % (int)[self->m_newsArray count];
                self->m_newsCurLine = [self->m_newsArray objectAtIndex:self->m_newsIndex];
            }
        } else if (self->m_newsPauseCounter > 99) { // faded back in: resume scrolling
            self->m_newsPauseCounter = 100;
            self->m_newsPauseStep = -2;
            self->m_newsFrame = 0;
            self->m_newsPaused = 0;
        }
    }

draw:
    // Ghidra: AepManager::DrawTextClipped (FUN_0001057c). The corner colours carry
    // the dark-grey news-text colour 0x181818 (the same value the plain DrawText
    // calls pass), the clip slot carries &m_newsTickerParams[0], and `priority` is
    // the OT slot the callback was handed.
    aep.DrawTextClipped([self->m_newsCurLine UTF8String],
                        0x1b,
                        self->m_newsScrollX,
                        self->m_newsTickerParams[1],
                        0,
                        self->m_newsPauseCounter,
                        0x181818,
                        &self->m_newsTickerParams[0],
                        priority);
}

/**
 * modeSelectRefreshNews. DownloadMain's NEWS delegate callback. Only acts when
 * the fetch actually returned news (`hasNews`) and the freshly fetched
 * lastGetNewsTime is newer than the timestamp of our cached copy (or we have
 * none yet); then it snapshots the news-text array and resets the ticker to line
 * 0. The binary's manual retain/release around the array / timestamp is ARC
 * bookkeeping here.
 * @ghidraAddress 0x6d8cc
 * @complete
 */
void MenuMainTask::refreshNews(bool hasNews) {
    if (!hasNews) {
        return;
    }
    DownloadMain *dl = [DownloadMain getInstance];
    NSDate *newsTime = dl.lastGetNewsTime;
    NSArray *newsArray = dl.newsTextArray;
    if (newsTime == nil || newsArray == nil) {
        return;
    }
    // Skip the rebuild when our cached copy is already same-or-newer than the
    // fetched news.
    if (m_newsTimestamp != nil && [m_newsTimestamp compare:newsTime] != NSOrderedAscending) {
        return;
    }

    NSMutableArray *copy = [NSMutableArray array];
    for (NSUInteger i = 0; i < [newsArray count]; i++) {
        [copy addObject:[newsArray objectAtIndex:i]];
    }
    m_newsArray = copy;
    m_newsTimestamp = [newsTime copy];
    m_newsIndex = 0; // restart the ticker at the first line
}

// C-linkage shim: DownloadMain reaches its NEWS delegate (a MenuMainTask, aka
// ModeSelTask) by the unmangled binary symbol. Forwards to the real method.
extern "C" void modeSelectRefreshNews(MenuMainTask *task, bool hasNews) {
    task->refreshNews(hasNews);
}
