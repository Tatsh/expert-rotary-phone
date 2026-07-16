//
//  RecommendWebViewController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendWebViewController.h"

// RecommendCore — the Recommend SDK core (redirect handling / SSL base URL). It
// supplies +sharedInstance and -redirectWithRequest:.
#import "RecommendCore.h"

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

@implementation RecommendWebViewController

// @ 0xe97ac
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0xe97d8
// @complete
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xe9804 — drop the delegate, pull the view out of its superview, then chain
// up.
// @complete
- (void)viewDidUnload {
    [self setDelegate:nil];
    [[self view] removeFromSuperview];
    [super viewDidUnload];
}

// @ 0xe9878 — detach the web view delegate.
// @complete
- (void)removeFromSuperview {
    [self setDelegate:nil];
}

// @ 0xe988c — pull the view out of its superview, then chain up to the base
// close handler.
// @complete
- (void)appliListClosed {
    [[self view] removeFromSuperview];
    [super appliListClosed];
}

// @ 0xe98ec — let RecommendCore intercept applilink redirects. When the request
// is not a redirect and the navigation bar is visible, treat the tap as leaving
// the applist and close. Returns whether the core consumed the request as a
// redirect. Shared by both web-view backends. (Extracted from the binary's
// UIWebView delegate webView:shouldStartLoadWithRequest:navigationType: @
// 0xe98ec, whose body is this helper.)
// @complete
- (BOOL)shouldStartLoadWithRequest:(NSURLRequest *)request {
    BOOL redirected = [[RecommendCore sharedInstance] redirectWithRequest:request];
    if (![self isNavigationBarHidden] && !redirected) {
        [self appliListClosed];
    }
    return redirected;
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

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
