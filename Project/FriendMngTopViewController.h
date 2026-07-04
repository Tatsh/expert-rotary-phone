//
//  FriendMngTopViewController.h
//  pop'n rhythmin
//
//  The friend-management hub (iPhone; the iPad uses FriendMngTopSplitViewController). Pushed by
//  MainViewController -GotoFriendManage: over the game view, wrapped in its own navigation
//  controller. Offers three sections — friend list, "presenting" (requests you sent), and replies
//  (requests to you, with a "new" warning badge). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initAtNavigationController @ 0xa59f0, startOpenAnimation @ 0xa6590).
//

#import <UIKit/UIKit.h>

@interface FriendMngTopViewController : UIViewController {
    __unsafe_unretained id m_Delegate;  // hosting VC (self-set; plain assign, not retained)
    UIImageView *_markView;       // "new reply" warning badge over the reply button
    BOOL _isAnimationing;         // an open/close animation is running (guards re-entry)
}

// The hosting controller (MainViewController on iPhone; the split hub on iPad) that
// section taps / close are forwarded to. Synthesized accessors backing m_Delegate.
// Ghidra: delegate @ 0xa6c00 / setDelegate: @ 0xa6c10.
@property (nonatomic, assign) id delegate;

// Build the hub view + its navigation controller (custom back button, section buttons) and return
// the navigation controller. Ghidra: initAtNavigationController @ 0xa59f0.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

// Fade the hub (and its nav view) in / out over 0.5 s. Ghidra: startOpenAnimation @ 0xa6590 /
// startCloseAnimation.
- (void)startOpenAnimation;
- (void)startCloseAnimation;

// Section buttons. Ghidra selectors onListButtonTouched: / onRequestButtonTouched: /
// onReplyButtonTouched:.
- (void)onListButtonTouched:(id)sender;
- (void)onRequestButtonTouched:(id)sender;
- (void)onReplyButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
