/** @file
 * The first-run "accept the terms of use" modal: a rounded, gradient-filled card centred over the
 * game view. It holds a scrolling terms summary (a read-only CustomTextView inside an embedded
 * navigation controller) and three buttons: show the full PolicyView, reject, and accept.
 * Accepting records the agreement through UserSettingData. MainViewController's GotoAcceptPolicy
 * adds the view over the root and calls startOpenAnimation.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The first-run "accept the terms of use" modal card.
 */
@interface AcceptPolicyViewController : UIViewController {
    BOOL isAnimationing;                 // an open/close fade is running (guards re-entry)
    UIView *_topView;                    // the card's primary content view
    UIImageView *_detailView;            // detail overlay (toggled by the back button)
    UINavigationController *_policyView; // lazily-built full-terms overlay (PolicyView host)
    UINavigationController *_naviCtrl;   // the card's embedded content navigation controller
}

/**
 * @brief Fade the card in over 0.3 s.
 * @ghidraAddress 0xb0540
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
