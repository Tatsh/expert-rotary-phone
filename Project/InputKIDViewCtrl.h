/**
 * @file
 * The e-AMUSEMENT "pop'n-link" (KONAMI ID) linking screen.
 *
 * The pop'n-link top screen pushes it while the player has not yet linked their account. It is a
 * scrollable form over "friman_bg" with a KONAMI ID field of at most 256 characters, a secure
 * PASSWORD field of at most 32, a secure OTP field of at most 16, a decide button, caption images,
 * and a tappable "input_kid_link" banner that opens the quick-entry web page, plus a dimmed cover
 * and spinner shown while the link POST is in flight. The KID and password are pre-filled from the
 * last saved values. Submitting POSTs "uuid&konami_id&password&otp" to StoreUtil +linkKidURL; a
 * successful link stores the returned RefId, enables the checker and quiz buttons, and, on pad,
 * tells the owning split controller to re-enter the score-checker section.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xd5888, startLinkKidHttp
 * @ 0xd7088). Built in Objective-C++, where the SE, scene, and login-context bridge drives the C++
 * neEngine, neSceneManager, and neAppEventCenter singletons.
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"                // CommonAlertViewDelegate
#import "Downloader.h"                     // DownloaderDelegate
#import "PopnLinkTopSplitViewController.h" // PopnLinkTopSplitViewControllerDelegate

@class TouchableScrollView;

/**
 * The pop'n-link KONAMI ID entry screen: id, password and one-time password.
 */
// Doxygen mis-parses an @interface whose line is wrapped before the ':' when an ivar block
// follows: it reports every protocol after the first as an undocumented ivar. Breaking inside the
// protocol list instead parses correctly, so the formatter is held off here.
// clang-format off
@interface InputKIDViewCtrl : UIViewController <UITextFieldDelegate,
                                                DownloaderDelegate,
                                                CommonAlertViewDelegate> {
    /** The tap-through form host; it scrolls up for the keyboard. */
    TouchableScrollView *_scrollView;
    UITextField *_kidField;  /**< The KONAMI ID entry; at most 256 characters, pre-filled. */
    UITextField *_passField; /**< The secure password entry; at most 32 characters, pre-filled. */
    UITextField *_otpField;  /**< The secure one-time-password entry; at most 16 characters. */
    /** The dimmed cover and spinner; owned, and released in -dealloc. */
    UIViewController *_dummyView;
    Downloader *_downloader; /**< The in-flight link POST; nil when idle. */
    NSString *oldKonamiId;   /**< The last saved KONAMI ID, used to pre-fill _kidField. */
    NSString *oldPassword;   /**< The last entered password, used to pre-fill _passField. */
    float _scrollOffset;     /**< The keyboard scroll offset: 90 on 3.5-inch, 0 on 4-inch. */
    BOOL _isAninationing;    /**< The animation guard; the binary's spelling is kept. */
    /** The owning split controller; a plain assign. */
    id<PopnLinkTopSplitViewControllerDelegate> __unsafe_unretained _delegate;
}
// clang-format on

/** The owning pop'n-link split controller on iPad, notified to re-enter the score checker after a
 * successful link. The accessors are a raw pointer load and store. Getter @ 0xd73f4, setter @
 * 0xd7404. */
@property(nonatomic, assign) id<PopnLinkTopSplitViewControllerDelegate> delegate;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
