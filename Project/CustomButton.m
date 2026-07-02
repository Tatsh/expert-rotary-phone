//
//  CustomButton.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CustomButton.h"

@implementation CustomButton

// @ 0xdcfc0 — hit-test the point against the bounds inset by `tappableInsets`. With
// the negative insets callers pass (e.g. -20 on every edge) this enlarges the tap
// area; the recovered vector math (origin += top/left, size -= top+bottom / left+
// right) is exactly UIEdgeInsetsInsetRect.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect area = UIEdgeInsetsInsetRect(self.bounds, self.tappableInsets);
    return CGRectContainsPoint(area, point);
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
