/**
 * @file
 * An in-app web panel, a UIView rather than a view controller, hosting a web view over the
 * app's root scene view.
 *
 * The Setting screens (SettingOther and SettingTable) use it to show the official "app info /
 * お知らせ" page. -initWithURL: builds the panel, attaches itself over the root view, starts
 * loading the URL, and shows a centred spinner; a small close button (top-right) and a big close
 * button (pinned to the bottom of the scrolled content, revealed via a contentSize KVO observer)
 * both dismiss it with a fade animation. On a successful load, if the Twitter-follow bonus has not
 * yet been claimed it adds a "follow us" button that awards treasure points.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (CustomWebView methods @
 * 0x5df50..0x5ee38). The superclass is UIView: Ghidra shows the ivars are laid out after UIView
 * and the initializer and dealloc chain to UIView.
 *
 * The panel-close notification is delivered through a plain C function pointer
 * (m_AlertViewCallback) rather than a delegate or target; see -SetCloseCallback:param:.
 */

#import <UIKit/UIKit.h>

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

/**
 * The C close callback, invoked with its opaque parameter from the close animation's
 * completion block.
 *
 * It is modelled as a non-object C function pointer to match the binary; the two ivars below are
 * stored as raw pointers and are not ARC-managed.
 * @param param The opaque parameter registered alongside the callback.
 */
typedef void (*CustomWebViewCloseCallback)(void *param);

/**
 * An in-app web panel — a UIView, not a view controller — hosting a web view over the app's
 * root scene view.
 */
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface CustomWebView : UIView <WKNavigationDelegate> {
#else
@interface CustomWebView : UIView <UIWebViewDelegate> {
#endif
    /** The C close callback; a raw pointer, not an ARC-managed object. */
    CustomWebViewCloseCallback m_AlertViewCallback;
    /** The close callback's opaque parameter; a raw pointer, not ARC-managed. */
    void *m_AlertViewCallbackParam;

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    WKWebView *_webView; /**< The hosted web view; its navigation delegate is self. */
#else
    UIWebView *_webView; /**< The hosted web view; its delegate is self. */
#endif
    UIButton *_closeBtnSmall; /**< The top-right close button, hidden until the first load ends. */
    UIButton *_closeBtnBig;   /**< The bottom-of-content close button, revealed via KVO. */
    UIActivityIndicatorView *_indicator; /**< The centred loading spinner. */
    NSString *_errorTitle;               /**< The title for the load-failure alert. */
    NSString *_errorText;                /**< The message for the load-failure alert. */
    CGRect webViewFrm;  /**< The cached web-view frame: the origin-zeroed panel bounds. */
    CGRect smallBtnFrm; /**< The cached small close-button frame. */
}

/**
 * Build the panel over the root scene view and start loading a URL.
 * @param url The page to load.
 * @return The initialised panel.
 * @ghidraAddress 0x5dfec
 */
- (instancetype)initWithURL:(NSURL *)url;

/**
 * Set the title and message -showErrorAlert uses when a load fails.
 * @param errorMsg The alert title.
 * @param text The alert message.
 * @ghidraAddress 0x5df50
 */
- (void)setErrorMsg:(NSString *)errorMsg text:(NSString *)text;

/**
 * Register a C callback fired when the panel finishes closing.
 * @param callback The function to call.
 * @param param The opaque parameter to pass it.
 * @ghidraAddress 0x5ed7c
 */
- (void)SetCloseCallback:(CustomWebViewCloseCallback)callback param:(void *)param;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
