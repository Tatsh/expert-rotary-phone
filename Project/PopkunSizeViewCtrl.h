//
//  PopkunSizeViewCtrl.h
//  pop'n rhythmin
//
//  The "pop-kun size" adjustment sub-screen, pushed from row 5 (ポップ君サイズ)
//  of SettingGameTableViewController. A UISlider (50-100%) live-resizes a
//  preview pop-kun UIImageView; a "%d%%" label tracks the current value and a
//  reset button restores 100%. The chosen size persists through UserSettingData
//  and is applied to the note field at play time (see -[UserSettingData
//  popkunSize]).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (viewDidLoad @
//  0x8b44c, didReceiveMemoryWarning @ 0x8c1a4, viewWillDisappear: @ 0x8c1d0,
//  dealloc @ 0x8c1fc, sliderValChanged: @ 0x8c228, sliderValDecide: @ 0x8c270,
//  touchedResetButton: @ 0x8c29c, backButtonFunc @ 0x8c30c, resizePopkun @
//  0x8c3a8; the compiler-emitted .cxx_construct @ 0x8c620 is not reproduced).
//  Built in PopkunSizeViewCtrl.mm (Objective-C++: it drives the neEngine /
//  neSceneManager C++ bridge for the pad-display flag and the system "cancel"
//  SE).
//
//  Two layouts: on iPhone the whole screen is used and a custom navi_btn_back
//  bar button drives backButtonFunc; on iPad the controls are laid out inside a
//  fixed 428pt-wide panel with an info label + preview art and the system back
//  button.
//

#import <UIKit/UIKit.h>

/**
 * @brief The note ("pop-kun") size setting screen: a slider over a live preview.
 */
@interface PopkunSizeViewCtrl : UIViewController

// Slider handlers and the reset button, exposed for the XIB-less wiring done in -viewDidLoad.

/**
 * @brief The slider moved: apply the live value to the preview.
 * @param sender The slider.
 * @ghidraAddress 0x8c228
 */
- (void)sliderValChanged:(id)sender;
/**
 * @brief The slider was released: persist the chosen size.
 * @param sender The slider.
 * @ghidraAddress 0x8c270
 */
- (void)sliderValDecide:(id)sender;
/**
 * @brief The reset button: restore 100%.
 * @param sender The tapped button.
 * @ghidraAddress 0x8c29c
 */
- (void)touchedResetButton:(id)sender;
/**
 * @brief The iPhone custom back-button action.
 * @ghidraAddress 0x8c30c
 */
- (void)backButtonFunc;

/**
 * @brief Apply the current size to the preview note and refresh the percentage label.
 * @ghidraAddress 0x8c3a8
 */
- (void)resizePopkun;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
