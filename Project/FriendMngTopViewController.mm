//
//  FriendMngTopViewController.m
//  pop'n rhythmin
//
//  See FriendMngTopViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. The open/close animations are byte-verified.
//  initAtNavigationController branches on the device (disassembly-verified frame
//  constants): iPhone wraps the hub in a navigation controller and stacks the
//  section buttons/captions at absolute offsets from a 568pt-derived vertical
//  centre; iPad leaves the view transparent (no navigation controller, returns
//  nil) and stacks them incrementally from y = 189. The section navigations
//  (onList/Request/Reply) are deferred (see HANDOFF.md).
//

#import "FriendMngTopViewController.h"

#import "DownloadMain.h" // friendRequestedCnt (drives the reply badge)
#import "FriendListViewController.h"
#import "FriendReplyViewController.h"
#import "FriendRequestViewController.h"
#import "HowToViewCtrl.h"
#import "UINavigationBar+RHHeader.h" // setBackgroundImageModern:
#import "UserSettingData.h"
#import "neEngineBridge.h" // neEngine::playSystemSe, neSceneManager::isPadDisplay

@implementation FriendMngTopViewController

// delegate @ 0xa6c00 / setDelegate: @ 0xa6c10 — synthesized assign accessors
// over m_Delegate.
@synthesize delegate = m_Delegate;

// dealloc @ 0xa6488 — ARC-omitted (super-only; _markView released
// automatically). viewDidLoad @ 0xa64b4 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xa64e0 — super-only override, omitted.

// @ 0xa650c — refresh the "new reply" badge on appear: shown only when at least
// one friend request is pending (DownloadMain friendRequestedCnt).
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _markView.hidden = ([[DownloadMain getInstance] friendRequestedCnt] < 1);
}

// @ 0xa59f0 — build the friend-manage hub. Verified against the disassembly: the
// discarded-init/self-retention (@ 0xa5a18), the device branch on g_bIsPadDisplay
// (@ 0xa5a8c), the per-device frame constants (list button y 189 on iPad, the
// centre offsets 100/166/196/260/307 on iPhone, from the constant pool at
// 0xa5dd0..0xa6484) and the raw setFrame arguments, the image names and
// selectors, and the first-play tutorial gate. The tutorial push at 0xa6390 is
// reached only when BOTH ![UserSettingData isFriendSelected] (@ 0xa636e,
// `tst; bne skip`) AND !neSceneManager::isPadDisplay() (@ 0xa638a) hold.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    // The binary (0xa5a18) calls -init only for its side effects and keeps the
    // original self; the result is intentionally discarded, so this is not
    // self = [self init].
    (void)[self init];
    m_Delegate = self;

    // The layout branches on the device. iPhone stacks the menu from a vertical
    // centre derived from the classic 568pt screen height; iPad (the left pane of
    // the split hub) stacks it from a fixed top.
    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGFloat centreY = (self.view.frame.size.height - 568.0f) * 0.5f;

    UINavigationController *nav = nil;
    if (!isPad) {
        // iPhone: a "friman_bg" backdrop wrapped in its own navigation controller
        // with a custom back button and nav-bar art.
        UIImageView *bg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friman_bg"]];
        [self.view addSubview:bg];

        nav = [[UINavigationController alloc] initWithRootViewController:self];
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(startCloseAnimation)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        [self.navigationController.navigationBar
            setBackgroundImageModern:[UIImage imageNamed:@"friman_navbar"]];
    } else {
        // iPad: the transparent left column of the split hub, with no navigation
        // controller (the split embeds this view directly; nil is returned).
        self.view.backgroundColor = [UIColor clearColor];
    }

    // The three section buttons all take the list button's size; each caption sits
    // below its button. The button and caption x are fixed per device (iPhone
    // 15/28, iPad 0/5). iPhone places each element at an absolute offset from the
    // vertical centre; iPad stacks incrementally from y = 189 using the running
    // element heights and a 72pt gap between sections.
    UIImage *listBtnImg = [UIImage imageNamed:@"friman_btn_list"];
    const CGFloat btnW = listBtnImg.size.width;
    const CGFloat btnH = listBtnImg.size.height;
    const CGFloat btnX = isPad ? 0.0f : 15.0f;
    const CGFloat textX = isPad ? 5.0f : 28.0f;

    NSString *const btnNames[3] = {
        @"friman_btn_list", @"friman_btn_presenting", @"friman_btn_receipt"};
    NSString *const textNames[3] = {
        @"friman_text_list", @"friman_text_presenting", @"friman_text_receipt"};
    const SEL actions[3] = {@selector(onListButtonTouched:),
                            @selector(onRequestButtonTouched:),
                            @selector(onReplyButtonTouched:)};

    CGFloat btnY[3];
    CGFloat textY[3];
    if (!isPad) {
        btnY[0] = centreY + 100.0f;
        textY[0] = centreY + 166.0f;
        btnY[1] = centreY + 196.0f;
        textY[1] = centreY + 260.0f;
        btnY[2] = centreY + 307.0f;
        textY[2] = centreY + 307.0f + btnH;
    } else {
        const CGFloat listTextH = [UIImage imageNamed:@"friman_text_list"].size.height;
        const CGFloat presTextH = [UIImage imageNamed:@"friman_text_presenting"].size.height;
        btnY[0] = 189.0f;
        textY[0] = btnY[0] + btnH;
        btnY[1] = textY[0] + listTextH + 72.0f;
        textY[1] = btnY[1] + btnH;
        btnY[2] = textY[1] + presTextH + 72.0f;
        textY[2] = btnY[2] + btnH;
    }

    for (int i = 0; i < 3; i++) {
        UIImage *bimg = [UIImage imageNamed:btnNames[i]];
        UIButton *b = [[UIButton alloc] initWithFrame:CGRectMake(btnX, btnY[i], btnW, btnH)];
        b.exclusiveTouch = YES;
        [b setBackgroundImage:bimg forState:UIControlStateNormal];
        [b addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];

        // The receipt button carries the "new reply" warning badge, added before its
        // caption. The badge sits inside the button (iPad tucks it at the top-left
        // corner with a negative offset; iPhone insets it slightly).
        if (i == 2) {
            _markView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"vie_cmn_warning"]];
            const CGSize warnSize = _markView.image.size;
            _markView.frame = isPad ? CGRectMake(-15.0f, -8.0f, warnSize.width, warnSize.height) :
                                      CGRectMake(5.0f, 15.0f, warnSize.width, warnSize.height);
            [b addSubview:_markView];
        }

        UIImage *timg = [UIImage imageNamed:textNames[i]];
        UIImageView *t = [[UIImageView alloc] initWithImage:timg];
        t.frame = CGRectMake(textX, textY[i], timg.size.width, timg.size.height);
        [self.view addSubview:t];
    }

    // On first entry (this is the iPhone hub only) push the friend how-to
    // tutorial, then mark it seen.
    if (![UserSettingData isFriendSelected] && !neSceneManager::isPadDisplay()) {
        HowToViewCtrl *howto =
            [[HowToViewCtrl alloc] initWithFileNameArray:@[ @"firstplay_friend" ]];
        howto.isCloseButtonEnable = YES;
        howto.backGroundImage = [UIImage imageNamed:@"friman_bg"];
        [self.navigationController pushViewController:howto animated:NO];
        [UserSettingData saveIsFriendSelected:YES];
    }

    return nav;
}

// @ 0xa6590 — fade the hub view + its nav view up to opaque over 0.5 s;
// endOpenAnimation clears the guard.
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

// @ 0xa66d0 — play the cancel SE, then (iPhone) fade the hub + its nav view out
// over 0.3 s with endCloseAnimation as the didStop; on iPad forward the close
// to the split-hub delegate. NB: the binary *clears* _isAnimationing here (strb
// #0 @ 0xa6742) instead of raising the guard — reproduced exactly as
// decompiled.
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

// @ 0xa687c — push the friend ranking list (iPhone); on iPad forward to the
// split hub delegate. The nav-bar art is swapped to the list's on the way in
// (backButtonFunc restores friman_navbar).
- (void)onListButtonTouched:(id)sender {
    neEngine::playSystemSe(1);
    if (!neSceneManager::isPadDisplay()) {
        FriendListViewController *vc =
            [[FriendListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImageModern:[UIImage imageNamed:@"frilis_navbar"]];
    } else {
        [m_Delegate onListButtonTouched:sender];
    }
}

// Plays the decide SE and, on iPhone, pushes the send-a-request screen
// (FriendRequestViewController: request by player id + a FriendRequestTable of
// recommendations + a FreeRequestListViewController "free request" list); on
// iPad it forwards to the split hub.
// @ 0xa69a8 — push the send-a-request screen (iPhone); iPad forwards to the
// split hub.
- (void)onRequestButtonTouched:(id)sender {
    neEngine::playSystemSe(1);
    if (!neSceneManager::isPadDisplay()) {
        FriendRequestViewController *vc = [[FriendRequestViewController alloc] init];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImageModern:[UIImage imageNamed:@"fripre_navbar"]];
    } else {
        [m_Delegate onRequestButtonTouched:sender];
    }
}

// @ 0xa6ad4 — push the incoming-requests reply screen (iPhone); iPad forwards
// to the split hub.
- (void)onReplyButtonTouched:(id)sender {
    neEngine::playSystemSe(1);
    if (!neSceneManager::isPadDisplay()) {
        FriendReplyViewController *vc =
            [[FriendReplyViewController alloc] initWithStyle:UITableViewStyleGrouped];
        if (self.navigationController.topViewController != self) {
            return;
        }
        [self.navigationController pushViewController:vc animated:YES];
        [self.navigationController.navigationBar
            setBackgroundImageModern:[UIImage imageNamed:@"frirep_navbar"]];
    } else {
        [m_Delegate onReplyButtonTouched:sender];
    }
}

@end
