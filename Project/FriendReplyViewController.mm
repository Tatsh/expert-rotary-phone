//
//  FriendReplyViewController.mm
//  pop'n rhythmin
//
//  See FriendReplyViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (initWithStyle: @ 0xa7854, viewDidLoad @ 0xa8060,
//  didReceiveMemoryWarning @ 0xa81c0, dealloc @ 0xa81ec,
//  startReplyFriendHttp:reply: @ 0xa82d8, numberOfSectionsInTableView: @
//  0xa8434, tableView:numberOfRowsInSection: @ 0xa8438,
//  tableView:cellForRowAtIndexPath: @ 0xa8460,
//  tableView:titleForHeaderInSection: @ 0xa8580,
//  tableView:didSelectRowAtIndexPath: @ 0xa8584, downloaderFinished: @ 0xa8598,
//  downloaderProceed: @ 0xa861c, downloaderError: @ 0xa8620,
//  releaseReceiveDataArray @ 0xa8720, getFriendRequestFinished @ 0xa87f0,
//  replyFriendFinished @ 0xa8dc0, backButtonFunc @ 0xa90b4). Objective-C++ for
//  the neEngine SE.
//
//  Honesty note: initWithStyle: frame origins are computed from runtime image
//  .size plus literal constants (22.0, 33.0, 140.0 spacer; spinner/placeholder
//  centres 160.0/328.0 on pad, and the half-frame - 10.0/44.0 phone offsets)
//  and are structural, not lost. The rowHeight 78.0/98.0 is DAT_000a8054/58.
//  The request/reply data flow, JSON parsing, sort/reload and alert copy are
//  exact. The two result messages are now decoded byte-exact from the CFString
//  table: reply-success "通信に成功しました。" (@ 0x139748) and the shared
//  network-error "通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
//  (@ 0x134a78). The two POSTs use ContextType "application/json" (@ 0x1351a8),
//  and the cell identifier format is "Cell%ld-%ld" (@ 0x134e38).
//

#import "FriendReplyViewController.h"

#import "AppDelegate.h"     // appDelegate.uuId
#import "CommonAlertView.h" // result alerts
#import "DownloadMain.h"    // getInstance / setFriendRequestedCnt:
#import "Downloader.h"      // request fetch + reply POST
#import "StoreUtil.h"       // +getFriendRequestURL / +replyFriendURL
#import "neEngineBridge.h"  // neEngine::playSystemSe, neSceneManager::isPadDisplay

@implementation FriendReplyViewController {
    UIView *_headView;                 // @164  populated-list header (frirep_messager)
    UIView *_lonelyHeadView;           // @168  empty-list header
    UIViewController *_dummyView;      // @172  loading overlay
    UIImageView *_lonelyImageView;     // @176  "no requests" placeholder
    Downloader *dlGetFriendRequest;    // @180  in-flight request fetch
    Downloader *dlReplyFriend;         // @184  in-flight reply POST
    NSString *_replyPlayerId;          // @188  the player being replied to
    NSMutableArray *_receiveDataArray; // @192  NSValue-wrapped ReplyDataStruct rows
}

// @ 0xa7854 — grouped table styling, message header, loading overlay, back
// button, placeholder. Verified: rowHeight 98/78 (DAT_000a8054/58), messager at
// (22, 33) in a 140-tall header, spinner scale 2x centred (160, 328) pad / half -
// 10 phone, placeholder centred (160, 328) pad / half - 44 phone.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self == nil) {
        return self;
    }

    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGRect viewFrame = self.view.frame;

    self.tableView.rowHeight = isPad ? 98.0f : 78.0f; // DAT_000a8058 / DAT_000a8054
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    // Header views (populated + empty variants). The message art sits inside a
    // 140pt-tall spacer.
    UIImage *messager = [UIImage imageNamed:@"frirep_messager"];
    UIImageView *messagerView = [[UIImageView alloc] initWithImage:messager];
    [messagerView setFrame:CGRectMake(22.0f, 33.0f, messager.size.width, messager.size.height)];
    _headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, messager.size.width, 140.0f)];
    [_headView addSubview:messagerView];
    _lonelyHeadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, messager.size.width, 140.0f)];
    self.tableView.tableHeaderView = _lonelyHeadView;

    if (!isPad) {
        UIImage *bg = [UIImage imageNamed:@"frirep_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [bgView setFrame:CGRectMake(0, 0, bg.size.width, bg.size.height)];
        self.tableView.backgroundView = bgView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Loading overlay + spinner.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = viewFrame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    _dummyView.view.hidden = YES;
    [self.view addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    // Binary passes raw style 2 (0xa7d1c), i.e. Gray, not WhiteLarge (0).
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    if (!isPad) {
        spinner.center =
            CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f - 10.0f);
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
        [backBtn addTarget:self
                      action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }

    // "No requests" placeholder.
    UIImage *lonely = [UIImage imageNamed:@"frirep_empty"];
    _lonelyImageView = [[UIImageView alloc] initWithImage:lonely];
    [_lonelyImageView setFrame:CGRectMake(0, 0, lonely.size.width, lonely.size.height)];
    if (!isPad) {
        _lonelyImageView.center =
            CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f - 44.0f);
    } else {
        _lonelyImageView.center = CGPointMake(160.0f, 328.0f);
    }

    return self;
}

// @ 0xa8060 — kick off the request-list fetch (uuid-only POST) once.
- (void)viewDidLoad {
    [super viewDidLoad];
    if (dlGetFriendRequest == nil) {
        NSString *body = [NSString stringWithFormat:@"uuid=%@", AppDelegate.appDelegate.uuId];
        // ContextType is "application/json" in the binary (0xa815c: __cfstring at
        // 0x1351a8 -> "application/json"), not form-urlencoded.
        dlGetFriendRequest =
            [[Downloader alloc] initWithURL:[StoreUtil getFriendRequestURL]
                                   delegate:self
                                       Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                ContextType:@"application/json"];
        [dlGetFriendRequest startDownloading];
        _dummyView.view.hidden = NO;
    }
}

// @ 0xa81c0
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xa82d8 — accept (reply == 1) / reject (reply == 0) a request: POST and
// show the loading cover.
- (void)startReplyFriendHttp:(NSString *)playerId reply:(int)reply {
    if (dlReplyFriend != nil) {
        return;
    }
    _replyPlayerId = playerId;
    NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@&reply=%d",
                                                AppDelegate.appDelegate.uuId,
                                                playerId,
                                                reply];
    // ContextType is "application/json" in the binary (0xa83ce: same __cfstring at
    // 0x1351a8 -> "application/json"), not form-urlencoded.
    dlReplyFriend = [[Downloader alloc] initWithURL:[StoreUtil replyFriendURL]
                                           delegate:self
                                               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                        ContextType:@"application/json"];
    [dlReplyFriend startDownloading];
    _dummyView.view.hidden = NO;
}

// @ 0xa8434
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xa8438
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _receiveDataArray ? (NSInteger)[_receiveDataArray count] : 0;
}

// @ 0xa8460
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Binary format is "Cell%ld-%ld" (0xa84b4: __cfstring at 0x134e38 -> chars at
    // 0x1029ae = "Cell%ld-%ld"), not "Cell_%ld_%ld".
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld-%ld",
                                                      static_cast<long>(indexPath.section),
                                                      static_cast<long>(indexPath.row)];
    FriendReplyCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FriendReplyCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:identifier];
    }
    [cell setReplyData:_receiveDataArray[indexPath.row]];
    [cell setDelegate:self];
    return cell;
}

// @ 0xa8580
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xa8584 — no navigation on row tap (the OK/NG buttons drive everything).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    static_cast<void>(indexPath.section);
}

// @ 0xa8720 — release each row's retained string fields, then the array itself.
// The binary (MRC) getValue-copies each ReplyDataStruct and -releases its three
// @ string fields (playerId, name, message) before releasing the array; under
// ARC those manual releases fold into the array release, so only the getValue
// loop and the array nil-out remain (behaviour equivalent).
- (void)releaseReceiveDataArray {
    if (_receiveDataArray != nil) {
        for (NSUInteger i = 0; i < [_receiveDataArray count]; i++) {
            ReplyDataStruct data;
            [_receiveDataArray[i] getValue:&data];
        }
        _receiveDataArray = nil;
    }
}

// @ 0xa8598 — dispatch a completed download to the right handler, then hide the
// loading cover.
- (void)downloaderFinished:(Downloader *)downloader {
    if (dlGetFriendRequest == downloader) {
        [self getFriendRequestFinished];
    }
    if (dlReplyFriend == downloader) {
        [self replyFriendFinished];
    }
    _dummyView.view.hidden = YES;
}

// @ 0xa861c
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xa8620 — transport-level failure on either request: clear it, hide cover,
// generic alert.
- (void)downloaderError:(Downloader *)downloader {
    if (dlGetFriendRequest == downloader) {
        dlGetFriendRequest = nil;
    }
    if (dlReplyFriend == downloader) {
        dlReplyFriend = nil;
    }
    _dummyView.view.hidden = YES;
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:nil
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xa87f0 — parse the "Receive" request list into ReplyDataStruct rows; swap
// headers/placeholder and update the badge count.
- (void)getFriendRequestFinished {
    NSDictionary *json = [dlGetFriendRequest getDataInJSON];
    NSString *errorMessage = nil;

    if ([json objectForKey:@"ErrorCode"] == nil) {
        NSArray *receive = [json objectForKey:@"Receive"];
        if (receive != nil && [receive count] != 0) {
            NSMutableArray *ids = [NSMutableArray array];
            NSMutableArray *names = [NSMutableArray array];
            NSMutableArray *messages = [NSMutableArray array];
            NSMutableArray *dates = [NSMutableArray array];
            NSMutableArray *charaIds = [NSMutableArray array];
            for (NSDictionary *entry in receive) {
                NSString *pid = [entry objectForKey:@"PlayerId"];
                NSString *name = [entry objectForKey:@"Name"];
                NSString *message = [entry objectForKey:@"Message"];
                NSNumber *date = [entry objectForKey:@"Date"];
                NSNumber *chara = [entry objectForKey:@"CharaId"];
                if (pid != nil && name != nil && message != nil) {
                    [ids addObject:pid];
                    [names addObject:name];
                    [messages addObject:message];
                    [dates addObject:date];
                    [charaIds addObject:chara];
                }
            }
            if ([ids count] != 0) {
                [self releaseReceiveDataArray];
                _receiveDataArray = [NSMutableArray array];
                for (NSUInteger i = 0; i < [ids count]; i++) {
                    ReplyDataStruct data;
                    memset(&data, 0, sizeof(data));
                    data.playerId = ids[i];
                    data.name = names[i];
                    data.message = messages[i];
                    data.date = dates[i];
                    data.charaId = (short)[charaIds[i] intValue];
                    [_receiveDataArray addObject:[NSValue value:&data
                                                     withObjCType:"{ReplyDataStruct=@@@@s[7i]}"]];
                }
            }
        }

        [self.tableView reloadData];
        NSUInteger count = [_receiveDataArray count];
        if (count == 0) {
            [self.view addSubview:_lonelyImageView];
            self.tableView.tableHeaderView = _lonelyHeadView;
        } else {
            self.tableView.tableHeaderView = _headView;
        }
        self.tableView.scrollEnabled = (count != 0);
        [[DownloadMain getInstance] setFriendRequestedCnt:static_cast<int>(count)];
    } else {
        // Exact CFString @ 0x134a78 -> chars at 0x12b90e (byte-verified UTF-16).
        errorMessage = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
    }

    dlGetFriendRequest = nil;

    if (errorMessage != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:nil
                                                                message:errorMessage
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xa8dc0 — reply POST done: on success drop the replied row + update
// headers/badge; alert either way.
- (void)replyFriendFinished {
    NSDictionary *json = [dlReplyFriend getDataInJSON];
    NSString *message;

    if (json == nil) {
        // Exact CFString @ 0x139748 -> chars at 0x12cc1c (byte-verified UTF-16).
        message = @"通信に成功しました。";
        for (NSUInteger i = 0; i < [_receiveDataArray count]; i++) {
            ReplyDataStruct data;
            [_receiveDataArray[i] getValue:&data];
            if ([data.playerId isEqualToString:_replyPlayerId]) {
                [_receiveDataArray removeObjectAtIndex:i];
                [self.tableView reloadData];
                NSUInteger count = [_receiveDataArray count];
                if (count == 0) {
                    [self.view addSubview:_lonelyImageView];
                    self.tableView.tableHeaderView = _lonelyHeadView;
                } else {
                    self.tableView.tableHeaderView = _headView;
                }
                self.tableView.scrollEnabled = (count != 0);
                [[DownloadMain getInstance] setFriendRequestedCnt:static_cast<int>(count)];
                break;
            }
        }
    } else {
        (void)[[json objectForKey:@"ErrorCode"] isKindOfClass:[NSNumber class]];
        // Exact CFString @ 0x134a78 -> chars at 0x12b90e (byte-verified UTF-16).
        message = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
    }

    dlReplyFriend = nil;

    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:nil
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xa90b4 — cancel SE, restore the hub nav bar art, pop.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xa81ec — the binary (MRC) additionally releases _dummyView / _lonelyImageView
// / _headView / _lonelyHeadView (ARC-automatic here); the cancels and
// releaseReceiveDataArray are the load-bearing cleanup.
- (void)dealloc {
    if (dlGetFriendRequest != nil) {
        [dlGetFriendRequest cancel];
    }
    if (dlReplyFriend != nil) {
        [dlReplyFriend cancel];
    }
    [self releaseReceiveDataArray];
}

@end
