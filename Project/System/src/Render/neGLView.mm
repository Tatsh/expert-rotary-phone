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

#import "C_RENDER.h" // neEnsureRenderer / neGetCurrentRenderer
#import "neGLES11.h" // ne::neGLES_11 backend — the view's m_GLInterface
#import "neGLView.h"
#import "neGraphics.h"

// Pass each touch's raw locationInView coordinate to neGraphics as a plain int.
// Disasm @ 0x2869c/0x286a0: the binary does vcvt.s32.f32 (a truncating
// float->int, NO fixed-point scale) before the bl to touchBegan @ 0x124f8, which
// itself does vcvt.f32.s32 -> * contentScale -> vcvt.s32.f32 to store plain
// pixels. There is no 16.16 fixed point in the touch path; the decompiler
// mis-rendered those vcvt ops as FixedToFP/FPToFixed.
static inline int ToViewInt(CGFloat v) {
    return static_cast<int>(v);
}

// The most-recently-created view, published for GetInstance. The binary keeps a
// raw (non-owning) pointer here: initWithFrame: stores self, dealloc clears it.
// @ 0x1882e4
static __unsafe_unretained neGLView *g_pGLViewInstance = nil;

@implementation neGLView {
    // The binary routes every framebuffer/renderbuffer operation through
    // m_GLInterface (the current ne::neGLES_11), whose vtable slots are thin GL ES
    // 1.1 / OES FBO wrappers. The reconstruction holds and drives that same
    // interface rather than issuing raw gl*OES calls.
    EAGLContext *m_GLContext;     // ivar 0x34
    int m_FrontBufferWidth;       // ivar 0x38
    int m_FrontBufferHeight;      // ivar 0x3c
    GLuint m_DefaultFramebuffer;  // ivar 0x40
    GLuint m_ColorRenderbuffer;   // ivar 0x44
    GLenum m_PresentTarget;       // ivar 0x48 (cached presentTarget() = GL_RENDERBUFFER_OES)
    ne::neGLES_11 *m_GLInterface; // ivar 0x4c (the current renderer; not owned)
}

// Ghidra shows -delegate/-setDelegate: as atomic accessors (DataMemoryBarrier
// around a plain pointer store — no objc_storeWeak, so this is assign, not ARC
// weak). Let the compiler emit them; the addresses are annotated here.
@synthesize delegate = _delegate; // -delegate @ 0x289d4 / -setDelegate: @ 0x289e8

// @ 0x28524
// @complete
- (int)GetFrontBufferWidth {
    return m_FrontBufferWidth;
}
// @ 0x28534
// @complete
- (int)GetFrontBufferHeight {
    return m_FrontBufferHeight;
}

// GL ES views are backed by a CAEAGLLayer. @ 0x280e4
// @complete
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

// @ 0x280d4 — the live view instance (raw global set in initWithFrame:).
// @complete
+ (neGLView *)GetInstance {
    return g_pGLViewInstance;
}

#pragma mark - Touch -> engine input

// @ 0x285e8 — report each touch's location (+ the view size for mapping).
// @complete
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGRect frame = self.frame;
    neGraphics &gfx = neGraphics::shared();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        gfx.touchBegan(ToViewInt(p.x),
                       ToViewInt(p.y),
                       ToViewInt(CGRectGetWidth(frame)),
                       ToViewInt(CGRectGetHeight(frame)));
    }
}

// @ 0x28718 — report each touch's new + previous location (drag tracking).
// @complete
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    neGraphics &gfx = neGraphics::shared();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        CGPoint prev = [touch previousLocationInView:self];
        gfx.touchMoved(ToViewInt(p.x), ToViewInt(p.y), ToViewInt(prev.x), ToViewInt(prev.y));
    }
}

// @ 0x28850 — if every touch ended, clear all; otherwise report each end.
// @complete
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    neGraphics &gfx = neGraphics::shared();
    if (touches.count == [event touchesForView:self].count) {
        gfx.clearTouches();
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        CGPoint prev = [touch previousLocationInView:self];
        gfx.touchEnded(ToViewInt(p.x), ToViewInt(p.y), ToViewInt(prev.x), ToViewInt(prev.y));
    }
}

// @ 0x289c4 — a cancelled touch is handled exactly like an ended one
// (the binary tail-calls -touchesEnded:withEvent:).
// @complete
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

#pragma mark - Render surface

// @ 0x28100 — create the EAGL context + FBO once the view exists.
// @complete
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
        // @ 0x28246 — with the context current, create the render facade
        // (neEnsureRenderer -> new ne::neGLES_11; initialize), cache it as
        // m_GLInterface and remember the renderbuffer target it presents to.
        neEnsureRenderer();
        m_GLInterface = static_cast<ne::neGLES_11 *>(neGetCurrentRenderer());
        m_PresentTarget = m_GLInterface->presentTarget(); // +0x0c -> GL_RENDERBUFFER_OES
        self.backgroundColor = [UIColor clearColor];
        self.multipleTouchEnabled = YES;
        // @ 0x282b4 — the binary inlines the FBO setup here through m_GLInterface's
        // vtable slots (there is no separate -createFramebuffer, and no
        // renderbufferStorage:fromDrawable: during init — that happens in
        // -layoutSubviews). Order: gen framebuffer, gen renderbuffer, bind each,
        // attach the colour renderbuffer to COLOR_ATTACHMENT0.
        m_GLInterface->genFramebuffer(m_DefaultFramebuffer);  // +0x10
        m_GLInterface->genRenderbuffer(m_ColorRenderbuffer);  // +0x1c
        m_GLInterface->bindFramebuffer(m_DefaultFramebuffer); // +0x18
        m_GLInterface->bindRenderbuffer(m_ColorRenderbuffer); // +0x24
        m_GLInterface->framebufferRenderbuffer(ne::neIGLES::RENDER_KIND_COLOR,
                                               m_ColorRenderbuffer); // +0x30
        g_pGLViewInstance = self; // @ 0x28312 — publish for GetInstance.
    }
    return self;
}

// @ 0x28334 — tear down the GL buffers and unbind the context. KEPT under ARC:
// the framebuffer/renderbuffer names and the EAGLContext current-binding are GL
// state, not object graph, so ARC will not free them. The original also
// released m_GLContext (ARC handles that) and called [super dealloc] (never
// call it here).
// @complete
- (void)dealloc {
    // Buffer deletes route through m_GLInterface (vtable +0x14 / +0x20), each gated
    // on a live name, matching the binary.
    if (m_DefaultFramebuffer) {
        m_GLInterface->deleteFramebuffer(m_DefaultFramebuffer); // +0x14
        m_DefaultFramebuffer = 0;
    }
    if (m_ColorRenderbuffer) {
        m_GLInterface->deleteRenderbuffer(m_ColorRenderbuffer); // +0x20
        m_ColorRenderbuffer = 0;
    }
    if ([EAGLContext currentContext] == m_GLContext) {
        [EAGLContext setCurrentContext:nil];
    }
    g_pGLViewInstance = nil; // @ 0x2841c
}

// @ 0x28544 — make the GL context current.
// @complete
- (BOOL)BeginRender {
    return [EAGLContext setCurrentContext:m_GLContext];
}

// @ 0x28570 — bind the default framebuffer through m_GLInterface (vtable +0x18).
// @complete
- (void)SetDefaultFrameBuffer {
    m_GLInterface->bindFramebuffer(m_DefaultFramebuffer);
}

// @ 0x28594 — bind the colour renderbuffer through m_GLInterface (vtable +0x24).
// @complete
- (void)SetDefaultColorBuffer {
    m_GLInterface->bindRenderbuffer(m_ColorRenderbuffer);
}

// @ 0x285b8 — present the cached renderbuffer target to the screen. The binary
// does NOT bind the colour renderbuffer first; it hands -presentRenderbuffer: the
// m_PresentTarget ivar (GL_RENDERBUFFER_OES, cached from presentTarget() at init).
// @complete
- (BOOL)Present {
    return [m_GLContext presentRenderbuffer:m_PresentTarget];
}

// @ 0x28428 — the drawable resized: rebind and refresh the renderbuffer storage
// from the layer, read back its pixel size through m_GLInterface, probe framebuffer
// completeness, then notify the delegate so it can update the projection. The
// binary does NOT publish scene metrics here (no neSceneManager::setScreenMetrics);
// that stand-in has been removed.
// @complete
- (void)layoutSubviews {
    m_GLInterface->bindRenderbuffer(m_ColorRenderbuffer); // +0x24
    [m_GLContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
    m_GLInterface->getRenderbufferWidth(m_FrontBufferWidth);   // +0x38
    m_GLInterface->getRenderbufferHeight(m_FrontBufferHeight); // +0x3c
    m_GLInterface->isFramebufferComplete();                    // +0x34 (result discarded)
    if ([self.delegate respondsToSelector:@selector(LayoutedGLView:)]) {
        [self.delegate LayoutedGLView:self];
    }
}

@end
