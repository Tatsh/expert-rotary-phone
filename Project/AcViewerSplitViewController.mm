//
//  AcViewerSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad AC-viewer
//  split panel. Objective-C++ (drives the C++ scene manager for close/teardown).
//

#import "AcViewerSplitViewController.h"
#import "AcViewerCategoryViewController.h"
#import "neEngineBridge.h"

// Root nav host + last-selected reset live on the engine singletons (Ghidra:
// NESceneManager_rootViewController, NEAppEventCenter last-music @ DAT_00187bf0).
static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}
extern "C" void neAppEventSetLastMusic(int music);   // NEAppEventCenter DAT_00187bf0

@implementation AcViewerSplitViewController {
    UIViewController *_leftViewCtrl;         // left button column
    UINavigationController *_rightViewCtrl;  // right list pane
    UIImageView *_arrowImageView;            // selection arrow
    UIButton *_btnCategory;
    UIButton *_btnMusicName;
    UIButton *_btnGenre;
    CGRect _rightViewFrm;                    // 385,182,320,716
    CGRect _categoryArrowFrm;                // 365,307,…
    CGRect _musicNameArrowFrm;               // 365,469,…
    CGRect _genreArrowFrm;                   // 365,631,…
    int _selectedButton;
    BOOL _isAnimationing;
}

// @ 0x318e8 — build the dimmed backdrop (tap to close), the artwork panel, the left
// button column (initForLeftView), the right navigation pane hosting the category
// list, the selection arrow, and a back button.
- (instancetype)init {
    if ((self = [super init])) {
        _rightViewFrm = CGRectMake(385, 182, 320, 716);

        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _arrowImageView = [[[UIImageView alloc] initWithImage:arrow] autorelease];
        _categoryArrowFrm  = CGRectMake(365, 307, arrow.size.width, arrow.size.height);
        _musicNameArrowFrm = CGRectMake(365, 469, arrow.size.width, arrow.size.height);
        _genreArrowFrm     = CGRectMake(365, 631, arrow.size.width, arrow.size.height);
        _arrowImageView.frame = _categoryArrowFrm;

        // Dimmed, tappable backdrop.
        UIView *cover = [[[UIView alloc] initWithFrame:self.view.frame] autorelease];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView:)] autorelease]];

        // Artwork panel that holds the split view, centred on the screen.
        UIImage *bgImg = [UIImage imageNamed:@"acv_bg"];
        UIImageView *bg = [[[UIImageView alloc] initWithImage:bgImg] autorelease];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center = CGPointMake(self.view.frame.size.width * 0.5f,
                                self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left column of category buttons.
        _leftViewCtrl = [[UIViewController alloc] init];
        [self initForLeftView];
        _leftViewCtrl.view.frame = CGRectMake(_leftViewCtrl.view.frame.origin.x, 182, 354, 716);
        [bg addSubview:_leftViewCtrl.view];

        // Right navigation pane hosting the category list.
        _rightViewCtrl = [[UINavigationController alloc] init];
        _rightViewCtrl.view.frame = _rightViewFrm;
        _rightViewCtrl.view.layer.borderColor =
            [UIColor colorWithRed:0 green:0.835f blue:0.679f alpha:1].CGColor;
        _rightViewCtrl.view.layer.borderWidth = 3;
        _rightViewCtrl.view.backgroundColor =
            [UIColor colorWithRed:0.953f green:0.953f blue:0.953f alpha:1];
        _rightViewCtrl.navigationController.delegate = (id<UINavigationControllerDelegate>)self;
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        AcViewerCategoryViewController *cat =
            [[[AcViewerCategoryViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
        cat.delegate = (id)self;
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_friman_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl popToRootViewControllerAnimated:NO];
        [_rightViewCtrl pushViewController:cat animated:NO];
        [bg addSubview:_arrowImageView];

        // Secondary top cover strip + back button.
        UIView *topCover = [[[UIView alloc] initWithFrame:
            CGRectMake(0, 0, self.view.frame.size.width, 140)] autorelease];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTapCoverView:)] autorelease]];

        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *back = [[UIButton alloc] initWithFrame:
            CGRectMake(10, 10, backImg.size.width, backImg.size.height)];
        [back setBackgroundImage:backImg forState:UIControlStateNormal];
        [back addTarget:self action:@selector(onBackButtonTouched:)
              forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:back];

        _selectedButton = 0;
    }
    return self;
}

// @ 0x322c4 — the left column: category / music-name / genre buttons, stacked.
- (void)initForLeftView {
    if (_leftViewCtrl == nil) {
        return;
    }
    _leftViewCtrl.view.backgroundColor = [UIColor clearColor];

    UIImage *catImg = [UIImage imageNamed:@"acv_btn_ver"];
    _btnCategory = [[[UIButton alloc] initWithFrame:
        CGRectMake(0, 105, catImg.size.width, catImg.size.height)] autorelease];
    _btnCategory.exclusiveTouch = YES;
    [_btnCategory setBackgroundImage:catImg forState:UIControlStateNormal];
    [_btnCategory addTarget:self action:@selector(onButtonTouched:)
           forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnCategory];

    UIImage *mnImg = [UIImage imageNamed:@"acv_btn_musicname"];
    CGFloat mnY = CGRectGetMaxY(_btnCategory.frame) + 16;
    _btnMusicName = [[[UIButton alloc] initWithFrame:
        CGRectMake(0, mnY, mnImg.size.width, mnImg.size.height)] autorelease];
    _btnMusicName.exclusiveTouch = YES;
    [_btnMusicName setBackgroundImage:mnImg forState:UIControlStateNormal];
    [_btnMusicName addTarget:self action:@selector(onButtonTouched:)
            forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnMusicName];

    UIImage *gnImg = [UIImage imageNamed:@"acv_btn_genrename"];
    CGFloat gnY = CGRectGetMaxY(_btnMusicName.frame) + 16;
    _btnGenre = [[[UIButton alloc] initWithFrame:
        CGRectMake(0, gnY, gnImg.size.width, gnImg.size.height)] autorelease];
    _btnGenre.exclusiveTouch = YES;
    [_btnGenre setBackgroundImage:gnImg forState:UIControlStateNormal];
    [_btnGenre addTarget:self action:@selector(onButtonTouched:)
        forControlEvents:UIControlEventTouchUpInside];
    [_leftViewCtrl.view addSubview:_btnGenre];
}

#pragma mark - Open/close animation (shared modal-VC lifecycle)

// @ 0x3272c — fade the view + nav view in over ~0.5s.
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

// @ 0x32858
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x32870 — reset the last-selected music, then fade out (phone) / fade the
// black board in (iPad) and dismiss.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    neAppEventSetLastMusic(-1);
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
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
- (void)endCloseAnimation {
    UIView *v = neSceneManager::isPadDisplay() ? self.view : self.navigationController.view;
    [v removeFromSuperview];
    [RootVC() performSelector:@selector(AcViewerEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Handlers

// @ 0x32d90 — a left-column button was tapped: switch the right pane's list and move
// the selection arrow to that row. (Selection wiring modeled; the tapped button sets
// _selectedButton and the arrow frame accordingly.)
- (void)onButtonTouched:(UIButton *)sender {
    if (sender == _btnCategory) {
        _selectedButton = 0;
        _arrowImageView.frame = _categoryArrowFrm;
    } else if (sender == _btnMusicName) {
        _selectedButton = 1;
        _arrowImageView.frame = _musicNameArrowFrm;
    } else if (sender == _btnGenre) {
        _selectedButton = 2;
        _arrowImageView.frame = _genreArrowFrm;
    }
}

// @ 0x32... — the back button / backdrop tap both close the panel.
- (void)onBackButtonTouched:(UIButton *)sender {
    [self startCloseAnimation];
}

- (void)handleTapCoverView:(UITapGestureRecognizer *)gesture {
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
