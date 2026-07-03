//
//  TouchableScrollView.h
//  pop'n rhythmin
//
//  A UIScrollView subclass that forwards began-touch events up the responder
//  chain so taps pass through to the content behind the scroller. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin
//  (touchesBegan:withEvent: @ 0xe3114).
//

#import <UIKit/UIKit.h>

@interface TouchableScrollView : UIScrollView

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
