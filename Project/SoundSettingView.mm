//
//  SoundSettingView.mm
//  pop'n rhythmin
//
//  See SoundSettingView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin:
//    initWithStyle: @ 0x811c8, dealloc @ 0x8131c, viewDidLoad @ 0x81564,
//    didReceiveMemoryWarning @ 0x8191c, viewDidUnload @ 0x81948,
//    viewWillAppear: @ 0x81974, viewDidAppear: @ 0x819a0,
//    viewWillDisappear: @ 0x819cc, viewDidDisappear: @ 0x819f8,
//    shouldAutorotateToInterfaceOrientation: @ 0x81a24,
//    numberOfSectionsInTableView: @ 0x81a30, tableView:numberOfRowsInSection: @ 0x81a60,
//    tableView:cellForRowAtIndexPath: @ 0x81a8c, tableView:titleForHeaderInSection: @ 0x82780,
//    tableView:viewForHeaderInSection: @ 0x82784, tableView:heightForHeaderInSection: @ 0x8292c,
//    tableView:didSelectRowAtIndexPath: @ 0x82934, bgmSliderValChanged: @ 0x82af4,
//    seSliderValChanged: @ 0x82bbc, touchSoundSliderValChanged: @ 0x82cc4,
//    isHaveTouchSound: @ 0x82d9c, backButtonFunc @ 0x82dc0.
//  Objective-C++ for the neSceneManager / neEngine C++ bridge.
//
//  FIXED-POINT NOTE: the SE and touch-sound volumes are stored as fixed-point shorts.
//  The binary converts with FPToFixed(value, frac=0, round) on save and FixedToFP on
//  load, i.e. a plain rounded float<->short in the 0..127 range; reconstructed here as
//  ordinary (short)/(float) casts. The BGM volume is a plain float (0..1).
//
//  HONESTY NOTE: three "preview" playSe:resourceId:Volume: calls (the SE/touch sliders
//  and the picker selection) have their resourceId/Volume argument registers
//  callee-saved-/NEON-spilled in the decompile (shown uninitialised). They are
//  reconstructed with the semantically-matching loaded SE handle and the slider's
//  fixed-point volume, and flagged inline. The iPad picker-cell check/background frame
//  maths are likewise NEON-spilled (best-effort, flagged). Everything else -- colours,
//  slider ranges, section titles (UTF-16 decoded), asset names -- is exact.
//

#import "SoundSettingView.h"

#import "AudioManager.h"       // BGM/SE volume + lib_rsnd SE load/play/stop/release
#import "AppFont.h"            // AppFontName (== Ghidra getFontNameDFSoGei / FUN_0005ef9c)
#import "UserSettingData.h"    // persisted BGM/SE/touch volumes + touch-sound kind
#import "neEngineBridge.h"     // neSceneManager::isPadDisplay / hitSoundName / normalSoundName
                               //   neEngine::playSystemSe (back-button cancel SE)

// Fixed-point <-> float helpers matching the binary's FPToFixed/FixedToFP (frac = 0).
static inline short SoundFPToFixed(float v) { return (short)v; }
static inline float SoundFixedToFP(short v) { return (float)v; }

@implementation SoundSettingView {
    UISlider *_bgmSlider;            // @0xa4  BGM master volume (0..1)
    UISlider *_seSlider;             // @0xa8  SE master volume (0..127)
    UISlider *_touchSoundSlider;     // @0xac  touch-sound volume (0..127)
    int _touchSoundRscId;            // @0xb0  loaded handle of the current touch SE (group 0)
    int _seRscId;                    // @0xb4  loaded handle of the "se02_kettei" decide SE (group 1)
    int _selectedTouchSoundNo;       // @0xb8  currently-selected touch-sound kind (0..9)
    int _touchSoundHaveFlg;          // @0xbc  bitmask of unlocked touch-sound kinds
    NSMutableArray *_touchSoundArray; // @0xc0 NSNumber(int) list of unlocked touch-sound kinds
}

// @ 0x811c8 -- grouped-table styling. iPhone tiles the "back_bg_st" panel behind the
// table; iPad goes transparent with no separators (cells draw their own frames).
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        self.tableView.backgroundColor = [UIColor clearColor];
        if (!neSceneManager::isPadDisplay()) {
            self.tableView.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
        } else {
            self.tableView.backgroundView = nil;
            self.tableView.separatorColor = [UIColor clearColor];
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        }
    }
    return self;
}

// @ 0x8131c -- commit every setting, tear down the two loaded SEs, release the sliders
// and the touch-sound list. The retainCount NSLogs are leftover debug traces.
- (void)dealloc {
    [UserSettingData saveBgmVolume:_bgmSlider.value];
    [UserSettingData saveSeVolume:SoundFPToFixed(_seSlider.value)];
    [UserSettingData saveTouchSoundVolume:SoundFPToFixed(_touchSoundSlider.value)];
    [UserSettingData saveTouchSoundKind:(short)_selectedTouchSoundNo];

    AudioManager *audio = [AudioManager sharedManager];
    [audio stopSe:_touchSoundRscId];
    [audio releaseSe:nil resourceId:_touchSoundRscId];
    [[AudioManager sharedManager] stopSe:_seRscId];
    [[AudioManager sharedManager] releaseSe:nil resourceId:_seRscId];

    NSLog(@"%lu", (unsigned long)[_bgmSlider retainCount]);
    NSLog(@"%lu", (unsigned long)[_seSlider retainCount]);
    NSLog(@"%lu", (unsigned long)[_touchSoundSlider retainCount]);
    NSLog(@"%lu", (unsigned long)[_touchSoundArray retainCount]);

    [_bgmSlider release];
    [_seSlider release];
    [_touchSoundSlider release];
    [_touchSoundArray release];

    [super dealloc];
}

// @ 0x81564 -- read the persisted touch-sound state, build the unlocked-kinds list,
// preload the selected touch SE + the "decide" SE, and install the back button.
- (void)viewDidLoad {
    [super viewDidLoad];

    _touchSoundHaveFlg = [UserSettingData haveTouchSoundFlg];
    short kind = [UserSettingData touchSoundKind];
    _selectedTouchSoundNo = kind;
    if (![self isHaveTouchSound:kind]) {
        _selectedTouchSoundNo = 0;   // fall back to the default (always-owned) kind 0
    }

    _touchSoundArray = [[NSMutableArray array] retain];
    for (int i = 0; i < 10; i++) {
        if ([self isHaveTouchSound:i]) {
            [_touchSoundArray addObject:[NSNumber numberWithInt:i]];
        }
    }

    // Preload the currently-selected touch SE (group 0 = low-latency lib_rsnd) and the
    // "decide"/confirm SE (se02_kettei, group 1) previewed when the SE slider moves.
    NSString *hitName = (__bridge NSString *)neSceneManager::hitSoundName(_selectedTouchSoundNo);
    NSString *hitPath = [[NSBundle mainBundle] pathForResource:hitName ofType:@"m4a"];
    _touchSoundRscId =
        (int)[[AudioManager sharedManager] loadSe:hitPath isLoop:NO callName:nil group:0];

    NSString *decidePath = [[NSBundle mainBundle] pathForResource:@"se02_kettei" ofType:@"m4a"];
    _seRscId =
        (int)[[AudioManager sharedManager] loadSe:decidePath isLoop:NO callName:nil group:1];

    if (!neSceneManager::isPadDisplay()) {
        // iPhone: custom "navi_btn_back" left bar button wired to backButtonFunc.
        UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
        CGSize sz = backImage ? backImage.size : CGSizeZero;
        UIButton *backButton = [[[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, sz.width, sz.height)] autorelease];
        [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
        [backButton addTarget:self action:@selector(backButtonFunc)
             forControlEvents:UIControlEventTouchUpInside];   // 0x40
        self.navigationItem.leftBarButtonItem =
            [[[UIBarButtonItem alloc] initWithCustomView:backButton] autorelease];
    } else {
        // iPad: hosted inside a panel, so just suppress the system back button.
        self.navigationItem.hidesBackButton = YES;
    }
}

// @ 0x8191c / 0x81948 / 0x81974 / 0x819a0 / 0x819cc / 0x819f8 -- plain super forwards.
- (void)didReceiveMemoryWarning { [super didReceiveMemoryWarning]; }
- (void)viewDidUnload { [super viewDidUnload]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; }

// @ 0x81a24 -- portrait only (UIInterfaceOrientationPortrait == 1).
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait;
}

#pragma mark - Table

// @ 0x81a30 -- three volume sections, plus the touch-sound picker section only when
// the player owns two or more unlocked touch sounds.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (_touchSoundArray.count >= 2) ? 4 : 3;
}

// @ 0x81a60 -- one row for each volume section; the picker section has one row per
// unlocked touch-sound kind.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < 3) {
        return 1;
    }
    if (section == 3) {
        return _touchSoundArray.count;
    }
    return 0;
}

// @ 0x81a8c -- volume-slider cells (sections 0/1/2) are built once, on first creation;
// picker cells (section 3) are re-decorated on every layout pass.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId = [NSString stringWithFormat:@"Cell%ld-%ld",
                        (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];

    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:cellId] autorelease];

        // iPad: give the volume cells a rounded, light-cream backgroundView.
        if (neSceneManager::isPadDisplay() && indexPath.section != 3) {
            UIView *bg = [[[UIView alloc] init] autorelease];
            bg.layer.borderWidth = 0.5f;    // 0x3f000000
            bg.layer.cornerRadius = 5.0f;   // 0x40a00000
            bg.backgroundColor = [UIColor colorWithRed:0.964706f green:0.949020f
                                                  blue:0.945098f alpha:1.0f];
            // 0x3f76f6f7 / 0x3f72f2f3 / 0x3f71f1f2 / 0x3f800000  (246 / 242 / 241 over 255)
            cell.backgroundColor = [UIColor clearColor];
            cell.backgroundView = bg;
        }

        // Slider frame. NEON-spilled on iPhone (best-effort): x = 16, width =
        // cellWidth - 32. iPad is a fixed 250-wide slider inset 10pt.
        CGRect frm = cell.frame;
        CGRect sliderFrame;
        if (!neSceneManager::isPadDisplay()) {
            sliderFrame = CGRectMake(16.0f, 0.0f, frm.size.width - 32.0f, frm.size.height);
        } else {
            sliderFrame = CGRectMake(10.0f, 0.0f, 250.0f, frm.size.height);   // 0x41200000 / 0x437a0000
        }

        // --- Section 0 / row 0: BGM volume (linear 0..1) ---
        if (indexPath.section == 0 && indexPath.row == 0) {
            _bgmSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _bgmSlider.minimumValue = 0.0f;
            _bgmSlider.maximumValue = 1.0f;   // 0x3f800000
            _bgmSlider.value = [UserSettingData bgmVolume];
            _bgmSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _bgmSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _bgmSlider.continuous = NO;
            [_bgmSlider addTarget:self action:@selector(bgmSliderValChanged:)
                 forControlEvents:UIControlEventValueChanged];   // 0x1000
            [cell addSubview:_bgmSlider];
        }

        // --- Section 1 / row 0: SE volume (0..127) ---
        if (indexPath.section == 1 && indexPath.row == 0) {
            _seSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _seSlider.minimumValue = 0.0f;
            _seSlider.maximumValue = 127.0f;   // 0x42fe0000
            _seSlider.value = SoundFixedToFP([UserSettingData seVolume]);
            _seSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _seSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _seSlider.continuous = NO;
            [_seSlider addTarget:self action:@selector(seSliderValChanged:)
                 forControlEvents:UIControlEventValueChanged];
            [cell addSubview:_seSlider];
        }

        // --- Section 2 / row 0: touch-sound volume (0..127) ---
        if (indexPath.section == 2 && indexPath.row == 0) {
            _touchSoundSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _touchSoundSlider.minimumValue = 0.0f;
            _touchSoundSlider.maximumValue = 127.0f;
            _touchSoundSlider.value = SoundFixedToFP([UserSettingData touchSoundVolume]);
            _touchSoundSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _touchSoundSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _touchSoundSlider.continuous = NO;
            [_touchSoundSlider addTarget:self action:@selector(touchSoundSliderValChanged:)
                 forControlEvents:UIControlEventValueChanged];
            [cell addSubview:_touchSoundSlider];
        }
    }

    // --- Section 3: touch-sound kind picker ---
    if (indexPath.section == 3) {
        int soundNo = [[_touchSoundArray objectAtIndexedSubscript:indexPath.row] intValue];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = (__bridge NSString *)neSceneManager::normalSoundName(soundNo);
        cell.textLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];   // 0x41880000
        cell.textLabel.backgroundColor = [UIColor clearColor];

        if (!neSceneManager::isPadDisplay()) {
            // iPhone: the selected kind gets black text + a checkmark; others are
            // dark-gray with no accessory.
            if (soundNo == _selectedTouchSoundNo) {
                cell.textLabel.textColor = [UIColor blackColor];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;   // 3
            } else {
                cell.textLabel.textColor = [UIColor darkGrayColor];
                cell.accessoryType = UITableViewCellAccessoryNone;        // 0
            }
            return cell;
        }

        // iPad: an explicit check image plus a segmented "custom_bt02" background.
        // (check/background frame maths are NEON-spilled -- best-effort placement.)
        NSString *checkName = (soundNo == _selectedTouchSoundNo) ? @"m_sort_check_01"
                                                                 : @"m_sort_check_00";
        UIImageView *check = [[[UIImageView alloc]
            initWithImage:[UIImage imageNamed:checkName]] autorelease];
        CGRect cf = check.frame;
        CGFloat checkX = ([UIDevice currentDevice].systemVersion.floatValue >= 7.0f)
                         ? 230.0f : 210.0f;   // DAT_00082778 / DAT_0008277c
        check.frame = CGRectMake(cf.origin.x + checkX, cf.origin.y + 7.0f,   // +7.0 (0x40e00000)
                                 cf.size.width + 8.0f, cf.size.height + 8.0f);
        for (UIView *sub in [[cell.contentView.subviews copy] autorelease]) {
            [sub removeFromSuperview];
        }
        [cell.contentView addSubview:check];

        NSString *bgName;
        if (indexPath.row == 0) {
            bgName = @"custom_bt02_top";
        } else if (indexPath.row == (NSInteger)_touchSoundArray.count - 1) {
            bgName = @"custom_bt02_under";
        } else {
            bgName = @"custom_bt02_center";
        }
        cell.backgroundView = [[[UIImageView alloc]
            initWithImage:[UIImage imageNamed:bgName]] autorelease];
        return cell;
    }

    // Volume sections finish with the tap highlight disabled.
    if (indexPath.section <= 2) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

// @ 0x82780 -- header text comes from viewForHeaderInSection: instead.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0x82784 -- a transparent header carrying the section title in the app font.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    // Header container: x = 5, w = 320, h = 32.
    UIView *header = [[[UIView alloc]
        initWithFrame:CGRectMake(5.0f, 0.0f, 320.0f, 32.0f)] autorelease];  // 0x40a00000 / 0x43a00000 / 0x42000000
    header.backgroundColor = [UIColor clearColor];

    NSString *title;
    switch (section) {
        case 0:  title = @"BGM ボリューム"; break;             // cf_B      (UTF-16)
        case 1:  title = @"SE ボリューム"; break;              // cf_S      (UTF-16)
        case 2:  title = @"タッチサウンド ボリューム"; break;   // cf_0000000 (UTF-16)
        case 3:  title = @"タッチサウンド"; break;             // cf_0000000 (UTF-16)
        default: title = @""; break;                           // cf_"" (empty)
    }

    UILabel *label = [[[UILabel alloc]
        initWithFrame:CGRectMake(5.0f, 0.0f, 320.0f, 32.0f)] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont fontWithName:AppFontName() size:14.0f];   // 0x41600000
    label.text = title;
    [header addSubview:label];
    return header;
}

// @ 0x8292c -- constant 32pt headers.
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32.0f;   // 0x42000000
}

// @ 0x82934 -- only the touch-sound picker rows respond: switch the selected kind
// (reloading its SE), then preview it at the current touch-sound volume.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AudioManager *audio = [AudioManager sharedManager];
    if (indexPath.section == 3) {
        int soundNo = [[_touchSoundArray objectAtIndexedSubscript:indexPath.row] intValue];
        if (soundNo != _selectedTouchSoundNo) {
            _selectedTouchSoundNo = soundNo;
            [audio stopSe:_touchSoundRscId];
            [audio releaseSe:nil resourceId:_touchSoundRscId];
            NSString *hitName =
                (__bridge NSString *)neSceneManager::hitSoundName(_selectedTouchSoundNo);
            NSString *hitPath = [[NSBundle mainBundle] pathForResource:hitName ofType:@"m4a"];
            _touchSoundRscId = (int)[audio loadSe:hitPath isLoop:NO callName:nil group:0];
            [self.tableView reloadData];
        }
        // Preview the (possibly new) touch SE. NOTE: resourceId/Volume registers are
        // NEON-spilled in the binary -- reconstructed as the loaded touch handle at the
        // touch-sound slider's fixed-point volume.
        [audio playSe:nil resourceId:_touchSoundRscId
               Volume:(float)SoundFPToFixed(_touchSoundSlider.value)];
    }
}

#pragma mark - Slider actions

// @ 0x82af4 -- live-apply the BGM volume (with and without fade); iPad persists it.
- (void)bgmSliderValChanged:(id)sender {
    float v = _bgmSlider.value;
    [[AudioManager sharedManager] setBgmVolume:v];
    [[AudioManager sharedManager] setJustBgmVolume:v];
    if (neSceneManager::isPadDisplay()) {
        [UserSettingData saveBgmVolume:_bgmSlider.value];
    }
}

// @ 0x82bbc -- apply the SE group volume, preview it when non-zero; iPad persists it.
- (void)seSliderValChanged:(id)sender {
    short vol = SoundFPToFixed(_seSlider.value);
    [[AudioManager sharedManager] setSeVolume:vol groupId:1];
    if (vol > 0) {
        // Preview SE (NEON-spilled resourceId/Volume -- reconstructed as the decide SE
        // handle at the SE slider's volume).
        [[AudioManager sharedManager] playSe:nil resourceId:_seRscId Volume:(float)vol];
        if (neSceneManager::isPadDisplay()) {
            [UserSettingData saveSeVolume:SoundFPToFixed(_seSlider.value)];
        }
    }
}

// @ 0x82cc4 -- preview the touch SE when the volume is non-zero; iPad persists it.
- (void)touchSoundSliderValChanged:(id)sender {
    short vol = SoundFPToFixed(_touchSoundSlider.value);
    if (vol > 0) {
        // Preview touch SE (NEON-spilled resourceId/Volume -- reconstructed as the
        // touch SE handle at the touch-sound slider's volume).
        [[AudioManager sharedManager] playSe:nil resourceId:_touchSoundRscId Volume:(float)vol];
        if (neSceneManager::isPadDisplay()) {
            [UserSettingData saveTouchSoundVolume:SoundFPToFixed(_touchSoundSlider.value)];
        }
    }
}

// @ 0x82d9c -- kind 0 is always owned; the rest are gated by the unlock bitmask.
- (BOOL)isHaveTouchSound:(int)soundNo {
    if (soundNo == 0) {
        return YES;
    }
    return (_touchSoundHaveFlg & (1 << (soundNo & 0xff))) != 0;
}

// @ 0x82dc0 -- play the cancel SE, restore the settings nav bar, and pop self.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);   // Ghidra: SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
