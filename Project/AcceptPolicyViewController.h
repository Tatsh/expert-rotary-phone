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
    /** An open or close fade is running; it guards against re-entry. */
    BOOL isAnimationing;
    UIView *_topView;         /**< The card's primary content view. */
    UIImageView *_detailView; /**< The detail overlay, toggled by the back button. */
    /** The lazily-built full-terms overlay, hosting a PolicyView. */
    UINavigationController *_policyView;
    /** The card's embedded content navigation controller. */
    UINavigationController *_naviCtrl;
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
