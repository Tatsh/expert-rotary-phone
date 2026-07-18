//
//  AcViewerSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad
//  AC-viewer split panel. Objective-C++ (drives the C++ scene manager for
//  close/teardown).
//

#import "AcViewerSplitViewController.h"
#import "AcViewerCategoryViewController.h"
#import "AcViewerMusicViewController.h"
#import "AcViewerOptionViewController.h" // pushed option screen (delegate = self)
#import "MainViewController.h"           // scene root -setAcMusicSelViewing:
#import "UserSettingData.h"
#import "neEngineBridge.h"

// Root nav host + last-selected reset live on the engine singletons (Ghidra:
// NESceneManager_rootViewController, NEAppEventCenter last-music @
// DAT_00187bf0).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// Self is the pushed AcViewerOptionViewController's delegate (opt.delegate =
// self).
@interface AcViewerSplitViewController () <AcViewerViewControllerDelegate>
@end

// The modal open/close (fade) transition duration, shared by
// startOpenAnimation / startCloseAnimation.
static const NSTimeInterval kModalAnimationDuration = 0.5;

@implementation AcViewerSplitViewController {
    UIViewController *_leftViewCtrl;        // left button column
    UINavigationController *_rightViewCtrl; // right list pane
    UIImageView *_arrowImageView;           // selection arrow
    UIButton *_btnCategory;
    UIButton *_btnMusicName;
    UIButton *_btnGenre;
    CGRect _rightViewFrm;      // 385,182,320,716
    CGRect _categoryArrowFrm;  // 365,307,…
    CGRect _musicNameArrowFrm; // 365,469,…
    CGRect _genreArrowFrm;     // 365,631,…
    UIButton *_selectedButton; // currently-selected left-column button (nil = none)
    BOOL _isAnimationing;
}

// .cxx_construct @ 0x33510 — compiler-emitted C++ ivar constructor; not
// hand-written.

// @ 0x318e8 — build the dimmed backdrop (tap to close), the artwork panel, the
// left button column (initForLeftView), the right navigation pane hosting the
// category list, the selection arrow, and a back button.
// @complete
- (instancetype)init {
    if ((self = [super init])) {
        _rightViewFrm = CGRectMake(385, 182, 320, 716);

        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _arrowImageView = [[UIImageView alloc] initWithImage:arrow];
        _categoryArrowFrm = CGRectMake(365, 307, arrow.size.width, arrow.size.height);
        _musicNameArrowFrm = CGRectMake(365, 469, arrow.size.width, arrow.size.height);
        _genreArrowFrm = CGRectMake(365, 631, arrow.size.width, arrow.size.height);
        _arrowImageView.frame = _categoryArrowFrm;

        // Dimmed, tappable backdrop.
        UIView *cover = [[UIView alloc] initWithFrame:self.view.frame];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                        initWithTarget:self
                                                action:@selector(handleTapCoverView)]];

        // Artwork panel that holds the split view, centred on the screen.
        UIImage *bgImg = [UIImage imageNamed:@"acv_bg"];
        UIImageView *bg = [[UIImageView alloc] initWithImage:bgImg];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center =
            CGPointMake(self.view.frame.size.width * 0.5f, self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left column of category buttons.
        _leftViewCtrl = [[UIViewController alloc] init];
        [self initForLeftView];
        // Ghidra: the origin's x is nudged right by 65 (DAT_00032194) before the
        // frame is set.
        _leftViewCtrl.view.frame =
            CGRectMake(_leftViewCtrl.view.frame.origin.x + 65, 182, 354, 716);
        [bg addSubview:_leftViewCtrl.view];

        // Right navigation pane hosting the category list.
        _rightViewCtrl = [[UINavigationController alloc] init];
        _rightViewCtrl.view.frame = _rightViewFrm;
        _rightViewCtrl.view.layer.borderColor =
            [UIColor colorWithRed:0 green:0.835f blue:0.679f alpha:1].CGColor;
        _rightViewCtrl.view.layer.borderWidth = 3;
        _rightViewCtrl.view.backgroundColor = [UIColor colorWithRed:0.953f
                                                              green:0.953f
                                                               blue:0.953f
                                                              alpha:1];
        _rightViewCtrl.navigationController.delegate = (id<UINavigationControllerDelegate>)self;
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        AcViewerCategoryViewController *cat =
            [[AcViewerCategoryViewController alloc] initWithStyle:UITableViewStyleGrouped];
        cat.delegate = (id)self;
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_friman_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:cat animated:NO];
        [bg addSubview:_arrowImageView];

        // Secondary top cover strip + back button.
        UIView *topCover =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 140)];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                                   action:@selector(handleTapCoverView)]];

        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *back = [[UIButton alloc]
            initWithFrame:CGRectMake(10, 10, backImg.size.width, backImg.size.height)];
        [back setBackgroundImage:backImg forState:UIControlStateNormal];
        [back addTarget:self
                      action:@selector(onBackButtonTouched:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:back];

        _selectedButton = 0;
    }
    return self;
}

// @ 0x322c4 — the left column: category / music-name / genre buttons, stacked.
// @complete
- (void)initForLeftView {
    if (_leftViewCtrl == nil) {
        return;
    }
    _leftViewCtrl.view.backgroundColor = [UIColor clearColor];

    UIImage *catImg = [UIImage imageNamed:@"acv_btn_ver"];
    _btnCategory =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 105, catImg.size.width, catImg.size.height)];
    _btnCategory.exclusiveTouch = YES;
    [_btnCategory setBackgroundImage:catImg forState:UIControlStateNormal];
    [_btnCategory addTarget:self
                     action:@selector(onButtonTouched:)
           forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnCategory];

    UIImage *mnImg = [UIImage imageNamed:@"acv_btn_musicname"];
    CGFloat mnY = CGRectGetMaxY(_btnCategory.frame) + 16;
    _btnMusicName =
        [[UIButton alloc] initWithFrame:CGRectMake(0, mnY, mnImg.size.width, mnImg.size.height)];
    _btnMusicName.exclusiveTouch = YES;
    [_btnMusicName setBackgroundImage:mnImg forState:UIControlStateNormal];
    [_btnMusicName addTarget:self
                      action:@selector(onButtonTouched:)
            forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnMusicName];

    UIImage *gnImg = [UIImage imageNamed:@"acv_btn_genrename"];
    CGFloat gnY = CGRectGetMaxY(_btnMusicName.frame) + 16;
    _btnGenre =
        [[UIButton alloc] initWithFrame:CGRectMake(0, gnY, gnImg.size.width, gnImg.size.height)];
    _btnGenre.exclusiveTouch = YES;
    [_btnGenre setBackgroundImage:gnImg forState:UIControlStateNormal];
    [_btnGenre addTarget:self
                  action:@selector(onButtonTouched:)
        forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnGenre];
}

#pragma mark - Lifecycle

// @ 0x32234 — detach the selection arrow from its superview on teardown; the
// left/right panel controllers are released automatically under ARC.
// @complete
- (void)dealloc {
    [_arrowImageView removeFromSuperview];
}

// viewDidLoad @ 0x326d4 — super-only override, omitted.
// didReceiveMemoryWarning @ 0x32700 — super-only override, omitted.

#pragma mark - Open/close animation (shared modal-VC lifecycle)

// @ 0x3272c — fade the view + nav view in over ~0.5s.
// @complete
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kModalAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1;
    self.navigationController.view.alpha = 1;
    [UIView commitAnimations];
}

// @ 0x32858
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x32870 — reset the last-selected music, then fade out (phone) / fade the
// black board in (iPad) and dismiss.
// @complete
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    // @0x32870: force event-center init, then reset the current AC-viewer
    // browsing music id.
    neAppEventCenter::shared();
    neAppEventCenter::clearAcViewerCurrentMusic(); // g_dwAcViewerMusicId = -1
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:kModalAnimationDuration];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    } else {
        [RootVC() performSelector:@selector(FadeInBlackBoard)];
        [self performSelector:@selector(endCloseAnimation) withObject:nil afterDelay:0.5];
    }
}

// @ 0x329f0 — remove the panel and notify the nav host it closed.
// @complete
- (void)endCloseAnimation {
    UIView *v = neSceneManager::isPadDisplay() ? self.view : self.navigationController.view;
    [v removeFromSuperview];
    [RootVC() performSelector:@selector(AcViewerEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Hide -> option-screen transition

// @ 0x32a80 — begin hiding the split panel to reveal the AC-viewer option
// screen: freeze input on the nav view, then either fade the view + nav view
// out over 0.3 s (animated, didStop -> endHiddenAnimation) or, non-animated,
// fire hiddenFunc after a 0.3 s delay.
// @complete
- (void)startHiddenAnimation:(BOOL)animated {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.navigationController.view.userInteractionEnabled = NO;
    if (animated) {
        self.view.alpha = 1;
        self.navigationController.view.alpha = 1;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endHiddenAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    } else {
        [self performSelector:@selector(hiddenFunc) withObject:nil afterDelay:0.3];
    }
}

// @ 0x32c18 — non-animated hide path: snap the view + nav view transparent,
// then run endHiddenAnimation.
// @complete
- (void)hiddenFunc {
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [self endHiddenAnimation];
}

// @ 0x32c7c — swap the right pane from the category list to the AC-viewer
// option screen (delegate = self) and flag the root VC that the AC music
// selection is no longer viewing.
// @complete
- (void)endHiddenAnimation {
    _isAnimationing = NO;
    AcViewerOptionViewController *opt = [[AcViewerOptionViewController alloc] init];
    opt.delegate = self;
    [_rightViewCtrl popViewControllerAnimated:NO];
    [_rightViewCtrl pushViewController:opt animated:NO];
    ((MainViewController *)RootVC()).acMusicSelViewing = NO;
}

#pragma mark - Handlers

// @ 0x32d90 — a left-column button was tapped. If a transition isn't already
// running and the tapped button isn't the current selection, play the confirm
// SE, strip the current top VC's bar-button items, build the destination list
// controller for the button, then run a width "flip" transition on the right
// pane (collapse to 0 width -> swap the pushed VC -> expand back) while sliding
// the selection arrow to the tapped row. The four nested blocks (@ 0x33170 /
// 0x33200 / 0x33358 / 0x334b8) are annotated inline below.
//
// Durations: outer + inner width transitions 0.3 s (DAT_00033160 /
// DAT_00033350), arrow slide 0.6 s (DAT_00033168). Options 0x10000 =
// UIViewAnimationOptionCurveEaseIn; the arrow uses 0x2 =
// UIViewAnimationOptionAllowUserInteraction.
// @complete
- (void)onButtonTouched:(UIButton *)sender {
    if (_isAnimationing) {
        return;
    }
    if (_selectedButton == sender) {
        return;
    }
    neEngine::playSystemSe(1);

    // Clear the currently shown top controller's bar-button items before the
    // swap.
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    UIViewController *dest;
    CGRect targetArrowFrm;
    if (sender == _btnCategory) {
        AcViewerCategoryViewController *cat =
            [[AcViewerCategoryViewController alloc] initWithStyle:UITableViewStyleGrouped];
        cat.delegate = (id)self;
        dest = cat;
        targetArrowFrm = _categoryArrowFrm;
    } else if (sender == _btnGenre) {
        [UserSettingData saveIsAcvGenreName:YES];
        AcViewerMusicViewController *music = [[AcViewerMusicViewController alloc] initWithData:nil];
        music.delegate = (id)self;
        dest = music;
        targetArrowFrm = _genreArrowFrm;
    } else {
        [UserSettingData saveIsAcvGenreName:NO];
        AcViewerMusicViewController *music = [[AcViewerMusicViewController alloc] initWithData:nil];
        music.delegate = (id)self;
        dest = music;
        targetArrowFrm = _musicNameArrowFrm;
    }

    dest.navigationItem.hidesBackButton = YES;
    _isAnimationing = YES;

    UIBarButtonItem *savedRightItem = dest.navigationItem.rightBarButtonItem;
    dest.navigationItem.rightBarButtonItem = nil;
    dest.navigationItem.leftBarButtonItem = nil;

    [UIView transitionWithView:_rightViewCtrl.view
        duration:0.3
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
          // @ 0x33170 — collapse the right pane to zero width for the flip-in.
          CGRect f = _rightViewCtrl.view.frame;
          f.size.width = 0;
          _rightViewCtrl.view.frame = f;
        }
        completion:^(BOOL finished) {
          // @ 0x33200 — swap in the destination list, then expand the pane back.
          [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_friman_navbar"]
                                             forBarMetrics:UIBarMetricsDefault];
          [_rightViewCtrl popToRootViewControllerAnimated:NO];
          [_rightViewCtrl pushViewController:dest animated:NO];
          [UIView transitionWithView:_rightViewCtrl.view
              duration:0.3
              options:UIViewAnimationOptionCurveEaseIn
              animations:^{
                // @ 0x33358 — restore the pane to its full stored frame.
                _rightViewCtrl.view.frame = _rightViewFrm;
              }
              completion:^(BOOL innerFinished) {
                // @ 0x333d0 — put the saved right bar-button item back and
                // release the guard.
                dest.navigationItem.rightBarButtonItem = savedRightItem;
                _isAnimationing = NO;
              }];
        }];

    [UIView animateWithDuration:0.6
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       // @ 0x334b8 — slide the selection arrow to the tapped row.
                       _arrowImageView.frame = targetArrowFrm;
                     }
                     completion:nil];

    _selectedButton = sender;
}

// @ 0x32d44 — the back button: play the cancel SE, clear the pending AC-viewer
// selection (music id / difficulty -> "none"), then fade the panel out.
// @complete
- (void)onBackButtonTouched:(UIButton *)sender {
    neEngine::playSystemSe(2);
    neAppEventCenter::clearAcViewerSelection();
    [self startCloseAnimation];
}

// @ 0x3350c — the dimmed backdrop / top-cover taps are swallowed (the real
// handler is empty; the covers just block touches from falling through to the
// panel).
// @complete
- (void)handleTapCoverView {
}

@end
