//
//  InviteTopViewControllerPad.h
//  pop'n rhythmin
//
//  The invite-code top screen, iPad variant (the iPhone uses
//  InviteTopViewController). Chosen by MainViewController -GotoInviteTop when
//  neSceneManager::isPadDisplay() is true, wrapped in its own navigation
//  controller. Unlike the phone version this is a single combined screen: it
//  shows my own invite code (with a "tweet it" button) and, below it, either
//  the guest-code entry field + decide button or an "already redeemed" banner.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initAtNavigationController @ 0x5c638, startOpenAnimation @ 0x5d350). Built
//  in InviteTopViewControllerPad.mm (Objective-C++: the neEngine /
//  neSceneManager singletons drive the system SE and the root-VC end callback).
//

#import <UIKit/UIKit.h>

@class Downloader;

@interface InviteTopViewControllerPad : UIViewController {
    BOOL isAnimationing;                 // an open/close fade is running (guards re-entry)
    UITextField *_codeField;             // guest invite-code entry field
    UIActivityIndicatorView *_indicator; // in-flight spinner (never instantiated in the binary)
    Downloader *_downloader;             // the invite POST (nil when idle)
    UIScrollView *_scrollView;           // scrolls the panels up when the keyboard shows
}

// Build the combined invite screen + wrap it in a navigation controller, which
// is returned. Ghidra: @ 0x5c638.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

// Fade the view (and its nav view) in over 0.3 s. Ghidra: @ 0x5d350.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
