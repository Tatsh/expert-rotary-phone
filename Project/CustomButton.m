//
//  CustomButton.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CustomButton.h"

@implementation CustomButton

// initWithFrame: @ 0xdcf5c — super-only override (forwards straight to -[UIButton
//   initWithFrame:] with no extra setup), omitted.
// dealloc @ 0xdcf94 — ARC-omitted (super-only; the UIEdgeInsets ivar is a value type).
// setTappableInsets: @ 0xdd11c — synthesized atomic struct setter; annotated on the
//   @property in CustomButton.h.
// .cxx_construct @ 0xdd154 — compiler-emitted C++ ivar constructor for the UIEdgeInsets
//   ivar; not hand-written.

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
