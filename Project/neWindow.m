//
//  neWindow.m
//  pop'n rhythmin
//
//  See neWindow.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (-initWithFrame: @ 0x28a00). The recovered body does nothing but chain to the
//  UIWindow implementation of -initWithFrame: through super; the binary's extra
//  load of the neWindow class pointer is just the runtime isa/stack setup and is
//  not observable behavior. The class ships no other methods and no ivars.
//

#import "neWindow.h"

@implementation neWindow

// @ 0x28a00 — [super initWithFrame:frame]; return the result unchanged.
- (instancetype)initWithFrame:(CGRect)frame {
    return [super initWithFrame:frame];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
