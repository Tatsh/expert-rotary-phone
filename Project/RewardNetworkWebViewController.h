//
//  RewardNetworkWebViewController.h
//  pop'n rhythmin
//
//  Full-screen web panel used by the bundled Konami **RewardNetwork** ("applilink")
//  ad/reward SDK to present the reward app-list. A UIViewController that manually hosts
//  a UIWebView, a UINavigationBar (with a single "close" button) and a loading indicator,
//  and re-lays them out for interface-orientation changes. It intercepts `applilink://`
//  navigations (scheme launches / close commands) in the UIWebViewDelegate callbacks.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (RewardNetworkWebViewController methods @ 0xec4d8..0xee150). Superclass is
//  UIViewController (Ghidra shows -init/-loadView/-didReceiveMemoryWarning chaining to
//  UIViewController, and the class object's superclass is UIViewController).
//
//  Six instance variables (types recovered from the decompiled ivar accesses):
//    _webView (UIWebView*), _navigationBar (UINavigationBar*),
//    _indicator (RewardNetworkIndicator*, an app-provided spinner view),
//    _delegate (assigned, not retained), _isNavigationBarHidden (BOOL),
//    _parentView (UIView*, retained).
//

#import <UIKit/UIKit.h>

#import "RewardNetworkIndicator.h"   // app-provided loading-indicator view (the _indicator ivar)

// Notifications the panel sends back to whoever opened it. All optional; each call site
// guards with -respondsToSelector: (Ghidra @ 0xecb28 / 0xecbd8 / 0xecd24).
@protocol RewardNetworkWebViewDelegate <NSObject>
@optional
- (void)appListDidAppear;                          // page finished loading
- (void)appListDidDisappear;                        // panel dismissed
- (void)appListFailLoadWithError:(NSError *)error;  // load failed
@end

@interface RewardNetworkWebViewController : UIViewController <UIWebViewDelegate> {
    UIWebView *_webView;                              // hosted web view (delegate == self)
    UINavigationBar *_navigationBar;                  // top bar with the close button
    RewardNetworkIndicator *_indicator;               // centred loading spinner
    __unsafe_unretained id<RewardNetworkWebViewDelegate> _delegate;  // assigned, NOT retained (see -setDelegate:)
    BOOL _isNavigationBarHidden;                      // hide the top bar (scheme-launch mode)
    UIView *_parentView;                              // container the panel is added onto (retained)
}

// Manual accessors (implemented, not @synthesized — they mirror the binary exactly).
- (id<RewardNetworkWebViewDelegate>)delegate;               // @ 0xee120
- (void)setDelegate:(id<RewardNetworkWebViewDelegate>)delegate;  // @ 0xee130 (non-retaining)
- (BOOL)isNavigationBarHidden;                              // @ 0xee100
- (void)setIsNavigationBarHidden:(BOOL)hidden;              // @ 0xee110
- (UIView *)parentView;                                     // @ 0xee140
- (void)setParentView:(UIView *)parentView;                 // @ 0xee150 (retaining)

// Hide/show the top navigation bar. Forwards to -setIsNavigationBarHidden:. @ 0xec8a8
- (void)setNavigationBarHidden:(BOOL)hidden;

// Build the request (url + query parameters), attach the panel over parentView (or the
// key window), and start loading. @ 0xec8b8
- (void)loadRequestWithURL:(NSURL *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id<RewardNetworkWebViewDelegate>)delegate;

// Re-lay out the hosted views for the given interface orientation, animated over `duration`.
// @ 0xed6cc
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration;

// Tear the panel down (remove the hosted views, drop the parent). @ 0xece74
- (void)appliListClosed;

// Show (YES) or hide (NO) the loading indicator. @ 0xecf50
- (void)updateIndicator:(BOOL)show;

// Close-button action. Forwards to -appliListClosed. @ 0xece64
- (void)btnCloseClicked:(id)sender;

// Walk the responder chain of `responder` looking for a hosting view controller. @ 0xee000
- (BOOL)hasParentViewController:(id)responder;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
