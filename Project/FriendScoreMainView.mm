//
//  FriendScoreMainView.mm
//  pop'n rhythmin
//
//  See FriendScoreMainView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initAtNavigationControllerWithMusicId: @ 0xa9df0
//    dealloc                               @ 0xabdd8
//    viewDidLoad                           @ 0xabef8
//    didReceiveMemoryWarning               @ 0xabf9c
//    startOpenAnimation                    @ 0xabfc8
//    endOpenAnimation                      @ 0xac120
//    startCloseAnimation                   @ 0xac138
//    endCloseAnimation                     @ 0xac270
//    numberOfSectionsInTableView:          @ 0xac384
//    tableView:numberOfRowsInSection:      @ 0xac388
//    tableView:cellForRowAtIndexPath:      @ 0xac45c
//    tableView:didSelectRowAtIndexPath:    @ 0xac74c
//    downloaderFinished:                   @ 0xac7f0
//    downloaderProceed:                    @ 0xadc10
//    downloaderError:                      @ 0xadc14
//    downloadMainFinished:                 @ 0xadcec
//    tabBarController:didSelectViewController: @ 0xaddc0
//    onBackButtonTouched                   @ 0xaddf4
//    releaseFriendScore                    @ 0xade6c
//    startGetFriendScoreHttp               @ 0xadee4
//    isAnimationing / musicId / setMusicId: @ 0xae028 / 0xae040 / 0xae054
//  Objective-C++ for the C++ neSceneManager singleton. ARC.
//
//  Honesty notes:
//   - The three tab tables (N/H/Ex) are plain UITableViewControllers whose delegate AND data
//     source are this main view; -tableView:...: dispatches on which controller's tableView is
//     asking. On phone they are the pages of a UITabBarController; on pad they sit side by side.
//   - initAtNavigationControllerWithMusicId: is a very large layout routine. Every UIKit call,
//     asset name, device branch and animation is reproduced; the exact sub-pixel frame offsets
//     were partly inlined by the decompiler as raw float vector ops, so a few frame origins are
//     approximated from the recovered constants and flagged inline. Behaviour (which views are
//     created, wired and added) is exact.
//   - downloaderFinished: parses the server JSON, builds five parallel friend arrays
//     (playerId / scoreN / scoreH / scoreEx / flag), re-orders them to match DownloadMain's
//     friend list, appends the local player's own row, then emits three NSValue-wrapped
//     ScoreDataStruct display arrays (one per difficulty) with finishing place, score rank,
//     full-combo / perfect flags and the "a rival beat you" notice flag (from OverScoreData).
//     The Flag bitfield is: bit0/1/2 = full-combo N/H/Ex, bit3/4/5 = perfect N/H/Ex.
//   - For the local player's own row the binary additionally reconciles the server "Me" scores
//     against the app-event-center in-memory score store (Ghidra free helpers
//     fetchScoreDataForMusic / updateHighScore / saveScoreData on the g_pNeAppEventCenter
//     singleton, plus scoreToRank) and persists any new best back into the local ScoreData store,
//     for each of the three difficulties. That write-back is reconstructed here: the singleton
//     that the store helpers take (&g_pNeAppEventCenter) is the shared PlayScore struct, so its
//     musicId / difficulty (g_wResultSheet) / rank (g_wResultClearRank) fields are modelled with a
//     local PlayScore. The server per-difficulty medal bits drive updateHighScore's GOOD/BAD/
//     full-combo tallies exactly as the binary derives them (see the downloaderFinished body).
//   - Under ARC the ScoreDataStruct NSString field is __unsafe_unretained (mirroring
//     FriendListData in DownloadMain.h). -dealloc is kept: it cancels the in-flight Downloader
//     and detaches this controller from DownloadMain's friend-list delegate.
//

#import "FriendScoreMainView.h"

#import "FriendScoreTableCell.h"   // one ranking row
#import "DownloadMain.h"           // friend list + DownloadMainDelegate
#import "MainViewController.h"     // PauseLoop / ResumeLoop / FriendScoreEndCallBack on the root VC
#import "AppDelegate.h"            // +appDelegate.displayType / managedObjectContext / uuId / appVersionNum
#import "CommonAlertView.h"        // error alert
#import "StoreUtil.h"              // friend-score URL
#import "MusicManager.h"           // song jacket / title art
#import "MusicData.h"
#import "OverScoreData.h"          // "a rival beat you" markers
#import "UserSettingData.h"        // local player id / chara
#import "neEngineBridge.h"         // neSceneManager::isPadDisplay / rootViewController, neEngine::playSystemSe

#import <objc/message.h>

// NSValue payload for one friend-score row, shared with FriendScoreTableCell
// (type-encoding "{ScoreDataStruct=@@iBBcsB}").
typedef struct {
    NSString *__unsafe_unretained playerId;   // @  nil => empty slot; non-nil + nil name => local player
    NSString *__unsafe_unretained name;       // @  friend display name; nil on the local player's row
    int score;            // i  -1 => no score recorded
    BOOL isPerfect;       // B
    BOOL isFullCombo;     // B
    char rank;            // c  0-based finishing place
    short charaId;        // s
    BOOL isNotice;        // B  a rival beat this player's score
} ScoreDataStruct;

// Score -> rank index (0 best .. 6 worst). Shared routine (Ghidra FUN_00028a40, also
// reconstructed file-local in PlayScene.mm / FriendScoreTableCell.mm).
static int scoreToRank(int score) {
    if (score >= 100000) return 0;
    if (score >= 98000)  return 1;
    if (score >= 95000)  return 2;
    if (score >= 90000)  return 3;
    if (score >= 80000)  return 4;
    if (score >= 70000)  return 5;
    return 6;
}

@interface FriendScoreMainView () <UITableViewDataSource, UITableViewDelegate, DownloadMainDelegate>
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)onBackButtonTouched;
- (void)releaseFriendScore;
- (void)startGetFriendScoreHttp;
@end

@implementation FriendScoreMainView {
    UITabBarController      *_tabCtrl;        // phone: pages the three tables
    UITableViewController   *_tblViewCtrlN;   // Normal
    UITableViewController   *_tblViewCtrlH;   // Hyper
    UITableViewController   *_tblViewCtrlEx;  // Ex
    UIViewController        *_dummyView;      // dim spinner overlay (request in flight)
    UIViewController        *_selectedView;   // currently-shown table controller
    Downloader              *_dlGetFriendScore;
    NSArray                 *_frScoreNArray;  // NSValue-wrapped ScoreDataStruct rows
    NSArray                 *_frScoreHArray;
    NSArray                 *_frScoreExArray;
}

@synthesize musicId = _musicId;
@synthesize isAnimationing = _isAnimationing;

// @ 0xa9df0
- (UINavigationController *)initAtNavigationControllerWithMusicId:(unsigned int)musicId __attribute__((objc_method_family(none))) {
    // family(none) factory: returns the nav, not self, so it cannot assign self; super init
    // returns the receiver in place -> self stays valid (matches the binary's super-init check).
    if (![super init]) {
        return nil;
    }
    _musicId = musicId;

    CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
    int displayType = [[AppDelegate appDelegate] displayType];
    BOOL isPad = neSceneManager::isPadDisplay();

    // Full-screen background.
    UIImage *bgImg = [UIImage imageNamed:@"frisco_bg"];
    UIImageView *bgView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
    [bgView setImage:bgImg];
    [self.view addSubview:bgView];

    // Wrap self in a navigation controller with a custom back button + nav-bar art.
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(onBackButtonTouched)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"frisco_navbar"] forBarMetrics:UIBarMetricsDefault];

    // --- The three difficulty tables (N / H / Ex) ---------------------------------------
    NSString *const tableBgName[3] = { @"frisco_table_no", @"frisco_table_hy", @"frisco_table_ex" };
    UITableViewController *tables[3];
    for (int i = 0; i < 3; i++) {
        UITableViewController *tvc = [[UITableViewController alloc]
            initWithStyle:UITableViewStyleGrouped];
        tvc.tableView.delegate = self;
        tvc.tableView.dataSource = self;
        if (!isPad) {
            UIImageView *bg = [[UIImageView alloc]
                initWithImage:[UIImage imageNamed:tableBgName[i]]];
            tvc.tableView.rowHeight = 54.0f;
            tvc.tableView.backgroundView = bg;
        } else {
            tvc.tableView.rowHeight = 112.0f;
            tvc.tableView.backgroundView = nil;
            tvc.tableView.backgroundColor = [UIColor clearColor];
            tvc.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            tvc.tableView.separatorColor = [UIColor clearColor];
        }
        tvc.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tables[i] = tvc;
    }
    _tblViewCtrlN  = tables[0];
    _tblViewCtrlH  = tables[1];
    _tblViewCtrlEx = tables[2];

    if (isPad) {
        // Pad: the three tables laid out side by side (thirds of the width), each under its
        // own header banner, with a clear table header. Exact origins approximated from the
        // decompiler's inlined third-width math (see honesty note).
        UIView *emptyHeader = [[UIView alloc] init];
        [emptyHeader setFrame:CGRectZero];
        for (int i = 0; i < 3; i++) {
            tables[i].tableView.tableHeaderView = emptyHeader;
        }
        _selectedView = _tblViewCtrlN;

        CGRect tblFrame = _tblViewCtrlN.view ? _tblViewCtrlN.view.frame : CGRectZero;
        // Disasm 0xaaa1c: the /3.0 numerator is self.view.frame width (viewFrame @ sp+0x270),
        // NOT the table VC's frame (which the binary never reads here). Divisor 3.0f, truncated.
        CGFloat third = (CGFloat)(int)(viewFrame.size.width / 3.0f);
        NSString *const banner[3] = { @"frisco_table_no", @"frisco_table_hy", @"frisco_table_ex" };
        for (int i = 0; i < 3; i++) {
            UIImageView *hdr = [[UIImageView alloc] initWithImage:[UIImage imageNamed:banner[i]]];
            hdr.frame = CGRectMake(0, third * i, tblFrame.size.width - bgImg.size.width, third);
            [self.view addSubview:hdr];
        }
        for (int i = 0; i < 3; i++) {
            tables[i].view.frame = CGRectMake(bgImg.size.width, third * i,
                                              tblFrame.size.width - bgImg.size.width, third);
            [self.view addSubview:tables[i].view];
        }
    } else {
        _selectedView = _tblViewCtrlN;

        // Which difficulties already have a rival ("over-score") record for this song — the
        // matching tab shows a blinking warning badge.
        BOOL warnN = NO, warnH = NO, warnEx = NO;
        NSArray *over = [OverScoreData getAllOverScoreData:[[AppDelegate appDelegate] managedObjectContext]];
        for (OverScoreData *rec in over) {
            if ([rec.music intValue] != (int)musicId) {
                continue;
            }
            switch ([rec.sheet intValue]) {
                case 0: warnN  = YES; break;
                case 1: warnH  = YES; break;
                case 2: warnEx = YES; break;
            }
        }

        [UITabBar appearance].backgroundColor = [UIColor clearColor];
        _tabCtrl = [[UITabBarController alloc] init];
        _tabCtrl.delegate = self;
        [_tabCtrl setViewControllers:@[ _tblViewCtrlN, _tblViewCtrlH, _tblViewCtrlEx ] animated:NO];

        // Tab-bar frame + per-item art. iOS 7 flattens the bar and needs template images.
        BOOL isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
        if (isOS7) {
            [_tblViewCtrlN.tableView setContentInset:UIEdgeInsetsMake(-20.0f, 0, 0, 0)];
            [_tblViewCtrlH.tableView setContentInset:UIEdgeInsetsMake(-20.0f, 0, 0, 0)];
            [_tblViewCtrlEx.tableView setContentInset:UIEdgeInsetsMake(-20.0f, 0, 0, 0)];
        }
        _tabCtrl.view.frame = CGRectMake(0, 0, viewFrame.size.width, viewFrame.size.height);
        CGRect barFrame = _tabCtrl.tabBar.frame;
        _tabCtrl.tabBar.frame = CGRectMake(barFrame.origin.x, barFrame.origin.y,
                                           viewFrame.size.width, 34.0f);
        _tabCtrl.tabBar.clipsToBounds = YES;

        UIEdgeInsets imgInsets = isOS7 ? UIEdgeInsetsMake(-1.0f, 0, 2.0f, 0)
                                       : UIEdgeInsetsMake(-1.0f, 0, 6.0f, 0);
        NSString *const onName[3]  = { @"frisco_tab_no_on",  @"frisco_tab_hy_on",  @"frisco_tab_ex_on"  };
        NSString *const offName[3] = { @"frisco_tab_no_off", @"frisco_tab_hy_off", @"frisco_tab_ex_off" };
        for (int i = 0; i < 3; i++) {
            UIImage *on  = [UIImage imageNamed:onName[i]];
            UIImage *off = [UIImage imageNamed:offName[i]];
            if (isOS7) {
                on  = [on  imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                off = [off imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            UITabBarItem *item = _tabCtrl.tabBar.items[i];
            [item setFinishedSelectedImage:on withFinishedUnselectedImage:off];
            [item setImageInsets:imgInsets];
        }
        [self.view addSubview:_tabCtrl.view];

        // Blink a warning badge over each difficulty tab that has a rival record.
        CGFloat warnY = (displayType == 2) ? 34.0f : 30.0f;   // DAT_000abce0/ce4
        const CGFloat warnX[3] = { 2.0f, 108.0f, 214.0f };
        const BOOL warn[3] = { warnN, warnH, warnEx };
        for (int i = 0; i < 3; i++) {
            if (!warn[i]) {
                continue;
            }
            UIImage *warnImg = [UIImage imageNamed:@"vie_cmn_warning"];
            UIImageView *warnView = [[UIImageView alloc] initWithImage:warnImg];
            warnView.frame = CGRectMake(warnX[i], warnY, warnImg.size.width, warnImg.size.height);
            // Disasm 0xab554/0xab698/0xab7ea: options = #0x18 = Repeat | Autoreverse (the
            // reconstruction dropped the Autoreverse bit, leaving a hard alpha snap-back).
            [UIView animateWithDuration:0.5 delay:0
                                options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                             animations:^{ warnView.alpha = 0; }
                             completion:nil];
            [self.view addSubview:warnView];
        }
    }

    // --- Song jacket / title art (both device layouts) ----------------------------------
    UIImageView *jacketBg = [[UIImageView alloc] init];
    [jacketBg setImage:[UIImage imageNamed:(isPad ? @"frisco_bg_jk" : @"frisco_jacket_BG")]];
    {
        CGFloat jx = isPad ? 183.0f : 13.0f;
        CGFloat jy = (displayType == 2) ? 20.0f : 6.0f;
        jacketBg.frame = CGRectMake(jx, jy, jacketBg.image.size.width, jacketBg.image.size.height);
        [self.view addSubview:jacketBg];
    }

    MusicData *md = [[MusicManager getInstance] getMusicData:_musicId];
    UIImageView *artwork = [[UIImageView alloc]
        initWithImage:[UIImage imageWithData:[md artwork2xData]]];
    {
        // Inset inside the jacket plate; pad rounds the corners.
        CGFloat ax = jacketBg.frame.origin.x + 6.0f;
        CGFloat ay = jacketBg.frame.origin.y + 6.0f;
        CGFloat side = 78.0f;
        if (isPad) {
            artwork.layer.cornerRadius = 3.0f;
            artwork.clipsToBounds = YES;
            side = 83.0f;
            ax -= 4.0f;
            ay -= 4.0f;
        }
        artwork.frame = CGRectMake(ax, ay, side, side);
        [self.view addSubview:artwork];
    }

    UIImageView *titleView = [[UIImageView alloc]
        initWithImage:[UIImage imageWithData:[md musicNameImage2xData]]];
    {
        CGFloat tx  = isPad ? 128.0f : 111.0f;
        CGFloat tw  = isPad ? 294.0f : 147.0f;
        CGFloat th  = isPad ? 32.0f  : 16.0f;
        CGFloat ty  = (displayType == 2) ? 50.0f : 41.0f;
        titleView.frame = CGRectMake(tx, ty, tw, th);
        [self.view addSubview:titleView];
    }

    // --- Dim overlay + spinner (shown while a request is in flight) ----------------------
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = viewFrame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    _dummyView.view.hidden = YES;
    [self.view addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    spinner.center = CGPointMake(viewFrame.size.width * 0.5f,
                                 (int)(viewFrame.size.height * 0.5f) - 10);
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];

    return nav;
}

// @ 0xabdd8 — cancel the in-flight request and detach from DownloadMain's friend-list
// delegate before teardown. Kept under ARC for those side effects; the ivar releases are
// ARC-managed (the ScoreDataStruct strings are __unsafe_unretained — see honesty note).
- (void)dealloc {
    [self releaseFriendScore];
    if (_dlGetFriendScore != nil) {
        [_dlGetFriendScore cancel];
    }
    DownloadMain *dm = [DownloadMain getInstance];
    if ([dm delegateGetFriendList] == self) {
        [dm setDelegateGetFriendList:nil];
    }
}

// @ 0xabef8 — become DownloadMain's friend-list delegate, kick a refresh, reveal the spinner.
- (void)viewDidLoad {
    [super viewDidLoad];
    DownloadMain *dm = [DownloadMain getInstance];
    [dm setDelegateGetFriendList:self];
    [dm startGetFriendListHttp];
    _dummyView.view.hidden = NO;
}

// didReceiveMemoryWarning @ 0xabf9c — super-only override, ARC/omit.

#pragma mark - Open / close animation

// @ 0xabfc8 — pause the render loop and cross-fade the nav host in.
- (void)startOpenAnimation {
    [(MainViewController *)neSceneManager::rootViewController() PauseLoop];
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // DAT_000ac118
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xac120
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xac138 — cross-fade the nav host out (cancel SE), then resume the render loop.
- (void)startCloseAnimation {
    if (!_isAnimationing) {
        _isAnimationing = YES;
        neEngine::playSystemSe(2);   // cancel SE
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];   // DAT_000ac268
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    }
    [(MainViewController *)neSceneManager::rootViewController() ResumeLoop];
}

// @ 0xac270 — detach every delegate/data source, remove the nav host and notify the root VC.
- (void)endCloseAnimation {
    _tabCtrl.delegate = nil;
    _tblViewCtrlN.tableView.delegate = nil;
    _tblViewCtrlH.tableView.delegate = nil;
    _tblViewCtrlEx.tableView.delegate = nil;
    [_tabCtrl.view removeFromSuperview];
    [self.navigationController.view removeFromSuperview];
    [(MainViewController *)neSceneManager::rootViewController() FriendScoreEndCallBack];
    _isAnimationing = NO;
}

#pragma mark - Table data source / delegate

// @ 0xac384
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// The score array backing a given page's tableView (nil if unknown).
- (NSArray *)arrayForTableView:(UITableView *)tableView {
    if (tableView == _tblViewCtrlN.tableView)  { return _frScoreNArray; }
    if (tableView == _tblViewCtrlH.tableView)  { return _frScoreHArray; }
    if (tableView == _tblViewCtrlEx.tableView) { return _frScoreExArray; }
    return nil;
}

// @ 0xac388 — always show at least one (placeholder) row.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *rows = [self arrayForTableView:tableView];
    NSInteger n = rows ? (NSInteger)rows.count : 0;
    (void)[[AppDelegate appDelegate] displayType];   // (touched in the binary; no effect)
    return n < 1 ? 1 : n;
}

// @ 0xac45c — one FriendScoreTableCell per row; empty tables get a single placeholder row.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int page = 0;
    NSArray *rows = _frScoreNArray;
    if (tableView == _tblViewCtrlH.tableView)  { page = 1; rows = _frScoreHArray; }
    else if (tableView == _tblViewCtrlEx.tableView) { page = 2; rows = _frScoreExArray; }

    NSString *identifier = [NSString stringWithFormat:@"Cell%d-%ld-%ld",
                            page, (long)indexPath.section, (long)indexPath.row];
    FriendScoreTableCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FriendScoreTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                           reuseIdentifier:identifier];
    }
    cell.backgroundView = nil;

    NSValue *scoreValue = nil;
    if ((NSUInteger)indexPath.row < rows.count) {
        // The rows carry their finishing place in the `rank` field; the visual row R shows the
        // row whose place (with ties broken by list order) equals R. Mirror the binary's scan:
        // for each candidate count how many rows placed higher plus how many tied ones precede it.
        for (NSUInteger i = 0; i < rows.count; i++) {
            ScoreDataStruct probe;
            [[rows objectAtIndex:i] getValue:&probe];
            int higher = 0, tiedBefore = 0;
            for (NSUInteger j = 0; j < rows.count; j++) {
                ScoreDataStruct other;
                [[rows objectAtIndex:j] getValue:&other];
                if (other.rank < probe.rank) {
                    higher++;
                }
            }
            for (NSUInteger j = i + 1; j < rows.count; j++) {
                ScoreDataStruct other;
                [[rows objectAtIndex:j] getValue:&other];
                if (other.rank == probe.rank) {
                    tiedBefore++;
                }
            }
            if (higher + tiedBefore == indexPath.row) {
                scoreValue = [rows objectAtIndex:i];
                break;
            }
        }
    } else {
        // Placeholder ("no score yet") row.
        ScoreDataStruct empty;
        empty.playerId = nil;
        empty.name = nil;
        empty.score = -1;
        empty.isPerfect = NO;
        empty.isFullCombo = NO;
        empty.rank = (char)indexPath.row;
        empty.charaId = 0;
        empty.isNotice = NO;
        scoreValue = [NSValue value:&empty withObjCType:@encode(ScoreDataStruct)];
    }
    if (scoreValue != nil) {
        [cell setScoreData:scoreValue];
    }
    return cell;
}

// @ 0xac74c — taps are inert (the screen is read-only); just validate the index path.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _tblViewCtrlN.tableView) {
        if (indexPath.section != 0) {
            return;
        }
        (void)indexPath.row;
    } else if (tableView == _tblViewCtrlH.tableView || tableView == _tblViewCtrlEx.tableView) {
        (void)indexPath.section;
    }
}

#pragma mark - UITabBarController delegate

// @ 0xaddc0 — play the decide SE when switching to a different tab.
- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController {
    if (_selectedView == viewController) {
        return;
    }
    neEngine::playSystemSe(1);   // decide SE
    _selectedView = viewController;
}

#pragma mark - Downloader delegate

// downloaderProceed: @ 0xadc10 / downloaderError: @ 0xadc14 — no-ops (share one empty body).
- (void)downloaderProceed:(Downloader *)downloader { }
- (void)downloaderError:(Downloader *)downloader { }

// @ 0xac7f0 — the friend-score response arrived: parse it, build the three display tables.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [_dlGetFriendScore getDataInJSON];

    if ([json objectForKey:@"ErrorCode"] != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。" delegate:nil
        cancelButtonTitle:nil otherButtonTitles:@"OK"];
        [alert show];
    } else {
        NSArray *friends = [json objectForKey:@"Friend"];   // `friend` is a C++ reserved word
        NSDictionary *me = [json objectForKey:@"Me"];

        NSMutableArray *playerIds = [[NSMutableArray alloc] init];
        NSMutableArray *scoreN    = [[NSMutableArray alloc] init];
        NSMutableArray *scoreH    = [[NSMutableArray alloc] init];
        NSMutableArray *scoreEx   = [[NSMutableArray alloc] init];
        NSMutableArray *flags     = [[NSMutableArray alloc] init];
        NSMutableArray *charaIds  = [[NSMutableArray alloc] init];

        for (NSDictionary *f in friends) {
            NSNumber *pid = [f objectForKey:@"PlayerId"];
            NSNumber *sN  = [f objectForKey:@"ScoreN"];
            NSNumber *sH  = [f objectForKey:@"ScoreH"];
            NSNumber *sEx = [f objectForKey:@"ScoreEx"];
            NSNumber *flg = [f objectForKey:@"Flag"];
            if (pid && sN && sH && sEx && flg) {
                [playerIds addObject:pid];
                [scoreN addObject:sN];
                [scoreH addObject:sH];
                [scoreEx addObject:sEx];
                [flags addObject:flg];
            }
        }

        // Re-order the server rows to match DownloadMain's friend list (server order may differ);
        // friends missing from the response get a -1 placeholder score row.
        NSArray *friendList = [[DownloadMain getInstance] friendListArray];
        for (NSUInteger i = 0; i < friendList.count; i++) {
            FriendListData fld;
            [[friendList objectAtIndex:i] getValue:&fld];
            NSString *wantId = fld.playerId;
            [charaIds insertObject:@(fld.charaId) atIndex:i];

            NSUInteger found = i;
            BOOL matched = (i < playerIds.count) && [wantId isEqualToString:[playerIds objectAtIndex:i]];
            if (!matched && i < playerIds.count) {
                for (found = i + 1; found < playerIds.count; found++) {
                    if ([wantId isEqualToString:[playerIds objectAtIndex:found]]) {
                        matched = YES;
                        break;
                    }
                }
            }
            if (matched && found != i) {
                [playerIds exchangeObjectAtIndex:i withObjectAtIndex:found];
                [scoreN exchangeObjectAtIndex:i withObjectAtIndex:found];
                [scoreH exchangeObjectAtIndex:i withObjectAtIndex:found];
                [scoreEx exchangeObjectAtIndex:i withObjectAtIndex:found];
                [flags exchangeObjectAtIndex:i withObjectAtIndex:found];
            } else if (!matched) {
                [playerIds insertObject:wantId atIndex:i];
                [scoreN insertObject:@(-1) atIndex:i];
                [scoreH insertObject:@(-1) atIndex:i];
                [scoreEx insertObject:@(-1) atIndex:i];
                [flags insertObject:@(0) atIndex:i];
            }
        }

        // The local player's own best per difficulty. The binary first reads it from the local
        // score store (Ghidra: the fetchScoreDataForMusic N/H/EX loop at the head of
        // downloaderFinished @ 0xac7f0), then reconciles it with the server "Me" record, showing
        // the better of the two.
        int myScore[3]  = { 0, 0, 0 };
        short myRank[3] = { 0, 0, 0 };
        BOOL myPerfect[3]   = { NO, NO, NO };
        BOOL myFullCombo[3] = { NO, NO, NO };
        for (int d = 0; d < 3; d++) {
            int playCnt = 0;
            bool fc = false, pf = false;
            fetchScoreDataForMusic(&neAppEventCenter::shared(), &myScore[d], &myRank[d], &playCnt,
                                   &fc, &pf, _musicId, d);
            myFullCombo[d] = fc ? YES : NO;
            myPerfect[d]   = pf ? YES : NO;
        }
        // Reconcile the server "Me" record with the local store and, per difficulty, persist any
        // new server best BACK into the local ScoreData store (updateHighScore + saveScoreData).
        //
        // In the binary the save path overlays the shared PlayScore struct on the app-event-center
        // singleton (&g_pNeAppEventCenter) and drives the free store helpers on it; the three
        // "result-screen" globals it pokes are just fields of that struct:
        //   g_pNeAppEventCenter = self->_musicId   -> PlayScore.musicId    (+0x00)
        //   g_wResultSheet      = <difficulty d>   -> PlayScore.difficulty (+0x04)
        //   g_wResultClearRank  = scoreToRank(...) -> PlayScore.rank        (+0x14)
        // We model that faithfully with a local PlayScore (neEngineBridge.h) carrying those exact
        // fields; the binary's extra neAppEventCenter::shared() force-init before the overlay is a
        // singleton side effect the local model does not need.
        if (me != nil) {
            NSNumber *mN  = [me objectForKey:@"ScoreN"];
            NSNumber *mH  = [me objectForKey:@"ScoreH"];
            NSNumber *mEx = [me objectForKey:@"ScoreEx"];
            NSNumber *mFlg = [me objectForKey:@"Flag"];
            if (mN && mH && mEx && mFlg) {
                NSNumber *meScore[3] = { mN, mH, mEx };
                int flag = [mFlg intValue];

                PlayScore ps = {};
                ps.musicId = _musicId;   // g_pNeAppEventCenter = self->_musicId

                for (int d = 0; d < 3; d++) {
                    int srvScore = [meScore[d] intValue];
                    // Server medal bits for this difficulty (shared Flag layout, bit0/1/2 = the
                    // full-combo group, bit3/4/5 = the perfect group):
                    int fcMedal = (flag >> d) & 1;         // bit d      -> myFullCombo[d]
                    int pfMedal = (flag >> (d + 3)) & 1;   // bit (d+3)  -> myPerfect[d]

                    // Persist when the server beat the local score, OR when the server holds a medal
                    // the local record lacks (the "even if not higher, save the new medal" branch).
                    BOOL writeBack = (myScore[d] < srvScore) ||
                                     (!myFullCombo[d] && fcMedal) ||
                                     (!myPerfect[d]   && pfMedal);
                    if (!writeBack) {
                        continue;
                    }

                    // updateHighScore(ps, srvScore, cool=1, great=2, good, bad, fullCombo):
                    //   fullCombo = fcMedal                       (the +0x04 full-combo bit)
                    //   good      = pfMedal ? 0 : 3               (uVar33 in the decompile)
                    //   bad       = fcMedal ? 0 : ((pfMedal<<2)^4)(uVar38: 0 if a cool/FC medal, else
                    //                                              0 when the perfect bit is set, 4 otherwise)
                    // The cool/great bases (1, 2) are the constants the binary passes verbatim.
                    ps.difficulty = d;                                // g_wResultSheet
                    updateHighScore(&ps, (unsigned)srvScore, 1, 2,
                                    pfMedal ? 0 : 3,
                                    fcMedal ? 0 : ((pfMedal << 2) ^ 4),
                                    (char)fcMedal);
                    ps.rank = (short)scoreToRank(srvScore);           // g_wResultClearRank
                    saveScoreData(&ps);

                    // Bump the local display best with the (now persisted) server values.
                    if (myScore[d] < srvScore) {
                        myScore[d] = srvScore;   // display the better of local vs. server
                    }
                    short srvRank = (short)scoreToRank(srvScore);
                    if (srvRank < myRank[d]) {
                        myRank[d] = srvRank;
                    }
                    if (fcMedal) { myFullCombo[d] = YES; }
                    if (pfMedal) { myPerfect[d]   = YES; }
                }
            }
        }

        // Append the local player as the final row.
        NSString *myId = [UserSettingData playerId];
        NSUInteger tail = friendList.count;
        [playerIds insertObject:(myId ? (id)myId : (id)[NSNull null]) atIndex:tail];
        [scoreN  insertObject:@(myScore[0]) atIndex:tail];
        [scoreH  insertObject:@(myScore[1]) atIndex:tail];
        [scoreEx insertObject:@(myScore[2]) atIndex:tail];
        [charaIds insertObject:@((int)[UserSettingData charaId]) atIndex:tail];
        int myFlagBits = 0;
        if (myFullCombo[0]) { myFlagBits |= 0x01; }
        if (myPerfect[0])   { myFlagBits |= 0x08; }
        if (myFullCombo[1]) { myFlagBits |= 0x02; }
        if (myPerfect[1])   { myFlagBits |= 0x10; }
        if (myFullCombo[2]) { myFlagBits |= 0x04; }
        if (myPerfect[2])   { myFlagBits |= 0x20; }
        [flags insertObject:@(myFlagBits) atIndex:tail];

        // The rival records that beat someone for this song (for the "notice" marker).
        NSArray *allOver = [OverScoreData getAllOverScoreData:[[AppDelegate appDelegate] managedObjectContext]];
        NSMutableArray *over = [[NSMutableArray alloc] init];
        for (OverScoreData *rec in allOver) {
            if ([rec.music intValue] == (int)_musicId) {
                [over addObject:rec];
            }
        }

        NSMutableArray *out[3];
        NSMutableArray *scores[3] = { scoreN, scoreH, scoreEx };
        int fcBit[3]  = { 0, 1, 2 };
        int pfBit[3]  = { 3, 4, 5 };
        for (int d = 0; d < 3; d++) {
            out[d] = [[NSMutableArray alloc] init];
            for (NSUInteger i = 0; i < playerIds.count; i++) {
                // Finishing place = how many rows scored higher for this difficulty.
                int place = 0;
                for (NSUInteger j = 0; j < playerIds.count; j++) {
                    if ([[scores[d] objectAtIndex:i] intValue] < [[scores[d] objectAtIndex:j] intValue]) {
                        place++;
                    }
                }
                id pidObj = [playerIds objectAtIndex:i];
                NSString *playerId = (pidObj == [NSNull null]) ? nil : (NSString *)pidObj;
                // Friend rows carry the friend's display name; the local player's row (the last
                // one) leaves it nil so the cell fills in the "you" band from UserSettingData.
                NSString *name = nil;
                if (i < friendList.count) {
                    FriendListData fld;
                    [[friendList objectAtIndex:i] getValue:&fld];
                    name = fld.name;
                }

                ScoreDataStruct row;
                row.playerId = playerId;
                row.name = name;
                row.charaId = (short)[[charaIds objectAtIndex:i] intValue];
                row.score = [[scores[d] objectAtIndex:i] intValue];
                int flag = [[flags objectAtIndex:i] intValue];
                row.isFullCombo = (flag & (1 << fcBit[d])) != 0;
                row.isPerfect   = (flag & (1 << pfBit[d])) != 0;
                row.rank = (char)place;
                row.isNotice = NO;
                for (OverScoreData *rec in over) {
                    if ([rec.sheet intValue] == d && playerId != nil &&
                        [playerId isEqual:rec.playerId]) {
                        row.isNotice = YES;
                    }
                }
                [out[d] addObject:[NSValue value:&row withObjCType:@encode(ScoreDataStruct)]];
            }
        }

        [self releaseFriendScore];
        _frScoreNArray  = [[NSArray alloc] initWithArray:out[0]];
        _frScoreHArray  = [[NSArray alloc] initWithArray:out[1]];
        _frScoreExArray = [[NSArray alloc] initWithArray:out[2]];

        [_tblViewCtrlN.tableView reloadData];
        [_tblViewCtrlH.tableView reloadData];
        [_tblViewCtrlEx.tableView reloadData];
    }

    _dlGetFriendScore = nil;
    _dummyView.view.hidden = YES;
}

#pragma mark - DownloadMain delegate

// @ 0xadcec — the friend list finished refreshing: on success fetch the friend scores, else
// hide the spinner and show an error.
- (void)downloadMainFinished:(NSNumber *)success {
    if ([success boolValue]) {
        [self startGetFriendScoreHttp];
    } else {
        _dummyView.view.hidden = YES;
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。" delegate:nil
        cancelButtonTitle:nil otherButtonTitles:@"OK"];
        [alert show];
    }
}

#pragma mark - Navigation / networking

// @ 0xaddf4 — back button: clear this song's rival records, then close.
- (void)onBackButtonTouched {
    [OverScoreData deleteRecordWithMusic:(int)_musicId
                 inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]];
    [self startCloseAnimation];
}

// @ 0xade6c — drop the three cached display arrays.
- (void)releaseFriendScore {
    _frScoreNArray = nil;
    _frScoreHArray = nil;
    _frScoreExArray = nil;
}

// @ 0xadee4 — POST "uuid=…&music=…&client_ver=…" to the friend-score URL.
- (void)startGetFriendScoreHttp {
    if (_dlGetFriendScore != nil) {
        return;
    }
    int ver = [[AppDelegate appDelegate] appVersionNum];
    NSString *body = [NSString stringWithFormat:@"uuid=%@&music=%09d&client_ver=%d",
                      [[AppDelegate appDelegate] uuId], _musicId, ver];
    _dlGetFriendScore = [[Downloader alloc]
        initWithURL:[StoreUtil getFriendScoreURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/x-www-form-urlencoded"];
    [_dlGetFriendScore startDownloading];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
