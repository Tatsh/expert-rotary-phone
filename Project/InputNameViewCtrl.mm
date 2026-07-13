//
//  InputNameViewCtrl.mm
//  pop'n rhythmin
//
//  See InputNameViewCtrl.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the neEngine / neSceneManager singletons
//  (the decide SE and the scene-manager root view controller
//  -InPlayerNameEndCallBack callback). Image / alert-string literals are the
//  exact values recovered from the
//  __cfstring table; the pad layout builds a floating gradient nav-card panel.
//

#import "InputNameViewCtrl.h"

#import <QuartzCore/QuartzCore.h> // CAGradientLayer / CALayer (pad card decoration)

#import "AppDelegate.h"        // +appDelegate / -appVersionNum / -uuId (request fields)
#import "AppFont.h"            // AppFontName() == getFontNameDFSoGei() (pad caption labels)
#import "CommonAlertView.h"    // error alerts
#import "MainViewController.h" // scene root -InPlayerNameEndCallBack
#import "StoreUtil.h"          // +playerNewURL, urlEncodeString()
#import "UserSettingData.h"    // +savePlayerName: / +savePlayerId:
#import "neEngineBridge.h" // neEngine::playSystemSe, neSceneManager::isPadDisplay / rootViewController

// Own privates (button target + the name-registration POST wired up by -init).
@interface InputNameViewCtrl ()
- (void)touchedDecideButton:(id)sender;
- (void)startPlayerNewHttp:(NSString *)name;
- (BOOL)checkUsableCharacter:(NSString *)name;
@end

@implementation InputNameViewCtrl

// @ 0x8f438 — build the player-name form. Phone: full-screen "friman_bg"
// backdrop with caption images. Pad: a floating rounded UINavigationController
// card over a dimmed cover, with the caption drawn as DFSoGei labels.
- (instancetype)init {
    self = [super init];
    neSceneManager::shared();
    BOOL isPad = neSceneManager::isPadDisplay();
    if (self != nil) {
        CGRect frame = self.view ? self.view.frame : CGRectZero;

        // The view the caption / field positions are laid out relative to (added to
        // self.view last): the backdrop on phone, the floating nav card on pad.
        UIView *contentView;
        int baseX = 0;
        int baseY = 0;

        if (!isPad) {
            UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
            [bg setImage:[UIImage imageNamed:@"friman_bg"]];
            contentView = bg;
        } else {
            // Dimmed cover.
            UIView *dim = [[UIView alloc] initWithFrame:frame];
            dim.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
            [self.view addSubview:dim];

            // Floating rounded navigation card, centred in the view.
            UINavigationController *navc = [[UINavigationController alloc] init];
            [navc.view setFrame:CGRectMake(0.0f, 0.0f, 418.0f, 236.0f)];
            navc.view.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
            navc.view.clipsToBounds = YES;
            navc.view.layer.cornerRadius = 2.5f;
            navc.view.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f);
            [navc.navigationBar setBackgroundImage:[UIImage imageNamed:@"inputname_navbar"]
                                     forBarMetrics:UIBarMetricsDefault];

            // Gradient "frame" card, 3pt larger than the nav card, sitting behind it.
            CGRect navFrame = navc.view.frame;
            UIView *gradientCard = [[UIView alloc] init];
            gradientCard.frame = CGRectMake(navFrame.origin.x - 3.0f,
                                            navFrame.origin.y - 3.0f,
                                            navFrame.size.width + 6.0f,
                                            navFrame.size.height + 6.0f);
            gradientCard.clipsToBounds = YES;
            gradientCard.layer.cornerRadius = 5.0f;
            CAGradientLayer *grad = [CAGradientLayer layer];
            grad.frame = CGRectMake(
                0.0f, 0.0f, gradientCard.frame.size.width, gradientCard.frame.size.height);
            grad.colors = @[
                (id)[UIColor colorWithRed:0.5059f green:1.0000f blue:0.9255f alpha:1.0f].CGColor,
                (id)[UIColor colorWithRed:1.0000f green:0.9098f blue:0.4079f alpha:1.0f].CGColor,
                (id)[UIColor colorWithRed:0.9961f green:0.6353f blue:0.6824f alpha:1.0f].CGColor
            ];
            [gradientCard.layer insertSublayer:grad atIndex:0];
            [self.view addSubview:gradientCard];

            // Inner rounded box inside the nav card.
            UIView *innerBox =
                [[UIView alloc] initWithFrame:CGRectMake(0.0f, 55.0f, 301.0f, 120.0f)];
            innerBox.backgroundColor = [UIColor colorWithRed:1.0f
                                                       green:0.7098f
                                                        blue:0.8275f
                                                       alpha:1.0f];
            innerBox.layer.cornerRadius = 5.0f;
            innerBox.layer.borderColor =
                [UIColor colorWithRed:0.7490f green:0.6941f blue:0.6667f alpha:1.0f].CGColor;
            innerBox.layer.borderWidth = 3.0f;
            innerBox.center = CGPointMake(navc.view.frame.size.width * 0.5f, innerBox.center.y);
            [navc.view addSubview:innerBox];

            contentView = navc.view;
            baseX = (int)navFrame.origin.x;
            baseY = (int)(navFrame.origin.y + 44.0f);
        }
        [self.view addSubview:contentView];

        // Decide button.
        UIImage *decideImg = [UIImage imageNamed:@"inputname_btn_deside"];
        UIButton *decideBtn = [[UIButton alloc] init];
        if (!isPad) {
            decideBtn.frame = CGRectMake(
                baseX + 184.0f, baseY + 135.0f, decideImg.size.width, decideImg.size.height);
        } else {
            decideBtn.frame = CGRectMake(0.0f, 0.0f, decideImg.size.width, decideImg.size.height);
            decideBtn.center = CGPointMake(self.view.frame.size.width * 0.5f,
                                           self.view.frame.size.height * 0.5f + 60.0f + 30.0f);
        }
        [decideBtn setBackgroundImage:decideImg forState:UIControlStateNormal];
        [decideBtn addTarget:self
                      action:@selector(touchedDecideButton:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:decideBtn];

        // Caption: images on phone, DFSoGei labels on pad.
        if (!isPad) {
            UIImage *mainImg = [UIImage imageNamed:@"inputname_text_main"];
            UIImageView *mainView = [[UIImageView alloc] initWithImage:mainImg];
            mainView.frame =
                CGRectMake(baseX + 48.0f, baseY + 25.0f, mainImg.size.width, mainImg.size.height);
            [self.view addSubview:mainView];

            UIImage *psImg = [UIImage imageNamed:@"inputname_text_ps"];
            UIImageView *psView = [[UIImageView alloc] initWithImage:psImg];
            psView.frame =
                CGRectMake(baseX + 57.0f, baseY + 54.0f, psImg.size.width, psImg.size.height);
            [self.view addSubview:psView];
        } else {
            UILabel *mainLabel = [[UILabel alloc] init];
            mainLabel.backgroundColor = [UIColor clearColor];
            mainLabel.textColor = [UIColor colorWithRed:0.1882f
                                                  green:0.1882f
                                                   blue:0.1882f
                                                  alpha:1.0f];
            mainLabel.highlightedTextColor = [UIColor whiteColor];
            mainLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];
            mainLabel.textAlignment = NSTextAlignmentCenter;
            mainLabel.frame = CGRectMake(0.0f, baseY + 25.0f, 300.0f, 17.0f);
            mainLabel.center = CGPointMake(self.view.frame.size.width * 0.5f, mainLabel.center.y);
            mainLabel.text = @"プレーヤー名を設定してね！";
            [self.view addSubview:mainLabel];

            UILabel *psLabel = [[UILabel alloc] init];
            psLabel.backgroundColor = [UIColor clearColor];
            psLabel.textColor = [UIColor colorWithRed:0.1882f
                                                green:0.1882f
                                                 blue:0.1882f
                                                alpha:1.0f];
            psLabel.highlightedTextColor = [UIColor whiteColor];
            psLabel.font = [UIFont fontWithName:AppFontName() size:12.0f];
            psLabel.textAlignment = NSTextAlignmentCenter;
            psLabel.frame = CGRectMake(0.0f, baseY + 54.0f, 300.0f, 12.0f);
            psLabel.text = @"(半角英数字12文字まで)";
            psLabel.center = CGPointMake(self.view.frame.size.width * 0.5f, psLabel.center.y);
            [self.view addSubview:psLabel];
        }

        // Name field.
        _nameField = [[UITextField alloc]
            initWithFrame:CGRectMake(baseX + 57.0f, baseY + 80.0f, 206.0f, 38.0f)];
        [_nameField setEnabled:YES];
        [_nameField setReturnKeyType:UIReturnKeyDone];
        [_nameField setDelegate:self];
        [_nameField setKeyboardType:UIKeyboardTypeASCIICapable];
        [_nameField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_nameField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_nameField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_nameField setBackground:[UIImage imageNamed:@"inputname_area_name"]];
        [_nameField setTextAlignment:NSTextAlignmentCenter];
        neSceneManager::shared();
        if (neSceneManager::isPadDisplay()) {
            _nameField.center = CGPointMake(self.view.frame.size.width * 0.5f, _nameField.center.y);
        }
        [self.view addSubview:_nameField];

        // In-flight spinner (configured + stored, but — matching the binary — not
        // added to any view here).
        _indicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _indicator.frame = CGRectMake(frame.size.width - 36.0f, 4.0f, 32.0f, 32.0f);
        _indicator.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        _indicator.hidesWhenStopped = YES;
        _indicator.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        _indicator.layer.cornerRadius = 4.0f;
    }
    return self;
}

// @ 0x90668 — wrap in a UINavigationController (back button hidden, custom bar
// image).
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    if ([self init] == nil) {
        return nil;
    }
    UINavigationController *navc = [[UINavigationController alloc] initWithRootViewController:self];
    [self.navigationItem setHidesBackButton:YES];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"inputname_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    return navc;
}

#pragma mark - Open / close animations

// @ 0x90740
- (void)startOpenAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0x90878
- (void)endOpenAnimation {
    m_IsAnimationing = NO;
}

// @ 0x90890
- (void)startCloseAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x90998 — tear down the panel and notify the scene root the name flow
// ended. (The binary also releases _nameField / _indicator here; automatic
// under ARC.)
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    neSceneManager::shared();
    // The scene root is the app's MainViewController; notify it name entry ended.
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root InPlayerNameEndCallBack];
    m_IsAnimationing = NO;
}

#pragma mark - UITextFieldDelegate

// @ 0x90b68
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0x90b6c
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_nameField resignFirstResponder];
    return YES;
}

// @ 0x90c10 — cap the name at 12 characters.
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    if (textField == _nameField && range.location + range.length + string.length < 13) {
        return YES;
    }
    return NO;
}

#pragma mark - Actions

// @ 0x90b94 — submit a non-empty name, then play the decide SE.
- (void)touchedDecideButton:(id)sender {
    [_nameField resignFirstResponder];
    NSString *name = _nameField.text;
    if (name.length == 0) {
        return;
    }
    [self startPlayerNewHttp:name];
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE
}

#pragma mark - Networking

// @ 0x90f14 — validate the name's charset, then POST "uuid&name&client_ver".
- (void)startPlayerNewHttp:(NSString *)name {
    if (_downloader != nil) {
        return;
    }
    if (![self checkUsableCharacter:name]) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"プレーヤーネーム"
                                           message:@"使用できない文字が含まれています。"
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK"];
        [alert show];
        return;
    }
    int version = [AppDelegate.appDelegate appVersionNum];
    NSString *encodedName = urlEncodeString(name);
    NSString *encodedUuid = urlEncodeString(AppDelegate.appDelegate.uuId);
    NSString *body = [NSString
        stringWithFormat:@"uuid=%@&name=%@&client_ver=%d", encodedUuid, encodedName, version];
    _downloader = [[Downloader alloc] initWithURL:[StoreUtil playerNewURL]
                                         delegate:self
                                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                      ContextType:@"application/json"];
    [_downloader startDownloading];
    [_indicator startAnimating];
}

// @ 0x90c4c — new-player POST finished. A JSON body with a string "PlayerId"
// means success (save the id + name and fade out); anything else is a failure
// alert.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    id playerId = nil;
    BOOL success = NO;
    NSString *message = nil;
    if (json == nil) {
        message = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
    } else {
        playerId = [json objectForKey:@"PlayerId"];
        if ([playerId isKindOfClass:[NSString class]]) {
            success = YES;
        } else {
            // The binary also probes ErrorCode (isKindOfClass:[NSNumber class]) here
            // but discards the result — the message is the generic failure
            // regardless.
            [json objectForKey:@"ErrorCode"];
            message = @"通信に失敗しました。";
        }
    }

    _downloader = nil;
    [_indicator stopAnimating];

    if (success) {
        [UserSettingData savePlayerName:_nameField.text];
        [UserSettingData savePlayerId:playerId];
        [self startCloseAnimation];
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"プレーヤーネーム"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0x90e48 — new-player POST failed (network/transport error).
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    [_indicator stopAnimating];
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"プレーヤーネーム"
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0x91108 — YES when the name consists only of ASCII letters, digits and the
// punctuation "@+-/!#%?$&_" (trimming that set leaves an empty string).
- (BOOL)checkUsableCharacter:(NSString *)name {
    NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
    [set addCharactersInString:@"abcdefghijklmnopqrstuvwxyz"];
    [set addCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    [set addCharactersInString:@"0123456789"];
    [set addCharactersInString:@"@+-/!#%?$&_"];
    return [name stringByTrimmingCharactersInSet:set].length == 0;
}

// Super-only overrides (Ghidra: each only chains to UIViewController) —
// omitted:
//   didReceiveMemoryWarning @ 0x90a28, viewDidLoad @ 0x90a54,
//   viewDidUnload @ 0x90a80, viewWillAppear: @ 0x90aac, viewDidAppear: @
//   0x90ad8, viewWillDisappear: @ 0x90b04, viewDidDisappear: @ 0x90b30.
// shouldAutorotateToInterfaceOrientation: @ 0x90b5c returns portrait-only (kept
// below).

// @ 0x90b5c
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
