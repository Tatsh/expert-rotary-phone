//
//  PopnLinkTopViewController.h
//  pop'n rhythmin
//
//  The "pop'n link" top menu: three stacked buttons over a "friman_bg" backdrop (phone)
//  or a clear view inside the pad split panel — KID info (onInKid), score checker
//  (onScoreChecker) and quiz (onQuiz), each with a "ps_*" caption image. The checker /
//  quiz buttons are enabled only once the player has linked their pop'n-link (e-AMUSEMENT
//  KID); until then the screen forces the KID-input flow. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (init @ 0xccacc and 15 more methods). Built in
//  PopnLinkTopViewController.mm (Objective-C++: drives the C++ neSceneManager /
//  neAppEventCenter singletons for the pad flag, SE playback and the link-enabled flag).
//
//  On the phone each button pushes the matching sub-screen onto its own navigation
//  controller; on the pad it forwards the tap to a delegate (the pad split host owns the
//  detail pane) — see PopnLinkTopViewControllerDelegate. Follows the app-wide modal-VC
//  lifecycle: startOpenAnimation fades the view + nav view 0 -> 1; startCloseAnimation
//  fades 1 -> 0 (or forwards to the delegate on the pad); endCloseAnimation removes the
//  nav view and notifies the host via -[MainViewController PopnLinkEndCallBack].
//

#import <UIKit/UIKit.h>

// The pad-layout host (the pop'n-link split/detail owner) receives the button taps and the
// close request so it can drive its own detail pane.
@protocol PopnLinkTopViewControllerDelegate <NSObject>
- (void)onInKidButtonTouched:(id)sender;         // @ 0xcdad4 (pad) forwards here
- (void)onScoreCheckerButtonTouched:(id)sender;  // @ 0xcdc18 (pad) forwards here
- (void)onQuizButtonTouched:(id)sender;          // @ 0xcdd5c (pad) forwards here
- (void)startCloseAnimation;                     // @ 0xcd908 (pad) forwards here
@end

@interface PopnLinkTopViewController : UIViewController

// Lay out the three buttons + caption images (phone: over friman_bg; pad: over a clear
// view) and seed the checker / quiz enabled state. Ghidra: init @ 0xccacc.
- (instancetype)init;

// Build self, wrap it in a fresh navigation controller (back button + nav-bar art) and
// return that controller (the phone layout). Ghidra: initAtNavigationController @ 0xcd2e0.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

- (void)startOpenAnimation;    // @ 0xcd5a8
- (void)startCloseAnimation;   // @ 0xcd908 (also the back-button action / cancel SE)

// Re-apply the checker / quiz enabled state from the link flag. Ghidra: updateButtonEnable @ 0xcca48.
- (void)updateButtonEnable;

// The pad-layout tap target. Synthesized assign accessors: getter @ 0xcdea0, setter @ 0xcdeb0.
@property (nonatomic, assign) id<PopnLinkTopViewControllerDelegate> delegate;

// Synthesized assign accessors: getter @ 0xcdec0, setter @ 0xcded0.
@property (nonatomic, assign) UIScrollView *scrollView;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
