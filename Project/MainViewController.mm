//
//  MainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): drives the C++ task/scene engine each display frame.
//

#import "MainViewController.h"
#import "neGLView.h"

// --- Engine entry points the loop calls into (cited; reconstructed in the
//     engine .cpp). ---
extern "C" {
// Advance every registered C_TASK by `fixedDt` (16.16 fixed seconds).
void neTaskManagerUpdate(int fixedDt);          // Ghidra: FUN_00027f40
// Draw the whole Aep scene (ordering table) for `aepManager`.
void neAepManagerDraw(void *aepManager);        // Ghidra: FUN_0001058c
// Clear the current framebuffer (GL_COLOR_BUFFER_BIT).
void neGraphicsClear(void);                     // Ghidra: FUN_00012c14 + vtbl[0x4c](0x4000)
// Compact the task manager's list, dropping tasks flagged for deletion.
void neTaskManagerReap(void);                   // Ghidra: task-list sweep @ 0xbb5c

// Frame timers (small structs owned inline by this controller).
void  neTimerReset(void *timer);                // Ghidra: FUN_00028084
float neTimerElapsedSeconds(void *timer);       // Ghidra: FUN_0002808c
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
    void *m_AepManager;          // C++ AepManager* (scene owner)
    BOOL m_flgCapture;
    UIImage *m_capturedImg;
    // Opaque inline frame timers (engine struct; see neTimer* above).
    unsigned char m_TaskTime[8];
    unsigned char m_RenderTime[8];
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
    neTimerReset(m_TaskTime);
    neTimerReset(m_RenderTime);
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
    float dt = neTimerElapsedSeconds(m_TaskTime);
    neTimerReset(m_TaskTime);
    neTaskManagerUpdate(SecondsToFixed(dt));
    // Sweep the task list: for each task, snapshot its state (prev = cur) and
    // swap-remove any flagged for deletion (original inlines this @ 0xbb5c).
    neTaskManagerReap();
}

// @ 0xbd30 — render the scene, frame-limited by the render timer.
- (void)draw {
    float dt = neTimerElapsedSeconds(m_RenderTime);
    if (dt < kRenderMinInterval) {
        [_glView BeginRender];
        [_glView SetDefaultFrameBuffer];
        neGraphicsClear();
        neAepManagerDraw(m_AepManager);

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
    neTimerReset(m_RenderTime);
}

@end
