//
//  RewardNetworkIndicator.h
//  pop'n rhythmin
//
//  Konami "RewardNetwork" (Applilink) ad-SDK modal busy indicator: a
//  translucent black UIView hosting a centered UIActivityIndicatorView.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (UIView
//  superclass; single
//  `_indicator` object ivar).
//

#import <UIKit/UIKit.h>

@interface RewardNetworkIndicator : UIView

// _indicator ivar / accessors @ 0xf3eb4 (getter) / 0xf3ec4 (setter).
@property(nonatomic, strong) UIActivityIndicatorView *indicator;

// @ 0xf3e14 — unhide and start the spinner.
- (void)show;

// @ 0xf3e64 — hide and stop the spinner.
- (void)close;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
