//
//  RecommendWebViewController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendWebViewController.h"

// TODO(dep): RecommendCore — the Recommend SDK core (redirect handling / SSL base URL) is not
// part of this pass. It supplies +sharedInstance and -redirectWithRequest:.
#import "RecommendCore.h"

@implementation RecommendWebViewController

// @ 0xe97ac
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0xe97d8
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0xe9804 — drop the delegate, pull the view out of its superview, then chain up.
- (void)viewDidUnload {
    [self setDelegate:nil];
    [[self view] removeFromSuperview];
    [super viewDidUnload];
}

// @ 0xe9878 — detach the web view delegate.
- (void)removeFromSuperview {
    [self setDelegate:nil];
}

// @ 0xe988c — pull the view out of its superview, then chain up to the base close handler.
- (void)appliListClosed {
    [[self view] removeFromSuperview];
    [super appliListClosed];
}

// @ 0xe98ec — let RecommendCore intercept applilink redirects. When the request is not a
// redirect and the navigation bar is visible, treat the tap as leaving the applist and close.
// Returns whether the core consumed the request as a redirect.
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
    BOOL redirected = [[RecommendCore sharedInstance] redirectWithRequest:request];
    if (![self isNavigationBarHidden] && !redirected) {
        [self appliListClosed];
    }
    return redirected;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
