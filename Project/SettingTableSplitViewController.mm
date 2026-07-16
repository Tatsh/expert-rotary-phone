//
//  SettingTableSplitViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad
//  settings split panel. Objective-C++ (drives the C++ scene manager for the
//  cancel SE and the root-VC close callback).
//

#import "SettingTableSplitViewController.h"

#import "SettingCustomerTableViewController.h"
#import "SettingGameTableViewController.h"
#import "SettingHowtoTableViewController.h"
#import "SettingOtherTableViewController.h"
#import "neEngineBridge.h"

// Root nav host (Ghidra: NESceneManager_rootViewController). The settings-close
// callback is sent to whatever VC the scene manager stored, mirroring the
// AC-viewer sibling.
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@interface SettingTableSplitViewController () {
@public // the de-inlined static helpers (settingTableSyncRightViewFrame etc.)
    // reach these via self->, matching the binary's by-offset access from
    // standalone functions.
    BOOL _isAnimationing;
    SettingTopViewController *_leftViewCtrl; // the four-button left column
    UINavigationController *_rightViewCtrl;  // the detail pane (swapped per tab)
    UIImageView *_arrowImageView;            // selection arrow (slides between rows)
    int _selectedIndex;                      // 0 game / 1 howto / 2 customer / 3 other
    CGRect _viewFrm[4];                      // right-pane frame per tab
    CGRect _arrowFrm[4];                     // arrow frame per tab
}
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)startViewAnimation:(int)index;
- (void)handleTapCoverView;
@end

// ---------------------------------------------------------------------------
// Block invoke helpers emitted by the compiler after the animation methods.
// Each captures self (at block-struct +0x14); settingTableSetRight/ArrowFrame
// also capture the selected-tab index (+0x18).
// ---------------------------------------------------------------------------

// Ghidra: settingTableSyncRightViewFrame @ 0xb6d54
// Zeroes the right navigation controller view's width while preserving its
// x-origin and height (collapses the pane horizontally).
// The nil-view branch (0xb6d96) uses CGRectZero, matching the ternary here.
// @complete
static void settingTableSyncRightViewFrame(SettingTableSplitViewController *self) {
    UIView *v = self->_rightViewCtrl.view;
    CGRect fr = v ? v.frame : CGRectZero;
    fr.size.width = 0.0f;
    [self->_rightViewCtrl.view setFrame:fr];
}

// Ghidra: settingTableSetRightViewFrame @ 0xb6f2c
// Applies the tab-indexed entry of _viewFrm to the right nav controller view.
// The binary indexes with index*16 (CGRect stride) off the ivar base (0xb6f70).
// @complete
static void settingTableSetRightViewFrame(SettingTableSplitViewController *self, NSInteger index) {
    self->_rightViewCtrl.view.frame = self->_viewFrm[index];
}

// Ghidra: settingTableSetArrowFrame @ 0xb709c
// Applies the tab-indexed entry of _arrowFrm to the selection arrow image view.
// @complete
static void settingTableSetArrowFrame(SettingTableSplitViewController *self, NSInteger index) {
    self->_arrowImageView.frame = self->_arrowFrm[index];
}

@implementation SettingTableSplitViewController

// .cxx_construct @ 0xb7144 — compiler-emitted C++ ivar constructor; not
// hand-written.

// @ 0xb5cb0 — build the dimmed backdrop (tap to close), the artwork panel, the
// left SettingTopViewController column (self is its split delegate), the right
// rounded nav pane pre-loaded with the ゲーム table, the selection arrow, and a
// top cover strip.
// Verified against disassembly: the four _viewFrm ((388,182,320,716),
// (388,332,320,266), (388,332,320,316), (388,182,320,716)), the four _arrowFrm
// (368 x; 317/417/517/617 y; arrow size), the +65 x / +100 y column offsets
// (literals at 0xb6610 / 0xb660c), cover alpha 0.5, border colour 0/0.835/0.679,
// background 0.953, border width 3, corner radius 6, and the "pl_konamiid_arrow"
// / "custom_bg" / "set_game_navbar" image names all match.
// @complete
- (instancetype)init {
    if ((self = [super init])) {
        // Right-pane frame per tab (the shorter panes leave room for the arrow
        // rows).
        _viewFrm[0] = CGRectMake(388, 182, 320, 716); // game
        _viewFrm[1] = CGRectMake(388, 332, 320, 266); // howto
        _viewFrm[2] = CGRectMake(388, 332, 320, 316); // customer
        _viewFrm[3] = CGRectMake(388, 182, 320, 716); // other

        // Selection arrow, one frame per row (same size, stepping Y).
        UIImage *arrow = [UIImage imageNamed:@"pl_konamiid_arrow"];
        _arrowImageView = [[UIImageView alloc] initWithImage:arrow];
        _arrowFrm[0] = CGRectMake(368, 317, arrow.size.width, arrow.size.height);
        _arrowFrm[1] = CGRectMake(368, 417, arrow.size.width, arrow.size.height);
        _arrowFrm[2] = CGRectMake(368, 517, arrow.size.width, arrow.size.height);
        _arrowFrm[3] = CGRectMake(368, 617, arrow.size.width, arrow.size.height);
        _arrowImageView.frame = _arrowFrm[0];

        // Dimmed, tappable backdrop that swallows touches (and closes the panel).
        UIView *cover = [[UIView alloc] initWithFrame:self.view.frame];
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        cover.userInteractionEnabled = YES;
        [self.view addSubview:cover];
        [cover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                        initWithTarget:self
                                                action:@selector(handleTapCoverView)]];

        // Artwork panel that hosts the split, centred on screen.
        UIImage *bgImg = [UIImage imageNamed:@"custom_bg"];
        UIImageView *bg = [[UIImageView alloc] initWithImage:bgImg];
        bg.userInteractionEnabled = YES;
        bg.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        bg.center =
            CGPointMake(self.view.frame.size.width * 0.5f, self.view.frame.size.height * 0.5f);
        [self.view addSubview:bg];

        // Left column: the four-button custom menu, forwarding taps to us.
        _leftViewCtrl = [[SettingTopViewController alloc] init];
        // Offsets applied to the column's own frame are small engine constants
        // (Ghidra DAT_000b6610 = 65 added to x / DAT_000b660c = 100 added to y);
        // the column is 354 wide, bg-tall.
        _leftViewCtrl.view.frame = CGRectMake(_leftViewCtrl.view.frame.origin.x + 65,
                                              _leftViewCtrl.view.frame.origin.y + 100,
                                              354,
                                              bgImg.size.height);
        [_leftViewCtrl setSettingTopDelegate:self];
        [bg addSubview:_leftViewCtrl.view];

        // Right pane: a rounded, bordered navigation controller.
        _rightViewCtrl = [[UINavigationController alloc] init];
        _rightViewCtrl.view.frame = _viewFrm[0];
        _rightViewCtrl.view.layer.borderColor =
            [UIColor colorWithRed:0 green:0.835f blue:0.679f alpha:1].CGColor;
        _rightViewCtrl.view.layer.borderWidth = 3;
        _rightViewCtrl.view.backgroundColor = [UIColor colorWithRed:0.953f
                                                              green:0.953f
                                                               blue:0.953f
                                                              alpha:1];
        _rightViewCtrl.view.layer.cornerRadius = 6;
        [bg addSubview:_rightViewCtrl.view];

        // Pre-load the ゲーム (game) table.
        SettingGameTableViewController *game =
            [[SettingGameTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        game.navigationItem.hidesBackButton = YES;
        [_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:@"set_game_navbar"]
                                           forBarMetrics:UIBarMetricsDefault];
        [_rightViewCtrl pushViewController:game animated:NO];

        // Top cover strip (blocks the panel's title area from stray taps).
        UIView *topCover =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 140)];
        [self.view addSubview:topCover];
        [topCover addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                                   action:@selector(handleTapCoverView)]];

        _selectedIndex = 0;
        [bg addSubview:_arrowImageView];
    }
    return self;
}

// dealloc @ 0xb6614 — only released _leftViewCtrl / _rightViewCtrl, which ARC
// does automatically; no other teardown, so omitted under ARC.

// viewDidLoad @ 0xb6684 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xb66b0 — super-only override, omitted.

#pragma mark - Open/close animation (shared modal-VC lifecycle)

// @ 0xb66dc — fade the view + nav view in over 0.5 s.
// The open duration is inline vmov 0x3fe0000000000000 (0.5 s exactly).
// @complete
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

// @ 0xb6808
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xb6820 — fade the view + nav view out over 0.3 s.
// The close duration literal at 0xb6920 decodes to 0x3fd3333340000000 (the
// double widening of 0.3f), i.e. 0.3 s, unlike the 0.5 s open fade.
// @complete
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

// @ 0xb6928 — remove the panel and notify the settings host it closed.
// Order matches the binary: removeFromSuperview, performSelector, flag = NO.
// @complete
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - SettingTopViewControllerDalegate (left-column button taps)

// @ 0xb6984 / 0xb6998 / 0xb69ac / 0xb69c0 — each button switches the right pane
// to its tab. Each is a tail call to startViewAnimation: with 0/1/2/3.
// @complete
- (void)onGameButtonTouched:(id)sender {
    [self startViewAnimation:0];
}
- (void)onHowtoButtonTouched:(id)sender {
    [self startViewAnimation:1];
}
- (void)onCustomerButtonTouched:(id)sender {
    [self startViewAnimation:2];
}
- (void)onOtherButtonTouched:(id)sender {
    [self startViewAnimation:3];
}

#pragma mark - Right-pane swap

// @ 0xb69d4 — cross-dissolve the right pane to the tapped tab's table (resizing
// the pane to that tab's frame) and slide the selection arrow to its row.
// Verified: guard on _isAnimationing then _selectedIndex == index; the switch
// (tbb at 0xb6a8c) maps 0/1/2/3 to Game/Howto/Customer/Other with navbar names
// set_game_navbar / set_howto_navbar / set_inquiry_navbar / set_other_navbar;
// case 3 also sends setViewCmnDelegate:self (0xb6bc8); the default (index > 3)
// returns; outer transition duration 0.25 with CurveEaseIn (options 0x10000),
// arrow animateWithDuration 0.5 with AllowUserInteraction (options 0x2); the
// saved right bar button item is restored in the innermost completion.
// @complete
- (void)startViewAnimation:(int)index {
    if (_isAnimationing || _selectedIndex == index) {
        return;
    }
    _isAnimationing = YES;

    // Drop the current pane's bar-button items before swapping.
    _rightViewCtrl.topViewController.navigationItem.leftBarButtonItem = nil;
    _rightViewCtrl.topViewController.navigationItem.rightBarButtonItem = nil;

    UITableViewController *vc = nil;
    NSString *navbar = nil;
    switch (index) {
    case 0:
        vc = [[SettingGameTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        navbar = @"set_game_navbar";
        break;
    case 1:
        vc = [[SettingHowtoTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        navbar = @"set_howto_navbar";
        break;
    case 2:
        vc = [[SettingCustomerTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        navbar = @"set_inquiry_navbar";
        break;
    case 3: {
        SettingOtherTableViewController *other =
            [[SettingOtherTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [other setViewCmnDelegate:(id)self]; // forwarded down to the embedded
                                             // ConversionView
        vc = other;
        navbar = @"set_other_navbar";
        break;
    }
    default:
        return;
    }
    vc.navigationItem.hidesBackButton = YES;
    UIBarButtonItem *savedRight = vc.navigationItem.rightBarButtonItem;
    vc.navigationItem.rightBarButtonItem = nil;

    // Two-stage cross-dissolve. The outer transition collapses the pane to zero
    // width (settingTableSyncRightViewFrame @ 0xb6d54); its completion swaps in
    // the new table + navbar, then a nested transition expands the pane to the
    // tapped tab's frame (settingTableSetRightViewFrame @ 0xb6f2c). Only the
    // innermost completion restores the bar-button item and clears the animating
    // flag.
    [UIView transitionWithView:_rightViewCtrl.view
        duration:0.25
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
          CGRect fr = self->_rightViewCtrl.view.frame;
          fr.size.width = 0.0f;
          self->_rightViewCtrl.view.frame = fr;
        }
        completion:^(BOOL finished) {
          [self->_rightViewCtrl setViewControllers:@[ vc ] animated:NO];
          [self->_rightViewCtrl.navigationBar setBackgroundImage:[UIImage imageNamed:navbar]
                                                   forBarMetrics:UIBarMetricsDefault];
          [UIView transitionWithView:self->_rightViewCtrl.view
              duration:0.25
              options:UIViewAnimationOptionCurveEaseIn
              animations:^{
                self->_rightViewCtrl.view.frame = self->_viewFrm[index];
              }
              completion:^(BOOL finished2) {
                vc.navigationItem.rightBarButtonItem = savedRight;
                self->_isAnimationing = NO;
              }];
        }];
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       self->_arrowImageView.frame = self->_arrowFrm[index];
                     }
                     completion:nil];
    _selectedIndex = index;
}

#pragma mark - Handlers

// @ 0xb7100 — a backdrop / top-cover tap: play the cancel SE and fade the panel
// out. Verified: guard on _isAnimationing, playSystemSe(2) (0xb712a, r1 = 2),
// then tail call to startCloseAnimation.
// @complete
- (void)handleTapCoverView {
    if (_isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
