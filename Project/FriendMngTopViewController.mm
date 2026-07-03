//
//  FriendMngTopViewController.m
//  pop'n rhythmin
//
//  See FriendMngTopViewController.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The open/close animations are byte-verified; initAtNavigationController's button/image/action
//  wiring is reconstructed, with its NEON-spilled, device-branched frame origins flagged (they are
//  laid out relative to the hub-view centre). The first-play HowToViewCtrl tutorial and the section
//  navigations (onList/Request/Reply) are deferred (see HANDOFF.md).
//

#import "FriendMngTopViewController.h"
#import "HowToViewCtrl.h"
#import "UserSettingData.h"
#import "FriendListViewController.h"
#import "FriendReplyViewController.h"
#import "DownloadMain.h"            // friendRequestedCnt (drives the reply badge)
#import "neEngineBridge.h"          // neEngine::playSystemSe, neSceneManager::isPadDisplay

@implementation FriendMngTopViewController

// delegate @ 0xa6c00 / setDelegate: @ 0xa6c10 — synthesized assign accessors over m_Delegate.
@synthesize delegate = m_Delegate;

// dealloc @ 0xa6488 — ARC-omitted (super-only; _markView released automatically).
// viewDidLoad @ 0xa64b4 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xa64e0 — super-only override, omitted.

// @ 0xa650c — refresh the "new reply" badge on appear: shown only when at least one
// friend request is pending (DownloadMain friendRequestedCnt).
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _markView.hidden = ([[DownloadMain getInstance] friendRequestedCnt] < 1);
}

// @ 0xa59f0 — build the hub + wrap it in a navigation controller.
- (UINavigationController *)initAtNavigationController {
    [self init];
    m_Delegate = self;

    // Backdrop.
    UIImageView *bg = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"friman_bg"]];
    [self.view addSubview:bg];

    // Wrap self in its own navigation controller with a custom back button + nav-bar art.
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:self];
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(startCloseAnimation)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"] forBarMetrics:UIBarMetricsDefault];

    // Three section buttons (list / presenting / reply) with their caption images. Frames are
    // centre-relative and NEON-spilled in the binary; best-effort vertical stack here.
    const CGFloat cx = self.view.frame.size.width * 0.5f;
    CGFloat y = 30.0f;
    struct { NSString *btn; NSString *text; SEL action; } sections[3] = {
        { @"friman_btn_list",       @"friman_text_list",       @selector(onListButtonTouched:) },
        { @"friman_btn_presenting", @"friman_text_presenting", @selector(onRequestButtonTouched:) },
        { @"friman_btn_receipt",    @"friman_text_receipt",    @selector(onReplyButtonTouched:) },
    };
    for (int i = 0; i < 3; i++) {
        UIImage *bimg = [UIImage imageNamed:sections[i].btn];
        UIButton *b = [[UIButton alloc]
            initWithFrame:CGRectMake(cx - bimg.size.width * 0.5f, y, bimg.size.width, bimg.size.height)];
        b.exclusiveTouch = YES;
        [b setBackgroundImage:bimg forState:UIControlStateNormal];
        [b addTarget:self action:sections[i].action forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];

        UIImage *timg = [UIImage imageNamed:sections[i].text];
        UIImageView *t = [[UIImageView alloc] initWithImage:timg];
        t.frame = CGRectMake(cx - timg.size.width * 0.5f, y, timg.size.width, timg.size.height);
        [self.view addSubview:t];

        // The reply button carries a "new reply" warning badge.
        if (i == 2) {
            _markView = [[UIImageView alloc]
                initWithImage:[UIImage imageNamed:@"vie_cmn_warning"]];
            _markView.frame = CGRectMake(5.0f, 15.0f,
                                         _markView.image.size.width, _markView.image.size.height);
            [b addSubview:_markView];
        }
        y += bimg.size.height + 20.0f;
    }

    // On first entry (this is the iPhone hub) push the friend how-to tutorial, then mark it seen.
    if (![UserSettingData isFriendSelected]) {
        HowToViewCtrl *howto = [[HowToViewCtrl alloc]
            initWithFileNameArray:@[@"firstplay_friend"]];
        howto.isCloseButtonEnable = YES;
        howto.backGroundImage = [UIImage imageNamed:@"friman_bg"];
        [self.navigationController pushViewController:howto animated:NO];
        [UserSettingData saveIsFriendSelected:YES];
    }

    return nav;
}

// @ 0xa6590 — fade the hub view + its nav view up to opaque over 0.5 s; endOpenAnimation clears
// the guard.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xa66bc
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xa66d0 — play the cancel SE, then (iPhone) fade the hub + its nav view out over
// 0.3 s with endCloseAnimation as the didStop; on iPad forward the close to the split-hub
// delegate. NB: the binary *clears* _isAnimationing here (strb #0 @ 0xa6742) instead of
// raising the guard — reproduced exactly as decompiled.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);
    if (!neSceneManager::isPadDisplay()) {
        if (_isAnimationing) {
            return;
        }
        _isAnimationing = NO;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    } else {
        [m_Delegate startCloseAnimation];
    }
}

// @ 0xa6810 — pull the nav view, notify the root VC the friend hub closed
// (FriendManageEndCallBack), then clear the animation guard.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(FriendManageEndCallBack)];
    _isAnimationing = NO;
}

// @ 0xa687c — push the friend ranking list (iPhone); on iPad forward to the split hub delegate.
// The nav-bar art is swapped to the list's on the way in (backButtonFunc restores friman_navbar).
- (void)onListButtonTouched:(id)sender {
    neEngine::playSystemSe(1);
    if (!neSceneManager::isPadDisplay()) {
        FriendListViewController *vc = [[FriendListViewController alloc]
            initWithStyle:UITableViewStyleGrouped];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"frilis_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [m_Delegate onListButtonTouched:sender];
    }
}

// @ 0xa69a8 — DEFERRED STUB (intentionally left for a later pass; see HANDOFF.md).
// The real implementation plays the decide SE and, on iPhone, pushes a FriendRequestViewController
// (init; nav bar art "fripre_navbar"); on iPad it forwards to m_Delegate. That controller (send a
// request by player id, with a FriendRequestTable of recommendations and a FreeRequestListViewController
// "free request" list) is a separate reconstruction unit, so this action is a no-op stub for now.
- (void)onRequestButtonTouched:(id)sender {
    // TODO(friend-request): push FriendRequestViewController once it + FriendRequestTable +
    // FreeRequestListViewController are reconstructed. Method/ivar map is recorded in HANDOFF.md.
}

// @ 0xa6ad4 — push the incoming-requests reply screen (iPhone); iPad forwards to the split hub.
- (void)onReplyButtonTouched:(id)sender {
    neEngine::playSystemSe(1);
    if (!neSceneManager::isPadDisplay()) {
        FriendReplyViewController *vc = [[FriendReplyViewController alloc]
            initWithStyle:UITableViewStyleGrouped];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    } else {
        [m_Delegate onReplyButtonTouched:sender];
    }
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
