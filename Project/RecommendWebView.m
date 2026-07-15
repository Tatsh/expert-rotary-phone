//
//  RecommendWebView.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendWebView.h"

#import "RecommendCore.h"
#import "RewardNetworkIndicator.h"
#import "RewardNetworkUtilities.h"

@interface RecommendWebView () {
    UIView *parentView;                 // host view for the indicator overlay (retained)
    RewardNetworkIndicator *_indicator; // busy-spinner overlay
    BOOL isIndicator;                   // YES if the overlay is enabled
    BOOL nowHidden;                     // last value passed through -setHidden:
    int _viewType;                      // ad layout selector
}

// @ 0xff268 — create and attach the indicator overlay if enabled.
- (void)loadRecommendView;
// @ 0xff30c — detach and drop the indicator overlay.
- (void)unloadRecommendView;
// @ 0xff86c — show/close the indicator overlay.
- (void)updateIndicator:(BOOL)show;
// @ 0xff828 — unload the overlay, remove from superview, drop the delegate.
- (void)appliListClosed;
// @ 0xff6fc — shared load-failure handler for both web-view backends.
- (void)handleNavigationFailWithError:(NSError *)error;

@end

@implementation RecommendWebView

// @ 0xfe808 — start hidden with no parent/overlay and the overlay disabled.
- (instancetype)init {
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    // WKWebView has no usable -init; it must be created with a frame and a
    // configuration.
    self = [super initWithFrame:CGRectZero configuration:[[WKWebViewConfiguration alloc] init]];
#else
    self = [super init];
#endif
    if (self) {
        parentView = nil;
        _indicator = nil;
        isIndicator = NO;
        nowHidden = NO;
        [super setHidden:YES];
    }
    return self;
}

// @ 0xfe8a4 — blank the page, drop the overlay and detach the delegate on
// teardown.
- (void)removeFromSuperview {
    [super removeFromSuperview];
    [self loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
    [self unloadRecommendView];
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    self.navigationDelegate = nil;
#else
    [self setDelegate:nil];
#endif
}

// @ 0xfe970 — main-queue app-list fetch (recommendWebViewLoadAppliList @
// 0xfe9ec, whose inner completion is recommendWebViewAppliListCallback @
// 0xfead8).
- (void)loadRequestWithCallback:(RecommendWebViewOpenAppliListCallback)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.backgroundColor = [UIColor clearColor];
      [self setOpaque:NO];
      [[RecommendCore sharedInstance] appliListWithCallBack:^(NSArray *appliList, NSError *error) {
        if (error != nil) {
            if (callback) {
                callback(error);
            }
            return;
        }
        // Keep only the ad ids whose companion app is actually installed on this
        // device.
        NSMutableArray *installedAdIds = [[NSMutableArray alloc] init];
        for (id item in appliList) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSString *scheme = [item objectForKey:@"default_scheme"];
                NSString *adId = [item objectForKey:@"ad_id"];
                if ([scheme isKindOfClass:[NSString class]] &&
                    [[RecommendCore sharedInstance] isInstalledAppliWithScheme:scheme] && adId) {
                    [installedAdIds addObject:adId];
                }
            }
        }
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
        [params setValue:[[RecommendCore sharedInstance] getCountryCode] forKey:@"country_code"];
        [params setValue:[[RecommendCore sharedInstance] getCategoryId] forKey:@"category_id"];
        [params setValue:@"1" forKey:@"is_sdk"];
        if ([installedAdIds count] != 0) {
            [params setObject:installedAdIds forKey:@"install_ad_id_list"];
        }
        NSString *adType;
        switch (_viewType) {
        case 1:
        case 2:
            adType = @"2";
            break;
        case 3:
            adType = @"3";
            break;
        case 0:
        default:
            adType = @"1";
            break;
        }
        [params setValue:adType forKey:@"ad_type"];
        [params setValue:(_viewType == 2 ? @"1" : @"0") forKey:@"is_banner_wide"];
        [self setCallbackForOpenAppliList:callback];
        [self setLastErrorForOpenAppliList:nil];
        NSString *url =
            [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/index.php"];
        [self loadRequestWithURL:url parameters:params delegate:nil];
      }];
    });
}

// @ 0xff354 — merge parameters into the URL, set a 30s reloading request,
// become the delegate, show the overlay and load. `delegate` is accepted for
// API symmetry but overridden with self.
- (void)loadRequestWithURL:(NSString *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id)delegate {
    parentView = self;
    NSString *full = [RewardNetworkUtilities appendParametersToURL:url parameters:parameters];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:full]];
    [request setTimeoutInterval:30.0];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    self.navigationDelegate = self;
#else
    [self setDelegate:self];
#endif
    [self loadRecommendView];
    [self loadRequest:request];
}

// @ 0xff0a8
- (void)cancelRequest {
    if ([self isLoading]) {
        [self stopLoading];
    }
}

// @ 0xff098
- (void)closeList {
    [self appliListClosed];
}

// @ 0xff0e0
- (void)setIndicatorwithEnable:(BOOL)enable {
    isIndicator = enable;
}

// @ 0xff0f0
- (void)setViewType:(int)viewType {
    _viewType = viewType;
}

// @ 0xff100 — walk the hosted subviews and apply scrolling/bouncing to any
// UIScrollView.
- (void)setScrollEnabled:(BOOL)enabled {
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            [(UIScrollView *)sub setScrollEnabled:enabled];
            [(UIScrollView *)sub setBounces:enabled];
        }
    }
}

// @ 0xff268
- (void)loadRecommendView {
    if (isIndicator) {
        _indicator = [[RewardNetworkIndicator alloc] initWithFrame:self.bounds];
        [parentView addSubview:_indicator];
    }
}

// @ 0xff30c
- (void)unloadRecommendView {
    if (_indicator != nil) {
        [_indicator removeFromSuperview];
    }
    _indicator = nil;
}

// @ 0xff86c
- (void)updateIndicator:(BOOL)show {
    if (_indicator != nil) {
        if (show) {
            [_indicator show];
        } else {
            [_indicator close];
        }
    }
}

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0

// @ 0xff340
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self updateIndicator:YES];
}

// @ 0xff574 — a "command=close" query closes the panel; otherwise hide the
// indicator and do the app-specific main-queue follow-up. WKWebView exposes no
// synchronous current request, so the query is read from the current URL.
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *query = [webView.URL query];
    if (query == nil || [query rangeOfString:@"command=close"].location == NSNotFound) {
        [self updateIndicator:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
          // @ 0xff68c — app-specific post-load follow-up on the main queue (a
          // nested message send on self; exact body not fully recovered).
          // Best-effort: re-assert scrolling.
          [self setScrollEnabled:YES];
        });
    } else {
        [self appliListClosed];
    }
}

#else

// @ 0xff340
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self updateIndicator:YES];
}

// @ 0xff574 — a "command=close" query closes the panel; otherwise hide the
// indicator and do the app-specific main-queue follow-up.
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *query = [[[webView request] URL] query];
    if (query == nil || [query rangeOfString:@"command=close"].location == NSNotFound) {
        [self updateIndicator:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
          // @ 0xff68c — app-specific post-load follow-up on the main queue (a
          // nested message send on self; exact body not fully recovered).
          // Best-effort: re-assert scrolling.
          [self setScrollEnabled:YES];
        });
    } else {
        [self appliListClosed];
    }
}

#endif

// @ 0xff494 — when dismissed, fire the stored open-app-list callback with the
// last error. The delegate probed here is the web view's own delegate (the view
// makes itself the delegate in -loadRequestWithURL:parameters:delegate:).
- (void)viewDidDisappear:(BOOL)animated {
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    id navigationDelegate = self.navigationDelegate;
#else
    id navigationDelegate = [self delegate];
#endif
    if (navigationDelegate != nil &&
        [navigationDelegate respondsToSelector:@selector(appListDidDisappear)]) {
        RecommendWebViewOpenAppliListCallback callback = [self callbackForOpenAppliList];
        if (callback != nil) {
            callback([self lastErrorForOpenAppliList]);
        }
    }
}

// @ 0xff6bc
- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    nowHidden = hidden;
}

// @ 0xff6fc — ignore cancellations and WebKit "frame load interrupted";
// otherwise report the failure through the delegate and close the panel. This
// body is shared by both WKWebView failure callbacks (committed and
// provisional).
- (void)handleNavigationFailWithError:(NSError *)error {
    [self updateIndicator:NO];
    if ([error code] == -999) {
        return;
    }
    if ([error code] == 102 && [[error domain] isEqual:@"WebKitErrorDomain"]) {
        return;
    }
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    id navigationDelegate = self.navigationDelegate;
#else
    id navigationDelegate = [self delegate];
#endif
    if (navigationDelegate != nil &&
        [navigationDelegate respondsToSelector:@selector(appListFailLoadWithError:)]) {
        [self setLastErrorForOpenAppliList:error];
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

// @ 0xff828
- (void)appliListClosed {
    [self unloadRecommendView];
    [self removeFromSuperview];
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    self.navigationDelegate = nil;
#else
    [self setDelegate:nil];
#endif
}

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0

// @ 0xff8a8 — hand every navigation to RecommendCore's Applilink redirect
// handler. The core returns whether the navigation should proceed.
- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if ([[RecommendCore sharedInstance] redirectWithRequest:navigationAction.request]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

#else

// @ 0xff8a8 — hand every navigation to RecommendCore's Applilink redirect
// handler.
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    return [[RecommendCore sharedInstance] redirectWithRequest:request];
}

#endif

// callbackForOpenAppliList / setCallbackForOpenAppliList: @ 0xff904 / 0xff918 —
// synthesized
//   (copy) accessors for the _callbackForOpenAppliList block ivar.
// lastErrorForOpenAppliList / setLastErrorForOpenAppliList: @ 0xff93c / 0xff94c
// — synthesized
//   (strong) accessors for the _lastErrorForOpenAppliList ivar.
// .cxx_destruct @ 0xff974 — compiler-emitted ARC teardown for the object ivars;
// not hand-written.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
