//
//  AcViewerHidSudViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. One of the
//  four arcade (AC) viewer per-option detail screens pushed by
//  AcViewerOptionViewController. This one edits HID-SUD (four values: OFF,
//  HIDDEN, SUDDEN, HID-SUD). Objective-C++
//  (.mm) because it drives the C++ "ne" engine singletons via neEngineBridge
//  (the scene manager pad-display flag, the AC-viewer event-center selection
//  that seeds the header, and the system-SE hooks).
//

#import "AcViewerHidSudViewController.h"

#import "AcMusicData.h"
#import "AcViewerDetailCell.h"
#import "AppFont.h"
#import "MusicManager.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

@interface AcViewerHidSudViewController ()
- (void)touchedBackButton:(id)sender;
@end

// One header caption label (song title / BPM); the binary builds both inline
// with an identical style (48/255 grey text, white when highlighted, DFSoGei
// font, auto-shrink).
static UILabel *AcvMakeHeaderLabel(CGFloat fontSize, NSTextAlignment alignment, CGRect frame) {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.textColor = [UIColor colorWithRed:48.0f / 255.0f
                                    green:48.0f / 255.0f
                                     blue:48.0f / 255.0f
                                    alpha:1.0f];
    lbl.highlightedTextColor = [UIColor whiteColor];
    lbl.font = [UIFont fontWithName:AppFontName() size:fontSize];
    lbl.textAlignment = alignment;
    lbl.adjustsFontSizeToFitWidth = YES;
    [lbl setMinimumScaleFactor:10.0f]; // raw 0x41200000 (legacy minimum-font-size
                                       // value)
    lbl.frame = frame;
    return lbl;
}

@implementation AcViewerHidSudViewController

// @ 0x1adf4 — build the list: a transparent, separator-less UITableView; a back
// button; the "friman" backdrop (phone only); and the shared custom header
// (song banner, difficulty banner, title/genre and BPM labels) built from the
// AC-viewer's current event-center selection.
// @complete
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) { // Ghidra: initWithStyle:1
        return nil;
    }
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    // Back button.
    NSString *backName = neSceneManager::isPadDisplay() ? @"pl_checker_return" : @"navi_btn_back";
    UIImage *backImg = [UIImage imageNamed:backName];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(touchedBackButton:)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    if (neSceneManager::isPadDisplay()) {
        self.navigationItem.hidesBackButton = YES;
    }

    // "friman" backdrop behind the whole list (phone only).
    if (!neSceneManager::isPadDisplay()) {
        UIImage *frimanImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *frimanView = [[UIImageView alloc] initWithImage:frimanImg];
        frimanView.frame = CGRectMake(0.0f, 0.0f, frimanImg.size.width, frimanImg.size.height);
        self.tableView.backgroundView = frimanView;
    }

    // --- Custom table header: song banner, difficulty banner, title and BPM ---
    neAppEventCenter::shared(); // force the event center to init before the AC
                                // globals
    int musicId = neAppEventCenter::acViewerMusicId();
    int difficulty = neAppEventCenter::acViewerDifficulty();
    AcMusicData *data = [[MusicManager getInstance] getAcMusicData:musicId];

    UIImage *bannerImg = [UIImage imageNamed:@"acv_custom_banner"];
    UIImageView *bannerView = [[UIImageView alloc] initWithImage:bannerImg];
    bannerView.frame = CGRectMake(0.0f, 17.0f, bannerImg.size.width, bannerImg.size.height);

    // Difficulty banner (index 0..3). NB: the binary's asset name for "hyper" is
    // misspelled "heper".
    static NSString *const kDiffBanner[] = {
        @"acv_custom_easy", @"acv_custom_normal", @"acv_custom_heper", @"acv_custom_ex"};
    UIImage *diffImg = [UIImage imageNamed:kDiffBanner[difficulty]];
    UIImageView *diffView = [[UIImageView alloc] initWithImage:diffImg];
    diffView.frame = CGRectMake(22.0f, 46.0f, diffImg.size.width, diffImg.size.height);

    UILabel *titleLbl =
        AcvMakeHeaderLabel(15.0f, NSTextAlignmentCenter, CGRectMake(20.0f, 26.0f, 280.0f, 18.0f));
    titleLbl.text = [UserSettingData isAcvGenreName] ? [data genreName] : [data musicName];

    NSString *bpm = nil;
    switch (difficulty) {
    case 0:
        bpm = [data bpmEasy];
        break;
    case 1:
        bpm = [data bpmNormal];
        break;
    case 2:
        bpm = [data bpmHyper];
        break;
    case 3:
        bpm = [data bpmEx];
        break;
    default:
        break;
    }
    UILabel *bpmLbl =
        AcvMakeHeaderLabel(14.0f, NSTextAlignmentRight, CGRectMake(195.0f, 46.0f, 100.0f, 18.0f));
    if (bpm != nil) {
        // Format CFString @ 0x1029a7 = "BPM %@" (a space after "BPM", not a colon).
        bpmLbl.text = [NSString stringWithFormat:@"BPM %@", bpm];
    }

    // Header container: the banner plus a 17 pt gap above and below it
    // (banner-height + 34; the binary derives it from the banner/difficulty image
    // sizes via vector adds).
    UIView *headerView = [[UIView alloc] init];
    headerView.frame = CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height + 34.0f);
    [headerView addSubview:bannerView];
    [headerView addSubview:titleLbl];
    [headerView addSubview:bpmLbl];
    [headerView addSubview:diffView];
    [self.tableView setTableHeaderView:headerView];

    return self;
}

// @ 0x1b6c8 — after loading, poke the scene manager (populates the pad-display
// flag).
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0x1b6f8
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x1b6fc — four HID-SUD values in section 0.
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? 4 : 0;
}

// @ 0x1b708 — one AcViewerDetailCell per value (reused by "Cell%ld_%ld"), bound
// to the HID-SUD option kind (2) and the row's value label.
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // The format string is the shared CFString @ 0x1029ae = "Cell%ld-%ld" (byte
    // 0x2d is a hyphen, not an underscore).
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    AcViewerDetailCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[AcViewerDetailCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:identifier];
    }
    if (indexPath.section == 0) {
        static NSString *const kHidSud[] = {@"OFF", @"HIDDEN", @"SUDDEN", @"HID-SUD"};
        cell.optionName = kHidSud[indexPath.row];
        cell.optionKind = 2;
        [cell setData:(int)indexPath.row];
    }
    return cell;
}

// @ 0x1b838 — no section headers.
// @complete
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0x1b83c — no accessory (private UITableView delegate hook).
// @complete
- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView
         accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellAccessoryNone;
}

// @ 0x1b840 — a new value: store it, refresh, play the decide SE and pop back
// to the option list. Re-selecting the current value does nothing.
// @complete
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) {
        return;
    }
    if ([UserSettingData acvHidSud] == indexPath.row) {
        return;
    }
    [UserSettingData saveAcvHidSud:(int)indexPath.row];
    [self.tableView reloadData];
    neEngine::playSystemSe(1);
    [self touchedBackButton:nil];
}

#pragma mark - Actions

// @ 0x1b910 — BACK: (on a real tap) play the cancel SE, refresh the option list
// behind this screen, restore the option-list nav-bar background and pop. A nil
// sender (the post-select auto-pop) skips the cancel SE.
// @complete
- (void)touchedBackButton:(id)sender {
    if (sender != nil) {
        neEngine::playSystemSe(2);
    }
    NSArray *vcs = self.navigationController.viewControllers;
    UITableViewController *prev = (UITableViewController *)[vcs objectAtIndex:vcs.count - 2];
    [prev.tableView reloadData];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"acv_option_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:!neSceneManager::isPadDisplay()];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
