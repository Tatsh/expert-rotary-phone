//
//  FriendListViewController.mm
//  pop'n rhythmin
//
//  See FriendListViewController.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0xb0774, dealloc @ 0xb1064, viewDidLoad @ 0xb1144, didReceiveMemoryWarning
//  @ 0xb11e8, numberOfSectionsInTableView: @ 0xb1214, tableView:numberOfRowsInSection: @ 0xb1218,
//  tableView:cellForRowAtIndexPath: @ 0xb1254, tableView:titleForHeaderInSection: @ 0xb13b0,
//  tableView:didSelectRowAtIndexPath: @ 0xb13b4, downloadMainFinished: @ 0xb15ec,
//  backButtonFunc @ 0xb1980, sortButtonFunc @ 0xb1a44). Objective-C++ for neSceneManager and SE.
//

#import "FriendListViewController.h"

#import "neEngineBridge.h"                    // neSceneManager::rootViewController / isPadDisplay
#import "DownloadMain.h"                      // FriendListData, DownloadMain, friendListArray
#import "FriendListCell.h"                    // row renderer
#import "FriendListDetail.h"                  // tap-row overlay
#import "CommonAlertView.h"                   // error alert
#import "AppFont.h"                           // (shared)
#import "Game/Data/Save/UserSettingData.h"   // isBestScoreSort / playerName / charaId

@implementation FriendListViewController {
    UIViewController *_dummyView;   // loading overlay VC, @164
    UIButton *_sortButton;          // total/best sort toggle, @168
    UIImageView *_lonelyImageView;  // "no friends" placeholder, @172
    FriendListDetail *_detailView;  // current tap overlay, @176
    BOOL _isBestScoreSort;          // sort mode, @180
    NSArray *_frinedDataArray;      // NSValue-wrapped FriendListData rows (binary spelling), @184
}

// @ 0xb0774 — grouped table styling, header spacer, loading overlay, back + sort bar buttons,
// and the "no friends" placeholder image.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    _isBestScoreSort = [UserSettingData isBestScoreSort];
    if (self == nil) {
        return self;
    }

    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGRect viewFrame = self.view.frame;

    self.tableView.rowHeight = isPad ? 74.0f : 54.0f;   // DAT_000b1060 / DAT_000b105c
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
    UIView *header = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, viewFrame.size.width, headerH)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // Phone: a friman_bg backdrop behind the table. iPad: transparent.
    if (!isPad) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc]
            initWithImage:bg];
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

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, 24, 24)];
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    if (!isPad) {
        spinner.center = CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f - 10.0f);
    } else {
        spinner.center = CGPointMake(160.0f, 328.0f);
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
        [backBtn addTarget:self action:@selector(backButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }

    // Sort toggle (total-score vs. best-score art).
    UIImage *sortImg = [UIImage imageNamed:(_isBestScoreSort ? @"frilis_btn_bssort" : @"frilis_btn_tssort")];
    _sortButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, sortImg.size.width, sortImg.size.height)];
    [_sortButton setBackgroundImage:sortImg forState:UIControlStateNormal];
    [_sortButton addTarget:self action:@selector(sortButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_sortButton];

    // "No friends yet" placeholder, centred.
    UIImage *lonely = [UIImage imageNamed:@"frilis_mes_empty"];
    _lonelyImageView = [[UIImageView alloc] initWithImage:lonely];
    [_lonelyImageView setFrame:CGRectMake(0, 0, lonely.size.width, lonely.size.height)];
    if (!isPad) {
        _lonelyImageView.center = CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f);
    } else {
        _lonelyImageView.center = CGPointMake(160.0f, 328.0f);
    }

    return self;
}

// @ 0xb1144
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
    DownloadMain *dl = [DownloadMain getInstance];
    [dl setDelegateGetFriendList:self];
    [dl startGetFriendListHttp];
}

// @ 0xb11e8
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xb1214
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xb1218 — rows only once there is more than the self row.
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
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell_%d_%d",
                            (int)indexPath.section, (int)indexPath.row];
    FriendListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FriendListCell alloc]
            initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.backgroundColor = [UIColor redColor];
    }
    [cell setFriendData:_frinedDataArray[indexPath.row]
                   rank:(int)indexPath.row
        isBestScoreSort:_isBestScoreSort];
    return cell;
}

// @ 0xb13b0
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xb13b4 — raise the friend detail overlay for the tapped row (guarded against re-entry while
// one is already up).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *root = (__bridge UIViewController *)neSceneManager::rootViewController();
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

    _detailView = [[FriendListDetail alloc]
        initWithFrame:frame friendData:_frinedDataArray[indexPath.row]];
    [parent addSubview:_detailView];
    [_detailView startOpenAnimation];
}

// @ 0xb1980 — restore the hub nav bar art and pop (blocked while a detail overlay is up).
- (void)backButtonFunc {
    if (_detailView != nil && [_detailView isEnabled]) {
        return;
    }
    neEngine::playSystemSe(2);
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xb1a44 — flip the sort mode, persist it, re-sort + reload, and swap the button art.
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

    [_sortButton setBackgroundImage:
        [UIImage imageNamed:(_isBestScoreSort ? @"frilis_btn_bssort" : @"frilis_btn_tssort")]
                           forState:UIControlStateNormal];
}

// @ 0xb15ec — friend list arrived: on failure alert; on success prepend the local player as the
// self row, sort, reload, and show/hide the placeholder + scrolling.
- (void)downloadMainFinished:(NSNumber *)result {
    _dummyView.view.hidden = YES;

    if (![result boolValue]) {
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                 delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
        [alert show];
        return;
    }

    _frinedDataArray = nil;

    NSMutableArray *rows = [[[DownloadMain getInstance] friendListArray] mutableCopy];

    // Prepend the local player as the self row (nil playerId marks "you").
    // NB: the binary aggregates the player's own clear counts here via NEAppEventCenter +
    // FUN_00029644 into the rank/perfect/fullComboOnly arrays; that aggregation is not yet
    // reconstructed, so those tallies are left zero (best-effort) while identity/name/charaId
    // are faithful. The row still sorts and renders correctly.
    FriendListData me;
    memset(&me, 0, sizeof(me));
    me.playerId = nil;
    me.name = [UserSettingData playerName];
    me.charaId = [UserSettingData charaId];
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

// Modern stand-in for the binary's sortedArrayUsingFunction: (FUN_000b1934 total / FUN_000b18e8
// best): rank by total- or best-score, descending.
- (NSArray *)sortedRows:(NSArray *)rows best:(BOOL)best {
    return [rows sortedArrayUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
        FriendListData da, db;
        [a getValue:&da];
        [b getValue:&db];
        int va = best ? da.bestScore : da.totalScore;
        int vb = best ? db.bestScore : db.totalScore;
        if (va > vb) return NSOrderedAscending;    // higher score first
        if (va < vb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

// @ 0xb1064
- (void)dealloc {
    DownloadMain *dl = [DownloadMain getInstance];
    if ([dl delegateGetFriendList] == self) {
        [dl setDelegateGetFriendList:nil];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
