/**
 * @file
 * The iPad layout of the arcade (AC) viewer.
 *
 * A floating split panel over a dimmed backdrop: a left column of category, music-name, and genre
 * buttons and a right navigation pane that hosts the AcViewerCategoryViewController list.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0x318e8, initForLeftView @
 * 0x322c4, the shared open and close fade animations, onButtonTouched: and
 * onBackButtonTouched:).
 *
 * All the app's modal view controllers share this animation lifecycle:
 *
 * - startOpenAnimation fades the view, and its nav controller view, 0 -> 1; didStop reaches
 *   endOpenAnimation, which clears isAnimationing.
 * - startCloseAnimation fades 1 -> 0; didStop reaches endCloseAnimation.
 * - endCloseAnimation removes the view from its superview and calls
 *   `[rootVC <Screen>EndCallBack]`.
 *
 * iPad variants sometimes slide or fade a "black board" instead; an isAnimationing flag guards
 * against overlapping transitions.
 */

#import <UIKit/UIKit.h>

/**
 * The iPad layout of the arcade viewer: a floating split panel over a dimmed backdrop.
 */
@interface AcViewerSplitViewController : UIViewController

/**
 * Fade the panel and its navigation controller in.
 * @ghidraAddress 0x3272c
 */
- (void)startOpenAnimation;
/**
 * Fade the panel out, tearing it down on didStop.
 * @ghidraAddress 0x32870
 */
- (void)startCloseAnimation;

/**
 * Fade the panel out and swap the right pane to the arcade-viewer option screen.
 * @param animated YES to fade, NO to swap after a short delay.
 * @ghidraAddress 0x32a80
 */
- (void)startHiddenAnimation:(BOOL)animated;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
