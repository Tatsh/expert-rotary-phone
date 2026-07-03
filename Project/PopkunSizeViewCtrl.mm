//
//  PopkunSizeViewCtrl.mm
//  pop'n rhythmin
//
//  See PopkunSizeViewCtrl.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ (MRC) for the neSceneManager / neEngine C++ bridge.
//
//  viewDidLoad builds the screen entirely in code. The device class
//  (neSceneManager::isPadDisplay()) selects one of two layouts:
//
//   * iPhone (non-pad): controls are centred horizontally in the live view width W
//     and stacked with per-control Y offsets seeded into offsetYForPad1..4. A
//     "popkun_size_text" caption image sits at the top and a custom "navi_btn_back"
//     bar button (-> backButtonFunc) is installed as the left nav item.
//   * iPad (pad): W is fixed at 428pt; offsetYForPad1..4 are small paddings; the
//     controls use hard-coded centres inside the panel, an info UILabel
//     ("ポップ君の大きさを変更できるよ！") and a "popkun_size_preview" image are
//     added, and the system back button is hidden (setHidesBackButton:YES) rather
//     than replaced with a custom bar button.
//
//  Honesty / recovery notes:
//   * All CGRect reads in the binary are NEON-spilled with compiler-generated
//     "receiver == nil -> zero the struct" guards; those are elided here and modelled
//     as ordinary Cocoa -frame/-center/-size calls (behaviourally identical for the
//     non-nil case that always holds at runtime).
//   * Float/colour constants are the exact IEEE-754 values decoded from the binary
//     (annotated inline with their hex).
//   * The info-label text is a UTF-16 CFString @ 0x12ca5c, bytes
//     DD30 C330 D730 1B54 6E30 2759 4D30 5530 9230 0959 F466 6730 4D30 8B30 8830 01FF
//     = "ポップ君の大きさを変更できるよ！".
//   * offsetYForPad1..4 (int ivars @0xcc/0xd0/0xd4/0xd8) are the per-control Y bias
//     table seeded at the top of viewDidLoad; their names come from the binary.
//   * _size persists via UserSettingData: read with +popkunSize (declared) and
//     written with +savePopkunSize: (selector present in the binary but NOT yet
//     declared in UserSettingData.h -- see the note at the call sites).
//

#import "PopkunSizeViewCtrl.h"

#import "neEngineBridge.h"    // neSceneManager::isPadDisplay, neEngine::playSystemSe
#import "AppFont.h"           // AppMaruFontName (info label typeface)
#import "UserSettingData.h"   // popkunSize getter (+ savePopkunSize: setter)
#import "CustomAlertView.h"   // CustomAlertView (the _hoge overlay created in viewDidLoad)

// The size slider's backing font (CFString cf_BullyBold in the binary); a bundled
// display face with no AppFont helper, so the literal name is used directly.
static NSString *const kPopkunSizeLabelFontName = @"BullyBold";

@implementation PopkunSizeViewCtrl {
    UIImageView     *_infoView;     // @0xa4  iPhone-only "popkun_size_text" caption art
    UIImageView     *_popkun;       // @0xa8  the live-resized preview pop-kun
    UISlider        *_sizeSlider;   // @0xac  50-100% size slider
    UIButton        *_resetButton;  // @0xb0  "popkun_size_btn_default" (restore 100%)
    UILabel         *_sizeLbl;      // @0xb4  "%d%%" readout above the pop-kun
    float            _size;         // @0xb8  current size percentage (50..100)
    CGRect           _orgFrame;     // @0xbc  the pop-kun art's natural frame (0,0,w,h)
    int              offsetYForPad1; // @0xcc  iPhone Y bias: info caption
    int              offsetYForPad2; // @0xd0  iPhone Y bias: slider
    int              offsetYForPad3; // @0xd4  iPhone Y bias: reset button
    int              offsetYForPad4; // @0xd8  iPhone Y bias: pop-kun preview
    CustomAlertView *_hoge;         // @0xdc  full-screen alert overlay
}

// @ 0x8b44c
- (void)viewDidLoad {
    [super viewDidLoad];

    const BOOL isPad = neSceneManager::isPadDisplay();

    // Per-control Y bias table. iPhone uses (mostly negative) nudges to pull the
    // stack up; iPad uses small paddings.
    if (!isPad) {
        offsetYForPad1 = -10;   // 0xfffffff6
        offsetYForPad2 = -10;   // 0xfffffff6
        offsetYForPad3 = -300;  // 0xfffffed4
        offsetYForPad4 = 30;    // 0x1e
    } else {
        offsetYForPad1 = 5;
        offsetYForPad2 = 5;
        offsetYForPad3 = 10;
        offsetYForPad4 = 10;
    }

    _size = [UserSettingData popkunSize];

    // Full-screen alert overlay, added first so it sits behind the controls.
    // @ 0x8b4d0 — bare -[CustomAlertView init] (inherited UIImageView init; no custom
    // designated initializer is used here).
    _hoge = [[CustomAlertView alloc] init];
    [self.view addSubview:_hoge];

    // Horizontal layout reference width: the live view width on iPhone, a fixed
    // 428pt (0x43d60000) panel on iPad.
    const CGFloat W = isPad ? 428.0f : self.view.frame.size.width;

    if (!isPad) {
        // iPhone: the whole view uses the "popkun_size_bg" pattern, and a caption
        // image ("popkun_size_text") is centred at (W/2, offsetYForPad1 + 40). On
        // iPad neither is used -- the info label + preview art below replace them.
        [self.view setBackgroundColor:
            [UIColor colorWithPatternImage:[UIImage imageNamed:@"popkun_size_bg"]]];

        UIImage *textImg = [UIImage imageNamed:@"popkun_size_text"];
        _infoView = [[UIImageView alloc] initWithImage:textImg];
        [_infoView setFrame:CGRectMake(0, 0, textImg.size.width, textImg.size.height)];
        [_infoView setCenter:CGPointMake(W * 0.5f, offsetYForPad1 + 40)];
        [self.view addSubview:_infoView];
    }

    // --- Size slider ---
    const CGFloat sliderW = W * (isPad ? 0.6f : 0.95f);   // 0x3f19999a / 0x3f733333
    _sizeSlider = [[UISlider alloc]
        initWithFrame:CGRectMake(0, 0, sliderW, 30.0f)];   // h 0x41f00000
    if (isPad) {
        [_sizeSlider setCenter:CGPointMake(134.0f, 90.0f)];   // 0x43060000 / 0x42b40000
    } else {
        [_sizeSlider setCenter:CGPointMake(W * 0.5f, offsetYForPad2 + 110)];
    }
    [_sizeSlider setMinimumValue:50.0f];    // 0x42480000
    [_sizeSlider setMaximumValue:100.0f];   // 0x42c80000
    [_sizeSlider setValue:_size];
    [_sizeSlider setMinimumValueImage:[UIImage imageNamed:@"popkun_size_icon_mini"]];
    [_sizeSlider setMaximumValueImage:[UIImage imageNamed:@"popkun_size_icon_max"]];
    [_sizeSlider addTarget:self action:@selector(sliderValChanged:)
          forControlEvents:UIControlEventValueChanged];                       // 0x1000
    [_sizeSlider addTarget:self action:@selector(sliderValDecide:)
          forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside]; // 0x60

    if (isPad) {
        // Info label: "ポップ君の大きさを変更できるよ！"
        UILabel *infoLbl = [[UILabel alloc] init];
        infoLbl.backgroundColor = [UIColor clearColor];
        infoLbl.textColor = [UIColor colorWithRed:0.188235f green:0.188235f blue:0.188235f
                                            alpha:1.0f];   // 0x3e40c0c1
        infoLbl.highlightedTextColor = [UIColor whiteColor];
        infoLbl.font = [UIFont fontWithName:AppMaruFontName() size:15.0f];   // 0x41700000
        infoLbl.textAlignment = NSTextAlignmentLeft;
        infoLbl.adjustsFontSizeToFitWidth = YES;
        infoLbl.minimumScaleFactor = 0.5f;   // 0x3f000000
        infoLbl.text = @"ポップ君の大きさを変更できるよ！";
        infoLbl.frame = CGRectMake(0, 0, 261.0f, 32.0f);   // 0x43828000 / 0x42000000
        infoLbl.center = CGPointMake(138.0f, 30.0f);       // 0x430a0000 / 0x41f00000
        [self.view addSubview:infoLbl];

        // Preview art below the info label.
        UIImageView *preview = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"popkun_size_preview"]];
        preview.frame = preview.frame;   // (binary re-sets the frame to the image frame)
        preview.center = CGPointMake(136.0f, 240.0f);   // 0x43080000 / 0x43700000
        [self.view addSubview:preview];
    }

    // --- Preview pop-kun (both layouts) ---
    UIImage *popkunImg = [UIImage imageNamed:@"popkun_size_popkun"];
    _orgFrame = CGRectMake(0, 0, popkunImg.size.width, popkunImg.size.height);
    _popkun = [[UIImageView alloc] initWithImage:popkunImg];
    if (isPad) {
        [_popkun setCenter:CGPointMake(134.0f, 240.0f)];   // 0x43060000 / 0x43700000
    } else {
        [_popkun setCenter:CGPointMake(W * 0.5f, offsetYForPad4 + 278)];   // +0x116
    }

    // --- Size readout label ---
    _sizeLbl = [[UILabel alloc] init];
    _sizeLbl.font = [UIFont fontWithName:kPopkunSizeLabelFontName size:16.0f];   // 0x41800000
    [_sizeLbl setTextColor:[UIColor colorWithWhite:0.8f alpha:1.0f]];            // 0x3f4ccccd
    [_sizeLbl setTextAlignment:NSTextAlignmentCenter];
    [_sizeLbl setFrame:CGRectMake(0, 0, 100.0f, 20.0f)];   // 0x42c80000 / 0x41a00000
    if (isPad) {
        // Sit 45pt above the pop-kun's centre (resizePopkun re-positions it too).
        _sizeLbl.center = CGPointMake(_popkun.center.x, _popkun.center.y - 45.0f);   // 0xc2340000
    }
    [_sizeLbl setBackgroundColor:[UIColor clearColor]];

    [self resizePopkun];

    // --- Reset button ---
    UIImage *resetImg = [UIImage imageNamed:@"popkun_size_btn_default"];
    _resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_resetButton setFrame:CGRectMake(0, 0, resetImg.size.width, resetImg.size.height)];
    if (isPad) {
        [_resetButton setCenter:CGPointMake(134.0f, 385.0f)];   // 0x43060000 / 0x43c08000
    } else {
        [_resetButton setCenter:CGPointMake(W * 0.5f, offsetYForPad3 + 450)];   // +0x1c2
    }
    [_resetButton setBackgroundImage:resetImg forState:UIControlStateNormal];
    [_resetButton addTarget:self action:@selector(touchedResetButton:)
           forControlEvents:UIControlEventTouchUpInside];   // 0x40

    [self.view addSubview:_sizeSlider];
    [self.view addSubview:_popkun];
    [self.view addSubview:_sizeLbl];
    [self.view addSubview:_resetButton];

    if (!isPad) {
        // iPhone: custom back bar button.
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];   // 0x40
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    } else {
        // iPad: use the system back button.
        [self.navigationItem setHidesBackButton:YES];
    }
}

// @ 0x8c1a4
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0x8c1d0
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

// dealloc @ 0x8c1fc — ARC-omitted (chained to super only; all sub-views retained by the
// view hierarchy).

// @ 0x8c228 -- live slider drag: track the value and re-apply it.
- (void)sliderValChanged:(id)sender {
    _size = [_sizeSlider value];
    [self resizePopkun];
}

// @ 0x8c270 -- slider touch-up: persist the chosen size.
- (void)sliderValDecide:(id)sender {
    // NOTE: +savePopkunSize: is present in the binary but not yet declared in
    // UserSettingData.h (only the +popkunSize getter is).
    [UserSettingData savePopkunSize:_size];
}

// @ 0x8c29c -- reset to 100% and persist.
- (void)touchedResetButton:(id)sender {
    _size = 100.0f;   // 0x42c80000
    [_sizeSlider setValue:_size];
    [UserSettingData savePopkunSize:_size];   // see note in sliderValDecide:
    [self resizePopkun];
}

// @ 0x8c30c -- iPhone back button: play the cancel SE, restore the settings nav bar
// background and pop.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);   // Ghidra: SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x8c3a8 -- scale the preview pop-kun to _size percent of its natural frame,
// reposition it, and refresh the "%d%%" readout.
- (void)resizePopkun {
    const BOOL isPad = neSceneManager::isPadDisplay();

    // iPhone centre X comes from the live view width; iPad uses a fixed centre.
    const CGFloat centerX = isPad ? 134.0f : self.view.frame.size.width * 0.5f;   // 0x43060000

    const CGFloat w = _orgFrame.size.width  * _size / 100.0f;   // DAT_0008c618 == 100
    const CGFloat h = _orgFrame.size.height * _size / 100.0f;
    [_popkun setFrame:CGRectMake(0, 0, w, h)];

    CGFloat centerY;
    if (isPad) {
        centerY = 240.0f;   // 0x43700000
    } else {
        centerY = offsetYForPad4 + 268;   // +0x10c
    }
    [_popkun setCenter:CGPointMake(centerX, centerY)];

    [_sizeLbl setText:[NSString stringWithFormat:@"%d%%", (int)_size]];
    [_sizeLbl sizeToFit];
    // Keep the readout 45pt above the pop-kun's centre.
    _sizeLbl.center = CGPointMake(_popkun.center.x, _popkun.center.y - 45.0f);   // DAT_0008c61c
}

@end
