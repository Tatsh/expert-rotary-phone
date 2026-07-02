//
//  MainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): drives the C++ task/scene engine each display frame.
//

#import "MainViewController.h"
#import "AepManager.h"
#import "C_TASK.h"
#import "neFrameTimer.h"
#import "neGLView.h"

// --- Engine entry points the loop still calls into (not yet reconstructed as
//     classes; referencing the real API is preferred once they are). ---
extern "C" {
// Clear the current framebuffer (GL_COLOR_BUFFER_BIT).
void neGraphicsClear(void);                     // Ghidra: FUN_00012c14 + vtbl[0x4c](0x4000)
// Compact the task manager's list, dropping tasks flagged for deletion.
void neTaskManagerReap(void);                   // Ghidra: task-list sweep @ 0xbb5c
}

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
    C_TASK::updateAll(SecondsToFixed(dt));
    // Sweep the task list: for each task, snapshot its state (prev = cur) and
    // swap-remove any flagged for deletion (original inlines this @ 0xbb5c).
    neTaskManagerReap();
}

// @ 0xbd30 — render the scene, frame-limited by the render timer.
- (void)draw {
    float dt = m_renderTime.elapsedSeconds();
    if (dt < kRenderMinInterval) {
        [_glView BeginRender];
        [_glView SetDefaultFrameBuffer];
        neGraphicsClear();
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
