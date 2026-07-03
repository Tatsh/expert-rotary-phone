//
//  RecommendWebViewController.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the in-app web view that hosts the recommend/ad
//  content. It is a thin subclass of RewardNetworkWebViewController that (a) tears the web
//  view out of its superview on unload/close and (b) lets RecommendCore intercept
//  "applilink://" redirect requests, closing the applist when a plain link is tapped.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass determined from
//  the Objective-C class_t metadata (superclass name "RewardNetworkWebViewController"); the
//  viewDidLoad/didReceiveMemoryWarning/viewDidUnload/appliListClosed bodies chain up to it.
//    viewDidLoad @ 0xe97ac   didReceiveMemoryWarning @ 0xe97d8   viewDidUnload @ 0xe9804
//    removeFromSuperview @ 0xe9878   appliListClosed @ 0xe988c
//    webView:shouldStartLoadWithRequest:navigationType: @ 0xe98ec
//

#import <UIKit/UIKit.h>

// TODO(dep): RewardNetworkWebViewController — the Applilink reward web-view controller base
// is not part of this pass. It supplies -setDelegate:, -isNavigationBarHidden, -appliListClosed
// and the UIViewController/UIWebView plumbing chained up to below.
#import "RewardNetworkWebViewController.h"

@interface RecommendWebViewController : RewardNetworkWebViewController <UIWebViewDelegate>

// Detach the web view delegate (invoked by the hosting controller when tearing the view down).
- (void)removeFromSuperview;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
