//
//  FriendListViewController.mm
//  pop'n rhythmin
//
//  See FriendListViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (initWithStyle: @ 0xb0774, dealloc @ 0xb1064,
//  viewDidLoad @ 0xb1144, didReceiveMemoryWarning
//  @ 0xb11e8, numberOfSectionsInTableView: @ 0xb1214,
//  tableView:numberOfRowsInSection: @ 0xb1218, tableView:cellForRowAtIndexPath:
//  @ 0xb1254, tableView:titleForHeaderInSection: @ 0xb13b0,
//  tableView:didSelectRowAtIndexPath: @ 0xb13b4, downloadMainFinished: @
//  0xb15ec, backButtonFunc @ 0xb1980, sortButtonFunc @ 0xb1a44). Objective-C++
//  for neSceneManager and SE.
//

#import "FriendListViewController.h"

#import "AppDelegate.h"                    // managedObjectContext (score aggregation)
#import "AppFont.h"                        // (shared)
#import "CommonAlertView.h"                // error alert
#import "DownloadMain.h"                   // FriendListData, DownloadMain, friendListArray
#import "FriendListCell.h"                 // row renderer
#import "FriendListDetail.h"               // tap-row overlay
#import "Game/Data/Save/ScoreData+Store.h" // +getAllScoreData:
#import "Game/Data/Save/UserSettingData.h" // isBestScoreSort / playerName / charaId
#import "neEngineBridge.h"                 // neSceneManager / readScoreDataFields

// Aggregated tallies over every saved ScoreData row, in the exact layout
// FUN_00029644 fills (0x74 bytes). The trailing three arrays mirror the tail of
// FriendListData ([3[7i]][3i][3i]), so downloadMainFinished: can copy them
// across.
typedef struct {
    int totalScore;   // +0x00 sum of every positive difficulty score
    int bestScore;    // +0x04 highest single difficulty score
    int rank[3][7];   // +0x08 per-difficulty rank tally, indexed by rank 0..6
    int fullCombo[3]; // +0x5c per-difficulty full-combo count
    int perfect[3];   // +0x68 per-difficulty perfect count
} ScoreStats;

// Ghidra: aggregateScoreStats (FUN_00029644) @ 0x29644 — walk every saved
// ScoreData row (all three difficulties each) and accumulate the local player's
// own totals into `out`. The binary's first argument is the neAppEventCenter
// singleton pointer, which the function never touches (vestigial); it is dropped
// here.
// Verified against disassembly: memset(out, 0, 0x74) (NEON zero-splat +0..+0x70);
// fast-enumerate [ScoreData getAllScoreData:managedObjectContext]; per row loop
// difficulty 0..2 calling readScoreDataFields (FUN_00029438) with the row in the
// recDup slot; totalScore += score when score > 0; bestScore = max; rank tally at
// +8 + difficulty*0x1c + rank*4 incremented when (unsigned)rank < 7; fullCombo[d]
// (+0x5c) and perfect[d] (+0x68) incremented on their flags. The (unused) `rec`
// slot holds a don't-care value at this call site in the binary (difficulty in
// r0); readScoreDataFields reads only recDup, so the row is passed there and the
// vestigial slot value is immaterial.
// @complete
static void aggregateScoreStats(ScoreStats *out) {
    if (out == nullptr) {
        return;
    }
    memset(out, 0, sizeof(*out));

    NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
    NSArray *allScores = [ScoreData getAllScoreData:ctx];
    for (ScoreData *row in allScores) {
        for (int difficulty = 0; difficulty < 3; difficulty++) {
            int score = 0;
            short rank = 0;
            int playCnt = 0;
            bool fullCombo = false, perfect = false;
            readScoreDataFields(
                row, &score, &rank, &playCnt, &fullCombo, &perfect, row, difficulty);

            if (score > 0) {
                out->totalScore += score;
            }
            if (score > out->bestScore) {
                out->bestScore = score;
            }
            if (static_cast<unsigned>(rank) < 7) {
                out->rank[difficulty][rank] += 1;
            }
            if (fullCombo) {
                out->fullCombo[difficulty] += 1;
            }
            if (perfect) {
                out->perfect[difficulty] += 1;
            }
        }
    }
}

@implementation FriendListViewController {
    UIViewController *_dummyView;  // loading overlay VC, @164
    UIButton *_sortButton;         // total/best sort toggle, @168
    UIImageView *_lonelyImageView; // "no friends" placeholder, @172
    FriendListDetail *_detailView; // current tap overlay, @176
    BOOL _isBestScoreSort;         // sort mode, @180
    NSArray *_frinedDataArray;     // NSValue-wrapped FriendListData rows (binary
                                   // spelling), @184
}

// @ 0xb0774 — grouped table styling, header spacer, loading overlay, back +
// sort bar buttons, and the "no friends" placeholder image.
// @complete
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    _isBestScoreSort = [UserSettingData isBestScoreSort];
    if (self == nil) {
        return self;
    }

    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGRect viewFrame = self.view.frame;

    self.tableView.rowHeight = isPad ? 74.0f : 54.0f; // DAT_000b1060 / DAT_000b105c
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    // Clear header spacer (device/OS-dependent height).
    CGFloat headerH;
    if (!isPad) {
        headerH = 20.0f;
    } else {
        headerH = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? 47.0f : 55.0f;
    }
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewFrame.size.width, headerH)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // Phone: a friman_bg backdrop behind the table. iPad: transparent.
    if (!isPad) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [bgView setFrame:CGRectMake(0, 0, bg.size.width, bg.size.height)];
        self.tableView.backgroundView = bgView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Loading overlay + spinner over the table.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = viewFrame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    _dummyView.view.hidden = YES;
    [self.view addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    if (!isPad) {
        // Ghidra @ 0xb0c48: the y coordinate truncates height*0.5 to an int
        // (vcvt.s32.f32) before subtracting 10; the x coordinate is not
        // truncated.
        spinner.center =
            CGPointMake(viewFrame.size.width * 0.5f, (int)(viewFrame.size.height * 0.5f) - 10);
    } else {
        // Pad: fixed x=214, y still tracks the (truncated) view mid-height minus
        // 10 (0x43560000 = 214; not the lonely image's 160/328). Ghidra @
        // 0xb0c12 truncates the same way as the phone path.
        spinner.center = CGPointMake(214.0f, (int)(viewFrame.size.height * 0.5f) - 10);
    }
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];

    // Back button (phone only).
    if (!isPad) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }

    // Sort toggle (total-score vs. best-score art).
    UIImage *sortImg =
        [UIImage imageNamed:(_isBestScoreSort ? @"frilis_btn_bssort" : @"frilis_btn_tssort")];
    _sortButton =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, sortImg.size.width, sortImg.size.height)];
    [_sortButton setBackgroundImage:sortImg forState:UIControlStateNormal];
    [_sortButton addTarget:self
                    action:@selector(sortButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_sortButton];

    // "No friends yet" placeholder, centred.
    UIImage *lonely = [UIImage imageNamed:@"frilis_mes_empty"];
    _lonelyImageView = [[UIImageView alloc] initWithImage:lonely];
    [_lonelyImageView setFrame:CGRectMake(0, 0, lonely.size.width, lonely.size.height)];
    if (!isPad) {
        _lonelyImageView.center =
            CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f);
    } else {
        _lonelyImageView.center = CGPointMake(160.0f, 328.0f);
    }

    return self;
}

// @ 0xb1144
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
    DownloadMain *dl = [DownloadMain getInstance];
    [dl setDelegateGetFriendList:self];
    [dl startGetFriendListHttp];
}

// @ 0xb11e8
// @complete
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xb1214
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xb1218 — rows only once there is more than the self row.
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_frinedDataArray != nil) {
        NSUInteger count = [_frinedDataArray count];
        if (count > 1) {
            return count;
        }
    }
    return 0;
}

// @ 0xb1254
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // The reuse identifier uses hyphen separators (CFString @ 0x10af18:
    // "Cell%d-%d"), not underscores.
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%d-%d", (int)indexPath.section, (int)indexPath.row];
    FriendListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FriendListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier];
        cell.backgroundColor = [UIColor redColor];
    }
    [cell setFriendData:_frinedDataArray[indexPath.row]
                   rank:(int)indexPath.row
        isBestScoreSort:_isBestScoreSort];
    return cell;
}

// @ 0xb13b0
// @complete
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xb13b4 — raise the friend detail overlay for the tapped row (guarded
// against re-entry while one is already up).
// @complete
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *root = neSceneManager::rootViewController();
    if (indexPath.section != 0) {
        return;
    }
    if (_detailView != nil && [_detailView isEnabled]) {
        return;
    }
    neEngine::playSystemSe(1);

    const BOOL isPad = neSceneManager::isPadDisplay();
    CGRect frame;
    UIView *parent;
    if (!isPad) {
        parent = self.navigationController.view.superview;
        frame = parent.frame;
    } else {
        parent = root.view;
        frame = parent.frame;
    }

    _detailView = [[FriendListDetail alloc] initWithFrame:frame
                                               friendData:_frinedDataArray[indexPath.row]];
    [parent addSubview:_detailView];
    [_detailView startOpenAnimation];
}

// @ 0xb1980 — restore the hub nav bar art and pop (blocked while a detail
// overlay is up).
// @complete
- (void)backButtonFunc {
    if (_detailView != nil && [_detailView isEnabled]) {
        return;
    }
    neEngine::playSystemSe(2);
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xb1a44 — flip the sort mode, persist it, re-sort + reload, and swap the
// button art.
// @complete
- (void)sortButtonFunc {
    if (_frinedDataArray == nil) {
        return;
    }
    neEngine::playSystemSe(2);
    _isBestScoreSort = !_isBestScoreSort;
    [UserSettingData saveIsBestScoreSort:_isBestScoreSort];

    _frinedDataArray = [self sortedRows:_frinedDataArray best:_isBestScoreSort];
    [self.tableView reloadData];

    if ([_frinedDataArray count] > 1) {
        self.tableView.scrollEnabled = YES;
    } else {
        [self.view addSubview:_lonelyImageView];
        self.tableView.scrollEnabled = NO;
    }

    [_sortButton setBackgroundImage:[UIImage imageNamed:(_isBestScoreSort ? @"frilis_btn_bssort" :
                                                                            @"frilis_btn_tssort")]
                           forState:UIControlStateNormal];
}

// @ 0xb15ec — friend list arrived: on failure alert; on success prepend the
// local player as the self row, sort, reload, and show/hide the placeholder +
// scrolling.
// Verified against disassembly: on failure show a CommonAlertView and return; on
// success release the previous _frinedDataArray, mutableCopy friendListArray, then
// build the self row. neAppEventCenter::shared() (@ 0xb16b2) is called only for
// its (discarded) side effect and its result is unused, so it is omitted here;
// aggregateScoreStats (FUN_00029644 @ 0xb16c4) fills the local player's own
// tallies. The self-row copy loop (@ 0xb1708..0xb173e) sets totalScore/bestScore,
// copies the first 4 rank slots of each difficulty (a 16-byte NEON move per row,
// with the trailing 3 slots left zero exactly as the binary does), stores
// perfect[d] verbatim, and stores fullComboOnly[d] = max(fullCombo[d] -
// perfect[d], 0). The NSValue boxing (objCType
// "{FriendListData=@@siii[3[7i]][3i][3i]}"), sortedArrayUsingFunction (total/best
// per _isBestScoreSort), reload, and placeholder/scroll toggles all match.
// @complete
- (void)downloadMainFinished:(NSNumber *)result {
    _dummyView.view.hidden = YES;

    if (![result boolValue]) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                           message:@"通信に失敗しました。\n電波状態"
                                                   @"の良い場所でやり直して下さい。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
        return;
    }

    _frinedDataArray = nil;

    NSMutableArray *rows = [[[DownloadMain getInstance] friendListArray] mutableCopy];

    // Aggregate the local player's own clear stats across every saved chart, then
    // prepend them as the self row (nil playerId marks "you").
    ScoreStats stats;
    aggregateScoreStats(&stats);

    FriendListData me;
    memset(&me, 0, sizeof(me));
    me.playerId = nil;
    me.name = [UserSettingData playerName];
    me.charaId = [UserSettingData charaId];
    me.totalScore = stats.totalScore;
    me.bestScore = stats.bestScore;
    for (int d = 0; d < 3; d++) {
        // The binary copies only the first four rank slots of each difficulty (a
        // single 16-byte move per row); the trailing three stay zero.
        for (int r = 0; r < 4; r++) {
            me.rank[d][r] = stats.rank[d][r];
        }
        const int fullComboOnly = stats.fullCombo[d] - stats.perfect[d];
        me.fullComboOnly[d] = (fullComboOnly > 0) ? fullComboOnly : 0;
        me.perfect[d] = stats.perfect[d];
    }
    [rows addObject:[NSValue value:&me withObjCType:"{FriendListData=@@siii[3[7i]][3i][3i]}"]];

    _frinedDataArray = [self sortedRows:rows best:_isBestScoreSort];

    [self.tableView reloadData];

    if ([_frinedDataArray count] < 2) {
        [self.view addSubview:_lonelyImageView];
        self.tableView.scrollEnabled = NO;
    } else {
        self.tableView.scrollEnabled = YES;
    }
}

// Modern stand-in for the binary's sortedArrayUsingFunction: (FUN_000b1934
// total / FUN_000b18e8 best): rank by total- or best-score, descending.
// Verified against both comparators: each -getValue: on a and b, compares the
// total-score field (+0xc, FUN_000b1934) or the best-score field (+0x10,
// FUN_000b18e8), returns valB - valA (higher score first), and on a tie returns
// -1 when a.playerId (+0x0) is nil or 1 when b.playerId is nil.
// @complete
- (NSArray *)sortedRows:(NSArray *)rows best:(BOOL)best {
    return [rows sortedArrayUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
      FriendListData da, db;
      [a getValue:&da];
      [b getValue:&db];
      int va = best ? da.bestScore : da.totalScore;
      int vb = best ? db.bestScore : db.totalScore;
      // On a score tie the self row (nil playerId) sorts first (matches the
      // binary comparators FUN_000b1934 / FUN_000b18e8: return -1/1 for a/b
      // playerId==0). Verified against both: they getValue a/b, compare the
      // total- or best-score field (b-a, so higher score sorts first), and on a
      // tie return -1 when a.playerId==0 or 1 when b.playerId==0.
      if (va == vb) {
          if (da.playerId == nil) {
              return NSOrderedAscending;
          }
          if (db.playerId == nil) {
              return NSOrderedDescending;
          }
          return NSOrderedSame;
      }
      if (va > vb) {
          return NSOrderedAscending; // higher score first
      }
      return NSOrderedDescending;
    }];
}

// @ 0xb1064
// @complete
- (void)dealloc {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl delegateGetFriendList] == self) {
        [dl setDelegateGetFriendList:nil];
    }
}

@end
