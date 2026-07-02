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
#import "AppDelegate.h"
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
#import "AcViewerCategoryViewController.h"
#import "AcViewerSplitViewController.h"
#import "OverScoreLogViewController.h"
#import "PresentBoxViewController.h"
#import "RecommendViewController.h"
#import "SortSelectViewController.h"
#import "StoreViewController.h"
#import "neEngineBridge.h"
#import "C_TASK.h"
#import "neFrameTimer.h"
#import "neGLView.h"

// Scene input-mode set + AEP content-area height come from the engine bridge
// (neEngine::setInputMode / neEngine::aepContentHeight). neEngineBridge.h imported below.

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
    UIView *_coverView;                 // dim backdrop shown behind iPad modal panels
    UINavigationController *_recommendNaviCtrl;
    UIViewController *_recommendViewCtrl;
    UINavigationController *_sortSelectNaviCtrl;
    UIViewController *_sortSelectViewCtrl;
    UINavigationController *_overScoreLogNaviCtrl;
    UIViewController *_overScoreLogViewCtrl;
    UINavigationController *_presentBoxNaviCtrl;
    UIViewController *_presentBoxViewCtrl;
    UIViewController *_storeViewController;
    UINavigationController *_acViewerNaviCtrl;
    UIViewController *_acViewerViewCtrl;
    BOOL _acMusicSelViewing;
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
    neEngine::setInputMode(2);   // Ghidra: FUN_0002c724(&DAT_00187b74, 2) — scene input mode
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

// The shared iPad modal-panel styling used by the friend/recommend/store-style
// screens: reveal the backdrop and centre a rounded, bordered 341x480 panel. The
// vertical offset is uniform (Ghidra DAT = -480, then -10); `leftX` + `border`
// differ per screen. Ghidra: the inlined block in the iPad branch of each Goto*.
- (void)styleIPadPanel:(UINavigationController *)nav leftX:(CGFloat)leftX border:(UIColor *)border {
    _coverView.hidden = NO;
    CGFloat y = (neEngine::aepContentHeight() - 128) * 0.5f - 490.0f;
    nav.view.backgroundColor = [UIColor colorWithRed:0.953f green:0.953f blue:0.953f alpha:1];
    [nav.view setFrame:CGRectMake(leftX, y, 341, 480)];
    nav.view.layer.borderColor = border.CGColor;
    nav.view.layer.borderWidth = 3;
    nav.view.layer.cornerRadius = 10;
}

// @ 0xc374 — the friend/recommend screen (param = context); a boxed iPad panel.
- (void)GotoRecommend:(void *)context {
    _recommendViewCtrl = [[RecommendViewController alloc] init];
    [(RecommendViewController *)_recommendViewCtrl initAtNavigationController:context];
    _recommendNaviCtrl = [[UINavigationController alloc] init];
    _recommendNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_recommendNaviCtrl leftX:141.5f
                      border:[UIColor colorWithRed:1.0f green:0.62f blue:0.808f alpha:1]];
    }
    [_recommendNaviCtrl pushViewController:_recommendViewCtrl animated:NO];
    [_recommendNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"frirec_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
    [self.view addSubview:_recommendNaviCtrl.view];
    [_recommendViewCtrl startOpenAnimation];
    if (!neSceneManager::isPadDisplay()) {
        [self PauseLoop];
    }
    NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
    fmt.dateFormat = @"yyyy/MM/ddHH:mm";
    [UserSettingData saveLastRecommendViewTimeString:[fmt stringFromDate:[NSDate date]]];
}

// @ 0xc9dc — the music sort-select screen (param = context); a boxed iPad panel.
- (void)GotoSortSelect:(void *)context {
    _sortSelectViewCtrl = [[SortSelectViewController alloc] init];
    [(SortSelectViewController *)_sortSelectViewCtrl initAtNavigationController:context];
    _sortSelectNaviCtrl = [[UINavigationController alloc] init];
    _sortSelectNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_sortSelectNaviCtrl leftX:22.0f
                      border:[UIColor colorWithRed:0.929f green:0.659f blue:0.0784f alpha:1]];
        _sortSelectNaviCtrl.view.userInteractionEnabled = YES;
    }
    [_sortSelectNaviCtrl pushViewController:_sortSelectViewCtrl animated:NO];
    [_sortSelectNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"m_sort_navbar"]
                                            forBarMetrics:UIBarMetricsDefault];
    [self.view addSubview:_sortSelectNaviCtrl.view];
    [_sortSelectViewCtrl startOpenAnimation];
    if (!neSceneManager::isPadDisplay()) {
        [self PauseLoop];
    }
}

// @ 0xe170 — the over-score (friend score log) screen (param = context); iPad panel.
- (void)GotoOverScoreLog:(void *)context {
    _overScoreLogViewCtrl = [[OverScoreLogViewController alloc] init];
    [(OverScoreLogViewController *)_overScoreLogViewCtrl initAtNavigationController:context];
    _overScoreLogNaviCtrl = [[UINavigationController alloc] init];
    _overScoreLogNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_overScoreLogNaviCtrl leftX:261.0f
                      border:[UIColor colorWithRed:0.792f green:0.933f blue:0.212f alpha:1]];
    }
    [_overScoreLogNaviCtrl pushViewController:_overScoreLogViewCtrl animated:NO];
    [_overScoreLogNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"osl_friend_navbar"]
                                              forBarMetrics:UIBarMetricsDefault];
    [self.view addSubview:_overScoreLogNaviCtrl.view];
    [_overScoreLogViewCtrl startOpenAnimation];
    if (!neSceneManager::isPadDisplay()) {
        [self PauseLoop];
    }
}

// @ 0xdd8c — the present box (gifts) screen; iPad panel styling.
- (void)GotoPresentBox {
    _presentBoxViewCtrl = [[PresentBoxViewController alloc] init];
    [(PresentBoxViewController *)_presentBoxViewCtrl initAtNavigationController];
    _presentBoxNaviCtrl = [[UINavigationController alloc] init];
    _presentBoxNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_presentBoxNaviCtrl leftX:22.0f
                      border:[UIColor colorWithRed:0.929f green:0.659f blue:0.0784f alpha:1]];
    }
    [_presentBoxNaviCtrl pushViewController:_presentBoxViewCtrl animated:NO];
    [_presentBoxNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"pbox_nav_gift"]
                                            forBarMetrics:UIBarMetricsDefault];
    [self.view addSubview:_presentBoxNaviCtrl.view];
    [_presentBoxViewCtrl startOpenAnimation];
    if (!neSceneManager::isPadDisplay()) {
        [self PauseLoop];
    }
}

// @ 0xd3d4 — the in-app store; built once, uses its own showAnimation (no PauseLoop),
// and records the view timestamp.
- (void)GotoStoreButton {
    if (_storeViewController != nil) {
        return;
    }
    _storeViewController = [[StoreViewController alloc] initWithRecommendPackId:-1];
    [self.view addSubview:_storeViewController.view];
    [(StoreViewController *)_storeViewController showAnimation];
    NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
    fmt.dateFormat = @"yyyyMMddHH";
    [UserSettingData saveLastStoreViewTimeString:[fmt stringFromDate:[NSDate date]]];
}

// @ 0xdb24 — the arcade (AC) viewer; phone nav / iPad split (guarded).
- (void)GotoAcViewer {
    _acMusicSelViewing = YES;
    if (!neSceneManager::isPadDisplay()) {
        AcViewerCategoryViewController *content =
            [[AcViewerCategoryViewController alloc] autorelease];
        _acViewerNaviCtrl = [content initAtNavigationController];
        [_acViewerNaviCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_category_navbar"]
                                              forBarMetrics:UIBarMetricsDefault];
        [self.view addSubview:_acViewerNaviCtrl.view];
        [content startOpenAnimation];
        [self PauseLoop];
    } else if (_acViewerViewCtrl == nil) {
        AcViewerSplitViewController *split = [[AcViewerSplitViewController alloc] init];
        _acViewerViewCtrl = split;
        [self.view addSubview:split.view];
        [split startOpenAnimation];
    }
}

// @ 0xe890 — open the Mail composer via a mailto: URL carrying `body`.
- (void)GotoMailWithText:(NSString *)body {
    NSString *urlStr = [NSString stringWithFormat:@"mailto:?body=%@", body];
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:urlStr]];
}

// @ 0xc754
- (void)RecommendEndCallBack {
    _coverView.hidden = YES;
    if (_recommendViewCtrl != nil) { [_recommendViewCtrl release]; _recommendViewCtrl = nil; }
    if (_recommendNaviCtrl != nil) { [_recommendNaviCtrl release]; _recommendNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xcd44
- (void)SortSelectEndCallBack {
    _coverView.hidden = YES;
    if (_sortSelectViewCtrl != nil) { [_sortSelectViewCtrl release]; _sortSelectViewCtrl = nil; }
    if (_sortSelectNaviCtrl != nil) { [_sortSelectNaviCtrl release]; _sortSelectNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xe4b8
- (void)OverScoreLogEndCallBack {
    _coverView.hidden = YES;
    if (_overScoreLogViewCtrl != nil) { [_overScoreLogViewCtrl release]; _overScoreLogViewCtrl = nil; }
    if (_overScoreLogNaviCtrl != nil) { [_overScoreLogNaviCtrl release]; _overScoreLogNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xe0d4
- (void)PresentBoxEndCallBack {
    _coverView.hidden = YES;
    if (_presentBoxViewCtrl != nil) { [_presentBoxViewCtrl release]; _presentBoxViewCtrl = nil; }
    if (_presentBoxNaviCtrl != nil) { [_presentBoxNaviCtrl release]; _presentBoxNaviCtrl = nil; }
    [self ResumeLoop];
}

// @ 0xd518 — the store closes without resuming the loop (it never paused it).
- (void)StoreEndCallBack {
    if (_storeViewController != nil) { [_storeViewController release]; _storeViewController = nil; }
}

// @ 0xdcd4 — on iPad also tears down the arcade play task before resuming.
- (void)AcViewerEndCallBack {
    if (_acViewerViewCtrl != nil) { [_acViewerViewCtrl release]; _acViewerViewCtrl = nil; }
    if (_acViewerNaviCtrl != nil) { [_acViewerNaviCtrl release]; _acViewerNaviCtrl = nil; }
    if (neSceneManager::isPadDisplay()) {
        // Stop the arcade main task (Ghidra: acMainTask + FUN_0002315c) on close.
        neEngine::stopAcMainTask(AppDelegate.appDelegate.acMainTask);
        _acMusicSelViewing = NO;
    }
    [self ResumeLoop];
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
