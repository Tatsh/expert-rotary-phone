//
//  main.m
//  pop'n rhythmin
//
//  Application entry point. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (entry @ 0xf2f4). The binary's entry does exactly what a standard iOS main() emits:
//  push an autorelease pool, then call UIApplicationMain with a nil principal class name and
//  the delegate class name resolved via NSStringFromClass([AppDelegate class]), popping the
//  pool on return. The objc_autoreleasePoolPush/Pop pair Ghidra shows is the @autoreleasepool
//  lowering; the third argument (principalClassName) is nil (0) in the binary.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
