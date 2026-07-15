//
//  InputKIDViewCtrl.mm
//  pop'n rhythmin
//
//  See InputKIDViewCtrl.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the neEngine / neSceneManager /
//  neAppEventCenter singletons (decide / cancel SE, pad-vs-phone branch, and
//  the login-context writes the link flow performs). Image / alert-string
//  literals are the exact values recovered from the __cfstring table.
//

#import "InputKIDViewCtrl.h"

#import <QuartzCore/QuartzCore.h> // CALayer cornerRadius (spinner backdrop)

#import "AppDelegate.h"         // +appDelegate / -uuId (device uuid for the request)
#import "MainViewController.h"  // scene root -PopnLinkEndCallBack
#import "StoreUtil.h"           // +linkKidURL, urlEncodeString()
#import "TouchableScrollView.h" // the tap-through form host
#import "UserSettingData.h"     // +konamiId / +saveKonamiId:
#import "neEngineBridge.h"      // neEngine::playSystemSe, neSceneManager / neAppEventCenter

// Own privates (button targets + the link POST wired up by -init).
@interface InputKIDViewCtrl ()
- (void)touchedDecideButton:(id)sender;
- (void)touchedBackButton:(id)sender;
- (void)endDirectCloseAnimation;
- (void)startLinkKidHttp;
- (void)keyboardWasShown:(NSNotification *)notification;
- (void)keyboardWillBeHidden:(NSNotification *)notification;
@end

@implementation InputKIDViewCtrl

@synthesize delegate = _delegate; // getter @ 0xd73f4 / setter @ 0xd7404 (plain assign)

// @ 0xd5888 — build the link form. On pad the fields sit 70pt lower (padOffset)
// and the backdrop is clear (the split-controller card provides it); on phone
// it is a full "friman_bg" screen with a nav-bar back button.
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        CGRect bounds = self.view ? self.view.bounds : CGRectZero;

        oldKonamiId = [UserSettingData konamiId];
        neAppEventCenter::shared();
        oldPassword = neAppEventCenter::inputPassword();

        neSceneManager::shared();
        BOOL isPad = neSceneManager::isPadDisplay();

        // Keyboard scroll offset: 90pt on 3.5" (< 568) screens, 0pt on 4" screens.
        _scrollOffset = (bounds.size.height < 568.0f) ? 90.0f : 0.0f;

        // Tap-through scroll host filling the view.
        _scrollView = [[TouchableScrollView alloc] initWithFrame:bounds];
        [_scrollView setUserInteractionEnabled:YES];
        [self.view addSubview:_scrollView];

        neSceneManager::shared();
        CGFloat padOffset = neSceneManager::isPadDisplay() ? 70.0f : 0.0f;

        // Backdrop.
        if (!isPad) {
            UIImageView *bg = [[UIImageView alloc] initWithFrame:bounds];
            [bg setImage:[UIImage imageNamed:@"friman_bg"]];
            [_scrollView addSubview:bg];
        } else {
            _scrollView.backgroundColor = [UIColor clearColor];
        }

        // Nav-bar back button (phone only).
        if (!isPad) {
            UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
            UIButton *backBtn = [[UIButton alloc]
                initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
            [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
            [backBtn addTarget:self
                          action:@selector(touchedBackButton:)
                forControlEvents:UIControlEventTouchUpInside];
            self.navigationItem.leftBarButtonItem =
                [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        }

        // Decide button.
        UIButton *decideBtn = [[UIButton alloc] init];
        UIImage *decideImg = [UIImage imageNamed:@"vcmn_btn_deside"];
        [decideBtn setBackgroundImage:decideImg forState:UIControlStateNormal];
        decideBtn.frame =
            CGRectMake(185.0f, padOffset + 325.0f, decideImg.size.width, decideImg.size.height);
        [decideBtn addTarget:self
                      action:@selector(touchedDecideButton:)
            forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:decideBtn];

        // Caption images.
        UIImage *titleImg = [UIImage imageNamed:@"input_kid_text"];
        UIImageView *titleView = [[UIImageView alloc] initWithImage:titleImg];
        titleView.frame = isPad ?
                              CGRectMake(40.0f, 35.0f, titleImg.size.width, titleImg.size.height) :
                              CGRectMake(25.0f, 25.0f, titleImg.size.width, titleImg.size.height);
        [_scrollView addSubview:titleView];

        UIImage *kidTextImg = [UIImage imageNamed:@"input_kid_text_kid"];
        UIImageView *kidTextView = [[UIImageView alloc] initWithImage:kidTextImg];
        kidTextView.frame =
            CGRectMake(50.0f, padOffset + 104.0f, kidTextImg.size.width, kidTextImg.size.height);
        [_scrollView addSubview:kidTextView];

        UIImage *pasTextImg = [UIImage imageNamed:@"input_kid_text_pas"];
        UIImageView *pasTextView = [[UIImageView alloc] initWithImage:pasTextImg];
        pasTextView.frame =
            CGRectMake(50.0f, padOffset + 172.0f, pasTextImg.size.width, pasTextImg.size.height);
        [_scrollView addSubview:pasTextView];

        UIImage *otpTextImg = [UIImage imageNamed:@"input_kid_text_pas1time"];
        UIImageView *otpTextView = [[UIImageView alloc] initWithImage:otpTextImg];
        otpTextView.frame =
            CGRectMake(50.0f, padOffset + 240.0f, otpTextImg.size.width, otpTextImg.size.height);
        [_scrollView addSubview:otpTextView];

        // Tappable "link help" banner (tag 300 -> opens the quick-entry page in
        // -touchesBegan:).
        UIImage *linkImg = [UIImage imageNamed:@"input_kid_link"];
        UIImageView *linkView = [[UIImageView alloc] initWithImage:linkImg];
        linkView.frame =
            CGRectMake(31.0f, isPad ? 480.0f : 380.0f, linkImg.size.width, linkImg.size.height);
        [linkView setUserInteractionEnabled:YES];
        [linkView setTag:300];
        [_scrollView addSubview:linkView];

        // KONAMI ID field (pre-filled from the last saved id).
        _kidField = [[UITextField alloc]
            initWithFrame:CGRectMake(64.0f, padOffset + 125.0f, 206.0f, 38.0f)];
        [_kidField setEnabled:YES];
        [_kidField setReturnKeyType:UIReturnKeyDone];
        [_kidField setDelegate:self];
        [_kidField setKeyboardType:UIKeyboardTypeASCIICapable];
        [_kidField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_kidField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_kidField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_kidField setBackground:[UIImage imageNamed:@"conv_inputarea_pass"]];
        [_kidField setTextAlignment:NSTextAlignmentCenter];
        if (oldKonamiId.length != 0) {
            [_kidField setText:oldKonamiId];
        }
        [_scrollView addSubview:_kidField];

        // Secure PASSWORD field (pre-filled from the last entered password).
        _passField = [[UITextField alloc]
            initWithFrame:CGRectMake(64.0f, padOffset + 192.0f, 206.0f, 38.0f)];
        [_passField setEnabled:YES];
        [_passField setSecureTextEntry:YES];
        [_passField setReturnKeyType:UIReturnKeyDone];
        [_passField setDelegate:self];
        [_passField setKeyboardType:UIKeyboardTypeASCIICapable];
        [_passField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_passField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_passField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_passField setBackground:[UIImage imageNamed:@"input_kid_area_pas"]];
        [_passField setTextAlignment:NSTextAlignmentCenter];
        if (oldPassword.length != 0) {
            [_passField setText:oldPassword];
        }
        [_scrollView addSubview:_passField];

        // Secure OTP field.
        _otpField = [[UITextField alloc]
            initWithFrame:CGRectMake(64.0f, padOffset + 269.0f, 206.0f, 38.0f)];
        [_otpField setEnabled:YES];
        [_otpField setSecureTextEntry:YES];
        [_otpField setReturnKeyType:UIReturnKeyDone];
        [_otpField setDelegate:self];
        [_otpField setKeyboardType:UIKeyboardTypeASCIICapable];
        [_otpField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_otpField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_otpField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_otpField setBackground:[UIImage imageNamed:@"pl_pass_bg"]];
        [_otpField setTextAlignment:NSTextAlignmentCenter];
        [_scrollView addSubview:_otpField];

        // Dimmed cover + spinner, hidden until the link POST runs.
        _dummyView = [[UIViewController alloc] init];
        [_dummyView.view setFrame:bounds];
        [_dummyView.view setBackgroundColor:[UIColor colorWithWhite:0.5f alpha:0.0f]];
        [_dummyView.view setHidden:YES];
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
        if (!isPad) {
            [spinner setCenter:CGPointMake(bounds.size.width * 0.5f,
                                           (float)((int)(bounds.size.height * 0.5f) - 10))];
        } else {
            [spinner setCenter:CGPointMake(148.0f, 300.0f)];
        }
        [spinner setTransform:CGAffineTransformMakeScale(2.0f, 2.0f)];
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Keyboard notifications (the binary does not remove these in -dealloc).
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

// @ 0xd6714 — resign the fields and cancel any in-flight link POST (KEEP — real
// cleanup; the binary also releases _dummyView, automatic under ARC).
- (void)dealloc {
    if (_kidField != nil) {
        [_kidField resignFirstResponder];
    }
    if (_passField != nil) {
        [_passField resignFirstResponder];
    }
    if (_otpField != nil) {
        [_otpField resignFirstResponder];
    }
    if (_downloader != nil) {
        [_downloader cancel];
    }
}

#pragma mark - UITextFieldDelegate

// @ 0xd6900
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0xd6904 — scroll the form back to the top when editing ends.
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [_scrollView setContentOffset:CGPointZero animated:YES];
}

// @ 0xd6948 — Return advances KID -> PASSWORD; on the other fields it
// dismisses.
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _kidField) {
        [_passField becomeFirstResponder];
        return NO;
    }
    if (textField == _passField || textField == _otpField) {
        [textField resignFirstResponder];
    }
    return YES;
}

// @ 0xd6cec — per-field length caps: KID <= 256, PASSWORD <= 32, OTP <= 16.
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    NSUInteger total = range.location + range.length + string.length;
    if (textField == _kidField) {
        return total < 0x101;
    }
    if (textField == _passField) {
        return total < 0x21;
    }
    if (textField == _otpField) {
        return total < 0x11;
    }
    return NO;
}

#pragma mark - Actions

// @ 0xd69b0 — submit a non-empty KID + password: save them, disable the link
// buttons while the POST runs, then always play the decide SE.
- (void)touchedDecideButton:(id)sender {
    if (_kidField != nil) {
        [_kidField resignFirstResponder];
    }
    if (_passField != nil) {
        [_passField resignFirstResponder];
    }
    if (_otpField != nil) {
        [_otpField resignFirstResponder];
    }
    NSString *kid = _kidField.text;
    NSString *pass = _passField.text;
    if (kid.length != 0 && pass.length != 0) {
        [UserSettingData saveKonamiId:kid];
        neAppEventCenter::shared();
        neAppEventCenter::setInputPassword(pass);
        neAppEventCenter::shared();
        neAppEventCenter::setLinkButtonsEnabled(false);
        [self startLinkKidHttp];
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE
}

// @ 0xd6af8 — back button: play the cancel SE, then fade out directly (when the
// link is still not enabled) or restore the pop'n-link bar and pop.
- (void)touchedBackButton:(id)sender {
    neSceneManager::shared();
    neEngine::playSystemSe(2); // cancel SE
    neAppEventCenter::shared();
    if (!neAppEventCenter::linkButtonsEnabled()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endDirectCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
        [UIView commitAnimations];
    } else {
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// @ 0xd6c90 — tear down the pushed nav view and notify the scene root the flow
// ended.
- (void)endDirectCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    neSceneManager::shared();
    // The scene root is the app's MainViewController; notify it the pop'n-link
    // flow ended.
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root PopnLinkEndCallBack];
}

#pragma mark - Networking

// @ 0xd7088 — POST "uuid&konami_id&password&otp" to the link endpoint; the OTP
// is omitted (empty) unless one has been entered, and the require-OTP flag is
// set to match.
- (void)startLinkKidHttp {
    if (_downloader != nil) {
        return;
    }
    NSString *encodedKid = urlEncodeString(_kidField.text);
    NSString *encodedPass = urlEncodeString(_passField.text);
    NSString *encodedUuid = urlEncodeString(AppDelegate.appDelegate.uuId);

    NSString *encodedOtp;
    if (_otpField.text != nil && _otpField.text.length != 0) {
        encodedOtp = urlEncodeString(_otpField.text);
        neAppEventCenter::shared();
        neAppEventCenter::setRequireOtpInput(true);
    } else {
        neAppEventCenter::shared();
        neAppEventCenter::setRequireOtpInput(false);
        encodedOtp = @"";
    }

    NSString *body = [NSString stringWithFormat:@"uuid=%@&konami_id=%@&password=%@&otp=%@",
                                                encodedUuid,
                                                encodedKid,
                                                encodedPass,
                                                encodedOtp];
    _downloader = [[Downloader alloc] initWithURL:[StoreUtil linkKidURL]
                                         delegate:self
                                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                      ContextType:@"application/json"];
    [_downloader startDownloading];
    [_dummyView.view setHidden:NO];
}

// @ 0xd6d90 — link POST finished. A JSON body with a non-empty "RefId" is
// success (store it, enable the link buttons); otherwise report the appropriate
// failure message.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *message = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
    BOOL success = NO;
    if (json != nil) {
        id refId = [json objectForKey:@"RefId"];
        if (refId == nil) {
            id errorCode = [json objectForKey:@"ErrorCode"];
            if ([errorCode intValue] == 4) {
                message = @"KONAMI ID または PASSWORD が正しくありません。";
            }
        } else if ([refId length] != 0) {
            neAppEventCenter::shared();
            neAppEventCenter::setLinkRefId(refId);
            message = @"通信に成功しました。";
            success = YES;
        } else {
            message = @"アクティブな\ne-AMUSEMENT PASS が\n設定されていません。";
        }
    }

    _downloader = nil;
    [_dummyView.view setHidden:YES];

    if (success) {
        neAppEventCenter::shared();
        neAppEventCenter::setLinkButtonsEnabled(true);
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"KONAMI ID"
                                                                message:message
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"KONAMI ID"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xd6fa8 — link POST failed (network/transport error).
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    [_dummyView.view setHidden:YES];
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"KONAMI ID"
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - CommonAlertViewDelegate

// @ 0xd7284 — dismissing the alert: on pad, tell the split controller to
// rebuild its left column and re-enter the score checker; on phone, just pop
// back.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        [_delegate reloadLeftView];
        [_delegate onScoreCheckerButtonTouched:nil];
    } else {
        [self touchedBackButton:nil];
    }
}

#pragma mark - Keyboard notifications

// @ 0xd72e4 — scroll the form up so the active field clears the keyboard.
- (void)keyboardWasShown:(NSNotification *)notification {
    [_scrollView setContentOffset:CGPointMake(0.0f, _scrollOffset) animated:YES];
}

// @ 0xd7328 — scroll the form back down.
- (void)keyboardWillBeHidden:(NSNotification *)notification {
    [_scrollView setContentOffset:CGPointZero animated:YES];
}

#pragma mark - Touches

// @ 0xd7358 — tapping the "link help" banner (tag 300) opens the quick-entry
// web page.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.view.tag == 300) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        [[UIApplication sharedApplication]
                      openURL:[NSURL URLWithString:@"https://id.konami.net/quick/Entry"]
                      options:@{}
            completionHandler:nil];
#else
        [[UIApplication sharedApplication]
            openURL:[NSURL URLWithString:@"https://id.konami.net/quick/Entry"]];
#endif
    }
}

// Super-only overrides (Ghidra: each only chains to UIViewController) —
// omitted:
//   didReceiveMemoryWarning @ 0xd66e8, viewDidLoad @ 0xd67ec, viewDidUnload @
//   0xd6818, viewWillAppear: @ 0xd6844, viewDidAppear: @ 0xd6870,
//   viewWillDisappear: @ 0xd689c, viewDidDisappear: @ 0xd68c8.

// @ 0xd68f4
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
