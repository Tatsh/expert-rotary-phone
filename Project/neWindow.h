//
//  neWindow.h
//  pop'n rhythmin
//
//  A thin UIWindow subclass. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. The __objc_classlist entry's class_ro (@ 0x140744) declares:
//    flags 0x10, instanceStart 0x90, instanceSize 0x90 (144), ivars = NULL.
//  Because instanceStart == instanceSize and the ivar list pointer is null, the
//  class adds NO ivars of its own; the 144-byte instance size is entirely the
//  inherited UIWindow layout. The superclass is UIWindow (confirmed by the sole
//  method calling UIWindow's -initWithFrame: via super).
//
//  Only one method is present in the class method_list (@ 0x140730, count 1):
//  -initWithFrame: @ 0x28a00.
//

#import <UIKit/UIKit.h>

@interface neWindow : UIWindow

// @ 0x28a00 — designated init, forwards straight to UIWindow.
- (instancetype)initWithFrame:(CGRect)frame;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
