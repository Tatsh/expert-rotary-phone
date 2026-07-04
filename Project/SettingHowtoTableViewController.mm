//
//  SettingHowtoTableViewController.mm
//  pop'n rhythmin
//
//  See SettingHowtoTableViewController.h. Compiled as Objective-C++ (.mm) because it
//  drives the C++ engine singletons through neEngineBridge.h (neSceneManager::,
//  neEngine::). Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  Byte-decoded constants (float hex -> decimal): row height 65.0 (0x42820000),
//  pad content inset top 20.0 (0x41a00000), open fade 0.5s, close fade ~0.3s
//  (double 0x3fd3333340000000), tile 290x53 (0x43910000/0x42540000), tile border
//  width 3.0 / corner 5.0, label 226x36 (0x43620000/0x42100000) / corner 10.0,
//  font size 15.0 (0x41700000). Label texts are UTF-16LE CFStrings (flags 0x7d0):
//  "ゲームプレー" @0x12c6d6, "トレジャーモード" @0x12c6e4.
//
//  -tableView:didSelectRowAtIndexPath: presents the iPad how-to overlay controller
//  HowToViewCtrlPad (the sibling of the phone variant HowToViewCtrl).
//
//  The tile / label frame *centres* in -tableView:cellForRowAtIndexPath: are byte-decoded
//  exact (@ 0x80cb4): [cell frame] stret → sp+0x30; vldr.32 s0,[sp,#0x38] = width;
//  vmul.f32 d8,d0,#0x3f000000 (0.5f); itt mi; vmov.f32 d16,#0xc1200000 (=-10.0f);
//  vadd.f32 d8,d8,d16 (pre-iOS-7 only); r3 = #0x42000000 = 32.0f at setCenter:.
//

#import "SettingHowtoTableViewController.h"

#import "AppFont.h"
#import "HowToViewCtrl.h"       // declares -initWithFileNameArray: (shared how-to selector)
#import "HowToViewCtrlPad.h"    // iPad how-to overlay presented by -didSelectRowAtIndexPath:
#import "neEngineBridge.h"

static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

@implementation SettingHowtoTableViewController {
    BOOL _isAnimationing;                 // ivar @ +0xA2 (type "c")
    HowToViewCtrlPad *_howtoViewCtrlPad;  // ivar @ +0xA4 (type @"HowToViewCtrlPad")
}

// @ 0x802e0 — 65 px rows; always a borderless, clear-backgrounded table (the tiles are
// drawn per-cell). On an iPad running pre-iOS 7, add a 20 px top content inset.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.tableView.rowHeight = 65.0f;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor clearColor];
        if (neSceneManager::isPadDisplay()) {
            if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
                self.tableView.contentInset = UIEdgeInsetsMake(20.0f, 0, 0, 0);
            } else {
                self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
            }
        }
    }
    return self;
}

// @ 0x80488 — wrap self in a navigation controller (the phone presentation), give it a
// custom "navi_btn_back" back button wired to -settingClose, and set the nav-bar
// background image.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    // Back button sized to the "navi_btn_back" art. Frame is runtime: backImg.size is not a
    // compile-time constant (two blx 0x12fe6c [UIImage size] stret calls @ 0x8051e/0x8052a).
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(settingClose)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    // Nav-bar background art (Ghidra references the "frirep_navbar" asset here).
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"frirep_navbar"]
        forBarMetrics:UIBarMetricsDefault];

    return nav;
}

// dealloc @ 0x80668 — ARC-omitted (chained to super only; _howtoViewCtrlPad released by ARC).

// @ 0x80694
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0x806c0
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Modal open/close animation (shared lifecycle)

// @ 0x806ec — fade the view + nav view in over 0.5s.
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

// @ 0x80818
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x80830 — play the cancel/back SE, then fade the view + nav view out over ~0.3s.
- (void)startCloseAnimation {
    neEngine::playSystemSe(2);   // cancel SE (Ghidra: SysSePlayIntoSlot(2))
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // double 0x3fd3333340000000
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x80950 — remove and hand control back to MainViewController.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SettingEndCallBack)];
    _isAnimationing = NO;
}

// @ 0x811b8 — back-button action.
- (void)settingClose {
    [self startCloseAnimation];
}

#pragma mark - Table (the two how-to topics)

// @ 0x809bc
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x809c0
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;   // ゲームプレー / トレジャーモード
}

// @ 0x809c4 — build a rounded, patterned tile with a per-row coloured border and a
// centred DFSoGei label. Reuse id is "Cell<section>-<row>".
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld",
            (long)indexPath.section, (long)indexPath.row];
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
    if (indexPath.row == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        borderColor = [UIColor colorWithRed:1.0f green:0.733333f blue:0.313726f alpha:1.0f];
        title = @"トレジャーモード";   // UTF-16LE @ 0x12c6e4
    } else if (indexPath.row == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        borderColor = [UIColor colorWithRed:1.0f green:0.647059f blue:0.627451f alpha:1.0f];
        title = @"ゲームプレー";       // UTF-16LE @ 0x12c6d6
    }

    // Rounded, patterned tile (290 x 53).
    UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290.0f, 53.0f)];
    tile.layer.borderWidth = 3.0f;
    tile.layer.borderColor = borderColor.CGColor;
    tile.layer.cornerRadius = 5.0f;
    tile.clipsToBounds = YES;
    tile.backgroundColor =
        [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    // @ 0x80cb4: [cell frame] stret → sp+0x30; sp+0x38 = frame.size.width; vmul with
    // #0x3f000000 (0.5f) → cx = width * 0.5; itt mi; vmov.f32 d16,#0xc1200000 (=-10.0f);
    // vadd.f32 d8,d8,d16 if iOS<7. r3 = #0x42000000 = 32.0f at setCenter:. Exact.
    CGRect cellFrm = cell.frame;
    CGFloat cx = cellFrm.size.width * 0.5f;
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
        cx -= 10.0f;
    }
    tile.center = CGPointMake(cx, 32.0f);
    [cell.contentView addSubview:tile];

    // Centred label (226 x 36).
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor colorWithRed:0.188235f green:0.188235f blue:0.188235f alpha:1.0f];
    label.backgroundColor = [UIColor whiteColor];   // overrides the clear set above (as in binary)
    label.highlightedTextColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5f;
    label.layer.cornerRadius = 10.0f;
    label.font = [UIFont fontWithName:AppFontName() size:15.0f];
    label.frame = CGRectMake(0, 0, 226.0f, 36.0f);
    label.text = title;
    label.center = CGPointMake(cx, 32.0f);   // exact: ldr r2,[sp,#0x14] = cx; r3 = #0x42000000 = 32.0f
    [cell.contentView addSubview:label];

    return cell;
}

// @ 0x80f1c — play the decide SE, then present the how-to tutorial for the tapped row.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    neEngine::playSystemSe(1);   // decide SE (Ghidra: SysSePlayIntoSlot(1))

    if (indexPath.row == 1) {
        NSArray *images = [NSArray arrayWithObjects:
            @"howto_tre01", @"howto_tre02", @"howto_tre03",
            @"howto_tre04", @"howto_tre05", @"howto_tre06", nil];
        if (_howtoViewCtrlPad != nil) {
            _howtoViewCtrlPad = nil;
        }
        _howtoViewCtrlPad = [[HowToViewCtrlPad alloc] initWithFileNameArray:images];
        [RootVC().view addSubview:_howtoViewCtrlPad.view];
    } else if (indexPath.row == 0) {
        NSArray *images = [NSArray arrayWithObjects:
            @"howto_01", @"howto_02", @"howto_03", @"howto_04", @"howto_05", nil];
        if (_howtoViewCtrlPad != nil) {
            _howtoViewCtrlPad = nil;
        }
        _howtoViewCtrlPad = [[HowToViewCtrlPad alloc] initWithFileNameArray:images];
        [_howtoViewCtrlPad.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"howto_navbar"]
            forBarMetrics:UIBarMetricsDefault];
        [RootVC().view addSubview:_howtoViewCtrlPad.view];
    }
}

@end
