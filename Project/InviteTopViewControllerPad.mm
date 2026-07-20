//
//  InviteTopViewControllerPad.mm
//  pop'n rhythmin
//
//  See InviteTopViewControllerPad.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neEngine / neSceneManager
//  singletons (system SE on decide/cancel, root-VC end callback). The
//  open/close fades and the invite POST are byte-verified;
//  initAtNavigationController's panel/field/button frames are the exact float
//  constants recovered from the binary (positions relative to the guest panel
//  are reproduced structurally). The alert / tweet copy is the exact Japanese
//  from the __cfstring table (shared with InputKidViewController).
//

#import "InviteTopViewControllerPad.h"

#import "AppDelegate.h"     // +appDelegate / -uuId (device uuid for the request)
#import "CommonAlertView.h" // modal alerts + CommonAlertViewDelegate
#import "Downloader.h"      // the invite POST + DownloaderDelegate
#import "StoreUtil.h"       // +invitedURL, urlEncodeString()
#import "TwitterUtil.h"     // +tweetWithText:image:
#import "UserSettingData.h" // +playerId, +isInputInviteCode/+save..., tickets
#import "neEngineBridge.h"  // neEngine::playSystemSe, neSceneManager::rootViewController

// Own privates + adopted delegates.
@interface InviteTopViewControllerPad () <UITextFieldDelegate,
                                          DownloaderDelegate,
                                          CommonAlertViewDelegate>
- (void)touchedDecideButton:(id)sender;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)startInviteHttp:(NSString *)code;
- (void)onTweetButton;
@end

@implementation InviteTopViewControllerPad

// @ 0x5c638 — build the combined invite screen and wrap it in a navigation
// controller.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    // family(none) factory: returns the nav, not self, so it cannot assign self;
    // super init returns the receiver in place -> self stays valid (matches the
    // binary's super-init check).
    if (![super init]) {
        return nil;
    }

    const CGRect frame = self.view.frame;

    // Wrap self in its own navigation controller (the return value).
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];

    // Nav-bar custom back button (drives the close fade directly) + nav-bar art.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(startCloseAnimation)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    UIImage *barImage = [UIImage imageNamed:@"invite_navbar"];
    [self.navigationController.navigationBar setBackgroundImage:barImage
                                                  forBarMetrics:UIBarMetricsDefault];
    // On iOS 13 and later the bar background resolves through
    // UINavigationBarAppearance, so the legacy setBackgroundImage: above is
    // ignored at the transparent scroll edge; mirror the image in.
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundImage = barImage;
        appearance.shadowColor = UIColor.clearColor;
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.navigationController.navigationBar.compactScrollEdgeAppearance = appearance;
        }
    }

    // Full-screen backdrop.
    UIImageView *bg =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    [bg setImage:[UIImage imageNamed:@"friman_bg"]];
    [self.view addSubview:bg];

    // Scrolling container holding both panels.
    _scrollView = [[UIScrollView alloc] initWithFrame:frame];
    [self.view addSubview:_scrollView];

    // "player" panel art (centred horizontally, y=330).
    UIImage *playerImg = [UIImage imageNamed:@"invite_view"];
    UIImageView *playerView = [[UIImageView alloc] initWithImage:playerImg];
    playerView.frame = CGRectMake(0, 0, playerImg.size.width, playerImg.size.height);
    playerView.center = CGPointMake(frame.size.width * 0.5f, 330.0f);
    [_scrollView addSubview:playerView];

    // My own invite code, drawn over the id-area strip (used both as the label's
    // size and, via a pattern colour, as its background).
    UIImage *idAreaImg = [UIImage imageNamed:@"fripre_idarea_player"];
    UILabel *idLabel = [[UILabel alloc] init];
    idLabel.frame = CGRectMake(443.0f, 265.0f, idAreaImg.size.width, idAreaImg.size.height);
    idLabel.textAlignment = NSTextAlignmentCenter;
    idLabel.backgroundColor =
        [UIColor colorWithPatternImage:[UIImage imageNamed:@"fripre_idarea_player"]];
    idLabel.textColor = [UIColor blackColor];
    idLabel.text = [UserSettingData playerId];
    [_scrollView addSubview:idLabel];

    // "tweet my code" button.
    UIImage *tweetImg = [UIImage imageNamed:@"bt_twitter"];
    UIButton *tweetBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(469.0f, 446.0f, tweetImg.size.width, tweetImg.size.height)];
    tweetBtn.exclusiveTouch = YES;
    [tweetBtn setBackgroundImage:tweetImg forState:UIControlStateNormal];
    [tweetBtn addTarget:self
                  action:@selector(onTweetButton)
        forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:tweetBtn];

    // "guest" panel art (centred horizontally minus 6pt, y=750).
    UIImage *guestImg = [UIImage imageNamed:@"invite_view_guest"];
    UIImageView *guestView = [[UIImageView alloc] initWithImage:guestImg];
    guestView.frame = CGRectMake(0, 0, guestImg.size.width, guestImg.size.height);
    guestView.center = CGPointMake(frame.size.width * 0.5f - 6.0f, 750.0f); // 0x443b8000
    [_scrollView addSubview:guestView];

    const CGRect gf = guestView.frame;
    if (![UserSettingData isInputInviteCode]) {
        // --- Guest-code entry form (positions anchored to the guest panel) ---
        const CGFloat fieldX = gf.origin.x + 165.0f;
        const CGFloat fieldY = gf.origin.y + 155.0f;

        _codeField = [[UITextField alloc] initWithFrame:CGRectMake(fieldX, fieldY, 206.0f, 38.0f)];
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
        [_scrollView addSubview:_codeField];

        UIImage *decideImg = [UIImage imageNamed:@"vcmn_btn_deside"];
        UIButton *decideBtn = [[UIButton alloc] init];
        decideBtn.frame =
            CGRectMake(fieldX + 230.0f, fieldY, decideImg.size.width, decideImg.size.height);
        decideBtn.exclusiveTouch = YES;
        [decideBtn setBackgroundImage:decideImg forState:UIControlStateNormal];
        [decideBtn addTarget:self
                      action:@selector(touchedDecideButton:)
            forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:decideBtn];
    } else {
        // --- "already redeemed" banner (anchored to the guest panel, added to the
        // view) ---
        UIImage *bannerImg = [UIImage imageNamed:@"invite_text_2"];
        UIImageView *bannerView = [[UIImageView alloc] initWithImage:bannerImg];
        bannerView.frame = CGRectMake(gf.origin.x + 212.0f,
                                      gf.origin.y + 155.0f,
                                      bannerImg.size.width,
                                      bannerImg.size.height);
        [self.view addSubview:bannerView];
    }

    return nav;
}

// dealloc @ 0x5d0fc — super-only override, omitted under ARC.

// @ 0x5d128 — decide button: validate the entered guest code, then POST it (or
// explain why not).
- (void)touchedDecideButton:(id)sender {
    [_codeField resignFirstResponder];
    NSString *code = [_codeField.text uppercaseString];
    if (code.length == 0) {
        return;
    }

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

// @ 0x5d350 — fade the view + its nav view up to opaque over 0.3 s.
- (void)startOpenAnimation {
    if (isAnimationing) {
        return;
    }
    isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0x5d488
- (void)endOpenAnimation {
    isAnimationing = NO;
}

// @ 0x5d4a0 — back button: play the cancel SE, then fade the view + its nav
// view out.
- (void)startCloseAnimation {
    if (isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    isAnimationing = YES;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView commitAnimations];
}

// @ 0x5d5c0 — pull the view, notify the root VC the invite flow closed, clear
// the guard.
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    [root performSelector:@selector(InviteCodeEndCallBack)];
    isAnimationing = NO;
}

// @ 0x5d61c — scroll the panels up so the keyboard does not cover the field.
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [_scrollView setContentOffset:CGPointMake(0, 200.0f) animated:YES];
    return YES;
}

// @ 0x5d654 — scroll back to the top once editing ends.
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [_scrollView setContentOffset:CGPointZero animated:YES];
}

// @ 0x5d698
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_codeField resignFirstResponder];
    return YES;
}

// @ 0x5d6c0 — cap the code at 8 characters.
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    NSMutableString *s = [[textField text] mutableCopy];
    [s replaceCharactersInRange:range withString:string];
    return s.length < 8;
}

// @ 0x5d728 — invite POST finished. An empty (non-JSON) body means success ->
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

    _downloader = nil; // @ release
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

// @ 0x5d944 — invite POST failed (network/transport error).
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil; // @ release
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

// @ 0x5da10 — alert dismissal callback (empty in the binary; the pad screen
// stays put).
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
}

// @ 0x5da14 — start the invite HTTP POST ("uuid=<uuid>&player_id=<code>") and
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

// @ 0x5db50 — "tweet my invite code" button: open the Twitter share sheet.
- (void)onTweetButton {
    NSString *text =
        [NSString stringWithFormat:@"いっしょにポップン "
                                   @"リズミンやろうよ！招待コード「%@"
                                   @"」を入力すれば、キャラチケ5枚もらえるよ♪ #リズミン "
                                   @"https://itunes.apple.com/jp/app/poppun-rizumin/"
                                   @"id626574779?ls=1&mt=8",
                                   [UserSettingData playerId]];
    [TwitterUtil tweetWithText:text image:nil];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
