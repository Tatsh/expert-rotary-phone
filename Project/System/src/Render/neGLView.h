//
//  neGLView.h
//  pop'n rhythmin
//
//  The CAEAGLLayer-backed OpenGL ES view. It presents the engine's rendered
//  frames and forwards UIKit touches into the C++ task/input system.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <UIKit/UIKit.h>

@interface neGLView : UIView

// Render surface control, called each frame by MainViewController -draw.
- (void)BeginRender;            // bind the GL context / default framebuffer
- (void)SetDefaultFrameBuffer;
- (void)SetDefaultColorBuffer;
- (void)Present;                // present the renderbuffer (swap)

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
