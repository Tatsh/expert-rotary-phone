//
//  InputKIDViewCtrl.h
//  pop'n rhythmin
//
//  The e-AMUSEMENT "pop'n-link" (KONAMI ID) linking screen, pushed by the pop'n-link
//  top screen while the player has not yet linked their account. A scrollable form
//  over "friman_bg" (KONAMI ID field <= 256, secure PASSWORD field <= 32, secure OTP
//  field <= 16, a decide button, caption images and a tappable "input_kid_link" banner
//  that opens the quick-entry web page), plus a dimmed cover + spinner shown while the
//  link POST is in flight. The KID / password are pre-filled from the last saved values.
//  Submitting POSTs "uuid&konami_id&password&otp" to StoreUtil +linkKidURL; a successful
//  link stores the returned RefId, enables the checker / quiz buttons and (on pad) tells
//  the owning split controller to re-enter the score-checker section.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xd5888,
//  startLinkKidHttp @ 0xd7088). Built in Objective-C++ (the SE / scene / login-context
//  bridge drives the C++ neEngine / neSceneManager / neAppEventCenter singletons).
//

#import <UIKit/UIKit.h>

#import "Downloader.h"                       // DownloaderDelegate
#import "CommonAlertView.h"                  // CommonAlertViewDelegate
#import "PopnLinkTopSplitViewController.h"   // PopnLinkTopSplitViewControllerDelegate

@class TouchableScrollView;

@interface InputKIDViewCtrl : UIViewController
    <UITextFieldDelegate, DownloaderDelegate, CommonAlertViewDelegate> {
    TouchableScrollView *_scrollView;  // tap-through form host (scrolls up for the keyboard)
    UITextField *_kidField;            // KONAMI ID entry (<= 256 chars, pre-filled)
    UITextField *_passField;           // secure PASSWORD entry (<= 32 chars, pre-filled)
    UITextField *_otpField;            // secure one-time-password entry (<= 16 chars)
    UIViewController *_dummyView;      // dimmed cover + spinner (owned; released in dealloc)
    Downloader *_downloader;           // the in-flight link POST (nil when idle)
    NSString *oldKonamiId;             // last saved KONAMI ID, used to pre-fill _kidField
    NSString *oldPassword;             // last entered password, used to pre-fill _passField
    float _scrollOffset;               // keyboard scroll offset (90 on 3.5", 0 on 4")
    BOOL _isAninationing;              // animation guard (binary spelling kept)
    id<PopnLinkTopSplitViewControllerDelegate> __unsafe_unretained _delegate;  // owning split controller (assign)
}

// The owning pop'n-link split controller (pad); notified to re-enter the score checker
// after a successful link. Plain assign (unsafe_unretained) — Ghidra getter @ 0xd73f4 /
// setter @ 0xd7404 are a raw pointer load / store.
@property (nonatomic, assign) id<PopnLinkTopSplitViewControllerDelegate> delegate;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
