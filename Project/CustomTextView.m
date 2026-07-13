//
//  CustomTextView.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CustomTextView.h"

@implementation CustomTextView

// initWithFrame: @ 0x27fd0 — super-only override (just chains to UITextView),
// omitted. dealloc @ 0x28008 — ARC-omitted (no custom teardown; only [super
// dealloc]).

// @ 0x28080 — never editable/selectable.
- (BOOL)canBecomeFirstResponder {
    return NO;
}

// @ 0x28034 — suppress the copy/select menu and drop first responder.
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    UIMenuController.sharedMenuController.menuVisible = NO;
    [self resignFirstResponder];
    return NO;
}

@end
