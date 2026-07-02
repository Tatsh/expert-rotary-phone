//
//  MainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): drives the C++ task/scene engine each display frame.
//

#import <OpenGLES/ES1/gl.h>

#import "MainViewController.h"
#import "AcceptPolicyViewController.h"
#import "AepManager.h"
#import "FriendMngTopSplitViewController.h"
#import "FriendMngTopViewController.h"
#import "InputConversionPassViewController.h"
#import "MapSelectSplitViewController.h"
#import "MapSelectViewController.h"
#import "SettingTableSplitViewController.h"
#import "SettingTableViewController.h"
#import "DefaultDataDownloadView.h"
#import "DownloadMain.h"
#import "FriendScoreMainView.h"
#import "InputNameViewCtrl.h"
#import "InviteTopViewController.h"
#import "InviteTopViewControllerPad.h"
#import "PopnLinkTopSplitViewController.h"
#import "PopnLinkTopViewController.h"
#import "SearchView.h"
#import "neEngineBridge.h"
#import "C_TASK.h"
#import "neFrameTimer.h"
#import "neGLView.h"

// Scene-manager input-mode set, called when entering the conversion-pass screen
// (Ghidra: FUN_0002c724(&DAT_00187b74, mode)) — a distinct engine reconstruction unit.
extern "C" void neSceneSetInputMode(int mode);

// Minimum seconds between rendered frames (Ghidra: DAT_0000be7c). Rendering is
// skipped when the accumulated render time has not yet reached this.
static const float kRenderMinInterval = 1.0f / 60.0f;

// Fixed-point (16.16) seconds helper for the task update step.
static int SecondsToFixed(float s) { return (int)(s * 65536.0f); }

@implementation MainViewController {
    BOOL m_IsLoop;
    BOOL m_IsPause;
    int m_LoopInterval;
    CADisplayLink *m_DisplayLink;
    neGLView *_glView;
    AepManager *m_AepManager;    // C++ scene owner
    BOOL m_flgCapture;
    UIImage *m_capturedImg;
    AcceptPolicyViewController *_acceptPolicyCtrl;   // first-run policy modal
    // Modal child controllers. On phone each screen is hosted in a navigation
    // controller (…NaviCtrl); on iPad it is a split-view controller (…ViewCtrl).
    UINavigationController *_settingNaviCtrl;
    UIViewController *_settingViewCtrl;
    BOOL _settingViewing;
    UINavigationController *_mapSelectNaviCtrl;
    UIViewController *_mapSelectViewCtrl;
    UINavigationController *_friendMngNaviCtrl;
    UIViewController *_friendMngViewCtrl;
    UIViewController *_defaultDlViewController;
    BOOL _isDefaultDlFailed;
    UINavigationController *_inputConvPassNaviCtrl;
    UIViewController *_inputConvPassViewCtrl;
    UINavigationController *_popnLinkNaviCtrl;
    UIViewController *_popnLinkViewCtrl;
    UINavigationController *_inputNameNaviCtrl;
    UIViewController *_inputNameViewCtrl;
    UINavigationController *_inviteNaviCtrl;
    UINavigationController *_searchNaviCtrl;
    // Wall-clock stopwatches pacing the task-update and render steps.
    neFrameTimer m_taskTime;
    neFrameTimer m_renderTime;
}

#pragma mark - Loop control

// @ 0xbeb0
- (void)StartLoop {
    m_IsLoop = YES;
    [self CreateTimer];
}

// @ 0xbef0
- (void)PauseLoop {
    m_IsPause = YES;
    [self RemoveTimer];
}

// @ 0xbf10
- (void)ResumeLoop {
    m_IsPause = NO;
    [self CreateTimer];
}

// @ 0xc054
- (void)SetLoopInterval:(int)interval {
    m_LoopInterval = interval;
    if (!m_IsPause && m_IsLoop && m_DisplayLink == nil) {
        [self CreateTimer];
    }
}

// @ 0xbf30 — (re)create the CADisplayLink bound to -mainLoop.
- (void)CreateTimer {
    if (m_IsPause || !m_IsLoop) {
        return;
    }
    m_taskTime.reset();
    m_renderTime.reset();
    if (m_DisplayLink == nil) {
        m_DisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(mainLoop)];
        m_DisplayLink.frameInterval = m_LoopInterval;
        [m_DisplayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
    }
}

// @ 0xc024
- (void)RemoveTimer {
    if (m_DisplayLink == nil) {
        return;
    }
    [m_DisplayLink invalidate];
    m_DisplayLink = nil;
}

- (BOOL)isPause { return m_IsPause; }   // @ 0xf148
- (BOOL)isLoop  { return m_IsLoop; }    // @ 0xf160

#pragma mark - Navigation

// @ 0xda40 — present the first-run accept-policy screen over the GL view and pause
// the render loop. (The pattern every Goto* follows: alloc/init the child VC, add
// its view, run its open animation, PauseLoop; the *EndCallBack reverses it.)
- (void)GotoAcceptPolicy {
    _acceptPolicyCtrl = [[AcceptPolicyViewController alloc] init];
    [self.view addSubview:_acceptPolicyCtrl.view];
    [_acceptPolicyCtrl startOpenAnimation];
    [self PauseLoop];
}

// @ 0xc160 — the settings screen. Phone: SettingTableViewController hosted in a nav
// controller (with a custom navbar image); iPad: SettingTableSplitViewController.
- (void)GotoSetting {
    if (!neSceneManager::isPadDisplay()) {
        SettingTableViewController *content = [[SettingTableViewController alloc] autorelease];
        _settingNaviCtrl = [content initAtNavigationController];
        [_settingNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
                                             forBarMetrics:UIBarMetricsDefault];
        [self.view addSubview:_settingNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        SettingTableSplitViewController *split = [[SettingTableSplitViewController alloc] init];
        _settingViewCtrl = split;
        [self.view addSubview:split.view];
        [split startOpenAnimation];
    }
    [self PauseLoop];
    _settingViewing = YES;
}

// @ 0xc7d8 — the sugoroku map-select screen (nav controller / split view per device).
- (void)GotoMapSelect {
    if (!neSceneManager::isPadDisplay()) {
        MapSelectViewController *content = [[MapSelectViewController alloc] autorelease];
        _mapSelectNaviCtrl = [content initAtNavigationController];
        [_mapSelectNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"map_select_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
        [self.view addSubview:_mapSelectNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        MapSelectSplitViewController *split = [[MapSelectSplitViewController alloc] init];
        _mapSelectViewCtrl = split;
        [self.view addSubview:split.view];
        [split startOpenAnimation];
    }
    [self PauseLoop];
}

// @ 0xcdc8 — the friend-management top screen (nav controller / split view per device).
- (void)GotoFriendManage {
    if (!neSceneManager::isPadDisplay()) {
        FriendMngTopViewController *content = [[FriendMngTopViewController alloc] autorelease];
        _friendMngNaviCtrl = [content initAtNavigationController];
        [self.view addSubview:_friendMngNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        FriendMngTopSplitViewController *split = [[FriendMngTopSplitViewController alloc] init];
        _friendMngViewCtrl = split;
        [self.view addSubview:split.view];
        [split startOpenAnimation];
    }
    [self PauseLoop];
}

// @ 0xd560 — the initial "default data" download screen; built once, seeded with
// DownloadMain's file list.
- (void)GotoDefaultDownload {
    if (_defaultDlViewController != nil) {
        return;
    }
    NSArray *files = [[DownloadMain getInstance] dlFileListDataArray];
    _defaultDlViewController = [[DefaultDataDownloadView alloc] initWithFileDataArray:files];
    [self.view addSubview:_defaultDlViewController.view];
    [_defaultDlViewController startOpenAnimation];
    [self PauseLoop];
}

// @ 0xe53c — the conversion-passcode entry screen; built once.
- (void)GotoInConversionPass {
    if (_inputConvPassViewCtrl != nil) {
        return;
    }
    neSceneSetInputMode(2);   // Ghidra: FUN_0002c724(&DAT_00187b74, 2) — scene input mode
    if (!neSceneManager::isPadDisplay()) {
        InputConversionPassViewController *content =
            [[InputConversionPassViewController alloc] autorelease];
        _inputConvPassNaviCtrl = [content initAtNavigationController];
        [self.view addSubview:_inputConvPassNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        InputConversionPassViewController *vc = [[InputConversionPassViewController alloc] init];
        _inputConvPassViewCtrl = vc;
        [self.view addSubview:vc.view];
        [vc startOpenAnimation];
    }
    [self PauseLoop];
}

#pragma mark - Navigation teardown

// @ 0xdae4
- (void)AcceptPolicyEndCallBack {
    if (_acceptPolicyCtrl != nil) {
        [_acceptPolicyCtrl release];
        _acceptPolicyCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xc300 — also clears the "settings visible" flag.
- (void)SettingEndCallBack {
    if (_settingViewCtrl != nil) {
        [_settingViewCtrl release];
        _settingViewCtrl = nil;
    }
    if (_settingNaviCtrl != nil) {
        [_settingNaviCtrl release];
        _settingNaviCtrl = nil;
    }
    _settingViewing = NO;
    [self ResumeLoop];
}

// @ 0xc978
- (void)MapSelectEndCallBack {
    if (_mapSelectViewCtrl != nil) {
        [_mapSelectViewCtrl release];
        _mapSelectViewCtrl = nil;
    }
    if (_mapSelectNaviCtrl != nil) {
        [_mapSelectNaviCtrl release];
        _mapSelectNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xcf0c
- (void)FriendManageEndCallBack {
    if (_friendMngViewCtrl != nil) {
        [_friendMngViewCtrl release];
        _friendMngViewCtrl = nil;
    }
    if (_friendMngNaviCtrl != nil) {
        [_friendMngNaviCtrl release];
        _friendMngNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd640 — latches whether the download failed (read later by TitleTask).
- (void)DefaultDownloadEndCallBack {
    _isDefaultDlFailed = [_defaultDlViewController isFailed] ? YES : NO;
    [_defaultDlViewController release];
    _defaultDlViewController = nil;
    [self ResumeLoop];
}

// @ 0xe67c — re-enables touch on the GL view when the passcode screen closes.
- (void)InConversionPassEndCallBack {
    if (_inputConvPassViewCtrl != nil) {
        [_inputConvPassViewCtrl release];
        _inputConvPassViewCtrl = nil;
    }
    if (_inputConvPassNaviCtrl != nil) {
        [_inputConvPassNaviCtrl release];
        _inputConvPassNaviCtrl = nil;
    }
    self.view.userInteractionEnabled = YES;
    [self ResumeLoop];
}

- (BOOL)isDefaultDlFailed { return _isDefaultDlFailed; }

// @ 0xd074 — the pop'n link (data-link) top screen (nav / split per device).
- (void)GotoPopnLink {
    if (!neSceneManager::isPadDisplay()) {
        PopnLinkTopViewController *content = [[PopnLinkTopViewController alloc] autorelease];
        _popnLinkNaviCtrl = [content initAtNavigationController];
        [self.view addSubview:_popnLinkNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        PopnLinkTopSplitViewController *split = [[PopnLinkTopSplitViewController alloc] init];
        _popnLinkViewCtrl = split;
        [self.view addSubview:split.view];
        [split startOpenAnimation];
    }
    [self PauseLoop];
}

// @ 0xd248 — the player-name entry screen (nav controller / plain per device).
- (void)GotoInPlayerName {
    if (!neSceneManager::isPadDisplay()) {
        InputNameViewCtrl *content = [[InputNameViewCtrl alloc] autorelease];
        _inputNameNaviCtrl = [content initAtNavigationController];
        [self.view addSubview:_inputNameNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        InputNameViewCtrl *vc = [[InputNameViewCtrl alloc] init];
        _inputNameViewCtrl = vc;
        [self.view addSubview:vc.view];
        [vc startOpenAnimation];
    }
    [self PauseLoop];
}

// @ 0xd7f4 — the invite-code screen; the phone/iPad variant is a distinct class.
- (void)GotoInviteCode {
    Class cls = !neSceneManager::isPadDisplay() ? [InviteTopViewController class]
                                                : [InviteTopViewControllerPad class];
    InviteTopViewController *content = [[[cls alloc] autorelease] initAtNavigationController];
    _inviteNaviCtrl = (UINavigationController *)content;
    [self.view addSubview:_inviteNaviCtrl.view];
    [(InviteTopViewController *)content startOpenAnimation];
    [self PauseLoop];
}

// @ 0xd930 — the arcade song-search screen.
- (void)GotoArcadeSearch {
    SearchView *content = [[SearchView alloc] autorelease];
    _searchNaviCtrl = [content initAtNavigationController];
    [self.view addSubview:_searchNaviCtrl.view];
    [content startOpenAnimation];
    [self PauseLoop];
}

// @ 0xcf9c — the friend-score screen for one music id. Shown over the friend nav
// (shares _friendMngNaviCtrl) and does NOT pause the loop.
- (void)GotoFriendScore:(unsigned int)musicId {
    FriendScoreMainView *content = [[FriendScoreMainView alloc] autorelease];
    _friendMngNaviCtrl = [content initAtNavigationControllerWithMusicId:musicId];
    [self.view addSubview:_friendMngNaviCtrl.view];
    [content startOpenAnimation];
}

// @ 0xe830 — open the App Store review page for this app.
- (void)GotoReviewPage {
    NSURL *url = [NSURL URLWithString:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/"
                  @"viewContentsUserReviews?id=626574779&onlyLatestVersion=true&pageNumber=0&"
                  @"sortOrdering=1&type=Purple+Software"];
    [UIApplication.sharedApplication openURL:url];
}

// @ 0xd1b8
- (void)PopnLinkEndCallBack {
    if (_popnLinkViewCtrl != nil) { [_popnLinkViewCtrl release]; _popnLinkViewCtrl = nil; }
    if (_popnLinkNaviCtrl != nil) { [_popnLinkNaviCtrl release]; _popnLinkNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xd370
- (void)InPlayerNameEndCallBack {
    if (_inputNameViewCtrl != nil) { [_inputNameViewCtrl release]; _inputNameViewCtrl = nil; }
    if (_inputNameNaviCtrl != nil) { [_inputNameNaviCtrl release]; _inputNameNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xd8d8
- (void)InviteCodeEndCallBack {
    if (_inviteNaviCtrl != nil) { [_inviteNaviCtrl release]; _inviteNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xd9e8
- (void)ArcadeSearchEndCallBack {
    if (_searchNaviCtrl != nil) { [_searchNaviCtrl release]; _searchNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xd044 — mirror of GotoFriendScore: releases the shared friend nav, no ResumeLoop.
- (void)FriendScoreEndCallBack {
    if (_friendMngNaviCtrl != nil) { [_friendMngNaviCtrl release]; _friendMngNaviCtrl = nil; }
}

#pragma mark - Frame

// @ 0xbe80 — one display frame.
- (void)mainLoop {
    [self task];
    [self draw];
}

// @ 0xbb5c — advance all tasks by the elapsed time, then reap dead ones.
- (void)task {
    float dt = m_taskTime.elapsedSeconds();
    m_taskTime.reset();
    // updateAll walks the priority list, updating live tasks and reaping (deleting)
    // any flagged for deletion in the same pass — no separate sweep needed.
    C_TASK::updateAll(SecondsToFixed(dt));
}

// @ 0xbd30 — render the scene, frame-limited by the render timer.
- (void)draw {
    float dt = m_renderTime.elapsedSeconds();
    if (dt < kRenderMinInterval) {
        [_glView BeginRender];
        [_glView SetDefaultFrameBuffer];
        glClear(GL_COLOR_BUFFER_BIT);
        m_AepManager->draw();

        if (m_flgCapture) {
            if (m_capturedImg != nil) {
                m_capturedImg = nil;
            }
            m_capturedImg = [MainViewController capture:_glView];
            m_flgCapture = NO;
        }

        [_glView SetDefaultColorBuffer];
        [_glView Present];
    }
    m_renderTime.reset();
}

@end
