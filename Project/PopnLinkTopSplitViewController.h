//
//  PopnLinkTopSplitViewController.h
//  pop'n rhythmin
//
//  The iPad pop'n-link hub: a floating master/detail split panel over a dimmed
//  backdrop. The left pane is a PopnLinkTopViewController (the section-button
//  column); the right pane is a UINavigationController whose top controller is
//  swapped between the KONAMI-ID input / score-checker / quiz sections by the
//  left column's buttons (forwarded here through the left VC's delegate). While
//  the player has not yet linked their pop'n-link (e-AMUSEMENT KID) the checker
//  / quiz buttons instead route to the KONAMI-ID input screen
//  (neAppEventCenter::linkButtonsEnabled()). Section swaps are block-based flip
//  transitions; a selection arrow tracks the active row. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (init @ 0xe0b40, the shared
//  open/close fade animations, the section handlers
//  onInKidButtonTouched:/onScoreCheckerButtonTouched:/onQuizButtonTouched:).
//
//  Animation lifecycle (shared modal-VC pattern):
//    startOpenAnimation  — fade the view (+ its nav view) 0 -> 1 over 0.5s;
//    didStop ->
//                          endOpenAnimation (clears the guard)
//    startCloseAnimation — fade 1 -> 0 over 0.3s; didStop -> endCloseAnimation
//    endCloseAnimation   — removeFromSuperview + [rootVC PopnLinkEndCallBack]
//

#import <UIKit/UIKit.h>

// Callback interface the KID-input screen (InputKIDViewCtrl) sends to its
// owning split controller once the pop'n-link succeeds on pad: rebuild the left
// column's inputs and re-enter the score-checker section.
// PopnLinkTopSplitViewController conforms via its own -reloadLeftView /
// -onScoreCheckerButtonTouched: below. Ghidra: sent from InputKIDViewCtrl
// -commonAlertView:clickedButtonAtIndex: @ 0xd7284.
/**
 * @brief The callback interface the KID-input screen sends to its owning split controller once the
 * pop'n-link succeeds on iPad.
 */
@protocol PopnLinkTopSplitViewControllerDelegate <NSObject>
/**
 * @brief Rebuild the left column's inputs after a link state change.
 */
- (void)reloadLeftView;
/**
 * @brief Re-enter the score-checker section.
 * @param sender The originating control.
 */
- (void)onScoreCheckerButtonTouched:(id)sender;
@end

/**
 * @brief The iPad pop'n-link hub: a section column beside a detail pane.
 */
@interface PopnLinkTopSplitViewController : UIViewController

/**
 * @brief Fade the panel and its navigation view in.
 * @ghidraAddress 0xe1538
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the panel and its navigation view out.
 * @ghidraAddress 0xe1858
 */
- (void)startCloseAnimation;

/**
 * @brief Rebuild the left column's inputs and re-evaluate its button-enabled state, called back
 * after a link state change.
 * @ghidraAddress 0xe2bb8
 */
- (void)reloadLeftView;

// Section buttons, driven by the left column (PopnLinkTopViewController) through its delegate:
// they swap the right pane's top controller and slide the selection arrow. Checker and quiz fall
// back to the KONAMI-ID input while the player is not linked.

/**
 * @brief Show the KONAMI-ID input in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xe19c0
 */
- (void)onInKidButtonTouched:(id)sender;
/**
 * @brief Show the score checker in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xe1fa8
 */
- (void)onScoreCheckerButtonTouched:(id)sender;
/**
 * @brief Show the quiz in the right pane.
 * @param sender The tapped button.
 * @ghidraAddress 0xe25b0
 */
- (void)onQuizButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
