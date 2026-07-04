//
//  CustomWebView.mm
//  pop'n rhythmin
//
//  See CustomWebView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  .mm because -initWithURL: / -pushCloseBtn reach the C++ "ne" engine bridge
//  (neSceneManager::shared / rootViewController / isPadDisplay, neEngine::playSystemSe).
//
//  Sub-view frames in -initWithURL:, -webViewDidFinishLoad: and -observeValueForKeyPath:… have
//  been byte-verified from ARM32 Thumb2 disassembly / literal-pool reads (vmov.f32 / movt).
//  The big-close-button horizontal centre is runtime-structural (depends on page contentSize).
//

#import "CustomWebView.h"

#import "neEngineBridge.h"     // neSceneManager::shared / rootViewController / isPadDisplay, neEngine::playSystemSe
#import "StoreUtil.h"          // +getOfficialPath / +getOfficialTwitterURL
#import "UserSettingData.h"    // +isFollowBonusGet / +treasurePoint / +saveTreasurePoint: / +saveIsFollowBonusGet:
#import "CommonAlertView.h"    // error + reward alerts

@implementation CustomWebView

// .cxx_construct @ 0x5ef8c — compiler-emitted C++ ivar constructor; not hand-written.

// @ 0x5df50 — stash the failure-alert title/message (plain assigns; ARC-strong).
- (void)setErrorMsg:(NSString *)errorMsg text:(NSString *)text {
    _errorTitle = errorMsg;
    _errorText = text;
}

// @ 0x5df80 — remove the contentSize KVO observer, then tear down.
- (void)dealloc {
    // KVO teardown is kept (see -observeValueForKeyPath:… / the addObserver: in -initWithURL:).
    [_webView.scrollView removeObserver:self forKeyPath:@"contentSize"];
    // [super dealloc] is ARC-omitted; object ivars are released automatically.
}

// @ 0x5dfe8 — direct frame construction is disabled; callers must use -initWithURL:.
- (instancetype)initWithFrame:(CGRect)frame {
    return nil;
}

// @ 0x5dfec — build the panel over the root scene view and start loading `url`.
- (instancetype)initWithURL:(NSURL *)url {
    neSceneManager::shared();
    UIViewController *rootVC = neSceneManager::rootViewController();
    CGRect rootFrame = rootVC.view ? rootVC.view.frame : CGRectZero;

    self = [super initWithFrame:rootFrame];
    if (self) {
        _errorTitle = nil;
        _errorText = nil;

        // Panel-sized web-view frame (self.frame with the origin zeroed).
        webViewFrm = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);

        _webView = [[UIWebView alloc] initWithFrame:webViewFrm];
        [_webView setScalesPageToFit:YES];
        _webView.delegate = self;
        [self addSubview:_webView];

        // Attach the panel over the root scene view and raise it to the front.
        [rootVC.view addSubview:self];
        [rootVC.view bringSubviewToFront:self];

        // --- small (top-right) close button ---
        UIImage *closeSmallImg = [UIImage imageNamed:@"inf_bt_close_s"];
        neSceneManager::shared();
        if (!neSceneManager::isPadDisplay()) {
            // phone: x = rf.width − sz.width + 16.0 (vmov.f32 0x41800000), y = 2.0
            // (vmov.f32 0x40000000). Byte-verified.
            CGRect rf = rootVC.view ? rootVC.view.frame : CGRectZero;
            CGSize sz = closeSmallImg ? closeSmallImg.size : CGSizeZero;
            smallBtnFrm = CGRectMake(rf.size.width - sz.width + 16.0f, 2.0f, sz.width, sz.height);
        } else {
            // pad: x=570.0 (movt #0x440e → 0x440e8000), y=15.0 (movt #0x4170 → 0x41700000).
            // Byte-verified.
            CGSize sz = closeSmallImg ? closeSmallImg.size : CGSizeZero;
            smallBtnFrm = CGRectMake(570.0f, 15.0f, sz.width, sz.height);
        }
        _closeBtnSmall = [[UIButton alloc] initWithFrame:smallBtnFrm];
        [_closeBtnSmall setHidden:YES];
        [_closeBtnSmall setBackgroundImage:closeSmallImg forState:UIControlStateNormal];
        [_closeBtnSmall addTarget:self action:@selector(pushCloseBtn)
                 forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeBtnSmall];

        // --- big close button (pinned into the scroll content, revealed by the KVO observer) ---
        UIImage *closeBigImg = [UIImage imageNamed:@"inf_bt_close"];
        _closeBtnBig = [[UIButton alloc] init];
        CGSize contentSize = _webView.scrollView ? _webView.scrollView.contentSize : CGSizeZero;
        CGSize bigSz = closeBigImg ? closeBigImg.size : CGSizeZero;
        // x = (contentSize.width − sz.width) * 0.5 (runtime-structural), y = 0.
        [_closeBtnBig setFrame:CGRectMake((contentSize.width - bigSz.width) * 0.5f, 0.0f,
                                          bigSz.width, bigSz.height)];
        [_closeBtnBig setHidden:YES];
        [_closeBtnBig setBackgroundImage:closeBigImg forState:UIControlStateNormal];
        [_closeBtnBig addTarget:self action:@selector(pushCloseBtn)
               forControlEvents:UIControlEventTouchUpInside];
        [_webView.scrollView addSubview:_closeBtnBig];

        // Observe the scroll view's content size so the big close button can be repositioned once
        // the page lays out (see -observeValueForKeyPath:…).
        [_webView.scrollView addObserver:self forKeyPath:@"contentSize" options:0 context:NULL];

        [_webView loadRequest:[NSURLRequest requestWithURL:url]];

        // --- centred loading spinner ---
        _indicator = [[UIActivityIndicatorView alloc]
                        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        // 50×50 (vmov.f32 0x42480000), centred: x = width*0.5−25 (0xc1c80000=−25.0),
        // y = height*0.5−25. Byte-verified.
        _indicator.frame = CGRectMake(self.frame.size.width * 0.5f - 25.0f,
                                      self.frame.size.height * 0.5f - 25.0f, 50.0f, 50.0f);
        _indicator.backgroundColor = [UIColor blackColor];
        _indicator.alpha = 0.5f;
        [self addSubview:_indicator];
    }
    return self;
}

// @ 0x5e6b8 — small/big close button tapped: play the decide SE, then close.
- (void)pushCloseBtn {
    neSceneManager::shared();
    neEngine::playSystemSe(1);   // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 1)
    [self close];
}

// @ 0x5e6e8 — fade the panel out (0.5s), then fire the close callback and remove it.
- (void)close {
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:(UIViewAnimationOptions)2
                     animations:^{
        // @ 0x5e78d — animation block: fade the panel out.
        self.alpha = 0.0f;
    }
                     completion:^(BOOL finished) {
        // @ 0x5e7b5 — completion block: if a C close callback was registered, invoke it with its
        // param, then detach the panel.
        if (m_AlertViewCallback != NULL) {
            m_AlertViewCallback(m_AlertViewCallbackParam);
        }
        [self removeFromSuperview];
    }];
}

#pragma mark - UIWebViewDelegate

// @ 0x5e808 — clear the URL cache and start the spinner when a load begins.
- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSURLCache *cache = [NSURLCache sharedURLCache];
    [cache setMemoryCapacity:0];
    [cache removeAllCachedResponses];
    [_indicator startAnimating];
}

// @ 0x5e874 — stop the spinner; on first successful load add the Twitter-follow button (unless the
// bonus was already claimed); reveal the small close button.
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_indicator stopAnimating];

    if (![UserSettingData isFollowBonusGet]) {
        UIImage *followImg = [UIImage imageNamed:@"twitter_follow"];
        CGSize sz = followImg ? followImg.size : CGSizeZero;
        CGRect f = self.frame;
        // Follow banner: x = (f.width − sz.width) * 0.5 (vmul.f32 with 0.5), y = 0.
        // Byte-verified; x-centre is runtime-structural.
        UIButton *followBtn = [[UIButton alloc]
            initWithFrame:CGRectMake((f.size.width - sz.width) * 0.5f, 0.0f, sz.width, sz.height)];
        [followBtn setBackgroundImage:followImg forState:UIControlStateNormal];
        [followBtn addTarget:self action:@selector(touchedFollowButton)
            forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:followBtn];

        // Push the web view and the small close button down by the banner height (runtime-structural).
        [_webView setFrame:CGRectMake(webViewFrm.origin.x, webViewFrm.origin.y + sz.height,
                                      webViewFrm.size.width, webViewFrm.size.height - sz.height)];
        [_closeBtnSmall setFrame:CGRectMake(smallBtnFrm.origin.x, smallBtnFrm.origin.y + sz.height,
                                            smallBtnFrm.size.width, smallBtnFrm.size.height)];
    }

    [_closeBtnSmall setHidden:NO];
}

// @ 0x5eb04 — on a real load failure (anything other than NSURLErrorCancelled) close the panel and
// schedule the error alert.
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [_indicator stopAnimating];
    if ([error code] != -999) {   // -999 == NSURLErrorCancelled (0xfffffc19)
        [self close];
        [self performSelector:@selector(showErrorAlert) withObject:nil afterDelay:0];
        [_closeBtnSmall setHidden:NO];
    }
}

// @ 0x5ebb4 — keep in-app navigation only within the official path; open other tapped links
// externally in Safari.
- (BOOL)webView:(UIWebView *)webView
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {   // 0
        NSString *urlStr = request.URL.absoluteString;
        if (![urlStr hasPrefix:[StoreUtil getOfficialPath]]) {
            [[UIApplication sharedApplication] openURL:request.URL];
            return NO;
        }
    }
    return YES;
}

#pragma mark - KVO

// @ 0x5ec5c — the scroll view laid out: reveal the big close button and pin it to the bottom of the
// scrolled content.
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [_closeBtnBig setHidden:NO];

    CGRect bigFrame = _closeBtnBig ? _closeBtnBig.frame : CGRectZero;
    CGSize contentSize = _webView.scrollView ? _webView.scrollView.contentSize : CGSizeZero;
    // y = contentSize.height − 45.0 (DAT_0005ed78 = 0xc2340000 = −45.0; nil-path movt
    // #0xc234 confirms same constant). Byte-verified.
    CGFloat y = contentSize.height + (-45.0f);
    [_closeBtnBig setFrame:CGRectMake(bigFrame.origin.x, y,
                                      bigFrame.size.width, bigFrame.size.height)];
}

#pragma mark -

// @ 0x5ed7c — register the C close callback and its opaque param (raw stores; not ARC-managed).
- (void)SetCloseCallback:(CustomWebViewCloseCallback)callback param:(void *)param {
    m_AlertViewCallback = callback;
    m_AlertViewCallbackParam = param;
}

// @ 0x5ed9c — show the failure alert (only if a message was set).
- (void)showErrorAlert {
    if (_errorText != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:_errorTitle
                                                                message:_errorText
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:nil];
        [alert show];
        // [alert release] is ARC-omitted.
    }
}

// @ 0x5ee38 — open the official Twitter page; first time only, grant the follow bonus (+3000
// treasure points), show a reward alert, and mark the bonus as claimed.
- (void)touchedFollowButton {
    [[UIApplication sharedApplication] openURL:[StoreUtil getOfficialTwitterURL]];

    if (![UserSettingData isFollowBonusGet]) {
        short pts = [UserSettingData treasurePoint];
        [UserSettingData saveTreasurePoint:(short)(pts + 3000)];

        // Reward text recovered from the binary (Ghidra UTF-16 CFString @ 0x1374c8, formatted with
        // the 3000-point award; "OK" dismiss button CFString @ 0x1347f8).
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:[NSString stringWithFormat:@"トレジャーポイント%dPゲットしました", 3000]
                 delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
        [alert show];
        // [alert release] is ARC-omitted.

        [UserSettingData saveIsFollowBonusGet:YES];
    }
}

@end
