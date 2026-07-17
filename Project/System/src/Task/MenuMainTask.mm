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
#import "CustomWebView.h" // the daily official-info web panel (state 8)
#import "DownloadMain.h"
#import "LoginBonusView.h"
#import "MainViewController.h"      // the concrete root VC: Goto*/Is*Enable/SetAlertViewCallback
#import "MapSelectViewController.h" // the isIndexInRange12 event-id bounds helper
#import "MenuMainTask.h"
#import "MusicManager.h"
#import "RandomLoginBonusView.h"
#import "RewardNetwork.h" // +setSessionParameters:url:method: (state 4)
#import "StoreUtil.h"     // +getRewardLoginTokenURL
#import "TaskFactory.h"
#import "UserSettingData.h"
#import "neDebugLog.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// The root nav host is a MainViewController here — it declares the
// Goto*/Is*Enable/ SetAlertViewCallback selectors the menu sends; type RootVC()
// as such so they resolve.
static MainViewController *RootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

/**
 * The menu's baseline Y: the AEP manager's cached canvas height (+0x7f3b00),
 * relative to which the top-row button rects are placed. Reads it through the
 * manager's screenHeight() accessor rather than a raw offset.
 * @ghidraAddress 0xf4a4
 * @complete
 */
static int AepBaselineY(AepManager &aep) {
    return aep.screenHeight();
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
    // hands this task back as the trailing context). NewsTickerUpdate has the
    // AepGroupDrawFn signature exactly, so it registers without a cast.
    // Ghidra: setAepCallbacks(aep, 2, &MenuMainTask::NewsTickerUpdate, this).
    aep.setGroupDrawCallback(2, &MenuMainTask::NewsTickerUpdate, this);

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

/**
 * MenuMainTask_update — the mode-select hub's ~20-state machine. Each frame:
 * detect a tap, step the current state, then advance every live AEP layer and
 * emit the menu overlay. State 0 setup + news fetch; 1 fade-in + player-get; 2
 * await the player record + name check; 3 name entry; 4 reward session; 5 intro
 * hand-off; 6 unlock gates; 8 daily info; 10 login bonus; 0xc INTERACTIVE menu;
 * 0xd..0x14 the sub-task spawn + fade-out + teardown.
 * @ghidraAddress 0x6ad88
 * @complete
 */
void MenuMainTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    DownloadMain *dl = [DownloadMain getInstance];
    AudioManager *audio = [AudioManager sharedManager];

    // Tap detection: the first released touch whose start/end differ by < 11px in
    // both axes. Its down point is logged in the (screen-scale-divided) layout
    // coordinate space the button rects live in.
    neGraphics &gfx = neGraphics::shared();
    const float uiScale = neSceneManager::screenScale();
    int tapX = -1, tapY = -1;
    bool haveTap = false;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->released == 0) {
            continue;
        }
        // Tap-vs-drag slop 0xb (Ghidra @ 0x6ad88), widened to pixels under
        // ENABLE_PATCHES for modern iOS sub-pixel touch. See NE_TAP_SLOP.
        const int dx = t->x - t->startX, dy = t->y - t->startY;
        if ((dx < 0 ? -dx : dx) < NE_TAP_SLOP(0xb) && (dy < 0 ? -dy : dy) < NE_TAP_SLOP(0xb)) {
            // startX/startY are 16.16 fixed device pixels (touchBegan stores
            // FloatToFixed). The binary converts them to float via FixedToFP
            // (i.e. / 65536) before dividing by the UI scale; a plain (float)
            // cast skips that and yields ~pixel * 65536, so the tap misses every
            // button rect. Ghidra: FixedToFP(nStartX) / g_dwUiScale @ ~0x6aec0.
            tapX = (int)(t->startX / 65536.0f / uiScale);
            tapY = (int)(t->startY / 65536.0f / uiScale);
            neDebugLog("MenuMain tap=(%d,%d) state=%d", tapX, tapY, m_state);
            NSLog(@"%d %d", tapX, tapY);
            haveTap = true;
            break;
        }
    }

    switch (m_state) {
    case 0: // build the scene, start the BGM, refresh the news if it is stale
        setup();
        [audio playBgm:0];
        {
            // Fetch news when there is no session start stamp yet, or more than an
            // hour (3600s) has elapsed since it.
            id startDate = neAppEventCenter::shared().sessionStartDate();
            bool stale = startDate == nil;
            if (!stale) {
                NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startDate];
                stale = (int)((float)elapsed / 3600.0f) > 0;
            }
            if (stale) {
                [dl setCppDelegateNews:this];
                [dl startNewsHttp];
            }
        }
        m_state = 1;
        break;
    case 1:                          // fade in, request the player record, start the intro layers
        aep.setAepTransitionMode(1); // fade in (fixed 30 frames)
        [dl startPlayerGetHttp];
        // Ghidra @ 0x6b00e: the open animation uses AepLyrCtrl::Play (play once,
        // FUN_0002cac0), NOT the looping AepLyrCtrl_play — it must reach the held
        // state so state 5's !isAnimating() gate fires and the menu turns
        // interactive. The prompt/background layers below keep the looping play().
        m_layers[0]->playOnce(); // the open animation (+0x28), one-shot
        if (!m_tutorialSkip) {
            m_layers[2]->play(); // the prompt / "TRY" layer (+0x30), looping
        }
        m_state = 2;
        break;
    case 2: { // await the player record, then branch on whether a name is set
        MainViewController *root = RootVC();
        if (![dl isPlayerGetDownLoading]) {
            [root DeleteCommunicating];
            BOOL needName = [UserSettingData playerId] == nil ||
                            [UserSettingData playerName] == nil || [dl errorGetPlayer] == 1;
            m_state = needName ? 3 : 4;
            // Once the daily-info flag is enabled, re-derive it from the
            // player-get result (error 99 = not-yet-known disables it).
            if (m_infoFlag) {
                bool enabled = [dl errorGetPlayer] != 99;
                if (m_infoFlag != enabled) {
                    m_infoFlag = enabled;
                }
            }
        } else if (![root IsCommunicatingEnable] && [dl getPlayerGetProgressSec] > 1.0) {
            // Still downloading past a second: show the communicating spinner.
            [root InsertCommunicating];
        }
        break;
    }
    case 3: // no player name yet -> the name-entry screen
        [RootVC() GotoInPlayerName];
        m_state = 4;
        break;
    case 4: { // hand the reward network its session parameters
        NSString *url = [[StoreUtil getRewardLoginTokenURL] absoluteString];
        // The binary also folds the reward appli id + player id into the session
        // dictionary, but those __stdcall_softfp string args are lost in the
        // decompile; only the {"env": "0"} pair is recoverable. RewardNetwork is a
        // no-op stub here, so the exact dictionary is inert.
        (void)[[AppDelegate appDelegate] rewardAppId];
        (void)[UserSettingData playerId];
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"env", nil];
        [RewardNetwork setSessionParameters:params url:url method:@"GET"];
        m_state = 5;
        break;
    }
    case 5: // wait for the open layer to finish, then start the looping background
        if (!m_layers[0]->isAnimating()) {
            m_layers[0]->reset();
            m_layers[1]->play(); // the looping background (+0x2c)
            m_state = 8;
        }
        break;
    case 6: { // unlock gates, one per frame via m_unlockStep, then the interactive menu
        const int invitePresent = [UserSettingData invitePresent];
        const int inviteCnt = [UserSettingData inviteCnt];
        // The shared "you unlocked something" confirm dialog: wire its dismiss to
        // modeSelectAlertClosed, then show a tagged OK alert.
        auto showUnlockAlert = [&](NSString *title, NSString *message) {
            MainViewController *root = RootVC();
            [root SetAlertViewCallback:&MenuMainTask::modeSelectAlertClosed param:this];
            CommonAlertView *alert =
                [[CommonAlertView alloc] initWithTitle:title
                                               message:message
                                              delegate:(id<CommonAlertViewDelegate>)root
                                     cancelButtonTitle:nil
                                     otherButtonTitles:@"OK"];
            [alert setTag:1];
            [alert show];
        };
        switch (m_unlockStep) {
        case 0: // 3 invites -> 5 character tickets
            if (invitePresent <= 2 && inviteCnt >= 3) {
                [UserSettingData saveCharaTicket:(short)([UserSettingData charaTicket] + 5)];
                [UserSettingData saveInvitePresent:3];
                m_state = 7;
                showUnlockAlert(@"招待コード",
                                @"招待数 3人 達成！\nキャラチケットを５枚手に入れました！");
            }
            break;
        case 1: // 5 invites -> the N/H special charts
            if (invitePresent < 5 && inviteCnt >= 5) {
                [UserSettingData saveInvitePresent:5];
                [[MusicManager getInstance] openInviteMusic];
                m_state = 7;
                showUnlockAlert(@"招待コード",
                                @"招待数 5人 達成！\nスペシャル楽曲 [N/H譜面] が解禁されました！");
            }
            break;
        case 2: // 7 invites -> the Ex special chart
            if (invitePresent < 7 && inviteCnt >= 7) {
                [UserSettingData saveInvitePresent:7];
                [[MusicManager getInstance] openInviteMusic];
                m_state = 7;
                showUnlockAlert(@"招待コード",
                                @"招待数 7人 達成！\nスペシャル楽曲 [Ex譜面] が解禁されました！");
            }
            break;
        case 3: // the "start BEMANI on the app" collabo music
            if (![UserSettingData isBemaniCollaboOpened] &&
                [MusicManager isOpenBemaniCollaboMusic]) {
                [UserSettingData saveIsBemaniCollaboOpened:YES];
                [[MusicManager getInstance] openCollaboMusic];
                m_state = 7;
                showUnlockAlert(
                    nil, @"アプリでビーマニはじめようキャンペーン！\n限定楽曲が解禁されました！");
            }
            break;
        default:
            break;
        }
        // No unlock fired this frame: advance the step, and after the last gate
        // (collabo, step 3) drop into the interactive menu.
        if (m_state == 6) {
            if (m_unlockStep++ >= 3) {
                m_state = 0xc;
            }
        }
        break;
    }
    case 8: { // the once-a-day official-info web view, then the login bonus
        if (!m_tutorialSkip) {
            m_state = 6;
            break;
        }
        NSDate *today = [NSDate date];
        if (m_infoFlag && ![UserSettingData isEqualToInfoViewDay:today]) {
            CustomWebView *web =
                [[CustomWebView alloc] initWithURL:[StoreUtil getOfficialAppInfoURL]];
            [web SetCloseCallback:&MenuMainTask::modeSelectAlertClosed param:this];
            [web setErrorMsg:@"ERROR" text:@"お知らせの取得に失敗しました。"];
            [UserSettingData saveInfoViewDay:today];
            m_state = 9;
        } else {
            m_state = 10;
        }
        break;
    }
    case 10: { // the login bonus (random or regular), then the interactive menu
        m_state = 6;
        if ([dl loginCnt] < 1) {
            break;
        }
        const bool cntUpdated = [dl isLoginCntUpdate];
        if ([dl loginBonusId] != 0) { // a random login bonus is pending
            if (!cntUpdated) {
                break;
            }
            [RootVC() SetAlertViewCallback:&MenuMainTask::modeSelectAlertClosed param:this];
            RandomLoginBonusView *view = [[RandomLoginBonusView alloc] init];
            [view show];
            m_state = 0xb;
            [dl setIsLoginCntUpdate:NO];
            break;
        }
        // A regular login bonus: settle the stored count toward the server's.
        if ([UserSettingData getLoginBonusCnt] == 0) {
            int settled = [dl loginCnt];
            if (cntUpdated) {
                settled -= 1;
            } else if ([LoginBonusView getRewardMaxCnt] == [dl loginCnt] &&
                       [UserSettingData getOpenedLoginBonusId] < [dl loginBonusId]) {
                settled -= 1;
            }
            [UserSettingData saveLoginBonusCnt:settled];
        }
        if ([UserSettingData getLoginBonusCnt] != [dl loginCnt]) {
            [RootVC() SetAlertViewCallback:&MenuMainTask::modeSelectAlertClosed param:this];
            LoginBonusView *view = [[LoginBonusView alloc] init];
            [view show];
            m_state = 0xb;
        }
        break;
    }
    case 0xc: { // *** interactive main menu — hit-test every mode button ***
        // Re-scan the treasure / game event ids whenever DownloadMain reports a
        // refresh, so the overlay badges reflect the latest active events.
        if ([dl isTreasureEventInfoUpdated]) {
            m_treasureEvent = 0;
            for (NSNumber *eventId in dl.treasureEventIdArray) {
                if (isIndexInRange12((unsigned int)[eventId intValue])) {
                    m_treasureEvent = 1;
                    break;
                }
            }
            [dl setIsTreasureEventInfoUpdated:NO];
        }
        if ([dl isGameEventInfoUpdated]) {
            m_gameEvent = 0;
            for (NSNumber *eventId in dl.gameEventIdArray) {
                if ([eventId intValue] == 0) {
                    m_gameEvent = 1;
                    break;
                }
            }
            [dl setIsGameEventInfoUpdated:NO];
        }
        if (!haveTap) {
            break;
        }

        MainViewController *root = RootVC();
        // The tap must land while the prompt layer (+0x30) is no longer animating
        // for every button except Play and Friend (which are always live).
        auto introQuiet = [&] { return !m_layers[2]->isAnimating(); };
        auto hit = [&](const ButtonRect &r) {
            return neGraphics::pointInRect(tapX, tapY, r.x, r.y, r.w, r.h);
        };
        // The three top-cluster rects share the row Y, width, and height, and
        // differ only in their X origin.
        auto hitTop = [&](int rectX) {
            return neGraphics::pointInRect(
                tapX, tapY, rectX, m_top.rowY, m_top.fielda4, m_top.fielda8);
        };

        if (hitTop(m_top.settingsX)) { // settings (+0x98)
            if (introQuiet()) {
                m_state = 0xd;
            }
        } else if (hitTop(m_top.fielda0)) { // featured / reward offer wall (+0xa0)
            if (introQuiet() && m_giftEnabled) {
                m_state = 0xf;
            }
        } else if (hitTop(m_top.field9c)) { // present box (+0x9c)
            if (introQuiet()) {
                neEngine::playSystemSe(1);
                [root GotoPresentBox];
                m_state = 0x11;
            }
        } else if (hit(m_buttons[kBtnFriend])) { // +0x148 friend management
            if (introQuiet()) {
                m_seInst[2] = static_cast<int>([audio playSe:0 resourceId:m_seId[2]]);
                [root GotoFriendManage];
                m_state = 0x11;
            }
        } else if (hit(m_buttons[kBtnPlay])) { // +0x128 play (tutorial on first play)
            m_seInst[0] = static_cast<int>([audio playSe:0 resourceId:m_seId[0]]);
            if (!m_tutorialSkip) {
                neAppEventCenter::shared().setGuestNoSaveMode(true);
                [UserSettingData saveIsTutorialPlayed:YES];
                m_spawnedTask = TutorialTaskCreate(); // the guest-mode tutorial PlayTask
            } else {
                m_spawnedTask = MainTaskCreate();
            }
            m_state = 0x12;
        } else if (hit(m_buttons[kBtnStore])) { // +0x138 store
            if (introQuiet()) {
                m_seInst[3] = static_cast<int>([audio playSe:0 resourceId:m_seId[3]]);
                [[DownloadMain getInstance] setIsNewMusicPackReleased:NO];
                [root GotoStoreButton];
                m_state = 0x11;
            }
        } else if (hit(m_buttons[kBtnArcade])) { // +0x158 AcMainTask (treasure board)
            if (introQuiet()) {
                m_seInst[1] = static_cast<int>([audio playSe:0 resourceId:m_seId[1]]);
                m_spawnedTask = AcMainTaskCreate();
                m_state = 0x12;
            }
        } else if (hit(m_buttons[kBtnAcViewer])) { // +0x168 AcViewerTask
            if (introQuiet()) {
                // iPad seeds a default browsing selection (music 1 / difficulty 0)
                // when none is set, then clears the pending "Sel" pair.
                if (neSceneManager::isPadDisplay()) {
                    if (neAppEventCenter::acViewerMusicId() < 1) {
                        neAppEventCenter::setAcViewerSelection(1, 0);
                    }
                    neAppEventCenter::clearAcViewerSelection();
                }
                m_seInst[5] = static_cast<int>([audio playSe:0 resourceId:m_seId[5]]);
                m_spawnedTask = AcViewerTaskCreate();
                m_state = 0x12;
            }
        } else if (hit(m_buttons[kBtnPopnLink])) { // +0x178 pop'n link
            if (introQuiet()) {
                m_seInst[4] = static_cast<int>([audio playSe:0 resourceId:m_seId[4]]);
                [root GotoPopnLink];
                m_state = 0x11;
            }
        } else if (hit(m_buttons[kBtnInvite])) { // +0x188 invite code
            // Only enter the invite screen when a player record exists: play the
            // confirm SE (slot 0) and navigate; otherwise play the deny SE (slot 2)
            // and stay on the menu.
            if (introQuiet()) {
                if ([UserSettingData playerId] != nil && [UserSettingData playerName] != nil) {
                    neEngine::playSystemSe(0);
                    [root GotoInviteCode];
                    m_state = 0x11;
                } else {
                    neEngine::playSystemSe(2);
                }
            }
        } else if (hit(m_buttons[kBtnArcadeSearch])) { // +0x198 arcade search
            if (introQuiet()) {
                neEngine::playSystemSe(0);
                [root GotoArcadeSearch];
                m_state = 0x11;
            }
        } else if (tapY < 0x33 && introQuiet()) {
            // A tap in the top news-ticker band opens the current news line's URL.
            NSArray *urls = dl.newsUrlArray;
            if (urls != nil && (NSUInteger)m_newsIndex < [urls count]) {
                NSString *url = [urls objectAtIndex:m_newsIndex];
                if ([url length] != 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                }
            }
        }
        break;
    }
    case 0xd: // settings screen
        neEngine::playSystemSe(1);
        [RootVC() GotoSetting];
        m_state = 0xe;
        break;
    case 0xe: { // wait for settings to close; relaunch the title on request
        MainViewController *root = RootVC();
        if (![root settingViewing]) {
            if ([root isGotoTitle] == 1) {
                m_spawnedTask = TitleTaskCreate(); // spawn a fresh TitleTask
                m_state = 0x12;
                [root setIsGotoTitle:NO];
            } else {
                m_state = 0xc;
            }
        }
        break;
    }
    case 0xf: { // the reward offer-wall web panel (RewardNetwork)
        neEngine::playSystemSe(1);
        MainViewController *root = RootVC();
        [root setRewardListViweing:YES];
        // The binary builds the campaign id and type as NSNumbers (numberWithInt:0
        // / numberWithInt:2); RewardNetwork's query-value parameters are `id`, so
        // they pass straight through. The offset/limit/delegate args are
        // __stdcall_softfp-lost; only campaignId, type, and parentView are
        // recovered.
        [[RewardNetwork sharedInstance] openAppListWebViewWithCampaignId:@0
                                                               inCompany:nil
                                                                    type:@2
                                                                  offset:nil
                                                                   limit:nil
                                                              parentView:[root view]
                                                                delegate:(id)root];
        m_state = 0x10;
        break;
    }
    case 0x10: // wait for the offer-wall to close, then re-enter the menu
        if (![RootVC() rewardListViweing]) {
            m_state = 0xc;
        }
        break;
    case 0x11: { // wait for the pushed screen to close, then re-enter the menu
        MainViewController *root = RootVC();
        if (![root IsPresentBoxEnable] && ![root IsInviteCodeEnable] &&
            ![root IsArcadeSearchEnable] && ![root IsStoreEnable] && ![root IsPopnLinkEnable] &&
            ![root IsFriendManageEnable]) {
            m_state = 0xc;
        }
        break;
    }
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

    // Per-frame tail (Ghidra: updateAndDrawAepLayers then ModeSelectTask::Draw):
    // advance + enqueue every live AEP layer globally, then emit this menu's own
    // overlay sprites.
    AepLyrCtrl::updateAndDrawAepLayers(0);
    drawOverlay();
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

/**
 * modeSelectAlertClosed — the confirm-dialog dismiss callback the binary installs
 * directly (SetAlertViewCallback / CustomWebView SetCloseCallback) with the task
 * as `context`. Detach the root VC's alert callback, then step the state machine:
 * 7 & 11 -> 6 (re-check the next unlock gate), 9 -> 10 (login bonus after the
 * daily-info web view), anything else -> 0xc (the interactive menu).
 * @ghidraAddress 0x6d1a4
 * @complete
 */
void MenuMainTask::modeSelectAlertClosed(void *context) {
    auto *self = static_cast<MenuMainTask *>(context);
    [RootVC() SetAlertViewCallback:nullptr param:nullptr];
    switch (self->m_state) {
    case 7:
    case 11:
        self->m_state = 6;
        break;
    case 9:
        self->m_state = 10;
        break;
    default:
        self->m_state = 0xc;
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
void MenuMainTask::NewsTickerUpdate(int child,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    int,
                                    uint32_t,
                                    int *,
                                    uint32_t priority,
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
                        static_cast<int>(priority));
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
