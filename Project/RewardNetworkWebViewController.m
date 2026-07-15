//
//  RewardNetworkWebViewController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See RewardNetworkWebViewController.h for the class overview and ivar map.
//

#import "RewardNetworkWebViewController.h"
#import "NSString+URLDecode.h" // -URLDecodedString (SDK percent-decode category)
#import "RewardNetworkIndicator.h"
#import "RewardNetworkMessage.h"
#import "RewardNetworkUtilities.h"

@implementation RewardNetworkWebViewController

// @ 0xec4d8
- (instancetype)init {
    self = [super init];
    return self;
}

// @ 0xec514
- (void)loadView {
    [super loadView];

    CGRect screenBounds = CGRectZero;
    UIScreen *screen = [UIScreen mainScreen];
    if (screen) {
        screenBounds = [screen bounds];
    }

    // Web view fills the screen below a 45pt navigation bar (Ghidra y-origin
    // 0x42340000 == 45.0f).
    CGRect webFrame =
        CGRectMake(0.0f, 45.0f, screenBounds.size.width, screenBounds.size.height);
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    _webView = [[WKWebView alloc] initWithFrame:webFrame
                                  configuration:[[WKWebViewConfiguration alloc] init]];
    _webView.navigationDelegate = self;
#else
    _webView = [[UIWebView alloc] initWithFrame:webFrame];
    [_webView setDelegate:self];
#endif
    [self.view addSubview:_webView];

    // Top navigation bar with a single "close" button on the left.
    _navigationBar = [[UINavigationBar alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, screenBounds.size.width, 45.0f)];
    UINavigationItem *item = [[UINavigationItem alloc]
        initWithTitle:[RewardNetworkMessage localizedMessage:@"RewardNetworkAppListTitle"]];
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc]
        initWithTitle:[RewardNetworkMessage localizedMessage:@"RewardNetworkAppListCloseButton"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(btnCloseClicked:)];
    [item setLeftBarButtonItem:closeItem];
    [_navigationBar pushNavigationItem:item animated:NO];
    [self.view addSubview:_navigationBar];

    // Loading spinner covering the view.
    _indicator = [[RewardNetworkIndicator alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_indicator];
}

// @ 0xec868
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
- (void)webView:(WKWebView *)webView
    didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self updateIndicator:YES];
}
#else
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self updateIndicator:YES];
}
#endif

// @ 0xec87c
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xec8a8
- (void)setNavigationBarHidden:(BOOL)hidden {
    [self setIsNavigationBarHidden:hidden];
}

// @ 0xec8b8
- (void)loadRequestWithURL:(NSURL *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id<RewardNetworkWebViewDelegate>)delegate {
    // Attach the panel: onto the caller's parentView, or onto the key window.
    if ([self parentView] == nil) {
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        if (window) {
            [window addSubview:self.view];
        }
    } else {
        [[self parentView] addSubview:self.view];
    }

    NSString *fullURL = [RewardNetworkUtilities appendParametersToURL:(NSString *)url
                                                           parameters:parameters];
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
    [request setTimeoutInterval:30.0];                                 // Ghidra 0x403e0000 == 30.0
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; // 1

    [self setDelegate:delegate];

    if (_webView == nil) {
        [self loadView];
    }

    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [self rotateWebViewWithInterfaceOrientation:orientation duration:0.0];

    [_webView loadRequest:request];
}

// @ 0xecb28
- (void)viewDidDisappear:(BOOL)animated {
    [self appliListClosed];
    if ([self delegate] != nil &&
        [[self delegate] respondsToSelector:@selector(appListDidDisappear)]) {
        [[self delegate] appListDidDisappear];
    }
}

// @ 0xecbd8 — a "command=close" query closes the panel; otherwise hide the
// indicator and notify the delegate.
- (void)handleNavigationFinishedForQuery:(NSString *)query {
    if (query != nil && [query rangeOfString:@"command=close"].location != NSNotFound) {
        // The page signalled a close.
        [self appliListClosed];
        return;
    }

    [self updateIndicator:NO];
    if ([self delegate] != nil &&
        [[self delegate] respondsToSelector:@selector(appListDidAppear)]) {
        [[self delegate] appListDidAppear];
    }
}

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // WKWebView exposes no synchronous current request, so the query is read
    // from the current URL.
    [self handleNavigationFinishedForQuery:[webView.URL query]];
}
#else
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self handleNavigationFinishedForQuery:[[[webView request] URL] query]];
}
#endif

// @ 0xecd24 — ignore user-cancelled loads (NSURLErrorCancelled == -999) and the
// WebKit "frame load interrupted" (102) errors; otherwise notify the delegate
// and close.
- (void)handleNavigationFailWithError:(NSError *)error {
    [self updateIndicator:NO];

    if ([error code] == -999) {
        return;
    }
    if ([error code] == 102 && [[error domain] isEqual:@"WebKitErrorDomain"]) {
        return;
    }

    if ([self delegate] != nil &&
        [[self delegate] respondsToSelector:@selector(appListFailLoadWithError:)]) {
        [[self delegate] appListFailLoadWithError:error];
        [self appliListClosed];
    }
}

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
    [self handleNavigationFailWithError:error];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
    [self handleNavigationFailWithError:error];
}
#else
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self handleNavigationFailWithError:error];
}
#endif

// @ 0xece64
- (void)btnCloseClicked:(id)sender {
    [self appliListClosed];
}

// @ 0xece74
- (void)appliListClosed {
    [_indicator removeFromSuperview];
    [_navigationBar removeFromSuperview];
    [_webView removeFromSuperview];
    [self.view removeFromSuperview];

    _indicator = nil;
    _navigationBar = nil;
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    _webView.navigationDelegate = nil;
#else
    [_webView setDelegate:nil];
#endif
    _webView = nil;

    [self setParentView:nil];
}

// @ 0xecf50
- (void)updateIndicator:(BOOL)show {
    if (_indicator != nil) {
        if (show) {
            [_indicator show];
        } else {
            [_indicator close];
        }
    }
}

// @ 0xecf8c — decide whether to allow a navigation, intercepting applilink://
// scheme launches. Shared by both web-view backends; returns YES to proceed.
- (BOOL)shouldStartLoadWithRequest:(NSURLRequest *)request {
    NSURL *url = [request URL];
    NSString *scheme = [url scheme];
    NSString *host = [url host];
    NSInteger port = [[url port] intValue];
    NSString *path = [url path];
    NSString *query = [url query];

    // Only intercept applilink:// navigations.
    if (scheme == nil || ![scheme hasPrefix:@"applilink"]) {
        return YES;
    }
    if (host == nil) {
        return YES;
    }

    // applilink://ext-app:80 — launch an external app via one of the URL schemes
    // carried in the query ("default_scheme=<url>&...") or in the path.
    if (![host isEqualToString:@"ext-app"] || port != 80) {
        return YES;
    }

    // (1) Any "default_scheme=<url>" query components: try to open each.
    if (query != nil) {
        NSArray *components = [query componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            if (component == nil ||
                [component rangeOfString:@"default_scheme="].location != NSNotFound) {
                NSUInteger prefixLen = [@"default_scheme=" length];
                NSString *encoded = [component substringFromIndex:prefixLen];
                NSURL *appURL = [NSURL URLWithString:[encoded URLDecodedString]];
                if (appURL != nil && [[UIApplication sharedApplication] canOpenURL:appURL]) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                    [[UIApplication sharedApplication] openURL:appURL options:@{} completionHandler:nil];
#else
                    [[UIApplication sharedApplication] openURL:appURL];
#endif
                    if (![self isNavigationBarHidden]) {
                        [self appliListClosed];
                    }
                    return NO;
                }
            }
        }
    }

    // (2) Otherwise treat the tail of the path (after "applilink://ext-app:80")
    // as the scheme URL, stripping a trailing "&<query>" if present.
    NSString *prefix = @"applilink://ext-app:80";
    NSString *launch = path;
    if ([[url absoluteString] hasPrefix:prefix]) {
        NSString *tail = [[url absoluteString] substringFromIndex:[prefix length]];
        if ([query length] != 0) {
            NSString *suffix = [NSString stringWithFormat:@"&%@", query];
            if ([tail hasSuffix:suffix]) {
                tail = [tail substringToIndex:[tail length] - [suffix length]];
            }
        }
        launch = tail;
    }

    if ([launch length] != 0) {
        // Drop the leading separator, take the first "&"-delimited token as the
        // URL.
        NSArray *parts = [[launch substringFromIndex:1] componentsSeparatedByString:@"&"];
        if ([parts count] != 0) {
            NSURL *appURL = [NSURL URLWithString:[[parts objectAtIndex:0] URLDecodedString]];
            if (appURL != nil && [[UIApplication sharedApplication] canOpenURL:appURL]) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                [[UIApplication sharedApplication] openURL:appURL options:@{} completionHandler:nil];
#else
                [[UIApplication sharedApplication] openURL:appURL];
#endif
                if (![self isNavigationBarHidden]) {
                    [self appliListClosed];
                }
                return NO;
            }
        }
    }

    return YES;
}

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if ([self shouldStartLoadWithRequest:navigationAction.request]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}
#else
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    return [self shouldStartLoadWithRequest:request];
}
#endif

// @ 0xed62c
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (![self shouldAutorotate]) {
        return NO;
    }
    NSUInteger mask;
    switch (interfaceOrientation) {
    case UIInterfaceOrientationPortrait:
        mask = UIInterfaceOrientationMaskPortrait;
        break; // 2
    case UIInterfaceOrientationPortraitUpsideDown:
        mask = UIInterfaceOrientationMaskPortraitUpsideDown;
        break; // 4
    case UIInterfaceOrientationLandscapeLeft:
        mask = UIInterfaceOrientationMaskLandscapeLeft;
        break; // 8
    case UIInterfaceOrientationLandscapeRight:
        mask = UIInterfaceOrientationMaskLandscapeRight;
        break; // 0x10
    default:
        return NO;
    }
    return ([self supportedInterfaceOrientations] & mask) != 0;
}

// @ 0xed684
- (BOOL)shouldAutorotate {
    return YES;
}

// @ 0xed688
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // Reads (and discards) the device idiom, then returns all orientations
    // (UIInterfaceOrientationMaskAll == 0x1e).
    (void)[[UIDevice currentDevice] userInterfaceIdiom];
    return UIInterfaceOrientationMaskAll;
}

// @ 0xed6cc
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration {
    // NOTE: this mirrors the (large, register-level) frame arithmetic from the
    // binary in behavioural form. The panel is placed manually (not inside a
    // UIViewController's managed view), so it rotates itself with a
    // CGAffineTransform and recomputes frames.

    // Are we hosted inside a real view-controller/view hierarchy (vs. straight on
    // a window)?
    BOOL hostedInViewController = NO;
    if ([self parentView] != nil && ![[self parentView] isKindOfClass:[UIWindow class]] &&
        [RewardNetworkUtilities hasParentViewController:[self parentView]]) {
        hostedInViewController = YES;
    }

    UIScreen *screen = [UIScreen mainScreen];
    CGRect base = CGRectZero;
    if (screen) {
#if defined(__IPHONE_9_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
        base = [screen bounds];
#else
        base = hostedInViewController ? [screen bounds] : [screen applicationFrame];
#endif
    }

    // Portrait-normalised size (shorter side == width).
    CGFloat shortSide = base.size.width;
    CGFloat longSide = base.size.height;
    if (longSide < shortSide) {
        CGFloat t = shortSide;
        shortSide = longSide;
        longSide = t;
    }

    CGAffineTransform xf;
    CGRect newBounds;
    switch (orientation) {
    case UIInterfaceOrientationPortraitUpsideDown: // 2
        xf = CGAffineTransformMakeRotation((CGFloat)M_PI);
        newBounds = CGRectMake(0.0f, 0.0f, shortSide, longSide);
        break;
    case UIInterfaceOrientationLandscapeLeft: // 3
        xf = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
        newBounds = CGRectMake(0.0f, 0.0f, longSide, shortSide);
        break;
    case UIInterfaceOrientationLandscapeRight: // 4
        xf = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));
        newBounds = CGRectMake(0.0f, 0.0f, longSide, shortSide);
        break;
    default: // portrait (1)
        xf = CGAffineTransformMakeRotation(0.0f);
        newBounds = CGRectMake(0.0f, 0.0f, shortSide, longSide);
        break;
    }

    if (hostedInViewController) {
        // A hosting view controller owns rotation; just adopt the new bounds.
        [self.view setBounds:newBounds];
    } else {
        [UIView animateWithDuration:duration
                         animations:^{ // @ 0xedef8 — animate transform + bounds
                           self.view.transform = xf;
                           self.view.bounds = newBounds;
                         }];
    }

    // Reposition the view for the current status-bar orientation.
    CGRect viewFrame = self.view.frame;
    CGFloat originX = 0.0f;
    CGFloat originY = 0.0f;
    if (shortSide > 0.0f) {
        UIInterfaceOrientation sbo = [[UIApplication sharedApplication] statusBarOrientation];
        if (sbo == UIInterfaceOrientationPortrait) {
            originY = shortSide;
        } else if (sbo == UIInterfaceOrientationLandscapeRight) {
            originX = shortSide;
        }
    }
    [self.view setFrame:CGRectMake(originX, originY, viewFrame.size.width, viewFrame.size.height)];

    // Re-lay the hosted subviews.
    [_webView setFrame:self.view.bounds];
    [_navigationBar sizeToFit];

    if (![self isNavigationBarHidden]) {
        CGRect webFrame = _webView ? _webView.frame : CGRectZero;
        CGRect barFrame = _navigationBar ? _navigationBar.frame : CGRectZero;
        // Push the web view down by the bar height and shrink it accordingly.
        webFrame.origin.y = barFrame.size.height;
        webFrame.size.height -= barFrame.size.height;
        [_webView setFrame:webFrame];
        [_navigationBar setFrame:barFrame];
        [_indicator setFrame:self.view.bounds];
    } else {
        [_navigationBar removeFromSuperview];
    }
}

// @ 0xedf98
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [self rotateWebViewWithInterfaceOrientation:orientation duration:duration];
}

// @ 0xee000
- (BOOL)hasParentViewController:(id)responder {
    if ([responder isKindOfClass:[UIWindow class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIApplication class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIView class]]) {
        return [self hasParentViewController:[responder nextResponder]];
    }
    if ([responder isKindOfClass:[UIViewController class]]) {
        return YES;
    }
    return NO;
}

// --- manual accessors (mirror 0xee100..0xee150) ---

// @ 0xee100
- (BOOL)isNavigationBarHidden {
    return _isNavigationBarHidden;
}

// @ 0xee110
- (void)setIsNavigationBarHidden:(BOOL)hidden {
    _isNavigationBarHidden = hidden;
}

// @ 0xee120
- (id<RewardNetworkWebViewDelegate>)delegate {
    return _delegate;
}

// @ 0xee130 — assigned, not retained.
- (void)setDelegate:(id<RewardNetworkWebViewDelegate>)delegate {
    _delegate = delegate;
}

// @ 0xee140
- (UIView *)parentView {
    return _parentView;
}

// @ 0xee150 — retained (strong under ARC).
- (void)setParentView:(UIView *)parentView {
    _parentView = parentView;
}

// .cxx_destruct @ 0xee178 — compiler-emitted ARC teardown; not hand-written.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
