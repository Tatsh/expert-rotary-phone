//
//  MainViewController.h
//  pop'n rhythmin
//
//  The root view controller and the bridge between UIKit and the C++ engine:
//  it hosts the GL view + AepManager scene and drives the render loop via a
//  CADisplayLink. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <UIKit/UIKit.h>

@class neGLView;

@interface MainViewController : UIViewController

// Loop control (driven from AppDelegate lifecycle callbacks).
- (void)SetLoopInterval:(int)interval;  // @ 0xc054
- (void)StartLoop;                      // @ 0xbeb0
- (void)PauseLoop;                      // @ 0xbef0
- (void)ResumeLoop;                     // @ 0xbf10
- (void)CreateTimer;                    // @ 0xbf30
- (void)RemoveTimer;                    // @ 0xc024

// One frame: advance tasks then render. Called by the CADisplayLink.
- (void)mainLoop;                       // @ 0xbe80
- (void)task;                           // @ 0xbb5c
- (void)draw;                           // @ 0xbd30

- (BOOL)isPause;                        // @ 0xf148
- (BOOL)isLoop;                         // @ 0xf160

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
