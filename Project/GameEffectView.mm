//
//  GameEffectView.mm
//  pop'n rhythmin
//
//  See GameEffectView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle: @ 0x72d4c, dealloc @ 0x72eb0, viewDidLoad @
//  0x72edc, didReceiveMemoryWarning @ 0x730f4, numberOfSectionsInTableView: @
//  0x73120, tableView:numberOfRowsInSection: @ 0x73124,
//  tableView:cellForRowAtIndexPath: @ 0x73128,
//  tableView:didSelectRowAtIndexPath: @ 0x73518,
//  tableView:viewForHeaderInSection:
//  @ 0x735dc, tableView:heightForHeaderInSection: @ 0x737b0, backButtonFunc @
//  0x737d8). Objective-C++ for the C++ engine bridge (neSceneManager:: /
//  neEngine::).
//
//  Byte-decoded constants (float hex -> decimal): phone row height 61.0
//  (0x42740000), font 15.0 (0x41700000, cells) / 16.0 phone & 14.0 pad headers,
//  header container 320 x 61 phone (x 15) / 320 x 32 pad (x 5), header
//  height 61.0 phone / 32.0 pad. UIControlEventTouchUpInside = 0x40. reloadRows
//  animation 5 = UITableViewRowAnimationNone. Checkmark placement offsets:
//  phone (+245, +15); pad iOS>=7 (+230, +8) / pre-iOS7
//  (+210, +8) — recovered from DAT_00073514/0c/10; see NEON note below.
//
//  HONESTY NOTE — verbatim label texts. The cell/ header UILabel text is set
//  from deduplicated CFString constants that, when byte-decoded, read as
//  strings unrelated to this screen: row-0 cell text is the UTF-16LE
//  "フレンドを解除します" (@ 0x12ce90, flags 0x7d0, len 10), row-1 cell text is
//  the ASCII "custom_bg" (@ 0x10b242), and the section-header label text is the
//  ASCII "Sheet" (@ 0x108f25). These are byte-exact from the binary and appear
//  to be leftover / linker-merged placeholder literals — the meaningful on/off
//  state is conveyed by the m_sort_check checkmark image. Reproduced verbatim
//  rather than "corrected".
//
//  Checkmark origin: imageView.frame starts at (0,0) after -initWithImage:;
//  constant offsets are added via NEON vadd. All offsets confirmed exact by
//  disassembly and DAT_ memory reads (DAT_00073514/0c/10); no best-effort
//  values remain.
//

#import "GameEffectView.h"

#import "AppFont.h"         // AppFontName (label typeface)
#import "AudioManager.h"    // -[AudioManager sharedManager], -setSeVolume:groupId:
#import "UserSettingData.h" // isEffectOn / isLongNotesEffectOn (+ save…) toggles
#import "neEngineBridge.h"  // neSceneManager::isPadDisplay, neEngine::playSystemSe

@implementation GameEffectView

// @ 0x72d4c — grouped-table styling. On phone the whole table gets a
// "back_bg_st" patterned background and 61 px rows; on iPad the table is made
// borderless and clear.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        if (!neSceneManager::isPadDisplay()) {
            self.tableView.rowHeight = 61.0f; // 0x42740000
            self.tableView.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
        } else {
            self.tableView.backgroundView = nil;
            self.tableView.separatorColor = [UIColor clearColor];
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            self.tableView.backgroundColor = [UIColor clearColor];
        }
    }
    return self;
}

// dealloc @ 0x72eb0 — ARC-omitted (chained to super only; class reports 0
// ivars).

// @ 0x72edc — phone: tile the table with "popkun_size_bg" and install a custom
// "navi_btn_back" back button (targets -backButtonFunc). iPad: just hide the
// back button.
- (void)viewDidLoad {
    [super viewDidLoad];

    if (!neSceneManager::isPadDisplay()) {
        self.tableView.backgroundColor =
            [UIColor colorWithPatternImage:[UIImage imageNamed:@"popkun_size_bg"]];
    }

    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
        CGSize backSize = backImage ? backImage.size : CGSizeZero;
        UIButton *backButton =
            [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backSize.width, backSize.height)];
        [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(backButtonFunc)
             forControlEvents:UIControlEventTouchUpInside]; // 0x40
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];
    } else {
        [self.navigationItem setHidesBackButton:YES];
    }
}

// @ 0x730f4
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table

// @ 0x73120
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x73124
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2; // row 0 = isEffectOn, row 1 = isLongNotesEffectOn
}

// @ 0x73128 — one toggle row: a text label (see HONESTY NOTE), an on/off
// checkmark, and (iPad only) a "custom_bt02" row background. Reuse id is
// "Cell<section>-<row>".
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell != nil) {
        return cell;
    }

    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:cellId];
    cell.textLabel.font = [UIFont fontWithName:AppFontName() size:15.0f]; // 0x41700000
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Verbatim leftover/placeholder label texts (see HONESTY NOTE in the file
    // header).
    if (indexPath.row == 0) {
        cell.textLabel.text = @"フレンドを解除します"; // UTF-16LE @ 0x12ce90
    } else {
        cell.textLabel.text = @"custom_bg"; // ASCII @ 0x10b242
    }

    // iPad only: a per-row background art (top row vs. under row).
    if (neSceneManager::isPadDisplay()) {
        NSString *bgName = (indexPath.row == 0) ? @"custom_bt02_top" : @"custom_bt02_under";
        UIImageView *bg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:bgName]];
        cell.backgroundView = bg;
    }

    // On/off checkmark for this row's stored flag.
    BOOL on =
        (indexPath.row == 0) ? [UserSettingData isEffectOn] : [UserSettingData isLongNotesEffectOn];
    UIImage *checkImage = [UIImage imageNamed:(on ? @"m_sort_check_01" : @"m_sort_check_00")];
    UIImageView *checkView = [[UIImageView alloc] initWithImage:checkImage];

    // Origin starts at (0,0,w,h); exact constant offsets from DAT_00073514/0c/10
    // + vmov.f32 immediates. Phone: (+245, +15). iPad: (+230, +8) iOS 7+, (+210,
    // +8) pre-7.
    CGRect f = checkView ? checkView.frame : CGRectZero;
    if (!neSceneManager::isPadDisplay()) {
        f.origin.x += 245.0f; // 0x43750000
        f.origin.y += 15.0f;  // 0x41700000
    } else {
        CGFloat ver = UIDevice.currentDevice.systemVersion.floatValue;
        f.origin.x += (ver < 7.0f) ? 210.0f : 230.0f; // 0x43520000 / 0x43660000
        f.origin.y += 8.0f;                           // 0x41000000
    }
    checkView.frame = f;
    [cell.contentView addSubview:checkView];

    return cell;
}

// @ 0x73518 — play the decide SE, flip the tapped row's stored flag, then
// reload the row so its checkmark updates.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    neEngine::playSystemSe(1); // decide SE (Ghidra: SysSePlayIntoSlot(1))

    if (indexPath.row == 0) {
        [UserSettingData saveIsEffectOn:![UserSettingData isEffectOn]];
    } else {
        [UserSettingData saveIsLongNotesEffectOn:![UserSettingData isLongNotesEffectOn]];
    }

    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                     withRowAnimation:UITableViewRowAnimationNone]; // animation 5
}

// @ 0x735dc — section header: a clear container UIView holding a centred label.
// The label text is the verbatim "Sheet" leftover constant (see HONESTY NOTE).
// Phone uses a 320x61 container at x=15 with a 16 pt font; iPad a 320x32
// container at x=5 with 14 pt.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGRect frame;
    CGFloat fontSize;
    if (!neSceneManager::isPadDisplay()) {
        frame = CGRectMake(15.0f, 0.0f, 320.0f,
                           61.0f); // 0x41700000 / 0x43a00000 / 0x42740000
        fontSize = 16.0f;          // 0x41800000
    } else {
        frame = CGRectMake(5.0f, 0.0f, 320.0f,
                           32.0f); // 0x40a00000 / 0x43a00000 / 0x42000000
        fontSize = 14.0f;          // 0x41600000
    }

    UIView *header = [[UIView alloc] initWithFrame:frame];
    header.backgroundColor = [UIColor clearColor];

    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.font = [UIFont fontWithName:AppFontName() size:fontSize];
    label.text = @"Sheet"; // ASCII @ 0x108f25 (verbatim leftover constant)
    label.backgroundColor = [UIColor clearColor];
    [header addSubview:label];

    return header;
}

// @ 0x737b0 — 61 pt header on phone, 32 pt on iPad.
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return neSceneManager::isPadDisplay() ? 32.0f : 61.0f; // 0x42000000 / 0x42740000
}

// @ 0x737d8 — back-button action: play the cancel SE, restore the
// "settings_navbar" bar background, pop self, then re-apply the stored SE
// volume.
- (void)backButtonFunc {
    neEngine::playSystemSe(2); // cancel SE (Ghidra: SysSePlayIntoSlot(2))

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];

    [[AudioManager sharedManager] setSeVolume:[UserSettingData seVolume] groupId:1];
}

@end
