//
//  SettingGameTableViewController.mm
//  pop'n rhythmin
//
//  See SettingGameTableViewController.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0x88b08, initAtNavigationController @ 0x88d7c, dealloc @ 0x88f5c,
//  viewDidLoad @ 0x88ff0, didReceiveMemoryWarning @ 0x8901c, viewDidAppear: @ 0x89048,
//  startOpenAnimation @ 0x89074, endOpenAnimation @ 0x891a0, startCloseAnimation @ 0x891b8,
//  endCloseAnimation @ 0x892d8, numberOfSectionsInTableView: @ 0x89344,
//  tableView:numberOfRowsInSection: @ 0x89348, tableView:heightForRowAtIndexPath: @ 0x8934c,
//  tableView:cellForRowAtIndexPath: @ 0x894d8, tableView:didSelectRowAtIndexPath: @ 0x8a27c,
//  settingClose @ 0x8a34c, .cxx_construct @ 0x8a35c -- the last is a compiler artifact and is
//  not reproduced). Objective-C++ for the neEngine SE + scene bridge.
//
//  The screen is a 6-row single section: rows 0/2/4 are the "back_bg_st" panelled category
//  headers (Sound / Game-effect / Pop-kun size), rows 1/3/5 are the collapsible in-line detail
//  rows. Tapping a header (didSelectRow) toggles _selectedIndexPath; heightForRow then expands
//  the matching detail row (row+1) from 0 to its dummy-frame height and cellForRow lazily builds
//  a rounded, coloured container that embeds the detail sub-controller's view.
//
//  DEPENDENCY NOTE: rows 1/3/5 embed three sub-controllers that are not yet reconstructed --
//  SoundSettingView, GameEffectView and PopkunSizeViewCtrl (see the TODO(dep) markers). Their
//  instantiation is left commented so this file references only existing/system classes; the
//  coloured detail container is still built so the layout stays faithful.
//
//  Honesty note: the panel/label centering in cellForRowAtIndexPath: and the row-container frames
//  are NEON-spilled in the binary (best-effort here, flagged inline). Frame origins/sizes recovered
//  from -[initWithStyle:]'s _dummyFrm writes are exact; colours are the exact float constants.
//

#import "SettingGameTableViewController.h"

#import "neEngineBridge.h"   // neEngine::playSystemSe, neSceneManager::isPadDisplay / rootViewController
#import "AppFont.h"          // AppFontName (label typeface)

// TODO(dep): SoundSettingView not yet reconstructed (row 1 detail -- initWithStyle:).
// TODO(dep): GameEffectView not yet reconstructed (row 3 detail -- initWithStyle:).
// TODO(dep): PopkunSizeViewCtrl not yet reconstructed (row 5 detail -- init).

static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

@implementation SettingGameTableViewController {
    BOOL _isAnimationing;               // @162 (0xa2)  open/close animation guard
    NSIndexPath *_selectedIndexPath;    // @164 (0xa4)  currently expanded header row (retained)
    UIViewController *_detailView[6];   // @168 (0xa8)  lazily-built detail controllers (indices 0/2/4)
    CGRect _dummyFrm[6];                // @192 (0xc0)  per-detail-row content frames (indices 0/2/4)
}

// @ 0x88b08 -- grouped-table styling; iPad content inset tweak; seeds the three detail-row frames.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self == nil) {
        return self;
    }

    self.tableView.rowHeight = 65.0f;                                   // 0x42820000
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    if (neSceneManager::isPadDisplay()) {
        // The binary writes the top inset twice; the first (-100) is immediately overwritten by
        // the version-based value below, so the net inset top is 20 (pre-iOS 7) or 0.
        self.tableView.contentInset = UIEdgeInsetsMake(-100.0f, 0, 0, 0);   // 0xc2c80000, overwritten
        CGFloat topInset = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? 20.0f : 0.0f;
        self.tableView.contentInset = UIEdgeInsetsMake(topInset, 0, 0, 0);  // 0x41a00000 / 0
    }

    // Detail-row content frames. x = 15 (iOS 7+) or 5 (pre-iOS 7); width 290. Heights differ per
    // section: Sound 320, Game-effect 137, Pop-kun size 430. Only indices 0/2/4 are populated.
    const CGFloat x = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? 5.0f : 15.0f;
    _dummyFrm[0] = CGRectMake(x, 0.0f, 290.0f, 320.0f);   // 0x43910000 / 0x43a00000
    _dummyFrm[2] = CGRectMake(x, 0.0f, 290.0f, 137.0f);   // 0x43910000 / 0x43090000
    _dummyFrm[4] = CGRectMake(x, 0.0f, 290.0f, 430.0f);   // 0x43910000 / 0x43d70000

    return self;
}

// @ 0x88d7c -- wrap self (grouped style) in a navigation controller with a custom back button and
// the "frirep_navbar" bar background.
- (UINavigationController *)initAtNavigationController {
    UINavigationController *nav = [UINavigationController alloc];
    [self initWithStyle:UITableViewStyleGrouped];
    nav = [nav initWithRootViewController:self];

    UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
    CGSize backSize = backImage ? backImage.size : CGSizeZero;
    UIButton *backButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backSize.width, backSize.height)];
    [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(settingClose)
         forControlEvents:UIControlEventTouchUpInside];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backButton];

    UIImage *barImage = [UIImage imageNamed:@"frirep_navbar"];
    [self.navigationController.navigationBar setBackgroundImage:barImage
                                                 forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// dealloc @ 0x88f5c — ARC-omitted (released object ivars only).

// @ 0x88ff0
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0x8901c
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0x89048
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0x89074 -- fade the view + nav view in over 0.5s.
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

// @ 0x891a0
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x891b8 -- play the "back/cancel" system SE, then fade the view + nav view out over 0.3s.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);   // Ghidra: SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // DAT_000892d0
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x892d8 -- remove and hand control back to MainViewController.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Table

// @ 0x89344
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x89348
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 6;   // 3 header rows (0/2/4) each followed by a collapsible detail row (1/3/5)
}

// @ 0x8934c -- detail rows (1/3/5) are 0-height unless the header above them is the selected row,
// in which case they expand to their _dummyFrm height. Header rows use the default 65pt.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 5) {
        NSIndexPath *parent = [NSIndexPath indexPathForRow:4 inSection:indexPath.section];
        if (_selectedIndexPath != nil && [_selectedIndexPath compare:parent] == NSOrderedSame) {
            return _dummyFrm[4].size.height;   // 430
        }
        return 0.0f;
    } else if (indexPath.row == 3) {
        NSIndexPath *parent = [NSIndexPath indexPathForRow:2 inSection:indexPath.section];
        if (_selectedIndexPath != nil && [_selectedIndexPath compare:parent] == NSOrderedSame) {
            return _dummyFrm[2].size.height;   // 137
        }
        return 0.0f;
    } else if (indexPath.row == 1) {
        NSIndexPath *parent = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
        if (_selectedIndexPath != nil && [_selectedIndexPath compare:parent] == NSOrderedSame) {
            return _dummyFrm[0].size.height;   // 320
        }
        return 0.0f;
    }
    return 65.0f;   // DAT_000894d4, header rows 0/2/4
}

// @ 0x894d8 -- builds either a category-header cell (rows 0/2/4) or a detail-container cell
// (rows 1/3/5) that embeds the section's sub-controller view.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId = [NSString stringWithFormat:@"Cell%ld-%ld",
                        (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell != nil) {
        return cell;
    }

    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:cellId];
    cell.backgroundView = nil;
    cell.backgroundColor = [UIColor clearColor];
    cell.clipsToBounds = YES;

    // Per-row header colour (used both as the header panel border and as the detail container's
    // border/background tint). Exact float constants from the binary.
    UIColor *headerColor = nil;

    switch (indexPath.row) {
        case 1: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            CGRect frm = _dummyFrm[0];
            UIView *box = [[UIView alloc] initWithFrame:frm];
            box.layer.borderWidth = 3.0f;
            box.layer.borderColor = [UIColor colorWithRed:1.0f green:0.647059f blue:0.627451f
                                                    alpha:1.0f].CGColor;   // 0x3f25a5a6 / 0x3f20a0a1
            box.layer.cornerRadius = 5.0f;
            box.clipsToBounds = YES;
            box.backgroundColor = [UIColor colorWithRed:0.996109f green:0.831373f blue:0.823529f
                                                  alpha:1.0f];             // 0x3f7efeff / 0x3f54d4d5 / 0x3f52d2d3
            UIView *inner = [[UIView alloc] init];
            inner.backgroundColor = [UIColor clearColor];
            inner.frame = CGRectMake(10.0f, 2.0f, frm.size.width - 20.0f, frm.size.height - 4.0f);
            [box addSubview:inner];
            if (_detailView[0] == nil) {
                // TODO(dep): SoundSettingView not yet reconstructed.
                // _detailView[0] = [[SoundSettingView alloc] initWithStyle:UITableViewStyleGrouped];
            }
            // _detailView[0].view.frame = CGRectMake(0, 0, frm.size.width - 20, frm.size.height - 4);
            // [inner addSubview:_detailView[0].view];
            [cell.contentView addSubview:box];
            return cell;
        }
        case 3: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            CGRect frm = _dummyFrm[2];
            UIView *box = [[UIView alloc] initWithFrame:frm];
            box.layer.borderWidth = 3.0f;
            box.layer.borderColor = [UIColor colorWithRed:1.0f green:0.733333f blue:0.313726f
                                                    alpha:1.0f].CGColor;   // 0x3f3bbbbc / 0x3ea0a0a1
            box.layer.cornerRadius = 5.0f;
            box.clipsToBounds = YES;
            box.backgroundColor = [UIColor colorWithRed:1.0f green:0.831373f blue:0.564706f
                                                  alpha:1.0f];             // 0x3f54d4d5 / 0x3f109091
            UIView *inner = [[UIView alloc] init];
            inner.backgroundColor = [UIColor clearColor];
            inner.frame = CGRectMake(10.0f, 2.0f, frm.size.width - 20.0f, frm.size.height - 4.0f);
            [box addSubview:inner];
            if (_detailView[2] == nil) {
                // TODO(dep): GameEffectView not yet reconstructed.
                // _detailView[2] = [[GameEffectView alloc] initWithStyle:UITableViewStyleGrouped];
            }
            // _detailView[2].view.frame = CGRectMake(0, 0, frm.size.width - 20, frm.size.height - 4);
            // [inner addSubview:_detailView[2].view];
            [cell.contentView addSubview:box];
            return cell;
        }
        case 5: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            CGRect frm = _dummyFrm[4];
            UIView *box = [[UIView alloc] initWithFrame:frm];
            box.layer.borderWidth = 3.0f;
            box.layer.borderColor = [UIColor colorWithRed:0.580392f green:0.960784f blue:0.372549f
                                                    alpha:1.0f].CGColor;   // 0x3f149495 / 0x3f75f5f6 / 0x3ebebebf
            box.layer.cornerRadius = 5.0f;
            box.clipsToBounds = YES;
            box.backgroundColor = [UIColor colorWithRed:0.741176f green:1.0f blue:0.6f
                                                  alpha:1.0f];             // 0x3f3dbdbe / 0x3f19999a
            UIView *inner = [[UIView alloc] init];
            inner.backgroundColor = [UIColor clearColor];
            // Row 5 trims 20 from the height (rows 1/3 trim 4).
            inner.frame = CGRectMake(10.0f, 2.0f, frm.size.width - 20.0f, frm.size.height - 20.0f);
            [box addSubview:inner];
            if (_detailView[4] == nil) {
                // TODO(dep): PopkunSizeViewCtrl not yet reconstructed.
                // _detailView[4] = [[PopkunSizeViewCtrl alloc] init];
            }
            // _detailView[4].view.frame = CGRectMake(0, 0, frm.size.width - 20, frm.size.height - 20);
            // [inner addSubview:_detailView[4].view];
            [cell.contentView addSubview:box];
            return cell;
        }
        case 0:
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            headerColor = [UIColor colorWithRed:1.0f green:0.647059f blue:0.627451f alpha:1.0f];
            break;
        case 2:
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            headerColor = [UIColor colorWithRed:1.0f green:0.733333f blue:0.313726f alpha:1.0f];
            break;
        case 4:
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            headerColor = [UIColor colorWithRed:0.580392f green:0.960784f blue:0.372549f alpha:1.0f];
            break;
    }

    // Category-header rows (0/2/4): a "back_bg_st" panelled, coloured-border box with a centred
    // title label. The panel/label centring is NEON-spilled in the binary (best-effort here).
    NSString *title = nil;
    switch (indexPath.row) {
        case 0: title = @"サウンド"; break;                        // サウンド (Sound)
        case 2: title = @"ゲーム演出"; break;                  // ゲーム演出 (Game effect)
        case 4: title = @"ポップ君サイズ"; break;      // ポップ君サイズ (Pop-kun size)
    }

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290.0f, 53.0f)];
    panel.layer.borderWidth = 3.0f;
    panel.layer.borderColor = headerColor.CGColor;
    panel.layer.cornerRadius = 5.0f;
    panel.clipsToBounds = YES;
    panel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];

    // best-effort: centre the panel horizontally in the cell (NEON-spilled frame maths).
    CGRect cellFrame = cell.frame;
    CGFloat centerX = cellFrame.size.width * 0.5f - 10.0f;
    panel.center = CGPointMake(centerX, 32.0f);   // y 0x42000000 = 32
    [cell.contentView addSubview:panel];

    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];                 // overwritten by whiteColor below
    label.textColor = [UIColor colorWithRed:0.188235f green:0.188235f blue:0.188235f alpha:1.0f]; // 0x3e40c0c1
    label.backgroundColor = [UIColor whiteColor];
    label.highlightedTextColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5f;
    label.layer.cornerRadius = 10.0f;
    label.font = [UIFont fontWithName:AppFontName() size:15.0f];
    label.frame = CGRectMake(0, 0, 226.0f, 36.0f);               // 0x43620000 / 0x42100000
    label.text = title;
    label.center = CGPointMake(centerX, 32.0f);
    [cell.contentView addSubview:label];
    return cell;
}

// @ 0x8a27c -- only header rows (0/2/4) are selectable: toggle the expanded section, then reload
// the tapped row to animate the detail row above/below open or closed.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1 || indexPath.row == 3 || indexPath.row == 5) {
        return;
    }
    if (_selectedIndexPath != nil && [_selectedIndexPath compare:indexPath] == NSOrderedSame) {
        // Tapped the already-expanded header -> collapse.
        _selectedIndexPath = nil;
    } else {
        _selectedIndexPath = indexPath;
    }
    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                     withRowAnimation:UITableViewRowAnimationNone];   // animation 5
}

// @ 0x8a34c -- back button action.
- (void)settingClose {
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
