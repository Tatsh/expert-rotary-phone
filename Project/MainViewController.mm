//
//  MainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): drives the C++ task/scene engine each display frame.
//

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "AcViewerCategoryViewController.h"
#import "AcViewerSplitViewController.h"
#import "AcceptPolicyViewController.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "C_TASK.h"
#import "CommonAlertView.h"
#import "CommunicatingView.h"
#import "CustomAlertView.h"
#import "DefaultDataDownloadView.h"
#import "DownloadMain.h"
#import "FriendMngTopSplitViewController.h"
#import "FriendMngTopViewController.h"
#import "FriendScoreMainView.h"
#import "InputConversionPassViewController.h"
#import "InputNameViewCtrl.h"
#import "InviteTopViewController.h"
#import "InviteTopViewControllerPad.h"
#import "MainViewController.h"
#import "MapSelectSplitViewController.h"
#import "MapSelectViewController.h"
#import "MusicManager.h"
#import "OverScoreLogViewController.h"
#import "PopnLinkTopSplitViewController.h"
#import "PopnLinkTopViewController.h"
#import "PresentBoxViewController.h"
#import "RecommendViewController.h"
#import "SearchView.h"
#import "SettingTableSplitViewController.h"
#import "SettingTableViewController.h"
#import "SortSelectViewController.h"
#import "StoreViewController.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neFrameTimer.h"
#import "neGLView.h"
#import "neRenderer.h"

// Scene input-mode set + AEP content-area height come from the engine bridge
// (neEngine::playSystemSe / neEngine::aepContentHeight). neEngineBridge.h
// imported below.

// Render-time gate threshold in MILLISECONDS (Ghidra: DAT_0000be7c = 1000.0).
// -draw renders only while the elapsed render time (ms) is below this, so in
// practice every frame draws (a gap longer than 1000 ms — e.g. after a long
// stall — skips that frame's render).
static const float kRenderMinInterval = 1000.0f;

// Float(ms)->fixed-point (16.16) helper for the task update step. The binary
// applies FPToFixed(ms, round-toward-zero, 16 frac bits) to the elapsed-ms
// value before updateAll.
static int FloatToFixed(float ms) {
    return (int)(ms * 65536.0f);
}

// This VC is the neGLView render/layout delegate and the delegate for both the
// common and custom alert views it raises.
@interface MainViewController () <neGLViewDelegate,
                                  CommonAlertViewDelegate,
                                  CustomAlertViewDelegate>
@end

// .cxx_construct @ 0xf1e8 — compiler-emitted C++ ivar constructor; not
// hand-written.
@implementation MainViewController {
    BOOL m_IsLoop;
    BOOL m_IsPause;
    int m_LoopInterval;
    CADisplayLink *m_DisplayLink;
    neGLView *_glView;
    AepManager *m_AepManager; // C++ scene owner
    BOOL m_flgCapture;
    UIImage *m_capturedImg;
    AcceptPolicyViewController *_acceptPolicyCtrl; // first-run policy modal
    // Modal child controllers. On phone each screen is hosted in a navigation
    // controller (…NaviCtrl); on iPad it is a split-view controller (…ViewCtrl).
    UINavigationController *_settingNaviCtrl;
    UIViewController *_settingViewCtrl;
    BOOL _settingViewing;
    UINavigationController *_mapSelectNaviCtrl;
    UIViewController *_mapSelectViewCtrl;
    UINavigationController *_friendMngNaviCtrl;
    UIViewController *_friendMngViewCtrl;
    DefaultDataDownloadView *_defaultDlViewController; // startOpenAnimation / isFailed
    BOOL _isDefaultDlFailed;
    UINavigationController *_inputConvPassNaviCtrl;
    UIViewController *_inputConvPassViewCtrl;
    UINavigationController *_popnLinkNaviCtrl;
    UIViewController *_popnLinkViewCtrl;
    UINavigationController *_inputNameNaviCtrl;
    UIViewController *_inputNameViewCtrl;
    UINavigationController *_inviteNaviCtrl;
    UINavigationController *_searchNaviCtrl;
    UIView *_coverView; // dim backdrop shown behind iPad modal panels
    UINavigationController *_recommendNaviCtrl;
    RecommendViewController *_recommendViewCtrl;
    UINavigationController *_sortSelectNaviCtrl;
    SortSelectViewController *_sortSelectViewCtrl;
    UINavigationController *_overScoreLogNaviCtrl;
    OverScoreLogViewController *_overScoreLogViewCtrl;
    UINavigationController *_presentBoxNaviCtrl;
    PresentBoxViewController *_presentBoxViewCtrl;
    UIViewController *_storeViewController;
    UINavigationController *_acViewerNaviCtrl;
    UIViewController *_acViewerViewCtrl;
    BOOL _acMusicSelViewing;
    // Wall-clock stopwatches pacing the task-update and render steps.
    neFrameTimer m_taskTime;
    neFrameTimer m_renderTime;
    // Modal "communicating…" network-activity overlay + the fade-to-black scrim.
    CommunicatingView *_communicatingView;
    UIView *_blackBoardView;
    // A one-shot C callback fired from the alert delegates when the confirm
    // button is hit (installed via SetAlertViewCallback:param:).
    void (*m_AlertViewCallback)(void *);
    void *m_AlertViewCallbackParam;
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
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        m_DisplayLink.preferredFramesPerSecond = 60 / m_LoopInterval;
#else
        m_DisplayLink.frameInterval = m_LoopInterval;
#endif
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

- (BOOL)isPause {
    return m_IsPause;
} // @ 0xf148
- (BOOL)isLoop {
    return m_IsLoop;
} // @ 0xf160

#pragma mark - Navigation

// @ 0xda40 — present the first-run accept-policy screen over the GL view and
// pause the render loop. (The pattern every Goto* follows: alloc/init the child
// VC, add its view, run its open animation, PauseLoop; the *EndCallBack
// reverses it.)
- (void)GotoAcceptPolicy {
    _acceptPolicyCtrl = [[AcceptPolicyViewController alloc] init];
    [self.view addSubview:_acceptPolicyCtrl.view];
    [_acceptPolicyCtrl startOpenAnimation];
    [self PauseLoop];
}

// @ 0xc160 — the settings screen. Phone: SettingTableViewController hosted in a
// nav controller (with a custom navbar image); iPad:
// SettingTableSplitViewController.
- (void)GotoSetting {
    if (!neSceneManager::isPadDisplay()) {
        SettingTableViewController *content = [SettingTableViewController alloc];
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

// @ 0xc7d8 — the sugoroku map-select screen (nav controller / split view per
// device).
- (void)GotoMapSelect {
    if (!neSceneManager::isPadDisplay()) {
        MapSelectViewController *content = [MapSelectViewController alloc];
        _mapSelectNaviCtrl = [content initAtNavigationController];
        [_mapSelectNaviCtrl.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"map_select_navbar"]
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

// @ 0xcdc8 — the friend-management top screen (nav controller / split view per
// device).
- (void)GotoFriendManage {
    if (!neSceneManager::isPadDisplay()) {
        FriendMngTopViewController *content = [FriendMngTopViewController alloc];
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

// @ 0xd560 — the initial "default data" download screen; built once, seeded
// with DownloadMain's file list.
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
    neEngine::playSystemSe(2); // Ghidra: SysSePlayIntoSlot(&g_pNeSceneManager, 2) @ 0x2c724
    if (!neSceneManager::isPadDisplay()) {
        InputConversionPassViewController *content = [InputConversionPassViewController alloc];
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
        _acceptPolicyCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xc300 — also clears the "settings visible" flag.
- (void)SettingEndCallBack {
    if (_settingViewCtrl != nil) {
        _settingViewCtrl = nil;
    }
    if (_settingNaviCtrl != nil) {
        _settingNaviCtrl = nil;
    }
    _settingViewing = NO;
    [self ResumeLoop];
}

// @ 0xc978
- (void)MapSelectEndCallBack {
    if (_mapSelectViewCtrl != nil) {
        _mapSelectViewCtrl = nil;
    }
    if (_mapSelectNaviCtrl != nil) {
        _mapSelectNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xcf0c
- (void)FriendManageEndCallBack {
    if (_friendMngViewCtrl != nil) {
        _friendMngViewCtrl = nil;
    }
    if (_friendMngNaviCtrl != nil) {
        _friendMngNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd640 — latches whether the download failed (read later by TitleTask).
- (void)DefaultDownloadEndCallBack {
    _isDefaultDlFailed = [_defaultDlViewController isFailed] ? YES : NO;
    _defaultDlViewController = nil;
    [self ResumeLoop];
}

// @ 0xe67c — re-enables touch on the GL view when the passcode screen closes.
- (void)InConversionPassEndCallBack {
    if (_inputConvPassViewCtrl != nil) {
        _inputConvPassViewCtrl = nil;
    }
    if (_inputConvPassNaviCtrl != nil) {
        _inputConvPassNaviCtrl = nil;
    }
    self.view.userInteractionEnabled = YES;
    [self ResumeLoop];
}

// isDefaultDlFailed is a synthesized @property accessor (@ 0xf100); see the
// header.

// @ 0xd074 — the pop'n link (data-link) top screen (nav / split per device).
- (void)GotoPopnLink {
    if (!neSceneManager::isPadDisplay()) {
        PopnLinkTopViewController *content = [PopnLinkTopViewController alloc];
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
        InputNameViewCtrl *content = [InputNameViewCtrl alloc];
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

// @ 0xd7f4 — the invite-code screen; the phone/iPad variant is a distinct
// class.
- (void)GotoInviteCode {
    Class cls = !neSceneManager::isPadDisplay() ? [InviteTopViewController class] :
                                                  [InviteTopViewControllerPad class];
    InviteTopViewController *content = [[cls alloc] initAtNavigationController];
    _inviteNaviCtrl = (UINavigationController *)content;
    [self.view addSubview:_inviteNaviCtrl.view];
    [(InviteTopViewController *)content startOpenAnimation];
    [self PauseLoop];
}

// @ 0xd930 — the arcade song-search screen.
- (void)GotoArcadeSearch {
    SearchView *content = [SearchView alloc];
    _searchNaviCtrl = [content initAtNavigationController];
    [self.view addSubview:_searchNaviCtrl.view];
    [content startOpenAnimation];
    [self PauseLoop];
}

// @ 0xcf9c — the friend-score screen for one music id. Shown over the friend
// nav (shares _friendMngNaviCtrl) and does NOT pause the loop.
- (void)GotoFriendScore:(unsigned int)musicId {
    FriendScoreMainView *content = [FriendScoreMainView alloc];
    _friendMngNaviCtrl = [content initAtNavigationControllerWithMusicId:musicId];
    [self.view addSubview:_friendMngNaviCtrl.view];
    [content startOpenAnimation];
}

// @ 0xe830 — open the App Store review page for this app.
- (void)GotoReviewPage {
    NSURL *url = [NSURL URLWithString:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/"
                                      @"viewContentsUserReviews?id=626574779&onlyLatestVersion="
                                      @"true&pageNumber=0&"
                                      @"sortOrdering=1&type=Purple+Software"];
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
#else
    [UIApplication.sharedApplication openURL:url];
#endif
}

// @ 0xd1b8
- (void)PopnLinkEndCallBack {
    if (_popnLinkViewCtrl != nil) {
        _popnLinkViewCtrl = nil;
    }
    if (_popnLinkNaviCtrl != nil) {
        _popnLinkNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd370
- (void)InPlayerNameEndCallBack {
    if (_inputNameViewCtrl != nil) {
        _inputNameViewCtrl = nil;
    }
    if (_inputNameNaviCtrl != nil) {
        _inputNameNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd8d8
- (void)InviteCodeEndCallBack {
    if (_inviteNaviCtrl != nil) {
        _inviteNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd9e8
- (void)ArcadeSearchEndCallBack {
    if (_searchNaviCtrl != nil) {
        _searchNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd044 — mirror of GotoFriendScore: releases the shared friend nav, no
// ResumeLoop.
- (void)FriendScoreEndCallBack {
    if (_friendMngNaviCtrl != nil) {
        _friendMngNaviCtrl = nil;
    }
}

// The shared iPad modal-panel styling used by the friend/recommend/store-style
// screens: reveal the backdrop and centre a rounded, bordered 341x480 panel.
// The vertical offset is uniform (Ghidra DAT = -480, then -10); `leftX` +
// `border` differ per screen. Ghidra: the inlined block in the iPad branch of
// each Goto*.
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
    [(RecommendViewController *)_recommendViewCtrl initAtNavigationController:(MainTask *)context];
    _recommendNaviCtrl = [[UINavigationController alloc] init];
    _recommendNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_recommendNaviCtrl
                       leftX:141.5f
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
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy/MM/ddHH:mm";
    [UserSettingData saveLastRecommendViewTimeString:[fmt stringFromDate:[NSDate date]]];
}

// @ 0xc9dc — the music sort-select screen (param = context); a boxed iPad
// panel.
- (void)GotoSortSelect:(void *)context {
    _sortSelectViewCtrl = [[SortSelectViewController alloc] init];
    [(SortSelectViewController *)_sortSelectViewCtrl
        initAtNavigationController:(MainTask *)context];
    _sortSelectNaviCtrl = [[UINavigationController alloc] init];
    _sortSelectNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_sortSelectNaviCtrl
                       leftX:22.0f
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

// @ 0xe170 — the over-score (friend score log) screen (param = context); iPad
// panel.
- (void)GotoOverScoreLog:(void *)context {
    _overScoreLogViewCtrl = [[OverScoreLogViewController alloc] init];
    [(OverScoreLogViewController *)_overScoreLogViewCtrl
        initAtNavigationController:(MainTask *)context];
    _overScoreLogNaviCtrl = [[UINavigationController alloc] init];
    _overScoreLogNaviCtrl.view.clipsToBounds = YES;
    if (neSceneManager::isPadDisplay()) {
        [self styleIPadPanel:_overScoreLogNaviCtrl
                       leftX:261.0f
                      border:[UIColor colorWithRed:0.792f green:0.933f blue:0.212f alpha:1]];
    }
    [_overScoreLogNaviCtrl pushViewController:_overScoreLogViewCtrl animated:NO];
    [_overScoreLogNaviCtrl.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"osl_friend_navbar"]
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
        [self styleIPadPanel:_presentBoxNaviCtrl
                       leftX:22.0f
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

// @ 0xd3d4 — the in-app store; built once, uses its own showAnimation (no
// PauseLoop), and records the view timestamp.
- (void)GotoStoreButton {
    if (_storeViewController != nil) {
        return;
    }
    _storeViewController = [[StoreViewController alloc] initWithRecommendPackId:-1];
    [self.view addSubview:_storeViewController.view];
    [(StoreViewController *)_storeViewController showAnimation];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMddHH";
    [UserSettingData saveLastStoreViewTimeString:[fmt stringFromDate:[NSDate date]]];
}

// @ 0xdb24 — the arcade (AC) viewer; phone nav / iPad split (guarded).
- (void)GotoAcViewer {
    _acMusicSelViewing = YES;
    if (!neSceneManager::isPadDisplay()) {
        AcViewerCategoryViewController *content = [AcViewerCategoryViewController alloc];
        _acViewerNaviCtrl = [content initAtNavigationController];
        [_acViewerNaviCtrl.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"acv_category_navbar"]
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
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:urlStr]
                                     options:@{}
                           completionHandler:nil];
#else
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:urlStr]];
#endif
}

// @ 0xc754
- (void)RecommendEndCallBack {
    _coverView.hidden = YES;
    if (_recommendViewCtrl != nil) {
        _recommendViewCtrl = nil;
    }
    if (_recommendNaviCtrl != nil) {
        _recommendNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xcd44
- (void)SortSelectEndCallBack {
    _coverView.hidden = YES;
    if (_sortSelectViewCtrl != nil) {
        _sortSelectViewCtrl = nil;
    }
    if (_sortSelectNaviCtrl != nil) {
        _sortSelectNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xe4b8
- (void)OverScoreLogEndCallBack {
    _coverView.hidden = YES;
    if (_overScoreLogViewCtrl != nil) {
        _overScoreLogViewCtrl = nil;
    }
    if (_overScoreLogNaviCtrl != nil) {
        _overScoreLogNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xe0d4
- (void)PresentBoxEndCallBack {
    _coverView.hidden = YES;
    if (_presentBoxViewCtrl != nil) {
        _presentBoxViewCtrl = nil;
    }
    if (_presentBoxNaviCtrl != nil) {
        _presentBoxNaviCtrl = nil;
    }
    [self ResumeLoop];
}

// @ 0xd518 — the store closes without resuming the loop (it never paused it).
- (void)StoreEndCallBack {
    if (_storeViewController != nil) {
        _storeViewController = nil;
    }
}

// @ 0xdcd4 — on iPad also tears down the arcade play task before resuming.
- (void)AcViewerEndCallBack {
    if (_acViewerViewCtrl != nil) {
        _acViewerViewCtrl = nil;
    }
    if (_acViewerNaviCtrl != nil) {
        _acViewerNaviCtrl = nil;
    }
    if (neSceneManager::isPadDisplay()) {
        // Stop the arcade main task (Ghidra: acMainTask + FUN_0002315c) on close.
        neEngine::stopAcMainTask(
            (AcMainTask *)AppDelegate.appDelegate.acMainTask); // acMainTask stored as void*
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
    float dt = m_taskTime.elapsedMs();
    m_taskTime.reset();
    C_TASK::updateAll(FloatToFixed(dt));
    // NOTE (Ghidra @ 0xbb5c): the binary then runs per-frame neGraphics
    // touch-pool upkeep inline here — for each active touch it clears the +0x2c
    // frame marker, copies the current point (+0xc/+0x10) into +0x1c/+0x20, and
    // swap-removes any touch whose released flag (+0x2d) is set, decrementing the
    // pool count (+0x80). That mutates neGraphics' private
    // m_touches/m_touchCount; it belongs behind an engine-layer maintenance
    // method (neGraphics), not reached into from here.
}

// @ 0xbd30 — render the scene, frame-limited by the render timer.
- (void)draw {
    float dt = m_renderTime.elapsedMs();
    if (dt < kRenderMinInterval) {
        [_glView BeginRender];
        [_glView SetDefaultFrameBuffer];
        // The binary sets no glViewport here (Ghidra: MainViewController::draw
        // @0xbd30 is BeginRender -> SetDefaultFrameBuffer -> clear -> AepManager
        // draw -> Present, nothing more). The GL viewport is owned by the engine's
        // orthographic viewport: LayoutedGLView: builds it over the whole front
        // buffer and neApplyViewport installs it during the flush. Setting a
        // separate aspect-scaled glViewport here fought that viewport (neApplyViewport
        // early-outs when its viewport is unchanged, so the stray rect stuck) and
        // clipped the scene.
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

// +[MainViewController capture:]  @ 0xbbec — grab the GL view's current
// renderbuffer into a UIImage. Reads the bound renderbuffer's RGBA8 pixels,
// wraps them in a CGImage, then redraws (copy blend) into a UIKit image context
// at the view's content scale so the returned image is upright at point size.
// Ghidra-faithful.
+ (UIImage *)capture:(neGLView *)glView {
    GLint width = 0, height = 0;
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);

    NSInteger byteCount = width * height * 4;
    GLubyte *data = (GLubyte *)malloc(byteCount);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, byteCount, NULL);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(width,
                                    height,
                                    8,
                                    32,
                                    width * 4,
                                    colorSpace,
                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
                                    provider,
                                    NULL,
                                    YES,
                                    kCGRenderingIntentDefault);

    CGFloat scale = glView.contentScaleFactor;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width / scale, height / scale), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width / scale, height / scale), iref);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    free(data);
    CFRelease(provider);
    CFRelease(colorSpace);
    CGImageRelease(iref);
    return image;
}

#pragma mark - Lifecycle

// @ 0xb51c — build the GL surface and boot the AEP engine/scene. Creates the
// neGLView sized to the screen (delegate = self), initialises AepManager
// against the on-disk data path, seeds the scene manager with the UI scale,
// then lays a hidden, clear cover button (with a tap recognizer) over the view
// — the backdrop the iPad modal panels dim and dismiss-on-tap through.
- (void)loadView {
    [super loadView];
    CGRect bounds = UIScreen.mainScreen.bounds;
    self.view.frame = bounds;
    if (_glView == nil) {
        _glView = [[neGLView alloc] initWithFrame:bounds];
        _glView.contentScaleFactor = UIScreen.mainScreen.scale;
        _glView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    _glView.delegate = self;
    [self.view addSubview:_glView];

    // AEP data root (baseDir): the binary reads "<baseDir>/<name>.idx" via fopen
    // from <Documents>/data/tex/, which the original POPULATED by a first-launch
    // server download (Ghidra NSSearchPathForDirectoriesInDomains(9,1,1) ->
    // Documents/data/tex/). That server is gone and this build ships every .idx
    // at the .app bundle root, so point baseDir at the bundle resource path --
    // the .idx files fopen straight from there, and the tile PNGs already resolve
    // via [NSBundle pathForResource:] regardless of baseDir
    // (AepTexture::decodeAndUpload).
    NSString *texDir = NSBundle.mainBundle.resourcePath;
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    AepManager &aep = AepManager::shared();
    CGFloat scale = UIScreen.mainScreen.scale;
    // Engine boot against the data paths; the surface is passed in device pixels
    // (points * scale). Kept as a bridge call — the AEP internals are not
    // reimplemented. The AEP renders at the CONTENT resolution the sprites are
    // authored for (the same canvas BootLogoTask/the scenes use), NOT the raw
    // device drawable: on devices the app predates (or in iPhone-compat on iPad)
    // UIScreen.bounds*scale is larger than the 640-wide iPhone content, which
    // left 2D content undersized in the top-left. The flush ortho uses these
    // extents and the viewport stretches them across the whole drawable
    // (MainViewController -draw).
    int contentW, contentH;
    if (neSceneManager::isPadDisplay()) {
        contentW = 1536;
        contentH = 2048; // iPad retina canvas
    } else {
        contentW = 640;
        contentH = (AppDelegate.appDelegate.displayType == 2) ? 1136 : 960; // 4" vs 3.5" iPhone
    }
    aepManagerInit(&aep, bundlePath.UTF8String, texDir.UTF8String, contentW, contentH, scale);
    neSceneManager::shared(); // force scene-manager lazy init
    reinterpret_cast<float &>(g_dwUiScale) =
        scale * 0.5f; // publish UI scale as float bits (binary @0xb51c)

    m_capturedImg = nil;
    m_flgCapture = NO;

    if (_coverView == nil) {
        UIButton *cover = [[UIButton alloc] initWithFrame:self.view.frame];
        _coverView = cover;
        cover.backgroundColor = [UIColor clearColor];
        _coverView.userInteractionEnabled = YES;
        _coverView.hidden = YES;
        [self.view addSubview:_coverView];
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [_coverView addGestureRecognizer:tap];
    }
}

// @ 0xb970 — cache the AepManager scene singleton after the base setup.
- (void)viewDidLoad {
    [super viewDidLoad];
    m_AepManager = &AepManager::shared();
}

// @ 0xb440 — real teardown only: stop the loop and detach the cover view. Under
// ARC the object ivars (m_capturedImg, GL view, …) are released automatically
// and there is no [super dealloc].
- (void)dealloc {
    [self StopLoop];
    [_coverView removeFromSuperview];
}

// didReceiveMemoryWarning @ 0xb4c4 — super-only override, omitted.
// viewDidUnload @ 0xb4f0 — super-only override, omitted.
// viewWillAppear: @ 0xb9b0 — super-only override, omitted.
// viewDidAppear: @ 0xb9dc — super-only override, omitted.
// viewWillDisappear: @ 0xba08 — super-only override, omitted.
// viewDidDisappear: @ 0xba34 — super-only override, omitted.

// @ 0xba60 — allow every orientation except upside-down portrait.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - GL surface / loop

// @ 0xba6c — neGLView layout delegate: the drawable was (re)sized, so rebuild
// the engine's orthographic viewport to the new front-buffer (pixel) size,
// repaint once so the resized surface isn't garbage, then record the new size
// into the scene manager. neGetCurrentRenderer / neCreateOrthoViewport /
// neSetCurrentViewport / neReleaseRef are System-layer engine calls, kept as-is
// (not reimplemented here).
- (void)LayoutedGLView:(neGLView *)view {
    neGetCurrentRenderer();
    int w = [view GetFrontBufferWidth];
    int h = [view GetFrontBufferHeight];
    neViewport *viewport = neCreateOrthoViewport((float)w, (float)h, 0, 0, w, h);
    neSetCurrentViewport(viewport);
    neReleaseRef(viewport);
    [view BeginRender];
    [view SetDefaultFrameBuffer];
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    [view SetDefaultColorBuffer];
    [view Present];
    // Publish the new drawable pixel size (keeps the scale set by neGLView
    // -layoutSubviews). Ghidra: DAT_00187b78 / DAT_00187b7c.
    neSceneManager::setScreenMetrics((float)w, (float)h, neSceneManager::screenScale());
}

// @ 0xc150 — the hosted GL view.
- (neGLView *)GetGlView {
    return _glView;
}

// @ 0xbb98 — arm a one-shot frame capture; -draw performs it on the next
// rendered frame.
- (void)screenshot {
    m_flgCapture = YES;
}

// @ 0xbbac — return the stored screenshot image (nil until -draw services a
// capture).
- (UIImage *)getCapturedImage {
    return m_capturedImg;
}

// @ 0xbbbc — drop the stored screenshot (ARC releases on nil-assign).
- (void)releaseCapturedImage {
    if (m_capturedImg != nil) {
        m_capturedImg = nil;
    }
}

// @ 0xbed0 — stop the loop for good (title exit): clear the run flag then drop
// the timer.
- (void)StopLoop {
    m_IsLoop = NO;
    [self RemoveTimer];
}

#pragma mark - Feature gates

// @ 0xcf70 — the friend-manage screen is up (phone nav or iPad split).
- (BOOL)IsFriendManageEnable {
    if (_friendMngViewCtrl != nil) {
        return YES;
    }
    return _friendMngNaviCtrl != nil;
}

// @ 0xd21c — the pop'n link screen is up (phone nav or iPad split).
- (BOOL)IsPopnLinkEnable {
    if (_popnLinkViewCtrl != nil) {
        return YES;
    }
    return _popnLinkNaviCtrl != nil;
}

// @ 0xd548 — the store screen is up.
- (BOOL)IsStoreEnable {
    return _storeViewController != nil;
}

// @ 0xd918 — the invite-code screen is up.
- (BOOL)IsInviteCodeEnable {
    return _inviteNaviCtrl != nil;
}

// @ 0xda28 — the arcade-search screen is up.
- (BOOL)IsArcadeSearchEnable {
    return _searchNaviCtrl != nil;
}

// @ 0xe158 — the present-box screen is up.
- (BOOL)IsPresentBoxEnable {
    return _presentBoxViewCtrl != nil;
}

#pragma mark - Communicating overlay

// @ 0xd6a8 — raise the "communicating…" overlay (built once) and play its
// fade-in.
- (void)InsertCommunicating {
    if (_communicatingView == nil) {
        _communicatingView = [[CommunicatingView alloc] init];
        [self.view addSubview:_communicatingView.view];
        [_communicatingView startOpenAnimation];
    }
}

// @ 0xd764 — YES while the overlay is mid-fade.
- (BOOL)IsCommunicatingAnimationing {
    return [_communicatingView isAnimationing];
}

// @ 0xd790 — YES while the overlay is present.
- (BOOL)IsCommunicatingEnable {
    return _communicatingView != nil;
}

// @ 0xd7a8 — switch the overlay to its "communication failed" caption.
- (void)CommunicatingFailed {
    [_communicatingView failed];
}

// @ 0xd744 — begin removing the "communicating…" overlay: play its fade-out.
// The overlay itself is dropped later in -CommunicatingEndCallBack when the
// animation ends.
- (void)DeleteCommunicating {
    [_communicatingView startCloseAnimation];
}

// @ 0xd7c8 — the overlay finished closing; drop it (ARC releases on
// nil-assign).
- (void)CommunicatingEndCallBack {
    _communicatingView = nil;
}

#pragma mark - Camera roll

// @ 0xe704 — save a captured screenshot (stored under the app-support dir as
// `fileName`) into the camera roll; completion routes to onCompleteCapture:….
- (void)SaveToCameraRoll:(NSString *)fileName {
    _cameraRollSaving = YES;
    NSString *path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:fileName];
    NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
    UIImage *image = [UIImage imageWithData:data];
    UIImageWriteToSavedPhotosAlbum(
        image, self, @selector(onCompleteCapture:didFinishSavingWithError:contextInfo:), NULL);
}

// @ 0xe7c0 — camera-roll save completion: stash the error (nil on success) and
// clear the in-flight flag. (ARC drops the manual release/retain the binary
// does here.)
- (void)onCompleteCapture:(UIImage *)image
    didFinishSavingWithError:(NSError *)error
                 contextInfo:(void *)contextInfo {
    _cameraRollError = error;
    _cameraRollSaving = NO;
}

#pragma mark - Alerts

// @ 0xe810 — install the one-shot confirm callback fired by the alert
// delegates.
- (void)SetAlertViewCallback:(void (*)(void *))callback param:(void *)param {
    m_AlertViewCallback = callback;
    m_AlertViewCallbackParam = param;
}

// @ 0xe914 — CommonAlertView delegate. Tag 0 is the "device change" (account
// reset) confirm dialog: perform the reset (reinit UserSettingData, reopen the
// collab/invite/ login-bonus/treasure music, rebuild TreasureData on the
// managed context) and show a completion alert. Tag 1 routes to the registered
// confirm callback. (The button index is unused — the binary re-reads the alert
// tag both times.)
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (alertView.tag == 0) {
        [UserSettingData initForConvert];
        [[MusicManager getInstance] openCollaboMusic];
        [[MusicManager getInstance] openInviteMusic];
        [[MusicManager getInstance] openLoginBonusMusic];
        [[MusicManager getInstance] openTreasureMusic];
        [TreasureData init:AppDelegate.appDelegate.managedObjectContext];
        CommonAlertView *done =
            [[CommonAlertView alloc] initWithTitle:@"機種変更"
                                           message:@"データの初期化が完了しました。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [done show];
        return;
    }
    if (alertView.tag == 1 && m_AlertViewCallback != NULL) {
        m_AlertViewCallback(m_AlertViewCallbackParam);
    }
}

// @ 0xeac8 — CustomAlertView delegate: any dismissal fires the registered
// callback.
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (m_AlertViewCallback != NULL) {
        m_AlertViewCallback(m_AlertViewCallbackParam);
    }
}

#pragma mark - Reward app list

// @ 0xeaec — reward app-list appeared: nothing to do.
- (void)appListDidAppear {
}

// @ 0xeaf0 — reward app-list dismissed: play the cancel SE and clear the
// "viewing" flag.
- (void)appListDidDisappear {
    neEngine::playSystemSe(2);
    _rewardListViweing = NO;
}

// @ 0xeb1c — reward app-list failed to load: show a "communication failed"
// alert and clear the "viewing" flag.
- (void)appListFailLoadWithError:(NSError *)error {
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:nil
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
    _rewardListViweing = NO;
}

#pragma mark - Cover tap / black board

// @ 0xeba8 — a tap on the dim cover behind an iPad modal panel: close whichever
// boxed panel is open (present-box only when it isn't already animating),
// playing the cancel SE.
- (void)handleTapCoverView:(UITapGestureRecognizer *)gesture {
    if (_presentBoxViewCtrl != nil && ![_presentBoxViewCtrl isAnimationing]) {
        neEngine::playSystemSe(2);
        [_presentBoxViewCtrl startCloseAnimation];
    }
    if (_sortSelectViewCtrl != nil) {
        neEngine::playSystemSe(2);
        [_sortSelectViewCtrl startCloseAnimation];
    }
    if (_recommendViewCtrl != nil) {
        neEngine::playSystemSe(2);
        [_recommendViewCtrl startCloseAnimation];
    }
    if (_overScoreLogViewCtrl != nil) {
        neEngine::playSystemSe(2);
        [_overScoreLogViewCtrl startCloseAnimation];
    }
}

// @ 0xeca4 — snap an opaque black scrim over the whole view (built once), on
// top.
- (void)InsertBlackBoard {
    if (_blackBoardView == nil) {
        _blackBoardView = [[UIView alloc] initWithFrame:self.view.frame];
        _blackBoardView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:_blackBoardView];
    }
    _blackBoardView.alpha = 1.0f;
    [self.view bringSubviewToFront:_blackBoardView];
}

// @ 0xede8 — fade the black scrim in (alpha 0 -> 1 over 0.3s), building it if
// needed.
- (void)FadeInBlackBoard {
    if (_blackBoardView == nil) {
        _blackBoardView = [[UIView alloc] initWithFrame:self.view.frame];
        _blackBoardView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:_blackBoardView];
    }
    [self.view bringSubviewToFront:_blackBoardView];
    _blackBoardView.alpha = 0.0f;
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       _blackBoardView.alpha = 1.0f;
                     }
                     completion:nil];
}

// @ 0xefdc — fade the black scrim out (alpha 1 -> 0 over 0.5s) if it exists.
- (void)FadeOutBlackBoard {
    if (_blackBoardView != nil) {
        [self.view bringSubviewToFront:_blackBoardView];
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                           _blackBoardView.alpha = 0.0f;
                         }
                         completion:nil];
    }
}

#pragma mark - Synthesized accessors

// The remaining state accessors are synthesized @property accessors (atomic
// reads/ writes in the binary); their addresses are annotated on the @property
// lines in the header: settingViewing @ 0xf0d0, cameraRollSaving @ 0xf0e8,
// isDefaultDlFailed @ 0xf100, rewardListViweing @ 0xf118 /
// setRewardListViweing: @ 0xf130, isGotoTitle @ 0xf178 / setIsGotoTitle: @
// 0xf190, acMusicSelViewing @ 0xf1a8 / setAcMusicSelViewing: @ 0xf1c0,
// cameraRollError @ 0xf1d8.

@end
