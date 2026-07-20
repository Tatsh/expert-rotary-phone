//
//  InputKidViewController.mm
//  pop'n rhythmin
//
//  See InputKidViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neEngine / neSceneManager
//  singletons (system SE on decide/cancel, pad-vs-phone branch). The alert
//  message strings are the exact Japanese literals recovered from the
//  __cfstring table. The invite request is a POST of
//  "uuid=<uuid>&player_id=<code>" to StoreUtil +invitedURL.
//

#import "InputKidViewController.h"

#import <QuartzCore/QuartzCore.h> // CALayer cornerRadius (spinner backdrop)

#import "AppDelegate.h"     // +appDelegate / -uuId (device uuid for the request)
#import "StoreUtil.h"       // +invitedURL, urlEncodeString()
#import "UserSettingData.h" // +playerId, +isInputInviteCode / +saveIsInputInviteCode:, tickets
#import "neEngineBridge.h"  // neEngine::playSystemSe, neSceneManager::isPadDisplay

// Own privates (selectors wired up by init).
@interface InputKidViewController ()
- (void)touchedDecideButton:(id)sender;
- (void)touchedBackButton;
- (void)startInviteHttp:(NSString *)code;
@end

@implementation InputKidViewController

// @ 0xe7cec — build the code-entry screen. Two layouts: the entry form (code
// field + decide button) when the code has not yet been redeemed, or a single
// "already used" banner when it has.
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        const CGRect frame = self.view.frame;

        // Full-screen backdrop.
        UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
        [bg setImage:[UIImage imageNamed:@"friman_bg"]];
        [self.view addSubview:bg];

        // Nav-bar custom back button.
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(touchedBackButton)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];

        UIView *lastView;
        if (![UserSettingData isInputInviteCode]) {
            // --- Entry form ---
            UIImage *decideImg = [UIImage imageNamed:@"vcmn_btn_deside"];
            UIButton *decideBtn = [[UIButton alloc] init];
            [decideBtn setBackgroundImage:decideImg forState:UIControlStateNormal];
            decideBtn.frame =
                CGRectMake(184.0f, 166.0f, decideImg.size.width, decideImg.size.height);
            [decideBtn addTarget:self
                          action:@selector(touchedDecideButton:)
                forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:decideBtn];

            UIImage *titleImg = [UIImage imageNamed:@"invite_text"];
            UIImageView *titleView = [[UIImageView alloc] initWithImage:titleImg];
            titleView.frame = CGRectMake(26.0f, 25.0f, titleImg.size.width, titleImg.size.height);
            [self.view addSubview:titleView];

            UIImage *psImg = [UIImage imageNamed:@"fripre_text_ps"];
            UIImageView *psView = [[UIImageView alloc] initWithImage:psImg];
            psView.frame = CGRectMake(26.0f, 77.0f, psImg.size.width, psImg.size.height);
            [self.view addSubview:psView];

            _codeField =
                [[UITextField alloc] initWithFrame:CGRectMake(57.0f, 104.0f, 206.0f, 38.0f)];
            _codeField.enabled = YES;
            _codeField.returnKeyType = UIReturnKeyDone;
            _codeField.delegate = self;
            _codeField.keyboardType = UIKeyboardTypeASCIICapable;
            _codeField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            _codeField.autocorrectionType = UITextAutocorrectionTypeNo;
            _codeField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            _codeField.background = [UIImage imageNamed:@"fripre_idarea_others"];
            _codeField.textAlignment = NSTextAlignmentCenter;
            _codeField.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
            lastView = _codeField;
        } else {
            // --- "already redeemed" banner (centred horizontally, y=50) ---
            UIImage *bannerImg = [UIImage imageNamed:@"invite_text_2"];
            UIImageView *bannerView = [[UIImageView alloc] initWithImage:bannerImg];
            bannerView.frame = CGRectMake((frame.size.width - bannerImg.size.width) * 0.5f,
                                          50.0f,
                                          bannerImg.size.width,
                                          bannerImg.size.height);
            lastView = bannerView;
        }
        [self.view addSubview:lastView];

        // Translucent in-flight spinner, pinned to the top-right.
        _indicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _indicator.frame = CGRectMake(frame.size.width - 36.0f, 4.0f, 32.0f, 32.0f);
        _indicator.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        _indicator.hidesWhenStopped = YES;
        _indicator.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
        _indicator.layer.cornerRadius = 4.0f;
    }
    return self;
}

// viewDidLoad @ 0xe84ec — super-only override, omitted.
// didReceiveMemoryWarning @ 0xe8518 — super-only override, omitted.

// @ 0xe8544
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0xe8548
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_codeField resignFirstResponder];
    return YES;
}

// @ 0xe8570 — cap the code at 8 characters.
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    NSMutableString *s = [[textField text] mutableCopy];
    [s replaceCharactersInRange:range withString:string];
    return s.length < 8;
}

// @ 0xe85d8 — decide button: validate the entered code, then POST it (or show
// why not).
- (void)touchedDecideButton:(id)sender {
    NSString *code = [_codeField.text uppercaseString];
    if (code.length == 0) {
        return;
    }
    [_codeField resignFirstResponder];

    NSString *playerId = [UserSettingData playerId];
    CommonAlertView *alert;
    if (playerId == nil || playerId.length == 0) {
        alert = [[CommonAlertView alloc]
                initWithTitle:@"招待コード"
                      message:@"プレーヤーネームの登録が完了していません。\n登録後"
                              @"に、再度入力して下さい。"
                     delegate:nil
            cancelButtonTitle:nil
            otherButtonTitles:@"OK"];
    } else if (![UserSettingData isInputInviteCode]) {
        if (![[playerId uppercaseString] isEqualToString:code]) {
            [self startInviteHttp:code];
            neEngine::playSystemSe(1);
            return;
        }
        alert = [[CommonAlertView alloc] initWithTitle:@"招待コード"
                                               message:@"自分の招待コードです。"
                                              delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:@"OK"];
    } else {
        alert = [[CommonAlertView alloc] initWithTitle:@"招待コード"
                                               message:@"招待コードは１回しか入力できません。"
                                              delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:@"OK"];
    }
    [alert show];
}

// @ 0xe87fc — back button: play the cancel SE and pop.
- (void)touchedBackButton {
    neEngine::playSystemSe(2);
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xe8840 — invite POST finished. An empty (non-JSON) body means success ->
// grant 5 tickets and mark the code redeemed; a JSON body carries an ErrorCode
// to report.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    BOOL success;
    NSString *message;
    if (json == nil) {
        success = YES;
        message = @"キャラチケットを５枚手に入れました！";
    } else {
        id errorCode = [json objectForKey:@"ErrorCode"];
        if (![errorCode isKindOfClass:[NSNumber class]]) {
            message = @"通信に失敗しました。";
        } else {
            int code = [errorCode intValue];
            if (code == 4) {
                [UserSettingData saveIsInputInviteCode:YES];
                message = @"招待コードの入力は１回までです。";
            } else if (code - 1 <= 1) {
                message = @"招待コードが正しくありません。";
            } else {
                message = @"通信に失敗しました。";
            }
        }
        success = NO;
    }

    _downloader = nil;
    [_indicator stopAnimating];

    if (success) {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"招待コード"
                                                                message:message
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
        [UserSettingData saveCharaTicket:[UserSettingData charaTicket] + 5];
        [UserSettingData saveIsInputInviteCode:YES];
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"招待コード"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xe8a5c — invite POST failed (network/transport error).
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    [_indicator stopAnimating];
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"招待コード"
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xe8b28 — dismissing the success alert (iPhone only) pops back to the
// invite top.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (neSceneManager::isPadDisplay()) {
        return;
    }
    [self touchedBackButton];
}

// @ 0xe8b5c — start the invite HTTP POST ("uuid=<uuid>&player_id=<code>") and
// spin.
- (void)startInviteHttp:(NSString *)code {
    if (_downloader != nil) {
        return;
    }
    NSString *encodedCode = urlEncodeString(code);
    NSString *encodedUuid = urlEncodeString(AppDelegate.appDelegate.uuId);
    NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@", encodedUuid, encodedCode];
    _downloader = [[Downloader alloc] initWithURL:[StoreUtil invitedURL]
                                         delegate:self
                                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                      ContextType:@"application/json"];
    [_downloader startDownloading];
    [_indicator startAnimating];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
