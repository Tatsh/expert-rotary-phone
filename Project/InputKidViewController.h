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

@interface InputKidViewController
    : UIViewController <UITextFieldDelegate, DownloaderDelegate, CommonAlertViewDelegate> {
    UITextField *_codeField;             // the 8-char invite-code entry field
    UIActivityIndicatorView *_indicator; // in-flight spinner (hidesWhenStopped)
    Downloader *_downloader;             // the in-flight invite POST (nil when idle)
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
