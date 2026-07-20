//
//  FreeRequestListViewController.mm
//  pop'n rhythmin
//
//  See FreeRequestListViewController.h. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin:
//    initWithStyle:                      @ 0xe5430
//    dealloc                             @ 0xe5bb4
//    viewDidLoad                         @ 0xe5c5c
//    didReceiveMemoryWarning             @ 0xe5ccc
//    numberOfSectionsInTableView:        @ 0xe5cf8
//    tableView:numberOfRowsInSection:    @ 0xe5cfc
//    tableView:cellForRowAtIndexPath:    @ 0xe5d24
//    tableView:titleForHeaderInSection:  @ 0xe5e3c
//    tableView:didSelectRowAtIndexPath:  @ 0xe5e40
//    releaseFriendList                   @ 0xe60cc
//    downloaderFinished:                 @ 0xe61e0
//    downloaderError:                    @ 0xe6c80
//    startGetRecommendFriendHttp         @ 0xe6d60
//    backButtonFunc                      @ 0xe6ea4
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - The recommend-friend list is downloaded via Downloader (POST to
//     +[StoreUtil getRecommendFriendURL], body "uuid=<appDelegate.uuId>",
//     Content-Type "application/json"). The parsed rows are NSValue-wrapped
//     FriendListData (see DownloadMain.h) — the same struct/type-encoding the
//     sibling
//     -[DownloadMain getFriendListFinished] produces; -downloaderFinished: here
//     mirrors that parse exactly, keyed on the "List" array (vs. "Friend"),
//     with FriendShip forced to 0 (no "FriendShip" key is read for this list).
//   - The binary builds the per-field values into ~26 parallel NSMutableArrays
//   first, then a
//     second pass assembles each FriendListData; that is behaviourally
//     identical to the direct per-entry assembly used here. Under ARC the
//     struct's NSString* fields are held
//     __unsafe_unretained (see DownloadMain.h), so no explicit retain/release
//     is issued — -releaseFriendList only unboxes, matching -[DownloadMain
//     releaseFriendList].
//   - The error alert strings are exact CFString decodes (UTF-16LE): title
//   "フレンド申請",
//     message "通信に失敗しました。\n電波状態の良い場所でやり直して下さい。",
//     OK button.
//   - -tableView:didSelectRowAtIndexPath: instantiates a FreeRequestDetail
//   overlay sized to the
//     nav host's superview (phone) or the root VC's view (pad).
//     FreeRequestDetail is now reconstructed (FreeRequestDetail.h/.mm) and
//     imported directly.
//

#import "FreeRequestListViewController.h"

#import "AppDelegate.h"              // +appDelegate.uuId
#import "CommonAlertView.h"          // network-failure alert
#import "DownloadMain.h"             // FriendListData struct + @encode
#import "Downloader.h"               // Downloader + DownloaderDelegate
#import "FreeRequestDetail.h"        // the friend-request confirm overlay
#import "FreeRequestListCell.h"      // one row per recommended friend
#import "StoreUtil.h"                // +getRecommendFriendURL
#import "UINavigationBar+RHHeader.h" // setBackgroundImageModern:
#import "neEngineBridge.h" // neSceneManager::isPadDisplay/rootViewController, neEngine::playSystemSe

@interface FreeRequestListViewController () <DownloaderDelegate>
- (void)releaseFriendList;
- (void)startGetRecommendFriendHttp;
- (void)backButtonFunc;
@end

@implementation FreeRequestListViewController {
    UIViewController *_dummyView;          // @0x… dimmed overlay hosting the activity indicator
    NSArray *_frinedDataArray;             // parsed rows (NSValue-wrapped FriendListData)
    Downloader *_downloader;               // in-flight recommend-friend request
    FreeRequestDetail *_freeRequestDetail; // raised confirm overlay for the tapped row
}

// @ 0xe5430 — build the header plate, dimmed dummy overlay + spinner, and the
// back button.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        CGRect viewFrame = self.view ? self.view.frame : CGRectZero;

        BOOL isPad = neSceneManager::isPadDisplay();
        self.tableView.rowHeight =
            isPad ? 74.0f : 54.0f; // pad DAT_000e5bb0=74, phone DAT_000e5bac=54
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor clearColor];

        // Header plate ("fpl_text") centred in a 70pt-tall clear header view.
        UIImage *headerImg = [UIImage imageNamed:@"fpl_text"];
        UIImageView *headerImgView = [[UIImageView alloc] initWithImage:headerImg];
        if (!isPad) {
            CGFloat x = (viewFrame.size.width - headerImg.size.width) * 0.5f;
            headerImgView.frame = CGRectMake(x, 20.0f, headerImg.size.width, headerImg.size.height);
        } else {
            headerImgView.frame = CGRectMake(28.0f,
                                             20.0f,
                                             headerImg.size.width,
                                             headerImg.size.height); // 0x41e00000
        }
        UIView *headerView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewFrame.size.width, 70.0f)];
        headerView.backgroundColor = [UIColor clearColor];
        [headerView addSubview:headerImgView];
        self.tableView.tableHeaderView = headerView;

        // Phone: a "friman_bg" backdrop behind the table.
        if (!isPad) {
            UIImage *bgImg = [UIImage imageNamed:@"friman_bg"];
            UIImageView *bgImgView = [[UIImageView alloc] initWithImage:bgImg];
            bgImgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
            self.tableView.backgroundView = bgImgView;
        }

        // Dimmed dummy overlay carrying the download spinner (hidden until
        // viewDidLoad).
        _dummyView = [[UIViewController alloc] init];
        _dummyView.view.frame = viewFrame;
        _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.view.hidden = YES;
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray; // style 2
        spinner.center = CGPointMake(viewFrame.size.width * 0.5f,
                                     static_cast<int>(viewFrame.size.height * 0.5f) - 10);
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Custom back button in the nav item.
        UIImage *backImg = [UIImage
            imageNamed:(neSceneManager::isPadDisplay() ? @"pl_checker_return" : @"navi_btn_back")];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        if (neSceneManager::isPadDisplay()) {
            self.navigationItem.hidesBackButton = YES;
        }
    }
    return self;
}

// @ 0xe5c5c — reveal the dummy overlay and kick off the download.
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
    [self startGetRecommendFriendHttp];
}

// didReceiveMemoryWarning @ 0xe5ccc — super-only override, ARC/omit.

#pragma mark - Table

// @ 0xe5cf8
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xe5cfc
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _frinedDataArray ? [_frinedDataArray count] : 0;
}

// @ 0xe5d24
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld-%ld",
                                                      static_cast<long>(indexPath.section),
                                                      static_cast<long>(indexPath.row)];
    FreeRequestListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FreeRequestListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:identifier];
    }
    [cell setFriendData:[_frinedDataArray objectAtIndex:indexPath.row]
                   rank:static_cast<int>(indexPath.row)];
    return cell;
}

// @ 0xe5e3c
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xe5e40 — raise the FreeRequestDetail confirm overlay for the tapped row
// (section 0 only).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) {
        return;
    }
    if (_freeRequestDetail != nil && [_freeRequestDetail isEnabled]) {
        return; // a confirm overlay is already open
    }

    neEngine::playSystemSe(1); // decide/confirm SE

    UIView *host = nil;
    if (!neSceneManager::isPadDisplay()) {
        UIView *superview = self.navigationController.view.superview;
        CGRect frame = superview ? superview.frame : CGRectZero;
        _freeRequestDetail = [[FreeRequestDetail alloc]
            initWithFrame:frame
               friendData:[_frinedDataArray objectAtIndex:indexPath.row]];
        host = superview;
    } else {
        UIViewController *rootVC = neSceneManager::rootViewController();
        CGRect frame = rootVC.view ? rootVC.view.frame : CGRectZero;
        _freeRequestDetail = [[FreeRequestDetail alloc]
            initWithFrame:frame
               friendData:[_frinedDataArray objectAtIndex:indexPath.row]];
        host = rootVC.view;
    }
    [host addSubview:_freeRequestDetail];
    [_freeRequestDetail startOpenAnimation];
}

#pragma mark - Friend list storage

// @ 0xe60cc — unbox each FriendListData row (its two __unsafe_unretained
// NSString fields), then drop the array. Mirrors -[DownloadMain
// releaseFriendList].
- (void)releaseFriendList {
    if (_frinedDataArray == nil) {
        return;
    }
    for (NSValue *boxed in _frinedDataArray) {
        FriendListData data;
        [boxed getValue:&data];
    }
    _frinedDataArray = nil;
}

#pragma mark - Downloader delegate

// @ 0xe61e0 — recommend-friend list arrived: alert on a nil response, else
// parse the "List" array into FriendListData rows and reload. Always drops the
// downloader + hides the spinner.
- (void)downloaderFinished:(Downloader *)downloader {
    static NSString *const kDiff[3] = {@"N", @"H", @"Ex"};
    static NSString *const kRankSuffix[5] = {@"S", @"AAA", @"AA", @"A", @"B"};

    NSDictionary *json = [downloader getDataInJSON];
    if (json == nil) {
        // (the binary additionally probes [json["ErrorCode"]
        // isKindOfClass:[NSNumber class]] here,
        //  but discards the result; on a nil response it just shows the failure
        //  alert.)
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                           message:@"通信に失敗しました。\n電波状態"
                                                   @"の良い場所でやり直して下さい。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
    } else {
        NSArray *list = json[@"List"];
        if (list != nil) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in list) {
                FriendListData data;
                data.playerId = entry[@"PlayerId"];
                data.name = entry[@"Name"];
                data.charaId = (short)[entry[@"CharaId"] intValue];
                data.totalScore = [entry[@"TotalScore"] intValue];
                data.bestScore = [entry[@"BestScore"] intValue];
                data.friendShip = 0; // no "FriendShip" key for the recommend list
                for (int d = 0; d < 3; d++) {
                    for (int r = 0; r < 5; r++) {
                        NSString *key =
                            [NSString stringWithFormat:@"Rank%@%@", kDiff[d], kRankSuffix[r]];
                        data.rank[d][r] = [entry[key] intValue];
                    }
                    int fullCombo =
                        [entry[[@"FullCombo" stringByAppendingString:kDiff[d]]] intValue];
                    int perfect = [entry[[@"Perfect" stringByAppendingString:kDiff[d]]] intValue];
                    data.rank[d][5] = fullCombo;
                    data.rank[d][6] = perfect;
                    data.fullComboOnly[d] = (fullCombo - perfect > 0) ? (fullCombo - perfect) : 0;
                    data.perfect[d] = perfect;
                }
                [out addObject:[NSValue value:&data withObjCType:@encode(FriendListData)]];
            }
            [self releaseFriendList];
            _frinedDataArray = [[NSArray alloc] initWithArray:out];
        }
        [self.tableView reloadData];
    }

    _downloader = nil;
    _dummyView.view.hidden = YES;
}

// @ 0xe6c80 — download failed: drop the downloader, hide the spinner, show the
// failure alert.
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    _dummyView.view.hidden = YES;

    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - Networking

// @ 0xe6d60 — POST the recommend-friend request (once), revealing the spinner
// overlay.
- (void)startGetRecommendFriendHttp {
    if (_downloader != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", [[AppDelegate appDelegate] uuId]];
    _downloader = [[Downloader alloc] initWithURL:[StoreUtil getRecommendFriendURL]
                                         delegate:self
                                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                      ContextType:@"application/json"];
    [_downloader startDownloading];
    _dummyView.view.hidden = NO;
}

// @ 0xe6ea4 — back button: pop this list (blocked while a confirm overlay is
// open).
- (void)backButtonFunc {
    if (_freeRequestDetail != nil && [_freeRequestDetail isEnabled]) {
        return;
    }
    neEngine::playSystemSe(2); // cancel/back SE
    [self.navigationController.navigationBar
        setBackgroundImageModern:[UIImage imageNamed:@"fripre_navbar"]];
    [self.navigationController popViewControllerAnimated:!neSceneManager::isPadDisplay()];
}

// @ 0xe5bb4 — cancel the in-flight download (so no late callback fires into a
// dead controller) and unbox the retained row strings before teardown. Kept
// under ARC because it cancels a Downloader; the object-ivar releases are
// ARC-managed.
- (void)dealloc {
    if (_downloader != nil) {
        [_downloader cancel];
    }
    [self releaseFriendList];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
