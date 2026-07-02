//
//  MainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): drives the C++ task/scene engine each display frame.
//

#import <OpenGLES/ES1/gl.h>

#import "MainViewController.h"
#import "AepManager.h"
#import "C_TASK.h"
#import "neFrameTimer.h"
#import "neGLView.h"

// Minimum seconds between rendered frames (Ghidra: DAT_0000be7c). Rendering is
// skipped when the accumulated render time has not yet reached this.
static const float kRenderMinInterval = 1.0f / 60.0f;

// Fixed-point (16.16) seconds helper for the task update step.
static int SecondsToFixed(float s) { return (int)(s * 65536.0f); }

@implementation MainViewController {
    BOOL m_IsLoop;
    BOOL m_IsPause;
    int m_LoopInterval;
    CADisplayLink *m_DisplayLink;
    neGLView *_glView;
    AepManager *m_AepManager;    // C++ scene owner
    BOOL m_flgCapture;
    UIImage *m_capturedImg;
    // Wall-clock stopwatches pacing the task-update and render steps.
    neFrameTimer m_taskTime;
    neFrameTimer m_renderTime;
}

#pragma mark - Loop control

// @ 0xbeb0
- (void)StartLoop {
    m_IsLoop = YES;
    [self CreateTimer];
}

// @ 0xbef0
- (void)PauseLoop {
    m_IsPause = YES;
    [self RemoveTimer];
}

// @ 0xbf10
- (void)ResumeLoop {
    m_IsPause = NO;
    [self CreateTimer];
}

// @ 0xc054
- (void)SetLoopInterval:(int)interval {
    m_LoopInterval = interval;
    if (!m_IsPause && m_IsLoop && m_DisplayLink == nil) {
        [self CreateTimer];
    }
}

// @ 0xbf30 — (re)create the CADisplayLink bound to -mainLoop.
- (void)CreateTimer {
    if (m_IsPause || !m_IsLoop) {
        return;
    }
    m_taskTime.reset();
    m_renderTime.reset();
    if (m_DisplayLink == nil) {
        m_DisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(mainLoop)];
        m_DisplayLink.frameInterval = m_LoopInterval;
        [m_DisplayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
    }
}

// @ 0xc024
- (void)RemoveTimer {
    if (m_DisplayLink == nil) {
        return;
    }
    [m_DisplayLink invalidate];
    m_DisplayLink = nil;
}

- (BOOL)isPause { return m_IsPause; }   // @ 0xf148
- (BOOL)isLoop  { return m_IsLoop; }    // @ 0xf160

#pragma mark - Frame

// @ 0xbe80 — one display frame.
- (void)mainLoop {
    [self task];
    [self draw];
}

// @ 0xbb5c — advance all tasks by the elapsed time, then reap dead ones.
- (void)task {
    float dt = m_taskTime.elapsedSeconds();
    m_taskTime.reset();
    // updateAll walks the priority list, updating live tasks and reaping (deleting)
    // any flagged for deletion in the same pass — no separate sweep needed.
    C_TASK::updateAll(SecondsToFixed(dt));
}

// @ 0xbd30 — render the scene, frame-limited by the render timer.
- (void)draw {
    float dt = m_renderTime.elapsedSeconds();
    if (dt < kRenderMinInterval) {
        [_glView BeginRender];
        [_glView SetDefaultFrameBuffer];
        glClear(GL_COLOR_BUFFER_BIT);
        m_AepManager->draw();

        if (m_flgCapture) {
            if (m_capturedImg != nil) {
                m_capturedImg = nil;
            }
            m_capturedImg = [MainViewController capture:_glView];
            m_flgCapture = NO;
        }

        [_glView SetDefaultColorBuffer];
        [_glView Present];
    }
    m_renderTime.reset();
}

@end
