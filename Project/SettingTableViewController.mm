//
//  SettingTableViewController.m
//  pop'n rhythmin
//
//  See SettingTableViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Uses the C++ neEngine / neSceneManager singletons (SE
//  playback, root VC, isPad flag) through neEngineBridge.h.
//
//  Honesty / uncertainty notes:
//   * The six section headers and the per-row cell labels are Japanese
//   CFStrings decoded
//     from the binary's UTF-16LE __cfstring data (flags 0x7d0). Exact code
//     points recovered: お知らせ / 設定 / 遊び方 / トレジャーモード / 機種変更
//     / お問い合わせ (headers) and サウンド / ポップ君サイズ / ゲーム演出 /
//     ゲームプレー / トレジャーモード / リタイア / 機種変更 / お問い合わせ /
//     特定商取引法に基づく表記 / 利用規約 (rows).
//   * CustomWebView, HowToViewCtrlPad and ConversionView are referenced by the
//   decompile and
//     are reconstructed in Project/ (imported below).
//   * viewDidAppear: (imp @ 0x7f2f0) genuinely tail-calls the *super*
//   viewWillDisappear:
//     selector in the binary; reproduced faithfully with a NOTE (matches the
//     sibling SettingOtherTableViewController).
//   * _effectSwitch (a UIButton toggle) and _simpleModeSwitch (a UISwitch) are
//   wired to
//     onEffectOnChanged: / onSimpleModeChanged:; the controls themselves are
//     created outside the methods reconstructed here.
//

#import "SettingTableViewController.h"

#import "CommonAlertView.h" // retire-confirm alert
#import "StoreUtil.h"       // +getOfficialAppInfoURL
#import "UserSettingData.h" // +isEffectOn / +saveIsEffectOn: / +saveIsSimpleMode: / +initTreasureTmp
#import "neEngineBridge.h" // neSceneManager::rootViewController / isPadDisplay, neEngine::playSystemSe

#import "ConversionView.h"     // "device change" (data transfer) panel
#import "CustomWebView.h"      // in-app web view (お問い合わせ / terms)
#import "GameEffectView.h"     // section 1, row 2
#import "HowToViewCtrl.h"      // section 2 (phone)
#import "HowToViewCtrlPad.h"   // section 2 (iPad how-to overlay)
#import "PolicyView.h"         // section 5, row 2
#import "PopkunSizeViewCtrl.h" // section 1, row 1
#import "SoundSettingView.h"   // section 1, row 0

// Private action / target methods (wired from the back button and the toggle
// controls). Also the ConversionView delegate (id<ViewCmnProtocol>); callbacks
// implemented below.
@interface SettingTableViewController () <ViewCmnProtocol>
- (void)settingClose;                   // @ 0x801dc
- (void)onEffectOnChanged:(id)sender;   // @ 0x801ec
- (void)onSimpleModeChanged:(id)sender; // @ 0x8029c
@end

// The app's root view controller (MainViewController), bridged from the C++
// scene manager.
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@implementation SettingTableViewController {
    BOOL _isAnimationing;                // open/close animation guard
    BOOL _isPad;                         // Ghidra ivar "isPad" — cached isPadDisplay()
    BOOL _isEffectOn;                    // Ghidra ivar "_isEffectOn" — cached effect flag
    HowToViewCtrlPad *_howtoViewCtrlPad; // Ghidra ivar "howtoViewCtrlPad" — iPad how-to overlay
    UIButton *_effectSwitch;             // Ghidra ivar "_effectSwitch" — effect toggle button
    UISwitch *_simpleModeSwitch;         // Ghidra ivar "_simpleModeSwitch" — simple-mode toggle
    CommonAlertView *_treasureRetireAlertView; // Ghidra ivar "_treasureRetireAlertView"
}

// @ 0x7eaf8 — 61 px rows; a patterned "back_bg_st" background on phone; on iPad
// a clear background with a "side_bar_bg" backgroundView and (pre-iOS 7) a top
// inset.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.tableView.rowHeight = 61.0f;
        if (neSceneManager::isPadDisplay()) {
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            self.tableView.separatorColor = [UIColor clearColor];
            if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
                self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
            }
            self.view.backgroundColor = [UIColor clearColor];
            self.tableView.backgroundView =
                [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"side_bar_bg"]];
        } else {
            self.tableView.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
        }
    }
    return self;
}

// @ 0x7ed98 — wrap self in a navigation controller (the phone presentation):
// install the custom phone back button and the "frirep_navbar" nav-bar art.
// Caches the iPad flag first.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    _isPad = neSceneManager::isPadDisplay();

    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
    CGSize backSize = backImage ? backImage.size : CGSizeZero;
    UIButton *backButton =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backSize.width, backSize.height)];
    [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self
                   action:@selector(settingClose)
         forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// dealloc @ 0x7ef98 — ARC-omitted (object ivars only; the MRC original released
// the strong howtoViewCtrlPad overlay, which ARC releases automatically).

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0x7efec
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

// @ 0x7f118
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x7f130 — fade out, then notify the host.
- (void)startCloseAnimation {
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

// @ 0x7f250 — tear down the toggle controls, remove the nav view, and hand
// control back to MainViewController.
- (void)endCloseAnimation {
    // NOTE: the MRC original released _effectSwitch and _simpleModeSwitch here
    // (they were alloc-owned toggle controls torn down with the nav view). Under
    // ARC we drop our strong refs by niling them instead of calling -release.
    _effectSwitch = nil;
    _simpleModeSwitch = nil;

    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - Lifecycle

// @ 0x7f2f0 — NOTE: the binary tail-calls the *super* viewWillDisappear: here
// (reproduced faithfully; matches the sibling SettingOtherTableViewController —
// likely a copy/paste artifact in the original source).
- (void)viewDidAppear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

// viewDidLoad @ 0x7f31c — super-only override, omitted.
// didReceiveMemoryWarning @ 0x7f348 — super-only override, omitted.

#pragma mark - Table structure

// @ 0x7f374
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 6;
}

// @ 0x7f378 — rows per section = { News:1, Settings:3, HowTo:2, Treasure:1,
// DeviceChange:1, Inquiry:3 } (DAT_0012f880).
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    static const NSInteger kRows[6] = {1, 3, 2, 1, 1, 3};
    if (section < 6) {
        return kRows[section];
    }
    return 0;
}

// @ 0x7f708 — section header titles.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
    case 0:
        return @"お知らせ"; // News
    case 1:
        return @"設定"; // Settings
    case 2:
        return @"遊び方"; // How to play
    case 3:
        return @"トレジャーモード"; // Treasure Mode
    case 4:
        return @"機種変更"; // Device change
    case 5:
        return @"お問い合わせ"; // Inquiry
    default:
        return nil;
    }
}

// @ 0x7f390 — plain default cells carrying the per-row title label. Building
// the game-effect row (section 1, row 2) also seeds the cached effect flag from
// UserSettingData.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:identifier];
        if (indexPath.section == 1 && indexPath.row == 2) {
            _isEffectOn = [UserSettingData isEffectOn];
        }
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    switch (indexPath.section) {
    case 0:
        if (indexPath.row == 0) {
            cell.textLabel.text = @"お知らせ";
        }
        break;
    case 1:
        if (indexPath.row == 2) {
            cell.textLabel.text = @"ゲーム演出";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"ポップ君サイズ";
        } else if (indexPath.row == 0) {
            cell.textLabel.text = @"サウンド";
        }
        break;
    case 2:
        if (indexPath.row == 1) {
            cell.textLabel.text = @"トレジャーモード";
        } else if (indexPath.row == 0) {
            cell.textLabel.text = @"ゲームプレー";
        }
        break;
    case 3:
        if (indexPath.row == 0) {
            cell.textLabel.text = @"リタイア";
        }
        break;
    case 4:
        if (indexPath.row == 0) {
            cell.textLabel.text = @"機種変更";
        }
        break;
    case 5:
        if (indexPath.row == 2) {
            cell.textLabel.text = @"利用規約";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"特定商取引法に基づく表記";
        } else if (indexPath.row == 0) {
            cell.textLabel.text = @"お問い合わせ";
        }
        break;
    }
    return cell;
}

// @ 0x7f764 — on the phone the sub-screen rows carry a disclosure indicator; on
// the iPad none do. (Sections 0/3 have no accessory; section 5 rows likewise.)
- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView
         accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
    case 1: {
        NSInteger row = indexPath.row;
        if (row != 0) {
            if (row == 2) {
                if (!_isPad) {
                    return UITableViewCellAccessoryDisclosureIndicator;
                }
            } else if (row != 1) {
                return UITableViewCellAccessoryNone;
            }
        }
        break; // rows 0/1 (and row 2 on iPad) fall to the final isPad check
    }
    case 2:
        if (_isPad) {
            return UITableViewCellAccessoryNone;
        }
        if (indexPath.row < 2) {
            return UITableViewCellAccessoryDisclosureIndicator;
        }
        return UITableViewCellAccessoryNone;
    case 4:
        if (indexPath.row != 0) {
            return UITableViewCellAccessoryNone;
        }
        break; // row 0 falls to the final isPad check
    default:
        return UITableViewCellAccessoryNone; // sections 0, 3, 5
    }

    if (!_isPad) {
        return UITableViewCellAccessoryDisclosureIndicator;
    }
    return UITableViewCellAccessoryNone;
}

#pragma mark - Selection

// @ 0x7f818 — dispatch a tap while this VC is the top of the nav stack: push
// (or, for the iPad how-to, overlay) the matching sub-screen and play the
// confirm SE.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self) {
        return;
    }

    switch (indexPath.section) {
    case 0: {
        // News -> the official app-info page in the in-app web view.
        if (indexPath.row != 0) {
            return;
        }
        CustomWebView *web = [[CustomWebView alloc] initWithURL:[StoreUtil getOfficialAppInfoURL]];
        [web setErrorMsg:@"ERROR" text:@"お知らせの取得に失敗しました。"];
        (void)web; // ARC: the web view installs itself; the local ref is not retained
        break;
    }
    case 1: {
        // Settings sub-screens.
        UIViewController *sub;
        NSString *navImage;
        if (indexPath.row == 2) {
            sub = [[GameEffectView alloc] initWithStyle:UITableViewStyleGrouped];
            navImage = @"settings_game_navbar";
        } else if (indexPath.row == 1) {
            sub = [[PopkunSizeViewCtrl alloc] init];
            navImage = @"popkun_size_navbar";
        } else if (indexPath.row == 0) {
            sub = [[SoundSettingView alloc] initWithStyle:UITableViewStyleGrouped];
            navImage = @"set_popkunSE_navbar";
        } else {
            return;
        }
        [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:navImage]
                                                      forBarMetrics:UIBarMetricsDefault];
        [self.navigationController pushViewController:sub animated:YES];
        break;
    }
    case 2: {
        // How to play: basic (row 0) or treasure-mode (row 1). On the iPad this is
        // shown as an overlay on the root scene view; on the phone it is pushed.
        NSArray *files;
        if (indexPath.row == 1) {
            files = @[
                @"howto_tre01",
                @"howto_tre02",
                @"howto_tre03",
                @"howto_tre04",
                @"howto_tre05",
                @"howto_tre06"
            ];
        } else if (indexPath.row == 0) {
            files = @[ @"howto_01", @"howto_02", @"howto_03", @"howto_04", @"howto_05" ];
        } else {
            return;
        }

        if (_isPad) {
            _howtoViewCtrlPad = nil; // MRC released the previous overlay first
            _howtoViewCtrlPad = [[HowToViewCtrlPad alloc] initWithFileNameArray:files];
            if (indexPath.row == 0) {
                // The basic how-to also themes the overlay's nav bar.
                [_howtoViewCtrlPad.navigationController.navigationBar
                    setBackgroundImage:[UIImage imageNamed:@"howto_navbar"]
                         forBarMetrics:UIBarMetricsDefault];
            }
            [RootVC().view addSubview:_howtoViewCtrlPad.view];
        } else {
            HowToViewCtrl *howto = [[HowToViewCtrl alloc] initWithFileNameArray:files];
            howto.fromNaviBarImage = [UIImage imageNamed:@"settings_navbar"];
            [self.navigationController.navigationBar
                setBackgroundImage:[UIImage imageNamed:@"howto_navbar"]
                     forBarMetrics:UIBarMetricsDefault];
            [self.navigationController pushViewController:howto animated:YES];
        }
        break;
    }
    case 3: {
        // Treasure Mode -> Retire: confirm before wiping progress.
        if (indexPath.row != 0) {
            return;
        }
        neEngine::playSystemSe(1);
        _treasureRetireAlertView =
            [[CommonAlertView alloc] initWithTitle:@"トレジャーモードをリタイアしますか？"
                                           message:@"※今回手に入れたモノは失われます。"
                                          delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 otherButtonTitles:@"OK"];
        [_treasureRetireAlertView show];
        // The strong ivar keeps the shown alert alive; it is nilled in the delegate
        // callback (the pointer is used there only to identify this alert).
        return; // note: the retire branch does not play the trailing SE
    }
    case 4: {
        // Device change -> the ConversionView (data-transfer) screen.
        if (indexPath.row != 0) {
            return;
        }
        ConversionView *conv = [[ConversionView alloc] init];
        [conv setDelegate:self];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"conv_navbar_change"]
                 forBarMetrics:UIBarMetricsDefault];
        [self.navigationController pushViewController:conv animated:YES];
        break;
    }
    case 5: {
        // Inquiry: FAQ (row 0) / 特定商取引法 (row 1) open in Safari; 利用規約 (row
        // 2) pushes the in-app PolicyView.
        if (indexPath.row == 2) {
            PolicyView *policy = [[PolicyView alloc] init];
            [self.navigationController.navigationBar
                setBackgroundImage:[UIImage imageNamed:@"set_agreement_navbar"]
                     forBarMetrics:UIBarMetricsDefault];
            [self.navigationController pushViewController:policy animated:YES];
        } else if (indexPath.row == 1) {
            [[UIApplication sharedApplication]
                openURL:[NSURL URLWithString:@"http://license.konami.com/TOKUSHO/"
                                             @"license/index.html"]];
        } else if (indexPath.row == 0) {
            [[UIApplication sharedApplication]
                openURL:[NSURL URLWithString:@"https://www.faq.konami.jp/app/confirm"]];
        } else {
            return;
        }
        break;
    }
    default:
        return;
    }

    neEngine::playSystemSe(1);
}

#pragma mark - CommonAlertViewDelegate

// @ 0x80128 — confirming the retire (button index 1) wipes the treasure temp
// and reports back.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (alertView == _treasureRetireAlertView && index == 1) {
        [UserSettingData initTreasureTmp];
        CommonAlertView *done = [[CommonAlertView alloc] initWithTitle:nil
                                                               message:@"リタイアしました。"
                                                              delegate:self
                                                     cancelButtonTitle:nil
                                                     otherButtonTitles:@"OK"];
        [done show];
        (void)done; // ARC: the alert retains itself while shown; local ref not needed
    }
    _treasureRetireAlertView = nil;
}

#pragma mark - Actions

// @ 0x801dc — back button -> fade out.
- (void)settingClose {
    [self startCloseAnimation];
}

// @ 0x801ec — effect toggle: flip the cached flag, play the confirm SE, swap
// the button art, then persist to UserSettingData.
- (void)onEffectOnChanged:(id)sender {
    _isEffectOn = !_isEffectOn;
    neEngine::playSystemSe(1);
    UIImage *art = [UIImage imageNamed:(_isEffectOn ? @"m_sort_check_01" : @"m_sort_check_00")];
    [_effectSwitch setBackgroundImage:art forState:UIControlStateNormal];
    [UserSettingData saveIsEffectOn:_isEffectOn];
}

// @ 0x8029c — simple-mode toggle: persist the switch state to UserSettingData.
- (void)onSimpleModeChanged:(id)sender {
    [UserSettingData saveIsSimpleMode:_simpleModeSwitch.isOn];
}

@end
