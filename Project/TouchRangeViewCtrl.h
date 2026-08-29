/**
 * @file
 * @brief The "touch range" adjustment sub-screen, pushed from the game settings.
 *
 * A UISlider covering 40-148pt sets the radius of the circular area around the preview pop-kun
 * within which a tap counts as a hit; dragging a finger inside that circle lights up the embedded
 * TouchRangeView with its "touched" art, and a reset button restores the default radius of 68pt.
 * The chosen radius persists through UserSettingData and is applied at play time; see
 * -[UserSettingData touchRadius].
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (viewDidLoad @ 0x8a360,
 * didReceiveMemoryWarning @ 0x8a9d0, viewWillDisappear: @ 0x8a9fc, sliderValChanged: @ 0x8aa9c,
 * touchedResetButton: @ 0x8aad0, isEnablePoint: @ 0x8ab04, touchesBegan:withEvent: @ 0x8abd0,
 * touchesMoved:withEvent: @ 0x8ad0c, touchesEnded:withEvent: @ 0x8af28,
 * touchesCancelled:withEvent: @ 0x8b15c, backButtonFunc @ 0x8b16c; the compiler-emitted
 * .cxx_construct @ 0x8b208 is not reproduced). Built in TouchRangeViewCtrl.mm, where
 * -backButtonFunc drives the neEngine C++ bridge for the system "cancel" SE.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The note touch-radius setting screen: a slider over a live touch-target preview.
 */
@interface TouchRangeViewCtrl : UIViewController

// The slider handler and reset button, exposed for the XIB-less wiring done in -viewDidLoad.

/**
 * @brief The slider moved: track its value into the radius.
 * @param sender The slider.
 * @ghidraAddress 0x8aa9c
 */
- (void)sliderValChanged:(id)sender;
/**
 * @brief The reset button: restore the default 68 pt radius.
 * @param sender The tapped button.
 * @ghidraAddress 0x8aad0
 */
- (void)touchedResetButton:(id)sender;
/**
 * @brief The custom back-button action.
 * @ghidraAddress 0x8b16c
 */
- (void)backButtonFunc;

/**
 * @brief Whether a point lies inside the current touch radius.
 * @param point The point, in view coordinates.
 * @return YES when it is within the radius of the pop-kun centre.
 * @ghidraAddress 0x8ab04
 */
- (BOOL)isEnablePoint:(CGPoint)point;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
