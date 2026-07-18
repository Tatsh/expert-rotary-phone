//
//  FriendRequestViewController.mm
//  pop'n rhythmin
//
//  See FriendRequestViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin:
//    init                                                      @ 0xb1c08
//    dealloc                                                   @ 0xb27bc
//    viewDidLoad                                               @ 0xb28ac
//    didReceiveMemoryWarning                                   @ 0xb2908
//    textFieldShouldBeginEditing:                              @ 0xb2934
//    textFieldShouldReturn:                                    @ 0xb2938
//    textField:shouldChangeCharactersInRange:replacementString:@ 0xb2960
//    touchedRequestButton:                                     @ 0xb29c8
//    touchedFreeRequestButton:                                 @ 0xb2bb0
//    downloaderFinished:                                       @ 0xb2ccc
//    downloaderError:                                          @ 0xb2ecc
//    downloadMainFinished:                                     @ 0xb2f98
//    startFriendRequestHttp:                                   @ 0xb303c
//    backButtonFunc                                            @ 0xb317c
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - The request POST goes to +[StoreUtil requestFriendURL], body
//     "uuid=<uuId>&player_id=<typedId>&message=", Content-Type
//     "application/json". A 200 with an empty (non-JSON) body is treated as
//     success; a JSON body carries a numeric "ErrorCode".
//   - -downloadMainFinished: is the DownloadMainDelegate cancel-friend
//   callback: the controller
//     registers itself as +[DownloadMain getInstance].delegateCancelFriend in
//     -viewDidLoad (and detaches in -dealloc). That protocol is adopted
//     privately in the class extension below; the public header exposes only
//     <UITextFieldDelegate, DownloaderDelegate>, matching the binary's class
//     protocol list.
//   - All alert strings are exact CFString decodes (UTF-16LE). Title
//   "フレンド申請"; OK button.
//     The ErrorCode->message table (codes 0/2/7 reuse the transport-failure
//     string; the isNumber check failing shows the title with a nil message,
//     exactly as the binary does).
//   - init's subview coordinates use the binary's exact offsets. iPad shifts
//   everything by
//     (ox=15, oy=44@iOS7); the top-right spinner sits at view.width-36
//     (DAT_000b2680 = -36.0) on phone / x=214 on iPad.
//

#import "FriendRequestViewController.h"

#import "AppDelegate.h"     // +appDelegate.uuId
#import "CommonAlertView.h" // result / validation alerts
#import "DownloadMain.h"    // +getInstance / delegateCancelFriend / downloadMainFinished:
#import "FreeRequestListViewController.h" // recommended-friend list (right-bar button)
#import "FriendRequestTable.h"            // embedded sent-requests table
#import "StoreUtil.h"                     // +requestFriendURL
#import "UserSettingData.h"               // +playerId (own id)
#import "neEngineBridge.h"                // neSceneManager::isPadDisplay, neEngine::playSystemSe

@interface FriendRequestViewController () <DownloadMainDelegate>
- (void)touchedRequestButton:(id)sender;
- (void)touchedFreeRequestButton:(id)sender;
- (void)startFriendRequestHttp:(NSString *)playerId;
- (void)backButtonFunc;
@end

@implementation FriendRequestViewController {
    UITextField *_playerIdField;         // target player-id entry (max 7 chars, uppercased)
    UIActivityIndicatorView *_indicator; // top-right spinner while the request POSTs
    FriendRequestTable *_requestTable;   // embedded list of already-sent requests
    Downloader *_downloader;             // in-flight friend-request POST
}

// @ 0xb1c08 — lay out the own-id label, the target-id field + request button,
// the spinner, the nav-bar buttons (back + recommended-friend list), and the
// embedded sent-requests table.
// @complete
- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }

    CGRect viewFrame = self.view ? self.view.frame : CGRectZero;

    BOOL isPad = neSceneManager::isPadDisplay();
    BOOL isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    // iPad shifts the whole form; iVar10 (horizontal) / iVar13 (vertical)
    // offsets.
    int ox = isPad ? 15 : 0;
    int oy = (isPad && isOS7) ? 44 : 0;

    // Backdrop: a "friman_bg" image on phone, a clear background on iPad.
    if (!isPad) {
        UIImage *bgImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgImgView = [[UIImageView alloc] initWithImage:bgImg];
        bgImgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        [self.view addSubview:bgImgView];
    } else {
        self.view.backgroundColor = [UIColor clearColor];
    }

    // Request (submit) button.
    UIImage *requestImg = [UIImage imageNamed:@"fripre_btn_presenting"];
    UIButton *requestBtn = [[UIButton alloc] init];
    requestBtn.frame =
        CGRectMake(ox + 176, oy + 185, requestImg.size.width, requestImg.size.height);
    [requestBtn setBackgroundImage:requestImg forState:UIControlStateNormal];
    [requestBtn addTarget:self
                   action:@selector(touchedRequestButton:)
         forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:requestBtn];

    // Instruction / heading art.
    UIImage *textOthersImg = [UIImage imageNamed:@"fripre_text_others"];
    UIImageView *textOthersView = [[UIImageView alloc] initWithImage:textOthersImg];
    textOthersView.frame =
        CGRectMake(ox + 31, oy + 97, textOthersImg.size.width, textOthersImg.size.height);
    [self.view addSubview:textOthersView];

    UIImage *textPsImg = [UIImage imageNamed:@"fripre_text_ps"];
    UIImageView *textPsView = [[UIImageView alloc] initWithImage:textPsImg];
    textPsView.frame = CGRectMake(ox + 40, oy + 157, textPsImg.size.width, textPsImg.size.height);
    [self.view addSubview:textPsView];

    // Target player-id entry field.
    _playerIdField =
        [[UITextField alloc] initWithFrame:CGRectMake(ox + 43, oy + 119, 206.0f, 38.0f)];
    _playerIdField.enabled = YES;
    _playerIdField.returnKeyType = UIReturnKeyDone;
    _playerIdField.delegate = self;
    _playerIdField.keyboardType = UIKeyboardTypeASCIICapable;
    _playerIdField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _playerIdField.autocorrectionType = UITextAutocorrectionTypeNo;
    _playerIdField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _playerIdField.background = [UIImage imageNamed:@"fripre_idarea_others"];
    _playerIdField.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_playerIdField];

    // Top-right progress spinner (revealed while a request POSTs).
    _indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _indicator.frame =
        CGRectMake(isPad ? 214.0f : (viewFrame.size.width - 36.0f), 4.0f, 32.0f, 32.0f);
    _indicator.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    _indicator.hidesWhenStopped = YES;
    _indicator.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
    _indicator.layer.cornerRadius = 4.0f;

    // "PLAYER" caption + the player's own id.
    UIImage *textPlayerImg = [UIImage imageNamed:@"fripre_text_player"];
    UIImageView *textPlayerView = [[UIImageView alloc] initWithImage:textPlayerImg];
    textPlayerView.frame =
        CGRectMake(ox + 31, oy + 25, textPlayerImg.size.width, textPlayerImg.size.height);
    [self.view addSubview:textPlayerView];

    UILabel *ownIdLabel = [[UILabel alloc] init];
    ownIdLabel.frame = CGRectMake(ox + 45, oy + 53, 201.0f, 33.0f);
    ownIdLabel.textAlignment = NSTextAlignmentCenter;
    ownIdLabel.backgroundColor =
        [UIColor colorWithPatternImage:[UIImage imageNamed:@"fripre_idarea_player"]];
    ownIdLabel.textColor = [UIColor blackColor];
    ownIdLabel.text = [UserSettingData playerId];
    [self.view addSubview:ownIdLabel];

    // Custom back button (phone only; iPad keeps the system nav treatment).
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

    // Right-bar button: open the recommended-friend list.
    UIImage *freeImg = [UIImage imageNamed:@"fpl_frindbtn"];
    UIButton *freeBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, freeImg.size.width, freeImg.size.height)];
    [freeBtn setBackgroundImage:freeImg forState:UIControlStateNormal];
    [freeBtn addTarget:self
                  action:@selector(touchedFreeRequestButton:)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:freeBtn];

    // Embedded sent-requests table.
    _requestTable = [[FriendRequestTable alloc] initWithStyle:UITableViewStyleGrouped];
    if (isPad) {
        _requestTable.tableView.autoresizingMask = UIViewAutoresizingNone;
    }
    [self.view addSubview:_requestTable.view];

    return self;
}

// @ 0xb28ac — register as the cancel-friend delegate so a cancel from a row
// updates this screen.
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
    [DownloadMain getInstance].delegateCancelFriend = self;
}

// didReceiveMemoryWarning @ 0xb2908 — super-only override, ARC/omit. @complete

#pragma mark - UITextFieldDelegate

// @ 0xb2934
// @complete
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0xb2938
// @complete
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_playerIdField resignFirstResponder];
    return YES;
}

// @ 0xb2960 — cap the entry at 7 characters (the resulting string must stay
// under 8).
// @complete
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    NSMutableString *newText = [[textField text] mutableCopy];
    [newText replaceCharactersInRange:range withString:string];
    return newText.length < 8;
}

#pragma mark - Actions

// @ 0xb29c8 — validate the typed id and fire the request (blocked while not the
// top VC on phone).
// @complete
- (void)touchedRequestButton:(id)sender {
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self) {
            return;
        }
    }

    [_playerIdField resignFirstResponder];
    NSString *typedId = [[_playerIdField text] uppercaseString];
    if (typedId.length == 0) {
        return;
    }

    NSString *ownId = [UserSettingData playerId];
    if (ownId == nil || ownId.length == 0) {
        CommonAlertView *alert = [[CommonAlertView alloc]
                initWithTitle:@"フレンド申請"
                      message:@"プレーヤーネームの登録が完了していません。\n登録後"
                              @"に、再度実行して下さい。"
                     delegate:nil
            cancelButtonTitle:nil
            otherButtonTitles:@"OK"];
        [alert show];
    } else if (![ownId isEqualToString:typedId]) {
        [self startFriendRequestHttp:typedId];
        neEngine::playSystemSe(1); // decide/confirm SE
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                                                message:@"自分のIDです。"
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xb2bb0 — push the recommended-friend list (only when this is the top VC).
// @complete
- (void)touchedFreeRequestButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"fpl_navbar"]
                                                  forBarMetrics:UIBarMetricsDefault];
    FreeRequestListViewController *vc =
        [[FreeRequestListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:vc animated:!neSceneManager::isPadDisplay()];
    neEngine::playSystemSe(1); // decide/confirm SE
}

#pragma mark - Networking

// @ 0xb303c — POST the friend request (once), revealing the spinner.
// @complete
- (void)startFriendRequestHttp:(NSString *)playerId {
    if (_downloader != nil) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@&message=%@",
                                                [[AppDelegate appDelegate] uuId],
                                                playerId,
                                                @""];
    _downloader = [[Downloader alloc] initWithURL:[StoreUtil requestFriendURL]
                                         delegate:self
                                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                      ContextType:@"application/json"];
    [_downloader startDownloading];
    [_indicator startAnimating];
}

#pragma mark - DownloaderDelegate

// @ 0xb2ccc — request result. Empty (non-JSON) body = success (clear the field
// + reload the sent list); a JSON "ErrorCode" maps to a message. Always drops
// the downloader, stops the spinner, and shows the "フレンド申請" alert.
// @complete
- (void)downloaderFinished:(Downloader *)downloader {
    NSString *message = nil;

    NSDictionary *json = [downloader getDataInJSON];
    if (json == nil) {
        _playerIdField.text = @"";
        [_requestTable reDownloadGetFriendRequest];
        message = @"フレンド申請に成功しました。";
    } else {
        id errorCode = json[@"ErrorCode"];
        if ([errorCode isKindOfClass:[NSNumber class]]) {
            switch ([errorCode intValue]) {
            case FriendResultCommError0:
            case FriendResultCommError2:
            case FriendResultCommError7:
                message = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
                break;
            case FriendResultCommError1:
            case FriendResultInvalidPlayerId:
                message = @"無効なプレーヤーIDです。";
                break;
            case FriendResultSelfListFull:
                message = @"これ以上、フレンドを登録することはできません。";
                break;
            case FriendResultPeerListFull:
                message = @"相手の人は、これ以上、フレンドを登録することはできません。";
                break;
            case FriendResultBlocked:
                message = @"ブロックリスト対象です。";
                break;
            case FriendResultAlreadyRequested:
                message = @"既に申請済み\nまたは、申請を受けています。";
                break;
            case FriendResultAlreadyRegistered:
                message = @"既に登録済みです。";
                break;
            default:
                message = nil;
                break;
            }
        }
    }

    _downloader = nil;
    [_indicator stopAnimating];

    // The binary shows the alert unconditionally (a nil message just yields a
    // titled, empty card).
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xb2ecc — request failed: drop the downloader, stop the spinner, show the
// failure alert.
// @complete
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    [_indicator stopAnimating];

    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - DownloadMainDelegate

// @ 0xb2f98 — a friend request was cancelled elsewhere: acknowledge and reload
// the sent list.
// @complete
- (void)downloadMainFinished:(NSNumber *)success {
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                       message:@"フレンド申請をキャンセルしました。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
    [_requestTable reDownloadGetFriendRequest];
}

#pragma mark - Nav

// @ 0xb317c — back button: restore the friend-hub nav bar art and pop (only
// when top VC). (The binary calls neSceneManager::isPadDisplay before the SE
// and discards the result; elided here as an observably no-op call.)
// @complete
- (void)backButtonFunc {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neEngine::playSystemSe(2); // cancel/back SE
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"friman_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xb27bc — cancel the in-flight request (so no late callback fires into a
// dead controller) and detach from DownloadMain's cancel-friend delegate. Kept
// under ARC because it cancels a Downloader and clears a non-owning delegate
// reference; the object-ivar releases are ARC-managed.
// @complete
- (void)dealloc {
    if (_downloader != nil) {
        [_downloader cancel];
    }
    DownloadMain *dm = [DownloadMain getInstance];
    if (dm.delegateCancelFriend == self) {
        dm.delegateCancelFriend = nil;
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
