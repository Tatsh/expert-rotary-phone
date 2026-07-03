//
//  neGLView.h
//  pop'n rhythmin
//
//  The CAEAGLLayer-backed OpenGL ES view. It presents the engine's rendered
//  frames and forwards UIKit touches into the C++ task/input system.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <UIKit/UIKit.h>

@class neGLView;

// The view tells its delegate when the drawable (and thus the framebuffer size)
// has changed. Ghidra: -[delegate LayoutedGLView:] in layoutSubviews (0x28428).
@protocol neGLViewDelegate <NSObject>
- (void)LayoutedGLView:(neGLView *)view;
@end

@interface neGLView : UIView

// The live view instance (raw global set on init, cleared on dealloc). Ghidra: @ 0x280d4
+ (neGLView *)GetInstance;

// Ghidra: -delegate/-setDelegate: are atomic accessors (DataMemoryBarrier around
// a plain pointer store — assign, not ARC weak). Addresses annotated in the .mm.
@property (atomic, assign) id<neGLViewDelegate> delegate;

// The GL drawable size, updated by -layoutSubviews from the renderbuffer.
- (int)GetFrontBufferWidth;   // Ghidra: @ 0x28524
- (int)GetFrontBufferHeight;  // Ghidra: @ 0x28534

// Render surface control, called each frame by MainViewController -draw.
- (BOOL)BeginRender;            // make the GL context current. Ghidra: @ 0x28544
- (void)SetDefaultFrameBuffer;  // bind the default framebuffer.  Ghidra: @ 0x28570
- (void)SetDefaultColorBuffer;  // bind the colour renderbuffer.  Ghidra: @ 0x28594
- (BOOL)Present;                // present the renderbuffer (swap). Ghidra: @ 0x285b8

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
