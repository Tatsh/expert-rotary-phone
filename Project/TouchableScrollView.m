//
//  TouchableScrollView.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "TouchableScrollView.h"

@implementation TouchableScrollView

// initWithFrame: @ 0xe30dc — super-only override, omitted

// @ 0xe3114 — forward the began-touch event to the next responder (the view
// behind/containing the scroller) first, then let UIScrollView handle it. The
// recovered code calls [[self nextResponder] touchesBegan:withEvent:] followed
// by [super touchesBegan:withEvent:].
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.nextResponder touchesBegan:touches withEvent:event];
    [super touchesBegan:touches withEvent:event];
}

@end
