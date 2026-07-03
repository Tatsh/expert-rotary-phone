//
//  SettingOtherTableViewController.mm
//  pop'n rhythmin
//
//  See SettingOtherTableViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the C++ neEngine / neSceneManager singletons.
//
//  Honesty / uncertainty notes:
//   * The per-row "pill" cell layout in -tableView:cellForRowAtIndexPath: uses several
//     NEON-spilled CGRect/CGPoint computations (frames + centers). The frame *sizes*,
//     border/corner/colors and text are exact; the pill/label *centering* offsets are
//     best-effort (marked NEON below).
//   * -tableView:didSelectRowAtIndexPath:'s reloadRowsAtIndexPaths:withRowAnimation: was a
//     tail call; the row-animation argument was not recoverable — Fade is used best-effort.
//   * -[UserSettingData initTreasureTmp] is invoked by the retire flow but is NOT declared
//     in the current UserSettingData.h (see TODO(dep) below).
//   * ConversionView and CustomWebView are not present in Project/ (TODO(dep)).
//   * viewDidAppear: (imp @ 0xd48bc) genuinely tail-calls the *super* viewWillDisappear:
//     selector in the binary; reproduced faithfully with a NOTE.
//   * Japanese CFStrings decoded from UTF-16LE (flags 0x7d0); ASCII from flags 0x7c8.
//

#import "SettingOtherTableViewController.h"

#import "neEngineBridge.h"     // neSceneManager::rootViewController / isPadDisplay, neEngine::playSystemSe
#import "StoreUtil.h"          // +getOfficialAppInfoURL
#import "UserSettingData.h"    // +initTreasureTmp (see TODO(dep) note)
#import "AppFont.h"            // AppFontName

// TODO(dep): these two app classes are referenced by the decompile but are missing from
// Project/. Forward-declared so the faithful calls below still express what the binary does.
//   ConversionView : UIViewController — the embedded "device change" (data transfer) panel;
//                    responds to -init, -setDelegate:, -view.
//   CustomWebView  : an in-app web view; responds to -initWithURL:, -setErrorMsg:text:.
@class ConversionView;   // TODO(dep): ConversionView
@class CustomWebView;    // TODO(dep): CustomWebView

// -[UserSettingData initTreasureTmp] clears the pending "treasure" progress (the Retire
// action). The selector exists in the binary but is not yet declared on UserSettingData.
// TODO(dep): add +initTreasureTmp to UserSettingData.h once verified.
@interface UserSettingData (SettingOtherRetire)
+ (void)initTreasureTmp;
@end

// The app's root view controller (MainViewController), bridged from the C++ scene manager.
static UIViewController *RootVC() {
    return (__bridge UIViewController *)neSceneManager::rootViewController();
}

@implementation SettingOtherTableViewController {
    CommonAlertView *_treasureRetireAlertView;   // @164 (0xa4)  in-flight retire confirm alert
    BOOL _isAnimationing;                         // @168 (0xa8)  open/close animation guard
    id<ViewCmnProtocol> _viewCmnDelegate;         // @172 (0xac)  forwarded to ConversionView
    NSIndexPath *_selectedIndexPath;              // @176 (0xb0)  expanded "機種変更" toggle row
    UIViewController *_convDetailView;            // @180 (0xb4)  the ConversionView (lazily made)
    CGRect _convDummyFrm;                         // @184 (0xb8)  frame of the expanded conv panel
    UIImageView *_arrowTopView;                   // @200 (0xc8)  (declared; unused in decompile)
    UIImageView *_arrowUnderView;                 // @204 (0xcc)  (declared; unused in decompile)
}

@synthesize viewCmnDelegate = _viewCmnDelegate;   // @ 0xd5860 / 0xd5870

// @ 0xd4180 — grouped table with no separators; computes the expanded-panel frame per OS.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        self.tableView.rowHeight = 61.0f;                                    // 0x42740000
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];

        // Pre-iOS 7 gets a 20pt top inset (for the status bar); iOS 7+ gets none.
        const float sysVer = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset = UIEdgeInsetsMake(sysVer < 7.0f ? 20.0f : 0.0f, 0, 0, 0);
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;

        // Frame of the expandable ConversionView row (section 2, row 1).
        if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            _convDummyFrm = CGRectMake(15.0f, 0.0f, 290.0f, 420.0f);   // 15 / 290 / 420
        } else {
            _convDummyFrm = CGRectMake(5.0f, 0.0f, 290.0f, 430.0f);    // 5 / 290 / 430
        }
    }
    return self;
}

// @ 0xd4398 — wrap in a nav controller, install the phone back button, set the nav-bar art.
- (UINavigationController *)initAtNavigationController {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)] autorelease];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(settingClose)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithCustomView:backBtn] autorelease];

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"] forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// @ 0xd4578
- (void)dealloc {
    if (_selectedIndexPath != nil) {
        [_selectedIndexPath release];
        _selectedIndexPath = nil;
    }
    if (_convDetailView != nil) {
        [_convDetailView release];
    }
    [super dealloc];
}

#pragma mark - Modal open/close animation

// @ 0xd45ec
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

// @ 0xd4718
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xd4730 — plays the cancel SE (slot 2) up front, then fades out.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xd4850 — remove and hand control back to the host (MainViewController).
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Lifecycle

// @ 0xd48bc — NOTE: the binary tail-calls the *super* viewWillDisappear: here (reproduced
// faithfully; likely a copy/paste artifact in the original source).
- (void)viewDidAppear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

// @ 0xd48e8
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0xd4914
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table structure

// @ 0xd4940
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

// @ 0xd4944 — rows per section = { News:1, TreasureMode:1, DeviceChange:2 } (DAT_0012fba8).
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    static const NSInteger kRows[3] = { 1, 1, 2 };
    if (section < 3) {
        return kRows[section];
    }
    return 0;
}

// @ 0xd495c — the expandable ConversionView row (section 2, row 1) is only tall when the
// toggle row (section 2, row 0) is currently selected; otherwise it collapses to 0.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2 && indexPath.row == 1) {
        NSIndexPath *toggle = [NSIndexPath indexPathForRow:0 inSection:2];
        if (_selectedIndexPath != nil && [_selectedIndexPath compare:toggle] == NSOrderedSame) {
            return _convDummyFrm.size.height;   // expanded: show the conversion panel
        }
        return 0.0f;                            // collapsed
    }
    return 61.0f;   // 0x42740000
}

// @ 0xd5330
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;   // headers are provided as views (below)
}

// @ 0xd54d4
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32.0f;   // 0x42000000
}

// @ 0xd5334 — a 320x32 clear header carrying the section title label (14pt app font).
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[[UIView alloc]
        initWithFrame:CGRectMake(15.0f, 0.0f, 320.0f, 32.0f)] autorelease];
    header.backgroundColor = [UIColor clearColor];

    NSString *title;
    switch (section) {
        case 0:  title = @"お知らせ";        break;   // News
        case 2:  title = @"機種変更";        break;   // Device change
        case 1:  title = @"トレジャーモード"; break;   // Treasure Mode
        default: title = @"";               break;
    }

    UILabel *label = [[[UILabel alloc]
        initWithFrame:CGRectMake(15.0f, 0.0f, 320.0f, 32.0f)] autorelease];
    label.font = [UIFont fontWithName:AppFontName() size:14.0f];   // 0x41600000
    label.backgroundColor = [UIColor clearColor];
    label.text = title;
    [header addSubview:label];
    return header;
}

// @ 0xd54dc — no accessory (disclosure) on any row.
- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView
             accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
    (void)indexPath.section;
    return UITableViewCellAccessoryNone;
}

#pragma mark - Cells

// @ 0xd4a08 — every row is a bordered, rounded "pill". Section 2 / row 1 hosts the embedded
// ConversionView; all other rows show a colored title pill (color varies per section).
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell != nil) {
        return cell;
    }

    cell = [[[UITableViewCell alloc]
        initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
    cell.backgroundView = nil;
    cell.backgroundColor = [UIColor clearColor];
    cell.clipsToBounds = YES;

    // --- Section 2, row 1: the embedded ConversionView panel ---
    if (indexPath.section == 2 && indexPath.row == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // Outer pill sized to the pre-computed panel frame; greenish border + light-green fill.
        UIView *pill = [[[UIView alloc] initWithFrame:_convDummyFrm] autorelease];
        pill.layer.borderWidth = 3.0f;
        pill.layer.borderColor = [UIColor colorWithRed:0.580f green:0.961f blue:0.373f alpha:1.0f].CGColor;
        pill.layer.cornerRadius = 5.0f;
        pill.clipsToBounds = YES;
        pill.backgroundColor = [UIColor colorWithRed:0.741f green:1.0f blue:0.600f alpha:1.0f];

        // Inner clear container, inset by (10, 2) with a (-20, -4) size delta [NEON].
        UIView *inner = [[[UIView alloc] init] autorelease];
        inner.backgroundColor = [UIColor clearColor];
        const CGFloat innerW = _convDummyFrm.size.width - 20.0f;
        const CGFloat innerH = _convDummyFrm.size.height - 4.0f;
        [inner setFrame:CGRectMake(10.0f, 2.0f, innerW, innerH)];

        // Lazily build the ConversionView and forward our common delegate to it.
        if (_convDetailView == nil) {
            ConversionView *conv = [[ConversionView alloc] init];   // TODO(dep): ConversionView
            _convDetailView = (UIViewController *)conv;
            [(id)conv setDelegate:_viewCmnDelegate];
        }
        [_convDetailView.view setFrame:CGRectMake(0, 0, innerW, innerH)];
        [inner addSubview:_convDetailView.view];

        [cell.contentView addSubview:pill];
        return cell;
    }

    // --- All other rows: a colored title pill with a centered label ---
    UIColor *pillColor;
    NSString *title;
    if (indexPath.section == 0) {
        // News.
        pillColor = [UIColor colorWithRed:1.0f green:0.647f blue:0.627f alpha:1.0f];
        title = (indexPath.row == 0) ? @"お知らせ" : @"";
    } else if (indexPath.section == 1) {
        // Treasure Mode -> Retire.
        pillColor = [UIColor colorWithRed:1.0f green:0.733f blue:0.314f alpha:1.0f];
        title = (indexPath.row == 0) ? @"リタイア" : @"";
    } else {
        // Device change (section 2, row 0 toggle).
        pillColor = [UIColor colorWithRed:0.580f green:0.961f blue:0.373f alpha:1.0f];
        title = ((indexPath.section == 2) && (indexPath.row == 0)) ? @"機種変更" : @"";
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Pill: 290x53, 3pt border in the section color, 5pt corners, patterned fill.
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290.0f, 53.0f)];
    pill.layer.borderWidth = 3.0f;                    // 0x40400000
    pill.layer.borderColor = pillColor.CGColor;
    pill.layer.cornerRadius = 5.0f;                   // 0x40a00000
    pill.clipsToBounds = YES;
    pill.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    // Center the pill in the cell; -10pt vertical nudge pre-iOS 7 [NEON, best-effort].
    CGRect cellFrame = (cell != nil) ? cell.frame : CGRectZero;
    CGFloat centerY = cellFrame.size.height * 0.5f;
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
        centerY -= 10.0f;
    }
    pill.center = CGPointMake(cellFrame.size.width * 0.5f, centerY);
    [cell.contentView addSubview:pill];

    // Title label centered over the pill.
    UILabel *label = [[[UILabel alloc] init] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
    label.backgroundColor = [UIColor whiteColor];
    label.highlightedTextColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5f;
    label.layer.cornerRadius = 10.0f;                 // 0x41200000
    label.font = [UIFont fontWithName:AppFontName() size:15.0f];   // 0x41700000
    label.frame = CGRectMake(0, 0, 226.0f, 36.0f);    // 0x43620000 / 0x42100000
    label.text = title;
    label.center = pill.center;   // [NEON: y term 30.0 best-effort]
    [cell.contentView addSubview:label];
    [pill release];

    return cell;
}

#pragma mark - Selection

// @ 0xd54f8 — dispatch a tap while this VC is the top of the nav stack.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self) {
        return;
    }
    // The embedded conversion row (section 2, row 1) is not itself tappable.
    if (indexPath.section == 2 && indexPath.row == 1) {
        return;
    }

    if (indexPath.section == 2) {
        // "機種変更" toggle: expand, or collapse if already expanded, then reload the row.
        if (indexPath.row == 0) {
            if (_selectedIndexPath == nil ||
                [_selectedIndexPath compare:indexPath] != NSOrderedSame) {
                _selectedIndexPath = [indexPath retain];
            } else {
                [_selectedIndexPath release];
                _selectedIndexPath = nil;
            }
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];   // animation best-effort
        }
    } else if (indexPath.section == 1) {
        // Treasure Mode -> Retire: confirm before wiping progress.
        if (indexPath.row == 0) {
            neEngine::playSystemSe(1);
            _treasureRetireAlertView = [[CommonAlertView alloc]
                initWithTitle:@"トレジャーモードをリタイアしますか？"
                      message:@"※今回手に入れたモノは失われます。"
                     delegate:self
            cancelButtonTitle:@"Cancel"
            otherButtonTitles:@"OK"];
            [_treasureRetireAlertView show];
            // Released here; the pointer is kept only to identify the alert in the delegate.
            [_treasureRetireAlertView release];
        }
    } else if (indexPath.section == 0) {
        // News: open the official app-info page in the in-app web view.
        if (indexPath.row == 0) {
            CustomWebView *web = [[CustomWebView alloc]
                initWithURL:[StoreUtil getOfficialAppInfoURL]];   // TODO(dep): CustomWebView
            [(id)web setErrorMsg:@"ERROR" text:@"お知らせの取得に失敗しました。"];
            [web release];
            neEngine::playSystemSe(1);
        }
    }
}

#pragma mark - CommonAlertViewDelegate

// @ 0xd579c — confirming the retire (button index 1) wipes the treasure temp and reports back.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (alertView == _treasureRetireAlertView && index == 1) {
        [UserSettingData initTreasureTmp];
        CommonAlertView *done = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"リタイアしました。"
                 delegate:self
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
        [done show];
        [done release];
    }
    _treasureRetireAlertView = nil;
}

#pragma mark - Actions

// @ 0xd5850 — back button -> fade out.
- (void)settingClose {
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
