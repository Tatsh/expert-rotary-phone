//
//  UIView+neSystemAddFunc.m
//  pop'n rhythmin
//
//  See UIView+neSystemAddFunc.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Float words decoded from the decompile:
//    0x3f800000=1.0  0x3f000000=0.5  0x3f99999a=1.2  0x3f666666=0.9
//    0x3eaaaaab=1/3  0x3e4ccccd=0.2  0x3f400000=0.75 0x3f4ccccd=0.8
//    0x3e800000=0.25 0x3dcccccd=0.1  0x7f7fffff=FLT_MAX
//    0xc2200000=-40.0 0xc1200000=-10.0 0xc0a00000=-5.0 0xc0000000=-2.0
//    double 0x4008000000000000=3.0  double 0x3ff0000000000000=1.0
//  ARC: the CGPath handle is a C object, released with CGPathRelease (not
//  ARC-managed).
//

#import <float.h>

#import <QuartzCore/QuartzCore.h>

#import "UIView+neSystemAddFunc.h"

@implementation UIView (neSystemAddFunc)

// @ 0x7dc90
- (void)setHarfSize {
    CGRect b = self.bounds;
    b.size.width *= 0.5f; // 0x3f000000
    b.size.height *= 0.5f;
    self.bounds = b;
}

// @ 0x7dd08
- (void)setHarfOrigin {
    CGRect f = self.frame;
    f.origin.x *= 0.5f;
    f.origin.y *= 0.5f;
    self.frame = f;
}

// @ 0x7dd88
- (void)setHarfSizeAndOrigin {
    CGRect f = self.frame;
    f.origin.x *= 0.5f;
    f.origin.y *= 0.5f;
    f.size.width *= 0.5f;
    f.size.height *= 0.5f;
    self.frame = f;
}

// @ 0x7de20
- (void)SetFlashEffectDuration:(float)duration Start:(float)startOpacity End:(float)endOpacity {
    [self RemoveFlashEffect];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.duration = duration;
    anim.repeatCount = FLT_MAX; // 0x7f7fffff
    anim.autoreverses = YES;
    anim.fromValue = [NSNumber numberWithFloat:startOpacity];
    anim.toValue = [NSNumber numberWithFloat:endOpacity];
    anim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5f:0.0f:0.75f:0.8f];
    anim.removedOnCompletion = NO;
    [self.layer addAnimation:anim forKey:@"FLUSH_ANIM"];
}

// @ 0x7dfd0
- (void)SetFlashEffectFast {
    // 0x3eaaaaab (~1/3 s), 0x3f800000 (1.0), 0x3e4ccccd (0.2)
    [self SetFlashEffectDuration:0.33333334f Start:1.0f End:0.2f];
}

// @ 0x7e160
- (void)SetJumpEffectBaseX:(float)baseX BaseY:(float)baseY {
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, baseX, baseY);

    // Four upward bounces with decreasing amplitude, each a cubic curve whose
    // control points sit at the peak so the view rises to (baseY + amp) and falls
    // back to baseY.
    const float amplitudes[4] = {-40.0f, -10.0f, -5.0f, -2.0f};
    for (int i = 0; i < 4; i++) {
        float peakY = baseY + amplitudes[i];
        CGPathAddCurveToPoint(path, NULL, baseX, peakY, baseX, peakY, baseX, baseY);
    }
    // Four settling segments that hold the base point (no further movement).
    for (int i = 0; i < 4; i++) {
        CGPathAddCurveToPoint(path, NULL, baseX, baseY, baseX, baseY, baseX, baseY);
    }

    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    anim.path = path;
    anim.duration = 3.0; // double 0x4008000000000000
    anim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.25f:0.1f:0.5f:0.5f];
    anim.repeatCount = FLT_MAX; // 0x7f7fffff
    anim.removedOnCompletion = NO;
    CGPathRelease(path);
    [self.layer addAnimation:anim forKey:@"PopAnim"];
}

// @ 0x7e3c4
- (void)setPopupEffect {
    [self removePopupEffect];

    CATransform3D base = self.layer.transform;
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    anim.values = @[
        [NSValue valueWithCATransform3D:CATransform3DScale(base, 0.0f, 0.0f, 1.0f)],
        [NSValue valueWithCATransform3D:CATransform3DScale(base,
                                                           1.2f,
                                                           1.2f,
                                                           1.0f)], // 0x3f99999a
        [NSValue valueWithCATransform3D:CATransform3DScale(base,
                                                           0.9f,
                                                           0.9f,
                                                           1.0f)], // 0x3f666666
        [NSValue valueWithCATransform3D:base],
    ];
    anim.keyTimes = @[ @0.0f, @0.5f, @0.9f, @1.0f ];
    anim.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
    ];
    anim.fillMode = kCAFillModeForwards;
    anim.removedOnCompletion = NO;
    anim.duration = 1.0; // double 0x3ff0000000000000
    [self.layer addAnimation:anim forKey:@"transAnimation"];
}

// @ 0x7df9c
- (void)RemoveFlashEffect {
    [self.layer removeAnimationForKey:@"FLUSH_ANIM"];
}

// @ 0x7eac0
- (void)removePopupEffect {
    [self.layer removeAnimationForKey:@"transAnimation"];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
