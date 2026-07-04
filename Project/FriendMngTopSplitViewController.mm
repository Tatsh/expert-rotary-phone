//
//  FriendMngTopSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad friend-manage
//  split hub. Objective-C++ (drives the C++ "ne" engine singletons for the SE / scene-root
//  bridge).
//

#import "FriendMngTopSplitViewController.h"
#import "FriendMngTopViewController.h"     // left pane (also the iPhone hub); delegate target
#import "FriendListViewController.h"       // list section
#import "FriendRequestViewController.h"    // "presenting" (requests you sent) section
#import "FriendReplyViewController.h"       // reply section
#import "HowToViewCtrlPad.h"               // first-play how-to overlay
#import "UserSettingData.h"                // isFriendSelected / saveIsFriendSelected:
#import "DownloadMain.h"                   // friendRequestedCnt (reply badge)
#import "neEngineBridge.h"                 // neEngine::playSystemSe, neSceneManager::rootViewController

@interface FriendMngTopSplitViewController ()
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)handleTapCoverView;
@end

// ─── File-static frame helpers ───────────────────────────────────────────────
// Forward-declare so the section-handler methods below can call them; bodies are
// defined after @end (where @implementation { } ivars are already visible).
// Single caller per helper → no shared header needed.
static void friendMngSyncRightViewFrame(FriendMngTopSplitViewController *);
static void friendMngSetListFrame(FriendMngTopSplitViewController *);
static void friendMngSetListArrowFrame(FriendMngTopSplitViewController *);
static void friendMngSetRequestFrame(FriendMngTopSplitViewController *);
static void friendMngSetRequestArrowFrame(FriendMngTopSplitViewController *);
static void friendMngSetReplyFrame(FriendMngTopSplitViewController *);
static void friendMngSetReplyArrowFrame(FriendMngTopSplitViewController *);

@implementation FriendMngTopSplitViewController {
    @public   // the file-static frame helpers (defined after @end) reach these via self->;
              // @private ivars are visible but not *accessible* to C functions, so publish them.
    BOOL _isAnimationing;                     // guards a transition against re-entry
    UIImageView *_markView;                    // "new reply" warning badge (assigned by the left VC)
    FriendMngTopViewController *_leftViewCtrl; // left section-button column
    UINavigationController *_rightViewCtrl;    // right detail pane (swapped by the section buttons)
    UIImageView *_arrowImageView;              // selection arrow
    int _selectedIndex;                        // -1 uninitialised, 0 list, 1 request, 2 reply
    CGRect _listFrm;                           // right-pane frame for each section (all identical)
    CGRect _requestFrm;
    CGRect _replyFrm;
    CGRect _listArrowFrm;                      // arrow frame per section row
    CGRect _requestArrowFrm;
    CGRect _replyArrowFrm;
    HowToViewCtrlPad *_howToView;              // first-play how-to overlay
}

// .cxx_construct @ 0xc5414 — compiler-emitted C++ ivar constructor; not hand-written.

// @ 0xc3358 — build the dimmed backdrop (tap to close), the artwork panel, the left
// section column (FriendMngTopViewController), the right navigation pane, the selection
// arrow, and a top cover strip; then populate the list section.
- (instancetype)init {
    if ((self = [super init])) {
        // The three sections share the same right-pane rect (385,182,320,716).
        _listFrm    = CGRectMake(385, 182, 320, 716);
        _requestFrm = CGRectMake(385, 182, 320, 716);
        _replyFrm   = CGRectMake(385, 182, 320, 716);

        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _arrowImageView = [[UIImageView alloc] initWithImage:arrow];
        _listArrowFrm    = CGRectMake(365, 307, arrow.size.width, arrow.size.height);
        _requestArrowFrm = CGRectMake(365, 469, arrow.size.width, arrow.size.height);
        _replyArrowFrm   = CGRectMake(365, 631, arrow.size.width, arrow.size.height);
        _arrowImageView.frame = _listArrowFrm;

        // Dimmed, tappable backdrop.
        UIView *cover = [[UIView alloc] initWithFrame:
            CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView)]];

        // Artwork panel holding the split view, centred on screen.
        UIImage *bgImg = [UIImage imageNamed:@"fritop_bg"];
        UIImageView *bg = [[UIImageView alloc] initWithImage:bgImg];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center = CGPointMake(self.view.frame.size.width * 0.5f,
                                self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left section column (the friend-manage top VC, built for the split via
        // -initAtNavigationController; its own view is embedded here).
        _leftViewCtrl = [[FriendMngTopViewController alloc] init];
        [_leftViewCtrl initAtNavigationController];
        _leftViewCtrl.view.frame = CGRectMake(_leftViewCtrl.view.frame.origin.x + 65,
                                              _leftViewCtrl.view.frame.origin.y + 100,
                                              354, bgImg.size.height);
        _leftViewCtrl.delegate = self;
        [bg addSubview:_leftViewCtrl.view];

        // Right navigation pane.
        _rightViewCtrl = [[UINavigationController alloc] init];
        _rightViewCtrl.view.frame = _listFrm;
        _rightViewCtrl.view.clipsToBounds = YES;
        _rightViewCtrl.view.layer.borderColor =
            [UIColor colorWithRed:0 green:0.835f blue:0.679f alpha:1].CGColor;
        _rightViewCtrl.view.layer.borderWidth = 3;
        _rightViewCtrl.view.backgroundColor =
            [UIColor colorWithRed:0.953f green:0.953f blue:0.953f alpha:1];
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        // Top cover strip (swallows taps over the nav-bar band).
        UIView *topCover = [[UIView alloc] initWithFrame:
            CGRectMake(0, 0, self.view.frame.size.width, 140)];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView)]];

        // Show the friend-list section first.
        _selectedIndex = -1;
        [self onListButtonTouched:nil];
        [bg addSubview:_arrowImageView];
    }
    return self;
}

#pragma mark - Lifecycle

// dealloc @ 0xc3bbc — ARC-omitted: the binary only MRC-releases _leftViewCtrl /
// _rightViewCtrl, which ARC handles automatically (no other teardown).

// viewDidLoad @ 0xc3c2c — super-only override, omitted.
// didReceiveMemoryWarning @ 0xc3c58 — super-only override, omitted.

// @ 0xc3c84 — show/hide the "new reply" badge for a pending friend request.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _markView.hidden = ([[DownloadMain getInstance] friendRequestedCnt] < 1);
}

#pragma mark - Open/close animation

// @ 0xc3d08 — fade the view + nav view in over 0.5s.
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
    self.view.alpha = 1;
    self.navigationController.view.alpha = 1;
    [UIView commitAnimations];
}

// @ 0xc3e34 — clear the guard, then (first time only) show the friend how-to overlay.
- (void)endOpenAnimation {
    _isAnimationing = NO;
    if (![UserSettingData isFriendSelected]) {
        _howToView = [[HowToViewCtrlPad alloc] initWithFileNameArray:@[@"firstplay_friend"]];
        [self.view addSubview:_howToView.view];
        [self.view bringSubviewToFront:_howToView.view];
        [_howToView startOpenAnimation];
        [UserSettingData saveIsFriendSelected:YES];
    }
}

// @ 0xc3f68 — fade the view + nav view out over 0.3s.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xc4070 — remove the panel and notify the nav host it closed.
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(FriendManageEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Section handlers

// @ 0xc40d0 — switch the right pane to the friend-list section. The first population
// (selectedIndex < 0) swaps in place; later taps flip the pane. Ghidra flip block helper
// friendMngShowListView @ 0xc4448 (modeled here as a single flip whose completion clears
// the guard and restores the top VC's right bar item).
- (void)onListButtonTouched:(id)sender {
    if (_isAnimationing || _selectedIndex == 0) {
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    FriendListViewController *vc =
        [[FriendListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.navigationItem.hidesBackButton = YES;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"frilis_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        UIBarButtonItem *rightItem = vc.navigationItem.rightBarButtonItem;
        vc.navigationItem.rightBarButtonItem = nil;
        // Outer flip: collapse right view width → friendMngSyncRightViewFrame @ 0xc43b8.
        // Completion = friendMngShowListView @ 0xc4448: swap VC, then inner flip →
        // friendMngSetListFrame @ 0xc45a0; inner completion → friendMngSetListArrowFrame @ 0xc4700.
        [UIView transitionWithView:_rightViewCtrl.view
                          duration:0.3
                           options:UIViewAnimationOptionCurveEaseIn
                        animations:^{
            friendMngSyncRightViewFrame(self);
        } completion:^(BOOL finished) {
            [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"frilis_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
            [UIView transitionWithView:_rightViewCtrl.view
                              duration:0.3
                               options:UIViewAnimationOptionCurveEaseIn
                            animations:^{
                friendMngSetListFrame(self);
            } completion:^(BOOL fin) {
                friendMngSetListArrowFrame(self);
                vc.navigationItem.rightBarButtonItem = rightItem;
                _isAnimationing = NO;
            }];
        }];
    }
    _selectedIndex = 0;
}

// @ 0xc4760 — switch the right pane to the "presenting" (requests you sent) section.
// Ghidra flip block helper friendMngShowRequestView @ 0xc4ad8.
- (void)onRequestButtonTouched:(id)sender {
    if (_isAnimationing || _selectedIndex == 1) {
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    FriendRequestViewController *vc = [[FriendRequestViewController alloc] init];
    vc.navigationItem.hidesBackButton = YES;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"fripre_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        UIBarButtonItem *rightItem = vc.navigationItem.rightBarButtonItem;
        vc.navigationItem.rightBarButtonItem = nil;
        // Outer flip: friendMngSyncRightViewFrame2 @ 0xc4a48 (identical to 0xc43b8).
        // Completion = friendMngShowRequestView @ 0xc4ad8: swap VC + inner flip →
        // friendMngSetRequestFrame @ 0xc4c30; inner completion → friendMngSetRequestArrowFrame @ 0xc4d90.
        [UIView transitionWithView:_rightViewCtrl.view
                          duration:0.3
                           options:UIViewAnimationOptionCurveEaseIn
                        animations:^{
            friendMngSyncRightViewFrame(self);
        } completion:^(BOOL finished) {
            [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"fripre_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
            [UIView transitionWithView:_rightViewCtrl.view
                              duration:0.3
                               options:UIViewAnimationOptionCurveEaseIn
                            animations:^{
                friendMngSetRequestFrame(self);
            } completion:^(BOOL fin) {
                friendMngSetRequestArrowFrame(self);
                vc.navigationItem.rightBarButtonItem = rightItem;
                _isAnimationing = NO;
            }];
        }];
    }
    _selectedIndex = 1;
}

// @ 0xc4df0 — switch the right pane to the reply section. Ghidra flip block helper
// friendMngShowReplyView @ 0xc5140.
- (void)onReplyButtonTouched:(id)sender {
    if (_isAnimationing || _selectedIndex == 2) {
        return;
    }
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    FriendReplyViewController *vc =
        [[FriendReplyViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.navigationItem.hidesBackButton = YES;

    if (_selectedIndex < 0) {
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:vc animated:NO];
    } else {
        _isAnimationing = YES;
        // Outer flip: friendMngSyncRightViewFrame3 @ 0xc50b0 (identical to 0xc43b8).
        // Completion = friendMngShowReplyView @ 0xc5140: swap VC + inner flip →
        // friendMngSetReplyFrame @ 0xc5290; inner completion → friendMngSetReplyArrowFrame @ 0xc5370.
        [UIView transitionWithView:_rightViewCtrl.view
                          duration:0.3
                           options:UIViewAnimationOptionCurveEaseIn
                        animations:^{
            friendMngSyncRightViewFrame(self);
        } completion:^(BOOL finished) {
            [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
                                               forBarMetrics:UIBarMetricsDefault];
            [_rightViewCtrl popToRootViewControllerAnimated:NO];
            [_rightViewCtrl pushViewController:vc animated:NO];
            [UIView transitionWithView:_rightViewCtrl.view
                              duration:0.3
                               options:UIViewAnimationOptionCurveEaseIn
                            animations:^{
                friendMngSetReplyFrame(self);
            } completion:^(BOOL fin) {
                friendMngSetReplyArrowFrame(self);
                _isAnimationing = NO;
            }];
        }];
    }
    _selectedIndex = 2;
}

// @ 0xc53d0 — a backdrop / top-cover tap: play the cancel SE and fade the panel out.
- (void)handleTapCoverView {
    if (_isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// ─── File-static frame helpers ───────────────────────────────────────────────
// In the binary these are the block-invoke functions emitted by the compiler for
// the ObjC block literals captured in on{List,Request,Reply}ButtonTouched: and
// the friendMngShow*View completion helpers. Each has exactly one caller class
// (FriendMngTopSplitViewController) → file-static, no shared header.
//
// NOTE: friendMngSyncRightViewFrame{,2,3} (0xc43b8, 0xc4a48, 0xc50b0) are
// byte-for-byte identical in the binary; a single static body serves all three.

// Ghidra: friendMngSyncRightViewFrame @ 0xc43b8
// (and friendMngSyncRightViewFrame2 @ 0xc4a48, friendMngSyncRightViewFrame3 @ 0xc50b0)
// Outer-transition animations block: reads _rightViewCtrl.view.frame, zeroes
// size.width, then writes the modified frame back → collapses the right pane to
// zero width so the VC swap starts from an invisible right pane.
static void friendMngSyncRightViewFrame(FriendMngTopSplitViewController *self) {
    UIView *v = self->_rightViewCtrl.view;
    CGRect f = (v != nil) ? v.frame : CGRectZero;
    f.size.width = 0.0f;
    [self->_rightViewCtrl.view setFrame:f];
}

// Ghidra: friendMngSetListFrame @ 0xc45a0
// Inner-transition animations block inside friendMngShowListView (0xc4448):
// restores the right view's frame from the stored _listFrm after the VC swap.
static void friendMngSetListFrame(FriendMngTopSplitViewController *self) {
    [self->_rightViewCtrl.view setFrame:self->_listFrm];
}

// Ghidra: friendMngSetListArrowFrame @ 0xc4700
// Inner-transition completion: repositions the selection arrow to the list row.
static void friendMngSetListArrowFrame(FriendMngTopSplitViewController *self) {
    [self->_arrowImageView setFrame:self->_listArrowFrm];
}

// Ghidra: friendMngSetRequestFrame @ 0xc4c30
// Analogous to friendMngSetListFrame but for the "presenting" (requests) section.
static void friendMngSetRequestFrame(FriendMngTopSplitViewController *self) {
    [self->_rightViewCtrl.view setFrame:self->_requestFrm];
}

// Ghidra: friendMngSetRequestArrowFrame @ 0xc4d90
// Inner-transition completion for the request section.
static void friendMngSetRequestArrowFrame(FriendMngTopSplitViewController *self) {
    [self->_arrowImageView setFrame:self->_requestArrowFrm];
}

// Ghidra: friendMngSetReplyFrame @ 0xc5290
// Analogous to friendMngSetListFrame but for the reply section.
static void friendMngSetReplyFrame(FriendMngTopSplitViewController *self) {
    [self->_rightViewCtrl.view setFrame:self->_replyFrm];
}

// Ghidra: friendMngSetReplyArrowFrame @ 0xc5370
// Inner-transition completion for the reply section.
static void friendMngSetReplyArrowFrame(FriendMngTopSplitViewController *self) {
    [self->_arrowImageView setFrame:self->_replyArrowFrm];
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
