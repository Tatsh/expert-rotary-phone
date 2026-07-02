//
//  neGLView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): forwards touches to the C++ task/input system.
//

#import <QuartzCore/QuartzCore.h>

#import "neGLView.h"

// Engine input entry points (the task manager dispatches touches to tasks).
extern "C" {
void *neTaskManagerShared(void);                                  // Ghidra: FUN_00012358
void neTaskInputTouchBegan(void *tm, int x, int y, int w, int h); // Ghidra: FUN_000124f8
void neTaskInputTouchEnded(void *tm, int x, int y, int px, int py);// Ghidra: FUN_000125ec
void neTaskInputClearTouches(void *tm);                           // Ghidra: FUN_00012698
}

// Engine touch coordinates are 16.16 fixed point.
static inline int ToFixed(CGFloat v) { return (int)(v * 65536.0f); }

@implementation neGLView

// GL ES views are backed by a CAEAGLLayer.
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Touch -> engine input

// @ 0x285e8 — report each touch's location (+ the view size for mapping).
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGRect frame = self.frame;
    void *tm = neTaskManagerShared();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        neTaskInputTouchBegan(tm, ToFixed(p.x), ToFixed(p.y),
                              ToFixed(CGRectGetWidth(frame)), ToFixed(CGRectGetHeight(frame)));
    }
}

// @ 0x28850 — if every touch ended, clear all; otherwise report each end.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    void *tm = neTaskManagerShared();
    if (touches.count == [event touchesForView:self].count) {
        neTaskInputClearTouches(tm);
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        CGPoint prev = [touch previousLocationInView:self];
        neTaskInputTouchEnded(tm, ToFixed(p.x), ToFixed(p.y),
                              ToFixed(prev.x), ToFixed(prev.y));
    }
}

#pragma mark - Render surface

// EAGLContext + framebuffer/renderbuffer management. [bodies pending — the
// original wraps the standard CAEAGLLayer + GL ES 1.1 framebuffer setup.]
- (void)BeginRender {}
- (void)SetDefaultFrameBuffer {}
- (void)SetDefaultColorBuffer {}
- (void)Present {}

@end
