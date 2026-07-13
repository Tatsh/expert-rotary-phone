//
//  ViewUtility.h
//  pop'n rhythmin
//
//  A stateless NSObject-derived helper. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin. The instance class_ro (@ 0x1477fc) has
//  instanceStart 4, instanceSize 4 (just the isa, an NSObject subclass), NULL
//  ivars, and a NULL instance method_list — so there are ZERO instance methods.
//
//  However the METACLASS class_ro (@ 0x1477d4) carries a baseMethods list
//  (@ 0x1477c0, count 1), i.e. the class exposes one CLASS method:
//    +getCommonBannerBg: @ 0x64f2c  (type "@24@0:4{CGRect=...}8", CGRect arg).
//  No categories reference ViewUtility elsewhere in the binary.
//

#import <UIKit/UIKit.h>

@interface ViewUtility : NSObject

// @ 0x64f2c — build the shared rounded gradient "banner" background view sized
// to `frame`, with a 3pt-inset inner tiled-pattern panel added as a subview.
+ (UIView *)getCommonBannerBg:(CGRect)frame;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
