//
//  PopnLinkTopViewController.h
//  pop'n rhythmin
//
//  The "pop'n link" top menu: three stacked buttons over a "friman_bg" backdrop
//  (phone) or a clear view inside the pad split panel — KID info (onInKid),
//  score checker (onScoreChecker) and quiz (onQuiz), each with a "ps_*" caption
//  image. The checker / quiz buttons are enabled only once the player has
//  linked their pop'n-link (e-AMUSEMENT KID); until then the screen forces the
//  KID-input flow. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (init @ 0xccacc and 15 more methods). Built in
//  PopnLinkTopViewController.mm (Objective-C++: drives the C++ neSceneManager /
//  neAppEventCenter singletons for the pad flag, SE playback and the
//  link-enabled flag).
//
//  On the phone each button pushes the matching sub-screen onto its own
//  navigation controller; on the pad it forwards the tap to a delegate (the pad
//  split host owns the detail pane) — see PopnLinkTopViewControllerDelegate.
//  Follows the app-wide modal-VC lifecycle: startOpenAnimation fades the view +
//  nav view 0 -> 1; startCloseAnimation fades 1 -> 0 (or forwards to the
//  delegate on the pad); endCloseAnimation removes the nav view and notifies
//  the host via -[MainViewController PopnLinkEndCallBack].
//

#import <UIKit/UIKit.h>

// The pad-layout host (the pop'n-link split/detail owner) receives the button
// taps and the close request so it can drive its own detail pane.
/**
 * @brief The iPad-layout host, the pop'n-link split or detail owner, which receives the button
 * taps and the close request so it can drive its own detail pane.
 */
@protocol PopnLinkTopViewControllerDelegate <NSObject>
/**
 * @brief The KONAMI-ID input button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0xcdad4
 */
- (void)onInKidButtonTouched:(id)sender;
/**
 * @brief The score-checker button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0xcdc18
 */
- (void)onScoreCheckerButtonTouched:(id)sender;
/**
 * @brief The quiz button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0xcdd5c
 */
- (void)onQuizButtonTouched:(id)sender;
/**
 * @brief Close the hub.
 * @ghidraAddress 0xcd908
 */
- (void)startCloseAnimation;
@end

/**
 * @brief The pop'n-link top screen: the KONAMI-ID input, score-checker and quiz buttons.
 */
@interface PopnLinkTopViewController : UIViewController

/**
 * @brief Lay out the three buttons and caption images — over friman_bg on phone, over a clear view
 * on iPad — and seed the checker and quiz enabled state.
 * @return The initialised controller.
 * @ghidraAddress 0xccacc
 */
- (instancetype)init;

/**
 * @brief Build self and wrap it in a fresh navigation controller with a back button and nav-bar
 * art; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0xcd2e0
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen in.
 * @ghidraAddress 0xcd5a8
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the screen out; this is also the back-button action, which plays the cancel SE.
 * @ghidraAddress 0xcd908
 */
- (void)startCloseAnimation;

/**
 * @brief Re-apply the checker and quiz enabled state from the link flag.
 * @ghidraAddress 0xcca48
 */
- (void)updateButtonEnable;

/** The iPad-layout tap target. Getter @ 0xcdea0, setter @ 0xcdeb0. */
@property(nonatomic, assign) id<PopnLinkTopViewControllerDelegate> delegate;

/** The scroll view hosting the buttons. Getter @ 0xcdec0, setter @ 0xcded0. */
@property(nonatomic, assign) UIScrollView *scrollView;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
