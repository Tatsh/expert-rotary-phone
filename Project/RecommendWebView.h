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

/**
 * @brief The completion for a hosted recommend or app-list load.
 * @param error The load error, or nil on success.
 */
typedef void (^RecommendWebViewOpenAppliListCallback)(NSError *error);

/**
 * @brief The web view that renders the recommend and app-list pages.
 */
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface RecommendWebView : WKWebView <WKNavigationDelegate>
#else
@interface RecommendWebView : UIWebView <UIWebViewDelegate>
#endif

/** The stored completion block, backed by the _callbackForOpenAppliList ivar. Getter @ 0xff904,
 * setter @ 0xff918. */
@property(nonatomic, copy) RecommendWebViewOpenAppliListCallback callbackForOpenAppliList;

/** The last load error, backed by the _lastErrorForOpenAppliList ivar. Getter @ 0xff93c, setter @
 * 0xff94c. */
@property(nonatomic, strong) NSError *lastErrorForOpenAppliList;

/**
 * @brief Hop to the main queue and fetch and render the recommend app list.
 * @param callback Stored, and fired with the load error or nil once the panel is dismissed.
 * @ghidraAddress 0xfe970
 */
- (void)loadRequestWithCallback:(RecommendWebViewOpenAppliListCallback)callback;

/**
 * @brief Build the parameterised request, show the indicator, and start loading.
 * @param url The page URL.
 * @param parameters The query parameters.
 * @param delegate Accepted but unused; the web view always makes itself the delegate.
 * @ghidraAddress 0xff354
 */
- (void)loadRequestWithURL:(NSString *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id)delegate;

/**
 * @brief Stop an in-flight load.
 * @ghidraAddress 0xff0a8
 */
- (void)cancelRequest;

/**
 * @brief Tear the panel down; it forwards to -appliListClosed.
 * @ghidraAddress 0xff098
 */
- (void)closeList;

/**
 * @brief Enable or disable the busy-indicator overlay.
 * @param enable YES to show the indicator.
 * @ghidraAddress 0xff0e0
 */
- (void)setIndicatorwithEnable:(BOOL)enable;

/**
 * @brief Select the ad layout, which picks the ad_type and is_banner_wide query values.
 * @param viewType The layout: 0, 1, 2 or 3.
 * @ghidraAddress 0xff0f0
 */
- (void)setViewType:(int)viewType;

/**
 * @brief Toggle scrolling and bouncing on the hosted UIScrollView subviews.
 * @param enabled YES to allow scrolling.
 * @ghidraAddress 0xff100
 */
- (void)setScrollEnabled:(BOOL)enabled;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
