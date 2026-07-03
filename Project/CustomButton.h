//
//  CustomButton.h
//  pop'n rhythmin
//
//  A UIButton whose hit-test area is grown (or shrunk) by `tappableInsets`:
//  negative insets enlarge the tappable region beyond the button's bounds, so a
//  small on-screen button can still be comfortably tapped. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (pointInside:withEvent: @ 0xdcfc0,
//  tappableInsets / setTappableInsets: @ 0xdd0f8 / 0xdd11c).
//

#import <UIKit/UIKit.h>

@interface CustomButton : UIButton

// Applied to the bounds before hit-testing (UIEdgeInsetsInsetRect); negative
// values expand the tappable area. Synthesized atomic property — the recovered
// setter uses an atomic objc_copyStruct (@ 0xdd0f8 getter / 0xdd11c setter).
@property (atomic) UIEdgeInsets tappableInsets;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
