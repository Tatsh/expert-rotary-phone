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
//    numberOfSectionsInTableView: @ 0x81a30, tableView:numberOfRowsInSection: @
//    0x81a60, tableView:cellForRowAtIndexPath: @ 0x81a8c,
//    tableView:titleForHeaderInSection: @ 0x82780,
//    tableView:viewForHeaderInSection: @ 0x82784,
//    tableView:heightForHeaderInSection: @ 0x8292c,
//    tableView:didSelectRowAtIndexPath: @ 0x82934, bgmSliderValChanged: @
//    0x82af4, seSliderValChanged: @ 0x82bbc, touchSoundSliderValChanged: @
//    0x82cc4, isHaveTouchSound: @ 0x82d9c, backButtonFunc @ 0x82dc0.
//  Objective-C++ for the neSceneManager / neEngine C++ bridge.
//
//  VOLUME NOTE: the SE and touch-sound volumes are stored as shorts. The binary
//  converts on save with a plain vcvt.s32.f32 (0x82c0a, no scale) and on load
//  with vcvt.f32.s32, i.e. an ordinary float<->short truncation in the 0..127
//  range. The BGM volume is a plain float (0..1).
//
//  HONESTY NOTE: three "preview" playSe:resourceId:Volume: calls (the SE/touch
//  sliders and the picker selection) have their resourceId/Volume argument
//  registers callee-saved-/NEON-spilled in the decompile (shown uninitialised).
//  They are reconstructed with the semantically-matching loaded SE handle and
//  the slider's volume, and flagged inline — these are runtime
//  values and cannot be expressed as compile-time constants. The iPad
//  picker-cell check frame constants are now exact by disassembly (y+8.0,
//  unmodified w/h; see inline). Everything else
//  -- colours, slider ranges, section titles (UTF-16 decoded), asset names --
//  is exact.
//

#import "SoundSettingView.h"

#import "AppFont.h"         // AppFontName (== Ghidra getFontNameDFSoGei / FUN_0005ef9c)
#import "AudioManager.h"    // BGM/SE volume + lib_rsnd SE load/play/stop/release
#import "UserSettingData.h" // persisted BGM/SE/touch volumes + touch-sound kind
#import "neEngineBridge.h"  // neSceneManager::isPadDisplay / hitSoundName / normalSoundName
//   neEngine::playSystemSe (back-button cancel SE)

// The sound-settings table sections: three single-row volume sliders, then a
// touch-sound picker (one row per unlocked touch sound; only shown when there
// is more than one, so the count is 3 or 4).
typedef NS_ENUM(NSInteger, SoundSettingSection) {
    SoundSettingSectionBgmVolume = 0,   // BGM ボリューム
    SoundSettingSectionSeVolume = 1,    // SE ボリューム
    SoundSettingSectionTouchVolume = 2, // タッチサウンド ボリューム
    SoundSettingSectionTouchPicker = 3, // タッチサウンド (per-kind picker)
    SoundSettingSectionCount = 4,
};

// Volume <-> stored-short helpers: a plain truncating float<->short round-trip
// (the binary's vcvt ops).
static inline short SoundVolumeToShort(float v) {
    return (short)v;
}
static inline float SoundShortToVolume(short v) {
    return (float)v;
}

#ifdef ENABLE_PATCHES
// Private modern-iOS drag-fix helpers (see the "Nested-scroll drag fix" section);
// declared here because cellForRowAtIndexPath: wires them before their
// definitions.
@interface SoundSettingView ()
- (void)wireSliderDragFix:(UISlider *)slider;
@end

// @newCode -- Volume cell that guarantees its slider is hit-testable. This table
// is embedded several layers deep (a table inside a game-settings cell), and on
// modern iOS the hit-test resolves a touch that lands on the slider to the cell
// itself rather than descending into it, so the slider never receives drags.
// Prefer the slider explicitly: if the point falls inside it, return it.
@interface RHVolumeSliderCell : UITableViewCell
@end

@implementation RHVolumeSliderCell
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UISlider class]] && !sub.hidden && sub.userInteractionEnabled &&
            sub.alpha > 0.01f) {
            CGPoint local = [self convertPoint:point toView:sub];
            if ([sub pointInside:local withEvent:event]) {
                return sub;
            }
        }
    }
    return [super hitTest:point withEvent:event];
}
@end
#endif

@implementation SoundSettingView {
    UISlider *_bgmSlider;        // @0xa4  BGM master volume (0..1)
    UISlider *_seSlider;         // @0xa8  SE master volume (0..127)
    UISlider *_touchSoundSlider; // @0xac  touch-sound volume (0..127)
    int _touchSoundRscId;        // @0xb0  loaded handle of the current touch SE (group
                                 // 0)
    int _seRscId;                // @0xb4  loaded handle of the "se02_kettei" decide SE (group 1)
    int _selectedTouchSoundNo;   // @0xb8  currently-selected touch-sound kind
                                 // (0..9)
    int _touchSoundHaveFlg;      // @0xbc  bitmask of unlocked touch-sound kinds
    NSMutableArray *_touchSoundArray; // @0xc0 NSNumber(int) list of unlocked
                                      // touch-sound kinds
}

// @ 0x811c8 -- grouped-table styling. iPhone tiles the "back_bg_st" panel
// behind the table; iPad goes transparent with no separators (cells draw their
// own frames).
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        // (The modern-iOS slider hit-testing fix lives in viewDidLoad, which
        // disables self-sizing, and in tableView:heightForRowAtIndexPath:, which
        // pins the row height; both are applied there rather than here because the
        // tableView discards these settings when it is configured after init.)
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

// @ 0x8131c -- commit every setting and tear down the two loaded SEs.
// (Slider/array releases and the leftover retainCount NSLog debug traces are
// ARC-omitted -- ARC forbids -retainCount and manages the object ivars.)
- (void)dealloc {
    [UserSettingData saveBgmVolume:_bgmSlider.value];
    [UserSettingData saveSeVolume:SoundVolumeToShort(_seSlider.value)];
    [UserSettingData saveTouchSoundVolume:SoundVolumeToShort(_touchSoundSlider.value)];
    [UserSettingData saveTouchSoundKind:(short)_selectedTouchSoundNo];

    AudioManager *audio = [AudioManager sharedManager];
    [audio stopSe:_touchSoundRscId];
    [audio releaseSe:nil resourceId:_touchSoundRscId];
    [[AudioManager sharedManager] stopSe:_seRscId];
    [[AudioManager sharedManager] releaseSe:nil resourceId:_seRscId];
}

// @ 0x81564 -- read the persisted touch-sound state, build the unlocked-kinds
// list, preload the selected touch SE + the "decide" SE, and install the back
// button.
- (void)viewDidLoad {
    [super viewDidLoad];

    // @newCode -- Modern iOS defaults tables to self-sizing (estimatedRowHeight is
    // automatic, i.e. -1). That path sizes each cell's contentView from Auto Layout;
    // these frame-based, constraint-less cells collapse the contentView to ~0 height,
    // and because hitTest clips at the zero-height contentView the sliders draw but
    // never receive touches. heightForRowAtIndexPath: fixes the cell height but not
    // the contentView. Setting estimatedRowHeight = 0 disables self-sizing outright,
    // restoring the classic fixed-height path where the contentView fills the cell.
    // This must be set in viewDidLoad (after loadView): the same assignment in
    // initWithStyle: was discarded when the tableView was configured.
    self.tableView.estimatedRowHeight = 0.0f;
    self.tableView.estimatedSectionHeaderHeight = 0.0f;
    self.tableView.estimatedSectionFooterHeight = 0.0f;

    _touchSoundHaveFlg = [UserSettingData haveTouchSoundFlg];
    short kind = [UserSettingData touchSoundKind];
    _selectedTouchSoundNo = kind;
    if (![self isHaveTouchSound:kind]) {
        _selectedTouchSoundNo = 0; // fall back to the default (always-owned) kind 0
    }

    _touchSoundArray = [NSMutableArray array];
    for (int i = 0; i < 10; i++) {
        if ([self isHaveTouchSound:i]) {
            [_touchSoundArray addObject:[NSNumber numberWithInt:i]];
        }
    }

    // Preload the currently-selected touch SE (group 0 = low-latency lib_rsnd)
    // and the "decide"/confirm SE (se02_kettei, group 1) previewed when the SE
    // slider moves.
    NSString *hitName = (__bridge NSString *)neSceneManager::hitSoundName(_selectedTouchSoundNo);
    NSString *hitPath = [[NSBundle mainBundle] pathForResource:hitName ofType:@"m4a"];
    _touchSoundRscId = (int)[[AudioManager sharedManager] loadSe:hitPath
                                                          isLoop:NO
                                                        callName:nil
                                                           group:0];

    NSString *decidePath = [[NSBundle mainBundle] pathForResource:@"se02_kettei" ofType:@"m4a"];
    _seRscId = (int)[[AudioManager sharedManager] loadSe:decidePath isLoop:NO callName:nil group:1];

    if (!neSceneManager::isPadDisplay()) {
        // iPhone: custom "navi_btn_back" left bar button wired to backButtonFunc.
        UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
        CGSize sz = backImage ? backImage.size : CGSizeZero;
        UIButton *backButton =
            [[UIButton alloc] initWithFrame:CGRectMake(0, 0, sz.width, sz.height)];
        [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(backButtonFunc)
             forControlEvents:UIControlEventTouchUpInside]; // 0x40
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];
    } else {
        // iPad: hosted inside a panel, so just suppress the system back button.
        self.navigationItem.hidesBackButton = YES;
    }
}

// @ 0x8191c / 0x81948 / 0x81974 / 0x819a0 / 0x819cc / 0x819f8 -- plain super
// forwards.
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (void)viewDidUnload {
    [super viewDidUnload];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

// @ 0x81a24 -- portrait only (UIInterfaceOrientationPortrait == 1).
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait;
}

#pragma mark - Table

// @ 0x81a30 -- three volume sections, plus the touch-sound picker section only
// when the player owns two or more unlocked touch sounds.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (_touchSoundArray.count >= 2) ? SoundSettingSectionCount :
                                           SoundSettingSectionTouchPicker;
}

// @ 0x81a60 -- one row for each volume section; the picker section has one row
// per unlocked touch-sound kind.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < SoundSettingSectionTouchPicker) {
        return 1;
    }
    if (section == SoundSettingSectionTouchPicker) {
        return _touchSoundArray.count;
    }
    return 0;
}

// @ 0x81a8c -- volume-slider cells (sections 0/1/2) are built once, on first
// creation; picker cells (section 3) are re-decorated on every layout pass.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];

    if (cell == nil) {
#ifdef ENABLE_PATCHES
        // Volume rows use the hit-test-forcing cell so their sliders stay draggable
        // through the nested-table embedding on modern iOS.
        Class cellClass = (indexPath.section <= SoundSettingSectionTouchVolume) ?
                              [RHVolumeSliderCell class] :
                              [UITableViewCell class];
#else
        Class cellClass = [UITableViewCell class];
#endif
        cell = [[cellClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];

        // iPad: give the volume cells a rounded, light-cream backgroundView.
        if (neSceneManager::isPadDisplay() && indexPath.section != 3) {
            UIView *bg = [[UIView alloc] init];
            bg.layer.borderWidth = 0.5f;  // 0x3f000000
            bg.layer.cornerRadius = 5.0f; // 0x40a00000
            bg.backgroundColor = [UIColor colorWithRed:0.964706f
                                                 green:0.949020f
                                                  blue:0.945098f
                                                 alpha:1.0f];
            // 0x3f76f6f7 / 0x3f72f2f3 / 0x3f71f1f2 / 0x3f800000  (246 / 242 / 241
            // over 255)
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
            sliderFrame = CGRectMake(10.0f,
                                     0.0f,
                                     250.0f,
                                     frm.size.height); // 0x41200000 / 0x437a0000
        }

        // --- Section 0 / row 0: BGM volume (linear 0..1) ---
        if (indexPath.section == SoundSettingSectionBgmVolume && indexPath.row == 0) {
            _bgmSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _bgmSlider.minimumValue = 0.0f;
            _bgmSlider.maximumValue = 1.0f; // 0x3f800000
            _bgmSlider.value = [UserSettingData bgmVolume];
            _bgmSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _bgmSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _bgmSlider.continuous = NO;
            [_bgmSlider addTarget:self
                           action:@selector(bgmSliderValChanged:)
                 forControlEvents:UIControlEventValueChanged]; // 0x1000
#ifdef ENABLE_PATCHES
            [self wireSliderDragFix:_bgmSlider];
#endif
            [cell addSubview:_bgmSlider];
        }

        // --- Section 1 / row 0: SE volume (0..127) ---
        if (indexPath.section == SoundSettingSectionSeVolume && indexPath.row == 0) {
            _seSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _seSlider.minimumValue = 0.0f;
            _seSlider.maximumValue = 127.0f; // 0x42fe0000
            _seSlider.value = SoundShortToVolume([UserSettingData seVolume]);
            _seSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _seSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _seSlider.continuous = NO;
            [_seSlider addTarget:self
                          action:@selector(seSliderValChanged:)
                forControlEvents:UIControlEventValueChanged];
#ifdef ENABLE_PATCHES
            [self wireSliderDragFix:_seSlider];
#endif
            [cell addSubview:_seSlider];
        }

        // --- Section 2 / row 0: touch-sound volume (0..127) ---
        if (indexPath.section == SoundSettingSectionTouchVolume && indexPath.row == 0) {
            _touchSoundSlider = [[UISlider alloc] initWithFrame:sliderFrame];
            _touchSoundSlider.minimumValue = 0.0f;
            _touchSoundSlider.maximumValue = 127.0f;
            _touchSoundSlider.value = SoundShortToVolume([UserSettingData touchSoundVolume]);
            _touchSoundSlider.minimumValueImage = [UIImage imageNamed:@"volume_small"];
            _touchSoundSlider.maximumValueImage = [UIImage imageNamed:@"volume_big"];
            _touchSoundSlider.continuous = NO;
            [_touchSoundSlider addTarget:self
                                  action:@selector(touchSoundSliderValChanged:)
                        forControlEvents:UIControlEventValueChanged];
#ifdef ENABLE_PATCHES
            [self wireSliderDragFix:_touchSoundSlider];
#endif
            [cell addSubview:_touchSoundSlider];
        }
    }

    // --- Section 3: touch-sound kind picker ---
    if (indexPath.section == SoundSettingSectionTouchPicker) {
        int soundNo = [[_touchSoundArray objectAtIndexedSubscript:indexPath.row] intValue];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = (__bridge NSString *)neSceneManager::normalSoundName(soundNo);
        cell.textLabel.font = [UIFont fontWithName:AppFontName() size:17.0f]; // 0x41880000
        cell.textLabel.backgroundColor = [UIColor clearColor];

        if (!neSceneManager::isPadDisplay()) {
            // iPhone: the selected kind gets black text + a checkmark; others are
            // dark-gray with no accessory.
            if (soundNo == _selectedTouchSoundNo) {
                cell.textLabel.textColor = [UIColor blackColor];
                cell.accessoryType = UITableViewCellAccessoryCheckmark; // 3
            } else {
                cell.textLabel.textColor = [UIColor darkGrayColor];
                cell.accessoryType = UITableViewCellAccessoryNone; // 0
            }
            return cell;
        }

        // iPad: an explicit check image plus a segmented "custom_bt02" background.
        // All frame constants exact by disassembly trace.
        NSString *checkName =
            (soundNo == _selectedTouchSoundNo) ? @"m_sort_check_01" : @"m_sort_check_00";
        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage imageNamed:checkName]];
        CGRect cf = check.frame;
        CGFloat checkX = ([UIDevice currentDevice].systemVersion.floatValue >= 7.0f) ?
                             230.0f :
                             210.0f; // DAT_00082778 / DAT_0008277c (exact)
        // +8.0 y offset: vmov.f32 d16,#0x41000000=8.0 at 0x82518; width/height
        // unchanged (sp[0x50]/sp[0x54] loaded unmodified at 0x82552/0x82556 before
        // setFrame:).
        check.frame = CGRectMake(cf.origin.x + checkX,
                                 cf.origin.y + 8.0f, // 0x41000000
                                 cf.size.width,
                                 cf.size.height);
        for (UIView *sub in [cell.contentView.subviews copy]) {
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
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:bgName]];
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
    UIView *header =
        [[UIView alloc] initWithFrame:CGRectMake(5.0f,
                                                 0.0f,
                                                 320.0f,
                                                 32.0f)]; // 0x40a00000 / 0x43a00000 / 0x42000000
    header.backgroundColor = [UIColor clearColor];

    NSString *title;
    switch (section) {
    case SoundSettingSectionBgmVolume:
        title = @"BGM ボリューム";
        break; // cf_B      (UTF-16)
    case SoundSettingSectionSeVolume:
        title = @"SE ボリューム";
        break; // cf_S      (UTF-16)
    case SoundSettingSectionTouchVolume:
        title = @"タッチサウンド ボリューム";
        break; // cf_0000000 (UTF-16)
    case SoundSettingSectionTouchPicker:
        title = @"タッチサウンド";
        break; // cf_0000000 (UTF-16)
    default:
        title = @"";
        break; // cf_"" (empty)
    }

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5.0f, 0.0f, 320.0f, 32.0f)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont fontWithName:AppFontName() size:14.0f]; // 0x41600000
    label.text = title;
    [header addSubview:label];
    return header;
}

// @ 0x8292c -- constant 32pt headers.
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32.0f; // 0x42000000
}

// @newCode -- The iOS 8 binary let rows use the default 44pt height. Pin it
// explicitly here for modern iOS; combined with the estimatedRowHeight = 0 set in
// viewDidLoad (which disables self-sizing so the cell's contentView fills the cell
// and the sliders stay hit-testable) this restores the original fixed-height rows.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

// @ 0x82934 -- only the touch-sound picker rows respond: switch the selected
// kind (reloading its SE), then preview it at the current touch-sound volume.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AudioManager *audio = [AudioManager sharedManager];
    if (indexPath.section == SoundSettingSectionTouchPicker) {
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
        // Preview the (possibly new) touch SE. NOTE: resourceId/Volume registers
        // are NEON-spilled in the binary -- reconstructed as the loaded touch
        // handle at the touch-sound slider's volume.
        [audio playSe:nil
            resourceId:_touchSoundRscId
                Volume:(float)SoundVolumeToShort(_touchSoundSlider.value)];
    }
}

#ifdef ENABLE_PATCHES
#pragma mark - Nested-scroll drag fix (modern iOS, not in the iOS 8 binary)

// The volume sliders live in cells of this table, which is itself embedded in a
// cell of SettingGameTableViewController's table -- a table inside a table. On
// current iOS the enclosing scroll views' pan-gesture recognisers claim a drag
// before the slider can track it, so the sliders appear frozen (the pop-kun-size
// slider, which sits in a plain view, is unaffected). Delivering content touches
// immediately (delaysContentTouches = NO on both tables) is not enough for the
// nested case, so each slider additionally suspends scrolling on every enclosing
// scroll view while it is being dragged and restores it on release. Scrolling is
// only disabled for the duration of the drag, so the picker rows below stay
// reachable.
- (void)wireSliderDragFix:(UISlider *)slider {
    [slider addTarget:self
                  action:@selector(sliderTouchDown:)
        forControlEvents:UIControlEventTouchDown];
    [slider addTarget:self
                  action:@selector(sliderTouchUp:)
        forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                         UIControlEventTouchCancel];
}

- (void)setEnclosingScrollEnabled:(BOOL)enabled forSlider:(UISlider *)slider {
    for (UIView *view = slider.superview; view != nil; view = view.superview) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            ((UIScrollView *)view).scrollEnabled = enabled;
        }
    }
}

- (void)sliderTouchDown:(UISlider *)slider {
    [self setEnclosingScrollEnabled:NO forSlider:slider];
}

- (void)sliderTouchUp:(UISlider *)slider {
    [self setEnclosingScrollEnabled:YES forSlider:slider];
}
#endif // ENABLE_PATCHES

#pragma mark - Slider actions

// @ 0x82af4 -- live-apply the BGM volume (with and without fade); iPad persists
// it.
- (void)bgmSliderValChanged:(id)sender {
    float v = _bgmSlider.value;
    [[AudioManager sharedManager] setBgmVolume:v];
    [[AudioManager sharedManager] setJustBgmVolume:v];
    if (neSceneManager::isPadDisplay()) {
        [UserSettingData saveBgmVolume:_bgmSlider.value];
    }
}

// @ 0x82bbc -- apply the SE group volume, preview it when non-zero; iPad
// persists it.
- (void)seSliderValChanged:(id)sender {
    short vol = SoundVolumeToShort(_seSlider.value);
    [[AudioManager sharedManager] setSeVolume:vol groupId:1];
    if (vol > 0) {
        // Preview SE (NEON-spilled resourceId/Volume -- reconstructed as the decide
        // SE handle at the SE slider's volume).
        [[AudioManager sharedManager] playSe:nil resourceId:_seRscId Volume:(float)vol];
        if (neSceneManager::isPadDisplay()) {
            [UserSettingData saveSeVolume:SoundVolumeToShort(_seSlider.value)];
        }
    }
}

// @ 0x82cc4 -- preview the touch SE when the volume is non-zero; iPad persists
// it.
- (void)touchSoundSliderValChanged:(id)sender {
    short vol = SoundVolumeToShort(_touchSoundSlider.value);
    if (vol > 0) {
        // Preview touch SE (NEON-spilled resourceId/Volume -- reconstructed as the
        // touch SE handle at the touch-sound slider's volume).
        [[AudioManager sharedManager] playSe:nil resourceId:_touchSoundRscId Volume:(float)vol];
        if (neSceneManager::isPadDisplay()) {
            [UserSettingData saveTouchSoundVolume:SoundVolumeToShort(_touchSoundSlider.value)];
        }
    }
}

// @ 0x82d9c -- kind 0 is always owned; the rest are gated by the unlock
// bitmask.
- (BOOL)isHaveTouchSound:(int)soundNo {
    if (soundNo == 0) {
        return YES;
    }
    return (_touchSoundHaveFlg & (1 << (soundNo & 0xff))) != 0;
}

// @ 0x82dc0 -- play the cancel SE, restore the settings nav bar, and pop self.
- (void)backButtonFunc {
    neEngine::playSystemSe(2); // Ghidra: SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
