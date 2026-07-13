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
@protocol PopnLinkTopSplitViewControllerDelegate <NSObject>
- (void)reloadLeftView;
- (void)onScoreCheckerButtonTouched:(id)sender;
@end

@interface PopnLinkTopSplitViewController : UIViewController

// Fade the panel (and its nav view) in / out. Ghidra: startOpenAnimation @
// 0xe1538 / startCloseAnimation @ 0xe1858.
- (void)startOpenAnimation;
- (void)startCloseAnimation;

// Rebuild the left column's inputs and re-evaluate its button-enabled state
// (called back after a link state change). Ghidra: reloadLeftView @ 0xe2bb8.
- (void)reloadLeftView;

// Section buttons, driven by the left column (PopnLinkTopViewController) via
// its delegate: swap the right pane's top controller and slide the selection
// arrow. Checker / quiz fall back to the KONAMI-ID input while the player is
// not linked. Ghidra: onInKidButtonTouched:
// @ 0xe19c0 / onScoreCheckerButtonTouched: @ 0xe1fa8 / onQuizButtonTouched: @
// 0xe25b0.
- (void)onInKidButtonTouched:(id)sender;
- (void)onScoreCheckerButtonTouched:(id)sender;
- (void)onQuizButtonTouched:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
