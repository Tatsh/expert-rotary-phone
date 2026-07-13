//
//  AcceptPolicyViewController.h
//  pop'n rhythmin
//
//  The first-run "accept the terms of use" modal. A rounded, gradient-filled
//  card centred over the game view, holding a scrolling terms summary (a
//  read-only CustomTextView inside an embedded navigation controller) and three
//  buttons: "詳細" (show the full PolicyView), reject, and accept. Accepting
//  records the agreement (UserSettingData +saveIsPolicyAccepted:). Shown by
//  MainViewController -GotoAcceptPolicy, which adds self.view over the root and
//  calls startOpenAnimation. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (init @ 0xaf848, dealloc @ 0xb02bc). Built in
//  AcceptPolicyViewController.mm (Objective-C++: the SE / scene-root bridge
//  drives the C++ neEngine singletons).
//

#import <UIKit/UIKit.h>

@interface AcceptPolicyViewController : UIViewController {
    BOOL isAnimationing;                 // an open/close fade is running (guards re-entry)
    UIView *_topView;                    // the card's primary content view
    UIImageView *_detailView;            // detail overlay (toggled by the back button)
    UINavigationController *_policyView; // lazily-built full-terms overlay (PolicyView host)
    UINavigationController *_naviCtrl;   // the card's embedded content navigation controller
}

// Fade the card in over 0.3 s. Ghidra: startOpenAnimation @ 0xb0540.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
