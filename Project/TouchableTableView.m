//
//  TouchableTableView.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "TouchableTableView.h"

@implementation TouchableTableView

// initWithFrame: @ 0xe96ec — super-only override, omitted
// dealloc @ 0xe9724 — super-only override, omitted

// @ 0xe9750 — forward the began-touch event to the next responder (the view
// behind/containing the table) first, then let UITableView handle it. The
// recovered code calls [[self nextResponder] touchesBegan:withEvent:] followed
// by [super touchesBegan:withEvent:].
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.nextResponder touchesBegan:touches withEvent:event];
    [super touchesBegan:touches withEvent:event];
}

@end
