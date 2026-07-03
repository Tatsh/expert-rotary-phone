//
//  neGLView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): forwards touches to the C++ task/input system.
//

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/QuartzCore.h>

#import "neEngineBridge.h"
#import "neGLView.h"
#import "neGraphics.h"

// Engine touch coordinates are 16.16 fixed point; the render/input manager
// (neGraphics) scales them to pixels and records them for the play-judge loop.
static inline int ToFixed(CGFloat v) { return (int)(v * 65536.0f); }

@implementation neGLView {
    // The binary routes the framebuffer/renderbuffer binds through m_GLInterface
    // (neGLES_11); those virtuals wrap exactly these GL ES 1.1 / OES FBO calls,
    // issued directly here.
    EAGLContext *m_GLContext;         // m_GLContext
    GLuint m_DefaultFramebuffer;      // m_DefaultFramebuffer
    GLuint m_ColorRenderbuffer;       // m_ColorRenderbuffer / m_RenderBufferID
    int m_FrontBufferWidth;           // m_FrontBufferWidth
    int m_FrontBufferHeight;          // m_FrontBufferHeight
}

// Ghidra shows -delegate/-setDelegate: as atomic accessors (DataMemoryBarrier
// around a plain pointer store — no objc_storeWeak, so this is assign, not ARC
// weak). Let the compiler emit them; the addresses are annotated here.
@synthesize delegate = _delegate;  // -delegate @ 0x289d4 / -setDelegate: @ 0x289e8

// @ 0x28524
- (int)GetFrontBufferWidth { return m_FrontBufferWidth; }
// @ 0x28534
- (int)GetFrontBufferHeight { return m_FrontBufferHeight; }

// GL ES views are backed by a CAEAGLLayer.
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Touch -> engine input

// @ 0x285e8 — report each touch's location (+ the view size for mapping).
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGRect frame = self.frame;
    neGraphics &gfx = neGraphics::shared();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        gfx.touchBegan(ToFixed(p.x), ToFixed(p.y),
                       ToFixed(CGRectGetWidth(frame)), ToFixed(CGRectGetHeight(frame)));
    }
}

// @ 0x28718 — report each touch's new + previous location (drag tracking).
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    neGraphics &gfx = neGraphics::shared();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        CGPoint prev = [touch previousLocationInView:self];
        gfx.touchMoved(ToFixed(p.x), ToFixed(p.y), ToFixed(prev.x), ToFixed(prev.y));
    }
}

// @ 0x28850 — if every touch ended, clear all; otherwise report each end.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    neGraphics &gfx = neGraphics::shared();
    if (touches.count == [event touchesForView:self].count) {
        gfx.clearTouches();
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        CGPoint prev = [touch previousLocationInView:self];
        gfx.touchEnded(ToFixed(p.x), ToFixed(p.y), ToFixed(prev.x), ToFixed(prev.y));
    }
}

// @ 0x289c4 — a cancelled touch is handled exactly like an ended one
// (the binary tail-calls -touchesEnded:withEvent:).
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

#pragma mark - Render surface

// @ 0x28100 — create the EAGL context + FBO once the view exists.
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // The CAEAGLLayer drawable: opaque, non-retained backing, RGB565.
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking : @NO,
            kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGB565,
        };
        m_GLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if (!m_GLContext || ![EAGLContext setCurrentContext:m_GLContext]) {
            return nil;
        }
        self.backgroundColor = [UIColor clearColor];
        self.multipleTouchEnabled = YES;
        [self createFramebuffer];
    }
    return self;
}

// A colour renderbuffer backed by the CAEAGLLayer drawable, attached to a
// framebuffer (the standard GL ES 1.1 CAEAGLLayer setup).
- (void)createFramebuffer {
    glGenFramebuffersOES(1, &m_DefaultFramebuffer);
    glGenRenderbuffersOES(1, &m_ColorRenderbuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_DefaultFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_ColorRenderbuffer);
    [m_GLContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES,
                                 GL_RENDERBUFFER_OES, m_ColorRenderbuffer);
}

// @ 0x28334 — tear down the GL buffers and unbind the context. KEPT under ARC:
// the framebuffer/renderbuffer names and the EAGLContext current-binding are GL
// state, not object graph, so ARC will not free them. The original also released
// m_GLContext (ARC handles that) and called [super dealloc] (never call it here).
- (void)dealloc {
    if (m_DefaultFramebuffer) {
        glDeleteFramebuffersOES(1, &m_DefaultFramebuffer);
        m_DefaultFramebuffer = 0;
    }
    if (m_ColorRenderbuffer) {
        glDeleteRenderbuffersOES(1, &m_ColorRenderbuffer);
        m_ColorRenderbuffer = 0;
    }
    if ([EAGLContext currentContext] == m_GLContext) {
        [EAGLContext setCurrentContext:nil];
    }
}

// @ 0x28544 — make the GL context current.
- (BOOL)BeginRender {
    return [EAGLContext setCurrentContext:m_GLContext];
}

// @ 0x28570 — bind the default framebuffer (m_GLInterface vtbl +0x18).
- (void)SetDefaultFrameBuffer {
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_DefaultFramebuffer);
}

// @ 0x28594 — bind the colour renderbuffer (m_GLInterface vtbl +0x24).
- (void)SetDefaultColorBuffer {
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_ColorRenderbuffer);
}

// @ 0x285b8 — present the colour renderbuffer to the screen.
- (BOOL)Present {
    [self SetDefaultColorBuffer];
    return [m_GLContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}

// @ 0x28428 — the drawable resized: refresh the renderbuffer storage + size,
// then notify the delegate so it can update the projection.
- (void)layoutSubviews {
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_ColorRenderbuffer);
    [m_GLContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &m_FrontBufferWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &m_FrontBufferHeight);
    // Publish the live drawable metrics to the scene manager so the note/sprite
    // layout code places geometry against the current surface (points + scale).
    neSceneManager::setScreenMetrics(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds),
                                     (float)self.contentScaleFactor);
    if ([self.delegate respondsToSelector:@selector(LayoutedGLView:)]) {
        [self.delegate LayoutedGLView:self];
    }
}

@end
