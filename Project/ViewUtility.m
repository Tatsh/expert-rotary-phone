//
//  ViewUtility.m
//  pop'n rhythmin
//
//  See ViewUtility.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin
//  (+getCommonBannerBg: @ 0x64f2c). The class has no instance methods and no
//  ivars; this single class method is its only real code in the binary.
//
//  Float constants recovered from the decompile (IEEE-754 hex -> value):
//    cornerRadius 0x40a00000 = 5.0 (outer), 0x40200000 = 2.5 (inner)
//    inset origin 0x40400000 = 3.0, size delta 0xc0c00000 = -6.0
//    gradient colors via -colorWithRed:green:blue:alpha: (values below are the
//    exact 8-bit-quantized floats from the binary).
//

#import "ViewUtility.h"
#import <QuartzCore/QuartzCore.h>

@implementation ViewUtility

// @ 0x64f2c
+ (UIView *)getCommonBannerBg:(CGRect)frame {
    UIView *bg = [[UIView alloc] init];
    UIView *inner = [[UIView alloc] init];

    bg.frame = frame;
    bg.clipsToBounds = YES;
    bg.layer.cornerRadius = 5.0f;

    // Three-stop vertical gradient behind the banner.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height);
    UIColor *c0 = [UIColor colorWithRed:129.0f / 255.0f // 0x3f018182
                                  green:1.0f            // 0x3f800000
                                   blue:236.0f / 255.0f // 0x3f6ceced
                                  alpha:1.0f];
    UIColor *c1 = [UIColor colorWithRed:1.0f            // 0x3f800000
                                  green:232.0f / 255.0f // 0x3f68e8e9
                                   blue:104.0f / 255.0f // 0x3ed0d0d1
                                  alpha:1.0f];
    UIColor *c2 = [UIColor colorWithRed:254.0f / 255.0f // 0x3f7efeff
                                  green:162.0f / 255.0f // 0x3f22a2a3
                                   blue:174.0f / 255.0f // 0x3f2eaeaf
                                  alpha:1.0f];
    gradient.colors = @[ (id)c0.CGColor, (id)c1.CGColor, (id)c2.CGColor ];
    [bg.layer insertSublayer:gradient atIndex:0];

    // Inner panel inset by 3pt on every side (origin +3,+3; size -6,-6), tiled
    // with the "back_bg_st" pattern image (string @ 0x10587d).
    inner.frame = CGRectMake(3.0f, 3.0f, frame.size.width - 6.0f, frame.size.height - 6.0f);
    inner.clipsToBounds = YES;
    inner.layer.cornerRadius = 2.5f;
    inner.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"back_bg_st"]];
    [bg addSubview:inner];

    return bg;
}

@end
