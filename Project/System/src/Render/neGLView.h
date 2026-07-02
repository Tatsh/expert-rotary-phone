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

@property (nonatomic, weak) id<neGLViewDelegate> delegate;

// The GL drawable size, updated by -layoutSubviews from the renderbuffer.
@property (nonatomic, readonly) int frontBufferWidth;
@property (nonatomic, readonly) int frontBufferHeight;

// Render surface control, called each frame by MainViewController -draw.
- (BOOL)BeginRender;            // make the GL context current. Ghidra: @ 0x28544
- (void)SetDefaultFrameBuffer;  // bind the default framebuffer.  Ghidra: @ 0x28570
- (void)SetDefaultColorBuffer;  // bind the colour renderbuffer.  Ghidra: @ 0x28594
- (BOOL)Present;                // present the renderbuffer (swap). Ghidra: @ 0x285b8

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
