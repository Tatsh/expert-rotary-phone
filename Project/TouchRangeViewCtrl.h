//
//  TouchRangeViewCtrl.h
//  pop'n rhythmin
//
//  The "touch range" adjustment sub-screen, pushed from the game settings. A UISlider
//  (40-148pt) sets the radius of the circular area around the preview pop-kun within
//  which a tap counts as a hit; dragging a finger inside that circle lights up the
//  embedded TouchRangeView (its "touched" art), and a reset button restores the
//  default radius (68pt). The chosen radius persists through UserSettingData and is
//  applied at play time (see -[UserSettingData touchRadius]).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (viewDidLoad @
//  0x8a360, didReceiveMemoryWarning @ 0x8a9d0, viewWillDisappear: @ 0x8a9fc,
//  sliderValChanged: @ 0x8aa9c, touchedResetButton: @ 0x8aad0, isEnablePoint: @
//  0x8ab04, touchesBegan:withEvent: @ 0x8abd0, touchesMoved:withEvent: @ 0x8ad0c,
//  touchesEnded:withEvent: @ 0x8af28, touchesCancelled:withEvent: @ 0x8b15c,
//  backButtonFunc @ 0x8b16c; the compiler-emitted .cxx_construct @ 0x8b208 is not
//  reproduced). Built in TouchRangeViewCtrl.mm (Objective-C++: -backButtonFunc drives
//  the neEngine C++ bridge for the system "cancel" SE).
//

#import <UIKit/UIKit.h>

@interface TouchRangeViewCtrl : UIViewController

// Slider handler (UISlider target/action) and reset button, exposed for the XIB-less
// wiring done in viewDidLoad.
- (void)sliderValChanged:(id)sender;      // @ 0x8aa9c  track slider value into _radius
- (void)touchedResetButton:(id)sender;    // @ 0x8aad0  restore default radius (68pt)
- (void)backButtonFunc;                   // @ 0x8b16c  custom back button

// YES if `point` (in view coordinates) lies within _radius of the pop-kun centre.
- (BOOL)isEnablePoint:(CGPoint)point;     // @ 0x8ab04

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
