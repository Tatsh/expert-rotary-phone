//
//  CustomWebView.h
//  pop'n rhythmin
//
//  An in-app web panel (a UIView, not a view controller) that hosts a web view
//  over the app's root scene view. Used by the Setting screens (SettingOther /
//  SettingTable) to show the official "app info / お知らせ" page: -initWithURL:
//  builds the panel, attaches itself over the root view, starts loading the URL
//  and shows a centred spinner; a small close button (top-right) and a big
//  close button (pinned to the bottom of the scrolled content, revealed via a
//  contentSize KVO observer) both dismiss it with a fade animation. On a
//  successful load, if the Twitter-follow bonus has not yet been claimed it
//  adds a "follow us" button that awards treasure points.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (CustomWebView methods @ 0x5df50..0x5ee38). Superclass is UIView (Ghidra
//  shows the ivars are laid out after UIView and the initializer / dealloc
//  chain to UIView).
//
//  The panel-close notification is delivered through a plain C function pointer
//  (m_AlertViewCallback) rather than a delegate/target — see
//  -SetCloseCallback:param:.
//

#import <UIKit/UIKit.h>

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

// C close-callback: invoked (with its opaque param) from the close animation's
// completion block. Modelled as a non-object C function pointer to match the
// binary (the two ivars below are stored as raw pointers and are NOT
// ARC-managed).
typedef void (*CustomWebViewCloseCallback)(void *param);

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
@interface CustomWebView : UIView <WKNavigationDelegate> {
#else
@interface CustomWebView : UIView <UIWebViewDelegate> {
#endif
    // C close callback + its opaque param (raw pointers, not ARC-managed
    // objects).
    CustomWebViewCloseCallback m_AlertViewCallback;
    void *m_AlertViewCallbackParam;

#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    WKWebView *_webView; // hosted web view (navigation delegate == self)
#else
    UIWebView *_webView; // hosted web view (delegate == self)
#endif
    UIButton *_closeBtnSmall;            // top-right close button (hidden until first load done)
    UIButton *_closeBtnBig;              // bottom-of-content close button (revealed via KVO)
    UIActivityIndicatorView *_indicator; // centred loading spinner
    NSString *_errorTitle;               // title for the load-failure alert
    NSString *_errorText;                // message for the load-failure alert
    CGRect webViewFrm;                   // cached web-view frame (origin-zeroed panel bounds)
    CGRect smallBtnFrm;                  // cached small close-button frame
}

// Build the panel over the root scene view and start loading `url`. Ghidra: @
// 0x5dfec.
- (instancetype)initWithURL:(NSURL *)url;

// Set the title/message shown by -showErrorAlert when a load fails. Ghidra: @
// 0x5df50.
- (void)setErrorMsg:(NSString *)errorMsg text:(NSString *)text;

// Register a C callback (and opaque param) fired when the panel finishes
// closing. Ghidra: @ 0x5ed7c.
- (void)SetCloseCallback:(CustomWebViewCloseCallback)callback param:(void *)param;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
