//
//  InputOTPViewCtrl.mm
//  pop'n rhythmin
//
//  See InputOTPViewCtrl.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the neEngine / neSceneManager singletons
//  (the decide / cancel system SE and the root view controller PopnLink
//  callback). The image resource names are the exact literals recovered from
//  the __cfstring table.
//

#import "InputOTPViewCtrl.h"

#import "CheckerCategoryViewController.h" // owner type + -startGetArcadeScoreHttpWithOtp:
#import "MainViewController.h"            // scene root -PopnLinkEndCallBack
#import "TouchableScrollView.h"           // the tap-through form host
#import "neEngineBridge.h" // neEngine::playSystemSe, neSceneManager::rootViewController

// Own privates (button targets wired up by -initWithCategoryView:).
@interface InputOTPViewCtrl ()
- (void)touchedDecideButton:(id)sender;
- (void)touchedBackButton:(id)sender;
- (void)keyboardWasShown:(NSNotification *)notification;
- (void)keyboardWillBeHidden:(NSNotification *)notification;
@end

@implementation InputOTPViewCtrl

// @ 0x78d18
// @complete
- (instancetype)initWithCategoryView:(CheckerCategoryViewController *)categoryView {
    self = [super init];
    if (self != nil) {
        _categoryView = categoryView;

        // Scroll offset depends on the screen height: 90pt on 3.5" (< 568) screens,
        // 0pt on 4" screens. Defaults to 90 when the view is not yet loaded.
        CGRect bounds;
        if (self.view != nil) {
            bounds = self.view.bounds;
            _scrollOffset = (bounds.size.height < 568.0f) ? 90.0f : 0.0f;
        } else {
            bounds = CGRectZero;
            _scrollOffset = 90.0f;
        }

        // Tap-through scroll host filling the view.
        _scrollView = [[TouchableScrollView alloc] initWithFrame:bounds];
        [_scrollView setUserInteractionEnabled:YES];
        [self.view addSubview:_scrollView];

        // Full-screen backdrop.
        UIImageView *bg = [[UIImageView alloc] initWithFrame:bounds];
        [bg setImage:[UIImage imageNamed:@"friman_bg"]];
        [_scrollView addSubview:bg];

        // Custom back button in the navigation item's left slot.
        UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backButton = [[UIButton alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, backImage.size.width, backImage.size.height)];
        [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(touchedBackButton:)
             forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];

        // Decide button.
        UIButton *decideButton = [[UIButton alloc] init];
        UIImage *decideImage = [UIImage imageNamed:@"vcmn_btn_deside"];
        [decideButton setBackgroundImage:decideImage forState:UIControlStateNormal];
        [decideButton
            setFrame:CGRectMake(185.0f, 125.0f, decideImage.size.width, decideImage.size.height)];
        [decideButton addTarget:self
                         action:@selector(touchedDecideButton:)
               forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:decideButton];

        // "Enter your one-time password" label.
        UIImage *labelImage = [UIImage imageNamed:@"input_kid_text_pas1time"];
        UIImageView *label = [[UIImageView alloc] initWithImage:labelImage];
        [label setFrame:CGRectMake(50.0f, 25.0f, labelImage.size.width, labelImage.size.height)];
        [_scrollView addSubview:label];

        // Secure OTP field.
        _otpField = [[UITextField alloc] initWithFrame:CGRectMake(64.0f, 54.0f, 206.0f, 38.0f)];
        [_otpField setEnabled:YES];
        [_otpField setSecureTextEntry:YES];
        [_otpField setReturnKeyType:UIReturnKeyDone];
        [_otpField setDelegate:self];
        [_otpField setKeyboardType:UIKeyboardTypeASCIICapable];
        [_otpField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_otpField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_otpField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_otpField setBackground:[UIImage imageNamed:@"input_kid_area_pas"]];
        [_otpField setTextAlignment:NSTextAlignmentCenter];
        [_scrollView addSubview:_otpField];

        // Dimmed cover + spinner, hidden until the parent runs the score sync.
        _dummyView = [[UIViewController alloc] init];
        [_dummyView.view setFrame:bounds];
        [_dummyView.view setBackgroundColor:[UIColor colorWithWhite:0.5f alpha:0.0f]];
        [_dummyView.view setHidden:YES];
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
        [spinner setCenter:CGPointMake(bounds.size.width * 0.5f,
                                       static_cast<float>(
                                           static_cast<int>(bounds.size.height * 0.5f) - 10))];
        [spinner setTransform:CGAffineTransformMakeScale(2.0f, 2.0f)];
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Keyboard notifications (removed in -dealloc).
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

// dealloc @ 0x79544 — the binary only releases _dummyView (both the -release and
// the [super dealloc] tail are ARC-implicit) and does NOT unregister the two
// NSNotificationCenter observers added in -initWithCategoryView:; there is no
// -removeObserver: call in the disassembly (verified: it loads the _dummyView
// ivar + "release", sends it, then chains "dealloc" to super — nothing else).
// Nothing to preserve under ARC, so -dealloc is omitted.
// @complete

// @ 0x79698
// @complete
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark - UITextFieldDelegate

// @ 0x796a4
// @complete
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0x796a8
// @complete
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _otpField) {
        [textField resignFirstResponder];
    }
    return YES;
}

// @ 0x798bc — cap the field at 16 characters.
// @complete
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    if (textField == _otpField && range.location + range.length + string.length < 17) {
        return YES;
    }
    return NO;
}

#pragma mark - Actions

// @ 0x796d4 — submit a non-empty code to the owner, then pop; always plays the
// SE.
// @complete
- (void)touchedDecideButton:(id)sender {
    NSString *code = _otpField.text;
    if (code.length != 0) {
        [_categoryView startGetArcadeScoreHttpWithOtp:code];
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
        [self.navigationController popViewControllerAnimated:YES];
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE
}

// @ 0x797c4
// @complete
- (void)touchedBackButton:(id)sender {
    neSceneManager::shared();
    neEngine::playSystemSe(2); // cancel SE
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"ppc_navbar"]
                                                  forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x79860 — tear down the pushed nav view and notify the app root that the
// applilink flow has ended.
// @complete
- (void)endDirectCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    neSceneManager::shared();
    // The scene root is the app's MainViewController; notify it the applilink
    // flow ended.
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root PopnLinkEndCallBack];
}

#pragma mark - Keyboard notifications

// @ 0x798f8 — registered in -initWithCategoryView:; no-op in the binary.
// @complete
- (void)keyboardWasShown:(NSNotification *)notification {
}

// @ 0x798fc — registered in -initWithCategoryView:; no-op in the binary.
// @complete
- (void)keyboardWillBeHidden:(NSNotification *)notification {
}

// Super-only overrides (Ghidra: each only chains to UIViewController) —
// omitted:
//   didReceiveMemoryWarning @ 0x79518, viewDidLoad @ 0x79590,
//   viewDidUnload @ 0x795bc, viewWillAppear: @ 0x795e8, viewDidAppear: @
//   0x79614, viewWillDisappear: @ 0x79640, viewDidDisappear: @ 0x7966c.

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
