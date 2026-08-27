//
//  InputKidViewController.h
//  pop'n rhythmin
//
//  The "enter an invite code" screen, pushed by InviteTopViewController's guest
//  panel. An 8-char code field, a decide button that POSTs the code (with the
//  device uuid) to the invite endpoint, and a translucent activity spinner
//  while the request is in flight. On success it grants 5 character tickets and
//  marks the code as redeemed (a code may be entered only once). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (init @ 0xe7cec,
//  startInviteHttp:
//  @ 0xe8b5c). Built in InputKidViewController.mm (Objective-C++: the SE /
//  scene bridge drives the C++ neEngine singletons).
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate
#import "Downloader.h"      // DownloaderDelegate

/**
 * @brief The invite-code entry screen.
 */
// Doxygen mis-parses an @interface whose line is wrapped before the ':' when an ivar block
// follows: it reports every protocol after the first as an undocumented ivar. Breaking inside the
// protocol list instead parses correctly, so the formatter is held off here.
// clang-format off
@interface InputKidViewController : UIViewController <UITextFieldDelegate,
                                                      DownloaderDelegate,
                                                      CommonAlertViewDelegate> {
    UITextField *_codeField;             /**< The 8-character invite-code entry field. */
    UIActivityIndicatorView *_indicator; /**< The in-flight spinner; it hides when stopped. */
    Downloader *_downloader;             /**< The in-flight invite POST; nil when idle. */
}
// clang-format on

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
