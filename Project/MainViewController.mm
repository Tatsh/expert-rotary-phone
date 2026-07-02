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
    UINavigationController *_inputNameNaviCtrl;
    UIViewController *_inputConvPassViewCtrl;
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
        _inputNameNaviCtrl = [content initAtNavigationController];
        [self.view addSubview:_inputNameNaviCtrl.view];
        [content startOpenAnimation];
    } else {
        InputConversionPassViewController *vc = [[InputConversionPassViewController alloc] init];
        _inputConvPassViewCtrl = vc;
        [self.view addSubview:vc.view];
        [vc startOpenAnimation];
    }
    [self PauseLoop];
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
