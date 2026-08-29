/**
 * @file
 * @brief The full-screen web panel the bundled Konami RewardNetwork ("applilink") ad and reward
 * SDK presents its app-list in.
 *
 * A UIViewController that manually hosts a web view, a UINavigationBar with a single "close"
 * button, and a loading indicator, and re-lays them out for interface-orientation changes. It
 * intercepts `applilink://` navigations, both scheme launches and close commands, in the
 * navigation-delegate callbacks.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (RewardNetworkWebViewController
 * methods @ 0xec4d8..0xee150). The superclass is UIViewController: Ghidra shows -init, -loadView,
 * and -didReceiveMemoryWarning chaining to UIViewController, and the class object's superclass is
 * UIViewController.
 *
 * There are six instance variables, with types recovered from the decompiled ivar accesses:
 * _webView (the web view), _navigationBar (UINavigationBar *), _indicator
 * (RewardNetworkIndicator *, an app-provided spinner view), _delegate (assigned, not retained),
 * _isNavigationBarHidden (BOOL), and _parentView (UIView *, retained).
 */

#import <UIKit/UIKit.h>
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

#import "RewardNetworkIndicator.h" // app-provided loading-indicator view (the _indicator ivar)

// Notifications the panel sends back to whoever opened it. All optional; each
// call site guards with -respondsToSelector: (Ghidra @ 0xecb28 / 0xecbd8 /
// 0xecd24).
/**
 * @brief The notifications the panel sends back to whoever opened it.
 *
 * All are optional; each call site guards with -respondsToSelector: (Ghidra @ 0xecb28, 0xecbd8 and
 * 0xecd24).
 */
@protocol RewardNetworkWebViewDelegate <NSObject>
@optional
/**
 * @brief The page finished loading.
 */
- (void)appListDidAppear;
/**
 * @brief The panel was dismissed.
 */
- (void)appListDidDisappear;
/**
 * @brief The page failed to load.
 * @param error What went wrong.
 */
- (void)appListFailLoadWithError:(NSError *)error;
@end

/**
 * @brief The Applilink reward web-view panel: the app list, its navigation bar and its loading
 * indicator.
 */
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface RewardNetworkWebViewController : UIViewController <WKNavigationDelegate> {
    WKWebView *_webView; /**< The hosted web view; its navigation delegate is self. */
#else
@interface RewardNetworkWebViewController : UIViewController <UIWebViewDelegate> {
    UIWebView *_webView; /**< The hosted web view; its delegate is self. */
#endif
    UINavigationBar *_navigationBar;    /**< The top bar carrying the close button. */
    RewardNetworkIndicator *_indicator; /**< The centred loading spinner. */
    /** The panel delegate; assigned, not retained. See -setDelegate:. */
    __unsafe_unretained id<RewardNetworkWebViewDelegate> _delegate;
    BOOL _isNavigationBarHidden; /**< Hide the top bar, for the scheme-launch mode. */
    UIView *_parentView;         /**< The container the panel is added onto; retained. */
}

// Manual accessors: implemented rather than @synthesized, mirroring the binary exactly.

/**
 * @brief The panel delegate.
 * @return The delegate.
 * @ghidraAddress 0xee120
 */
- (id<RewardNetworkWebViewDelegate>)delegate;
/**
 * @brief Set the panel delegate, without retaining it.
 * @param delegate The delegate.
 * @ghidraAddress 0xee130
 */
- (void)setDelegate:(id<RewardNetworkWebViewDelegate>)delegate;
/**
 * @brief Whether the top navigation bar is hidden.
 * @return YES when hidden.
 * @ghidraAddress 0xee100
 */
- (BOOL)isNavigationBarHidden;
/**
 * @brief Set whether the top navigation bar is hidden.
 * @param hidden YES to hide the bar.
 * @ghidraAddress 0xee110
 */
- (void)setIsNavigationBarHidden:(BOOL)hidden;
/**
 * @brief The container the panel is added onto.
 * @return The parent view.
 * @ghidraAddress 0xee140
 */
- (UIView *)parentView;
/**
 * @brief Set the container the panel is added onto, retaining it.
 * @param parentView The parent view.
 * @ghidraAddress 0xee150
 */
- (void)setParentView:(UIView *)parentView;

/**
 * @brief Hide or show the top navigation bar; it forwards to -setIsNavigationBarHidden:.
 * @param hidden YES to hide the bar.
 * @ghidraAddress 0xec8a8
 */
- (void)setNavigationBarHidden:(BOOL)hidden;

/**
 * @brief Build the request from a URL and query parameters, attach the panel over the parent view
 * or the key window, and start loading.
 * @param url The page URL.
 * @param parameters The query parameters.
 * @param delegate The panel delegate.
 * @ghidraAddress 0xec8b8
 */
- (void)loadRequestWithURL:(NSURL *)url
                parameters:(NSDictionary *)parameters
                  delegate:(id<RewardNetworkWebViewDelegate>)delegate;

/**
 * @brief Re-lay out the hosted views for a new interface orientation.
 * @param orientation The new interface orientation.
 * @param duration The animation duration.
 * @ghidraAddress 0xed6cc
 */
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration;

/**
 * @brief Tear the panel down: remove the hosted views and drop the parent.
 * @ghidraAddress 0xece74
 */
- (void)appliListClosed;

/**
 * @brief Show or hide the loading indicator.
 * @param show YES to show the indicator.
 * @ghidraAddress 0xecf50
 */
- (void)updateIndicator:(BOOL)show;

/**
 * @brief The close-button action; it forwards to -appliListClosed.
 * @param sender The tapped button.
 * @ghidraAddress 0xece64
 */
- (void)btnCloseClicked:(id)sender;

/**
 * @brief Walk a responder chain looking for a hosting view controller.
 * @param responder The responder to walk from.
 * @return YES when a host was found.
 * @ghidraAddress 0xee000
 */
- (BOOL)hasParentViewController:(id)responder;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
