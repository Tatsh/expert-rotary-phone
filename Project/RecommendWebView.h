//
//  RecommendWebView.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the raw web view that renders the
//  recommend/app-list content. It is a web-view subclass that acts as its own
//  navigation delegate: it hides itself until content is ready, optionally
//  overlays a RewardNetworkIndicator busy spinner on its parent view, fetches
//  the app list through RecommendCore, then loads /ad/external/index.php.
//  Applilink redirects (applilink://ext-app:80/...) are handed to
//  RecommendCore.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  superclass is UIWebView (the -init/-setHidden: bodies message the superclass
//  through objc_msgSendSuper2, resolved to UIWebView, and the instance responds
//  to -loadRequest:/-isLoading/-stopLoading/-setDelegate:).
//    init @ 0xfe808   removeFromSuperview @ 0xfe8a4   loadRequestWithCallback:
//    @ 0xfe970 closeList @ 0xff098   cancelRequest @ 0xff0a8
//    setIndicatorwithEnable: @ 0xff0e0 setViewType: @ 0xff0f0 setScrollEnabled:
//    @ 0xff100   loadRecommendView @ 0xff268 unloadRecommendView @ 0xff30c
//    webViewDidStartLoad: @ 0xff340 loadRequestWithURL:parameters:delegate: @
//    0xff354   viewDidDisappear: @ 0xff494 webViewDidFinishLoad: @ 0xff574
//    setHidden: @ 0xff6bc webView:didFailLoadWithError: @ 0xff6fc
//    appliListClosed @ 0xff828 updateIndicator: @ 0xff86c
//    webView:shouldStartLoadWithRequest:navigationType: @ 0xff8a8
//    callbackForOpenAppliList @ 0xff904 / setCallbackForOpenAppliList: @
//    0xff918 lastErrorForOpenAppliList @ 0xff93c /
//    setLastErrorForOpenAppliList: @ 0xff94c
//

#import <UIKit/UIKit.h>

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

// Completion for a hosted recommend/app-list load: invoked with the load error
// (or nil).
typedef void (^RecommendWebViewOpenAppliListCallback)(NSError *error);

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface RecommendWebView : WKWebView <WKNavigationDelegate>
#else
@interface RecommendWebView : UIWebView <UIWebViewDelegate>
#endif

// _callbackForOpenAppliList ivar (block, copied) — accessors @ 0xff904 /
// 0xff918.
@property(nonatomic, copy) RecommendWebViewOpenAppliListCallback callbackForOpenAppliList;

// _lastErrorForOpenAppliList ivar — accessors @ 0xff93c / 0xff94c.
@property(nonatomic, strong) NSError *lastErrorForOpenAppliList;

// @ 0xfe970 — hop to the main queue and fetch/render the recommend app list.
// `callback` is stored and later fired (with the load error, or nil) once the
// panel is dismissed.
- (void)loadRequestWithCallback:(RecommendWebViewOpenAppliListCallback)callback;

// @ 0xff354 — build the parameterised request, show the indicator, and start
// loading. The web view always makes itself the delegate; `delegate` is
// accepted but unused.
- (void)loadRequestWithURL:(NSString *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id)delegate;

// @ 0xff0a8 — stop an in-flight load.
- (void)cancelRequest;

// @ 0xff098 — tear the panel down (forwards to -appliListClosed).
- (void)closeList;

// @ 0xff0e0 — enable/disable the busy-indicator overlay.
- (void)setIndicatorwithEnable:(BOOL)enable;

// @ 0xff0f0 — select the ad layout (0/1/2/3 → ad_type + is_banner_wide query
// values).
- (void)setViewType:(int)viewType;

// @ 0xff100 — toggle scrolling/bouncing on the hosted UIScrollView subviews.
- (void)setScrollEnabled:(BOOL)enabled;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
