//
//  SettingCustomerTableViewController.mm
//  pop'n rhythmin
//
//  See SettingCustomerTableViewController.h. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin:
//    initWithStyle:                     @ 0xd32b8
//    initAtNavigationController         @ 0xd3460
//    dealloc                            @ 0xd3640
//    viewDidLoad                        @ 0xd3694
//    didReceiveMemoryWarning            @ 0xd36c0
//    startOpenAnimation                 @ 0xd36ec
//    endOpenAnimation                   @ 0xd3818
//    startCloseAnimation                @ 0xd3830
//    endCloseAnimation                  @ 0xd3950
//    numberOfSectionsInTableView:       @ 0xd39bc
//    tableView:numberOfRowsInSection:   @ 0xd39c0
//    tableView:cellForRowAtIndexPath:   @ 0xd39c4
//    tableView:didSelectRowAtIndexPath: @ 0xd3f70
//    settingClose                       @ 0xd4170
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. MRC.
//
//  Honesty notes:
//   - The row-label CFStrings are exact (UTF-16LE, decoded byte-for-byte):
//   お問い合わせ /
//     特定商取引法に基づく表示 / 利用規約. The two support URLs are exact ASCII
//     CFStrings.
//   - The RGBA border/text colours and the geometry constants (row height 65,
//   inner
//     button 290x53, label 226x36, border 3 / corner 5 / label-corner 10, font
//     15pt) are exact float-hex decodes.
//   - -[... cellForRowAtIndexPath:] centres the button/label from the *cell
//   frame* via
//     NEON (exact @ 0xd3d08): vldr.32 s0,[sp,#0x38] = width; vmul.f32
//     d8,d0,#0x3f000000 (0.5f); itt mi; vmov.f32 d16,#0xc1200000 (=-10.0f);
//     vadd.f32 d8,d8,d16 (iOS<7); r3 = #0x42000000 = 32.0f. All byte-decoded
//     constants; not best-effort.
//   - row 2 shows a PolicyView terms-of-use overlay, wrapped in a
//   UINavigationController.
//

#import "SettingCustomerTableViewController.h"

#import "AppFont.h"        // AppFontName (DFSoGei gothic face)
#import "PolicyView.h"     // row 2 terms-of-use overlay (@ PTR_PolicyView_0015c0b4)
#import "neEngineBridge.h" // neSceneManager::isPadDisplay/rootViewController, neEngine::playSystemSe

static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@implementation SettingCustomerTableViewController {
    BOOL _isAnimationing;                // @0xA2  animation-in-flight guard (ivar type "c")
    UINavigationController *_policyView; // @0xA4  lazily-built terms-of-use overlay nav controller
}

// @ 0xd32b8 — 65px rows, no separators, clear background; a top inset on
// pre-iOS 7 iPad.
// @complete
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.tableView.rowHeight = 65.0f; // 0x42820000
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor clearColor];
        if (neSceneManager::isPadDisplay()) {
            CGFloat top = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? 20.0f : 0.0f;
            self.tableView.contentInset = UIEdgeInsetsMake(top, 0, 0, 0); // 0x41a00000 == 20
        }
    }
    return self;
}

// @ 0xd3460 — wrap self (grouped) in a nav controller, add a back button +
// nav-bar art.
// @complete
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(settingClose)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    return nav;
}

// @ 0xd3694
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0xd36c0
// @complete
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table

// @ 0xd39bc
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xd39c0
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3; // お問い合わせ / 特定商取引法に基づく表示 / 利用規約
}

// @ 0xd39c4 — each row is a rounded, colour-bordered "back_bg_st" button with a
// centred label.
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell != nil) {
        return cell;
    }

    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:identifier];
    cell.backgroundView = nil;
    cell.backgroundColor = [UIColor clearColor];

    // Per-row border colour + label text.
    UIColor *borderColor = nil;
    NSString *title = nil;
    switch (indexPath.row) {
    case 2: // 利用規約 (Terms of Use)
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        borderColor = [UIColor colorWithRed:0.580f green:0.961f blue:0.373f alpha:1.0f];
        title = @"利用規約";
        break;
    case 1: // 特定商取引法に基づく表示 (SCTA notation)
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        borderColor = [UIColor colorWithRed:1.0f green:0.733f blue:0.314f alpha:1.0f];
        title = @"特定商取引法に基づく表示";
        break;
    case 0: // お問い合わせ (Inquiry / FAQ)
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        borderColor = [UIColor colorWithRed:1.0f green:0.647f blue:0.627f alpha:1.0f];
        title = @"お問い合わせ";
        break;
    default:
        break;
    }

    // Rounded button plate.
    UIView *plate = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290.0f, 53.0f)];
    plate.layer.borderWidth = 3.0f;
    plate.layer.borderColor = borderColor.CGColor;
    plate.layer.cornerRadius = 5.0f;
    plate.clipsToBounds = YES;
    plate.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];

    // Centre from the cell frame (exact @ 0xd3d08). Pre-iOS 7 nudges X by -10.0f.
    CGRect cellFrame = cell.frame;
    CGFloat centerX = cellFrame.size.width * 0.5f;
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
        centerX += -10.0f;
    }
    const CGPoint plateCenter = CGPointMake(centerX, 32.0f);
    plate.center = plateCenter;
    [cell.contentView addSubview:plate];

    // Centred label over the plate.
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
    label.backgroundColor = [UIColor whiteColor]; // faithful: overwrites the clear above
    label.highlightedTextColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5f;
    label.layer.cornerRadius = 10.0f;
    label.font = [UIFont fontWithName:AppFontName() size:15.0f];
    label.frame = CGRectMake(0, 0, 226.0f, 36.0f);
    label.text = title;
    label.center = plateCenter;
    [cell.contentView addSubview:label];

    return cell;
}

// @ 0xd3f70 — dispatch the tapped support action, then play the decide SE.
// (The binary uses single-arg -openURL:; the modern -openURL:options: path is a
// current-SDK accommodation, faithful in the #else branch.)
// @complete
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
    case 2: { // 利用規約 -> in-app Terms-of-Use overlay
        if (_policyView == nil) {
            // Ghidra: PTR_PolicyView_0015c0b4, -[PolicyView init] @ 0x52a04.
            PolicyView *policy = [[PolicyView alloc] init];
            _policyView = [[UINavigationController alloc] initWithRootViewController:policy];
            [_policyView.navigationBar
                setBackgroundImage:[UIImage imageNamed:@"set_agreement_navbar"]
                     forBarMetrics:UIBarMetricsDefault];
        }
        [RootVC().view addSubview:_policyView.view];
        break;
    }
    case 1: { // 特定商取引法に基づく表示 -> KONAMI TOKUSHO page
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        [[UIApplication sharedApplication]
                      openURL:[NSURL URLWithString:@"http://license.konami.com/TOKUSHO/"
                                                   @"license/index.html"]
                      options:@{}
            completionHandler:nil];
#else
        [[UIApplication sharedApplication]
            openURL:[NSURL URLWithString:@"http://license.konami.com/TOKUSHO/"
                                         @"license/index.html"]];
#endif
        break;
    }
    case 0: { // お問い合わせ -> FAQ page
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        [[UIApplication sharedApplication]
                      openURL:[NSURL URLWithString:@"https://www.faq.konami.jp/app/confirm"]
                      options:@{}
            completionHandler:nil];
#else
        [[UIApplication sharedApplication]
            openURL:[NSURL URLWithString:@"https://www.faq.konami.jp/app/confirm"]];
#endif
        break;
    }
    default:
        return;
    }
    neEngine::playSystemSe(1); // decide/confirm SE
}

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0xd36ec — fade the view + nav view in over 0.5s.
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

// @ 0xd3818
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xd3830 — cancel SE, then fade out over 0.3s; on stop notify the host.
// @complete
- (void)startCloseAnimation {
    neEngine::playSystemSe(2); // cancel/back SE
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    // 0.3: double 0x3fd3333340000000 @ 0xd3948 (close fade; open uses 0.5).
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xd3950 — remove the nav view and hand control back to MainViewController.
// @complete
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

// @ 0xd4170 — back-button action.
// @complete
- (void)settingClose {
    [self startCloseAnimation];
}

// dealloc @ 0xd3640 — ARC-omitted (the binary explicitly releases _policyView;
// ARC synthesises that). @complete

@end
