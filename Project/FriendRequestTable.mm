//
//  FriendRequestTable.mm
//  pop'n rhythmin
//
//  See FriendRequestTable.h. Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:                      @ 0xb7148
//    dealloc                             @ 0xb794c
//    viewDidLoad                         @ 0xb79e8
//    didReceiveMemoryWarning             @ 0xb7a28
//    reDownloadGetFriendRequest          @ 0xb7a54
//    numberOfSectionsInTableView:        @ 0xb7b98
//    tableView:numberOfRowsInSection:    @ 0xb7b9c
//    tableView:cellForRowAtIndexPath:    @ 0xb7bc4
//    tableView:titleForHeaderInSection:  @ 0xb7cd0
//    tableView:didSelectRowAtIndexPath:  @ 0xb7cd4
//    releaseSendDataArray                @ 0xb7cd8
//    backButtonFunc                      @ 0xb7d9c
//    downloaderFinished:                 @ 0xb7e38
//    downloaderProceed:                  @ 0xb84dc
//    downloaderError:                    @ 0xb84e0
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - The sent-request list is POSTed to +[StoreUtil getFriendRequestURL] (body "uuid=<uuId>",
//     Content-Type "application/json"). The response's "Send" array is parsed into NSValue-wrapped
//     records boxed with the binary's literal Obj-C type-encoding "{RequestDataStruct=@@@s}", which
//     is layout-identical to FriendRequestCell's FriendRequestDataStruct (playerId / name / date /
//     charaId) — so the boxed values feed -[FriendRequestCell setFriendData:] directly.
//   - The binary builds four parallel NSMutableArrays (ids / names / dates / charaIds) in a first
//     pass, then assembles each record in a second pass; that is behaviourally identical to the
//     direct per-entry assembly used here. Under ARC the struct's NSString* fields are held
//     __unsafe_unretained (see FriendRequestCell.h), so -releaseSendDataArray only unboxes — it
//     matches the sibling -[FreeRequestListViewController releaseFriendList]. (The binary also
//     manually -retain'd/-release'd the boxed id fields; that is a no-op under this ARC port.)
//   - Error alert strings are exact CFString decodes (UTF-16LE): title nil, OK button, and the
//     failure message "通信に失敗しました。\n電波状態の良い場所でやり直して下さい。" (used both when
//     the response carries an "ErrorCode" and on a transport error).
//   - The init frame arithmetic uses the binary's exact constants (verified DAT_000b76xx floats);
//     the iPad table-height base is the messiest part of the original and is reproduced as closely
//     as the decompile allows (see the comment in -initWithStyle:).
//

#import "FriendRequestTable.h"

#import "Downloader.h"          // Downloader + DownloaderDelegate
#import "FriendRequestCell.h"   // one row per sent request (setFriendData:)
#import "CommonAlertView.h"     // error alerts
#import "AppDelegate.h"         // +appDelegate.uuId / .displayType
#import "StoreUtil.h"           // +getFriendRequestURL
#import "neEngineBridge.h"      // neSceneManager::isPadDisplay, neEngine::playSystemSe

@interface FriendRequestTable () <DownloaderDelegate>
- (void)releaseSendDataArray;
- (void)backButtonFunc;
@end

@implementation FriendRequestTable {
    UIViewController *_dummyView;      // dimmed overlay hosting the download spinner
    UIImageView *_lonelyImageView;     // "no sent requests" placeholder art
    Downloader *dlGetFriendRequest;    // in-flight sent-request-list request
    NSMutableArray *_sendDataArray;    // parsed rows (NSValue-wrapped {RequestDataStruct=@@@s})
}

// @ 0xb7148 — build the background plate, dimmed dummy overlay + spinner, and the back button.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        UIImage *plateImg = [UIImage imageNamed:@"fripre_table"];
        CGSize plateSize = plateImg ? plateImg.size : CGSizeZero;

        BOOL isPad = neSceneManager::isPadDisplay();
        BOOL isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;

        CGRect viewFrame = self.view ? self.view.frame : CGRectZero;

        // Table frame: x = 4, y = (iPad & iOS7) ? 278 : 234 (DAT_000b76xx). Height derives from the
        // host view height: phone = view.height - 239 (DAT_000b7610 -234, minus a 5pt bottom
        // margin); iPad adds DAT_000b7618 (+140). (The iPad base is the murkiest part of the
        // original; this reproduces its net effect: view.height - 99.)
        CGFloat tableY = (isPad && isOS7) ? 278.0f : 234.0f;
        CGFloat tableH = viewFrame.size.height - 239.0f;
        if (isPad) {
            tableH += 140.0f;
        }
        self.tableView.frame = CGRectMake(4.0f, tableY, plateSize.width, tableH);
        self.tableView.rowHeight = 57.0f;   // 0x42640000
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.layer.cornerRadius = 12.0f;
        self.tableView.clipsToBounds = YES;

        // Clear header spacer: 40pt (50pt on the tall-screen tier @ iOS7), +10pt on iPad.
        CGFloat headerH = ([AppDelegate appDelegate].displayType == 2 && isOS7) ? 50.0f : 40.0f;
        if (isPad) {
            headerH += 10.0f;
        }
        UIView *headerView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, plateSize.width, headerH)];
        headerView.backgroundColor = [UIColor clearColor];
        self.tableView.tableHeaderView = headerView;

        // Background plate (its own height + 100pt of slack). iPad overlays a "fripre_table_font".
        UIImageView *plateView = [[UIImageView alloc] initWithImage:plateImg];
        plateView.frame = CGRectMake(0, 0, plateSize.width, plateSize.height + 100.0f);   // DAT_000b7948
        if (isPad) {
            UIImage *fontImg = [UIImage imageNamed:@"fripre_table_font"];
            UIImageView *fontView = [[UIImageView alloc] initWithImage:fontImg];
            fontView.frame = CGRectMake(27.0f, 10.0f, fontImg.size.width, fontImg.size.height);
            [plateView addSubview:fontView];
        }
        self.tableView.backgroundView = plateView;

        // Dimmed dummy overlay carrying the download spinner (hidden until viewDidLoad).
        _dummyView = [[UIViewController alloc] init];
        _dummyView.view.frame = CGRectMake(4.0f, tableY, plateSize.width, tableH);
        _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.view.hidden = YES;
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        spinner.center = CGPointMake(plateSize.width * 0.5f, (int)(tableH * 0.5f) - 10);
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Custom back button in the nav item.
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return self;
}

// @ 0xb79e8 — kick off the initial sent-request-list download.
- (void)viewDidLoad {
    [super viewDidLoad];
    [self reDownloadGetFriendRequest];
}

// didReceiveMemoryWarning @ 0xb7a28 — super-only override, ARC/omit.

// @ 0xb7a54 — POST the sent-request-list request (once), revealing the spinner overlay.
- (void)reDownloadGetFriendRequest {
    if (dlGetFriendRequest != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@", [[AppDelegate appDelegate] uuId]];
    dlGetFriendRequest = [[Downloader alloc]
        initWithURL:[StoreUtil getFriendRequestURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/json"];
    [dlGetFriendRequest startDownloading];
    _dummyView.view.hidden = NO;
}

#pragma mark - Table

// @ 0xb7b98
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xb7b9c
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sendDataArray ? [_sendDataArray count] : 0;
}

// @ 0xb7bc4
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell_%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    FriendRequestCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[FriendRequestCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:identifier];
    }
    [cell setFriendData:[_sendDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0xb7cd0
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xb7cd4 — rows are not selectable (the per-row Cancel button drives the action).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark - Sent-request storage

// @ 0xb7cd8 — unbox each record (its __unsafe_unretained NSString fields), then drop the array.
- (void)releaseSendDataArray {
    if (_sendDataArray == nil) {
        return;
    }
    for (NSValue *boxed in _sendDataArray) {
        FriendRequestDataStruct data;
        [boxed getValue:&data];
    }
    _sendDataArray = nil;
}

#pragma mark - Downloader delegate

// @ 0xb7e38 — sent-request list arrived. On an "ErrorCode" show the failure alert; otherwise parse
// the "Send" array into rows, swap in / remove the empty placeholder, and reload. Always drops the
// downloader and hides the spinner.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [dlGetFriendRequest getDataInJSON];
    id errorCode = json[@"ErrorCode"];
    [self releaseSendDataArray];

    NSString *alertMessage = nil;
    if (errorCode != nil) {
        // 通信に失敗しました。\n電波状態の良い場所でやり直して下さい。 (CFString @ 0x134a78)
        alertMessage = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
    } else {
        NSArray *send = json[@"Send"];
        if (send != nil && [send count] != 0) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *entry in send) {
                NSString *playerId = entry[@"PlayerId"];
                NSString *name = entry[@"Name"];
                NSString *date = entry[@"Date"];
                id charaId = entry[@"CharaId"];
                if (playerId != nil && name != nil && date != nil) {
                    FriendRequestDataStruct data;
                    data.playerId = playerId;
                    data.name = name;
                    data.date = date;
                    data.charaId = (short)[charaId intValue];
                    // Binary boxes with the literal encoding "{RequestDataStruct=@@@s}" (layout-
                    // identical to FriendRequestDataStruct).
                    [out addObject:[NSValue value:&data withObjCType:"{RequestDataStruct=@@@s}"]];
                }
            }
            if ([out count] != 0) {
                _sendDataArray = [NSMutableArray arrayWithArray:out];
            }
        }

        if (_sendDataArray == nil || [_sendDataArray count] == 0) {
            // No sent requests: show the "fripre_empty" placeholder centred in the view and stop
            // the table scrolling.
            CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
            UIImage *emptyImg = [UIImage imageNamed:@"fripre_empty"];
            _lonelyImageView = [[UIImageView alloc] initWithImage:emptyImg];
            _lonelyImageView.frame = CGRectMake(
                viewFrame.size.width * 0.5f - emptyImg.size.width * 0.5f,
                viewFrame.size.height * 0.5f - emptyImg.size.height * 0.5f,
                emptyImg.size.width, emptyImg.size.height);
            [self.view addSubview:_lonelyImageView];
            self.tableView.scrollEnabled = NO;
        } else {
            if (_lonelyImageView != nil) {
                [_lonelyImageView removeFromSuperview];
                _lonelyImageView = nil;
            }
            self.tableView.scrollEnabled = YES;
        }
        [self.tableView reloadData];
    }

    dlGetFriendRequest = nil;

    if (alertMessage != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:alertMessage
                 delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
        [alert show];
    }

    _dummyView.view.hidden = YES;
}

// @ 0xb84dc — per-chunk progress: nothing to do.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xb84e0 — download failed: drop the downloader, hide the spinner, show the failure alert.
- (void)downloaderError:(Downloader *)downloader {
    dlGetFriendRequest = nil;
    _dummyView.view.hidden = YES;

    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:nil
              message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
             delegate:nil
    cancelButtonTitle:nil
    otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - Nav

// @ 0xb7d9c — back button: restore the friend-hub nav bar art and pop.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);   // cancel/back SE
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xb794c — unbox the retained row strings and cancel any in-flight download (so no late callback
// fires into a dead controller). Kept under ARC because it cancels a Downloader; the object-ivar
// releases are ARC-managed.
- (void)dealloc {
    [self releaseSendDataArray];
    if (dlGetFriendRequest != nil) {
        [dlGetFriendRequest cancel];
        dlGetFriendRequest = nil;
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
