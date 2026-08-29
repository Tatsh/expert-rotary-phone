/**
 * @file
 * The in-app web view hosting the Konami "Applilink" Recommend ad SDK's content.
 *
 * A thin subclass of RewardNetworkWebViewController that tears the web view out of its superview
 * on unload or close, and lets RecommendCore intercept "applilink://" redirect requests, closing
 * the applist when a plain link is tapped.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The superclass is determined from
 * the Objective-C class_t metadata, whose superclass name is "RewardNetworkWebViewController"; the
 * viewDidLoad, didReceiveMemoryWarning, viewDidUnload, and appliListClosed bodies chain up to it:
 * viewDidLoad @ 0xe97ac, didReceiveMemoryWarning @ 0xe97d8, viewDidUnload @ 0xe9804,
 * removeFromSuperview @ 0xe9878, appliListClosed @ 0xe988c, and
 * webView:shouldStartLoadWithRequest:navigationType: @ 0xe98ec.
 */

#import <UIKit/UIKit.h>

// RewardNetworkWebViewController — the Applilink reward web-view controller
// base. It supplies -setDelegate:, -isNavigationBarHidden, -appliListClosed and
// the UIViewController/UIWebView plumbing chained up to below.
#import "RewardNetworkWebViewController.h"

/**
 * The recommend app-list web-view controller.
 */
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface RecommendWebViewController : RewardNetworkWebViewController <WKNavigationDelegate>
#else
@interface RecommendWebViewController : RewardNetworkWebViewController <UIWebViewDelegate>
#endif

/**
 * Detach the web view delegate. The hosting controller invokes it when tearing the view
 * down.
 */
- (void)removeFromSuperview;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
