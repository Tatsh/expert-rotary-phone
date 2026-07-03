//
//  AcViewerMusicViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade (AC) viewer's
//  song list. Objective-C++ (.mm) because it drives the C++ "ne" engine singletons via
//  neEngineBridge (scene manager pad-display flag, the AC-viewer event-center selection,
//  and the system-SE hooks).
//

#import "AcViewerMusicViewController.h"

#import "AcViewerMusicCell.h"
#import "AcViewerOptionViewController.h"
#import "AcMusicData.h"
#import "DownloadMain.h"
#import "MusicManager.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

@interface AcViewerMusicViewController ()
- (void)handleGesture:(UIPanGestureRecognizer *)recognizer;
- (void)touchedBackButton:(id)sender;
- (void)touchedChangeButton:(id)sender;
- (void)touchedSheetButton:(id)sender event:(UIEvent *)event;
- (NSIndexPath *)indexPathForControlEvent:(UIEvent *)event;
@end

// The genre-category header banner, indexed by AcMusicData.category (clamped 0..23). The
// binary looks these up from the CFString table at PTR_cf_ppc_mlist_header_etc (0x133568);
// a nil source array falls back to "ppc_mlist_header_all".
static NSString *const kCategoryBanner[] = {
    @"ppc_mlist_header_etc", @"ppc_mlist_header_tv",
    @"ppc_mlist_header_p01", @"ppc_mlist_header_p02", @"ppc_mlist_header_p03",
    @"ppc_mlist_header_p04", @"ppc_mlist_header_p05", @"ppc_mlist_header_p06",
    @"ppc_mlist_header_p07", @"ppc_mlist_header_p08", @"ppc_mlist_header_p09",
    @"ppc_mlist_header_p10", @"ppc_mlist_header_p11", @"ppc_mlist_header_p12",
    @"ppc_mlist_header_p13", @"ppc_mlist_header_p14", @"ppc_mlist_header_p15",
    @"ppc_mlist_header_p16", @"ppc_mlist_header_p17", @"ppc_mlist_header_p18",
    @"ppc_mlist_header_p19", @"ppc_mlist_header_p20", @"ppc_mlist_header_p21",
    @"ppc_mlist_header_p22",
};

@implementation AcViewerMusicViewController {
    NSArray *_acMusicDataArray;   // the sorted AcMusicData rows
    UIImage *_genreButton;        // "acv_diff_category00" — genre-order button art
    UIImage *_titleButton;        // "acv_diff_category01" — song-order button art
    UIButton *_changeButton;      // right nav-bar button toggling the sort order
}

@synthesize delegate = _delegate;

// @ 0xcba44 — build the list: a transparent, separator-less UITableView; the category
// header banner; the "friman" backdrop (phone only); a back button; and the right-hand
// order-toggle button. The rows are sorted per UserSettingData.isAcvGenreName.
- (instancetype)initWithData:(NSArray *)acMusicDataArray {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) {
        return nil;
    }
    neSceneManager::shared();
    self.tableView.rowHeight = neSceneManager::isPadDisplay() ? 110.0f : 90.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    // --- Custom header: the genre-category banner of the first listed song ---
    int category = [(AcMusicData *)[acMusicDataArray objectAtIndexedSubscript:0] category];
    NSString *bannerName = (acMusicDataArray == nil) ? @"ppc_mlist_header_all"
                                                     : kCategoryBanner[(short)category];
    UIImage *bannerImg = [UIImage imageNamed:bannerName];
    UIImageView *bannerView = [[UIImageView alloc] initWithImage:bannerImg];
    bannerView.frame = CGRectMake(0.0f, 17.0f, bannerImg.size.width, bannerImg.size.height);

    // Header height = banner height + (17 top gap from bannerView.origin.y) + 12 bottom gap;
    // the binary derives it from the banner image size and bannerView frame via vector adds.
    UIView *headerView = [[UIView alloc] init];
    headerView.frame = CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height + 29.0f);
    [headerView addSubview:bannerView];
    self.tableView.tableHeaderView = headerView;

    // "friman" backdrop behind the whole list (phone only).
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *frimanImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *frimanView = [[UIImageView alloc] initWithImage:frimanImg];
        frimanView.frame = CGRectMake(0.0f, 0.0f, frimanImg.size.width, frimanImg.size.height);
        self.tableView.backgroundView = frimanView;
    }

    // Back button (skipped on iPad when this screen is already the nav top view controller).
    neSceneManager::shared();
    BOOL skipBackButton = neSceneManager::isPadDisplay()
                          && self.navigationController.topViewController == self;
    if (!skipBackButton) {
        neSceneManager::shared();
        NSString *backName = neSceneManager::isPadDisplay() ? @"pl_checker_return" : @"navi_btn_back";
        UIImage *backImg = [UIImage imageNamed:backName];
        UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(touchedBackButton:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        if (neSceneManager::isPadDisplay()) {
            self.navigationItem.hidesBackButton = YES;
        }
    }

    // --- Right-hand order-toggle button + the initial sort ---
    _genreButton = [UIImage imageNamed:@"acv_diff_category00"];
    _titleButton = [UIImage imageNamed:@"acv_diff_category01"];
    _changeButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _genreButton.size.width, _genreButton.size.height)];

    NSArray *source = (acMusicDataArray == nil) ? [[MusicManager getInstance] getAcMusicDataArray]
                                                : acMusicDataArray;
    UIImage *changeImg;
    if (![UserSettingData isAcvGenreName]) {
        _acMusicDataArray = [source sortedArrayUsingSelector:@selector(compareMusicNameCustom:)];
        changeImg = _titleButton;
    } else {
        _acMusicDataArray = [source sortedArrayUsingSelector:@selector(compareGenreNameCustom:)];
        changeImg = _genreButton;
    }
    [_changeButton setBackgroundImage:changeImg forState:UIControlStateNormal];
    [_changeButton addTarget:self action:@selector(touchedChangeButton:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_changeButton];
    return self;
}

// @ 0xcc218 — drop this screen as DownloadMain's visitor delegate if it still holds it; the
// UIImage / UIButton / NSArray ivars are released automatically under ARC.
- (void)dealloc {
    DownloadMain *dl = [DownloadMain getInstance];
    if ((id)dl.delegateGetVisitor == self) {
        dl.delegateGetVisitor = nil;
    }
}

// @ 0xcc2ec — after loading, poke the scene manager (populates the pad-display flag).
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
}

// @ 0xcc31c — treat a rightward pan (translation.x > 80) as a back-button press.
- (void)handleGesture:(UIPanGestureRecognizer *)recognizer {
    if (recognizer == nil) {
        return;
    }
    CGPoint t = [recognizer translationInView:self.view];
    if (t.x > 80.0f) {
        [self touchedBackButton:nil];
    }
}

// @ 0xcc388 — super only.
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xcc3b4
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xcc3b8 — one row per listed song.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_acMusicDataArray != nil) ? (NSInteger)_acMusicDataArray.count : 0;
}

// @ 0xcc3e0 — one AcViewerMusicCell per song (reused by "Cell%ld_%ld"); on first build wire
// the four difficulty buttons to touchedSheetButton:event:, then bind the row's song.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    AcViewerMusicCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[AcViewerMusicCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        [cell.easyBtn addTarget:self action:@selector(touchedSheetButton:event:) forControlEvents:UIControlEventTouchUpInside];
        [cell.normalBtn addTarget:self action:@selector(touchedSheetButton:event:) forControlEvents:UIControlEventTouchUpInside];
        [cell.hyperBtn addTarget:self action:@selector(touchedSheetButton:event:) forControlEvents:UIControlEventTouchUpInside];
        [cell.exBtn addTarget:self action:@selector(touchedSheetButton:event:) forControlEvents:UIControlEventTouchUpInside];
    }
    [cell setData:[_acMusicDataArray objectAtIndexedSubscript:indexPath.row]];
    return cell;
}

// @ 0xcc588 — no section headers.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

#pragma mark - Actions

// @ 0xcc58c — BACK: only when this screen is the nav top VC; play the cancel SE, restore the
// category nav-bar art and pop (animated on phone).
- (void)touchedBackButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_category_navbar"]
                                                 forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:!neSceneManager::isPadDisplay()];
}

// @ 0xcc664 — toggle genre/song-name ordering: play the cancel SE, flip the stored mode,
// re-sort the rows, swap the toggle button art and reload.
- (void)touchedChangeButton:(id)sender {
    neEngine::playSystemSe(2);
    BOOL wasGenreName = [UserSettingData isAcvGenreName];
    [UserSettingData saveIsAcvGenreName:!wasGenreName];
    NSArray *previous = _acMusicDataArray;
    if (!wasGenreName) {
        _acMusicDataArray = [previous sortedArrayUsingSelector:@selector(compareGenreNameCustom:)];
        [_changeButton setBackgroundImage:_genreButton forState:UIControlStateNormal];
    } else {
        _acMusicDataArray = [previous sortedArrayUsingSelector:@selector(compareMusicNameCustom:)];
        [_changeButton setBackgroundImage:_titleButton forState:UIControlStateNormal];
    }
    [self.tableView reloadData];
}

// @ 0xcc7ac — the table index path under the touch that raised `event`.
- (NSIndexPath *)indexPathForControlEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    UITableView *tableView = self.tableView;
    CGPoint point = (touch != nil) ? [touch locationInView:tableView] : CGPointZero;
    return [self.tableView indexPathForRowAtPoint:point];
}

// @ 0xcc82c — a difficulty button was tapped: only when this screen is the nav top VC; map
// the button tag (100..103) to a difficulty (0..3), seed the AC-viewer's current selection
// (music id / difficulty), swap the nav-bar to the option art, push the option screen
// (forwarding the delegate on iPad) and play the decide SE.
- (void)touchedSheetButton:(id)sender event:(UIEvent *)event {
    if (self.navigationController.topViewController != self) {
        return;
    }
    // Button tags 100/101/102/103 -> difficulty 0/1/2/3 (Ghidra table @ 0x12fa90); any other
    // tag falls back to 1.
    static const int kDifficultyForTag[] = {0, 1, 2, 3};
    NSInteger tag = [sender tag];
    int difficulty = ((NSUInteger)(tag - 100) < 4) ? kDifficultyForTag[tag - 100] : 1;

    NSIndexPath *indexPath = [self indexPathForControlEvent:event];
    AcMusicData *data = [_acMusicDataArray objectAtIndexedSubscript:indexPath.row];
    neAppEventCenter::shared();
    neAppEventCenter::setAcViewerSelection(data.acMusicId, difficulty);

    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"acv_option_navbar"]
                                                 forBarMetrics:UIBarMetricsDefault];
    AcViewerOptionViewController *option = [[AcViewerOptionViewController alloc] init];
    BOOL animated = !neSceneManager::isPadDisplay();
    if (neSceneManager::isPadDisplay()) {
        option.delegate = self.delegate;
    }
    [self.navigationController pushViewController:option animated:animated];
    neSceneManager::shared();
    neEngine::playSystemSe(1);
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
