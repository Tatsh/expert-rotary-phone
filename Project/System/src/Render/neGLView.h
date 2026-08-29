/**
 * @file
 * The CAEAGLLayer-backed OpenGL ES view.
 *
 * It presents the engine's rendered frames and forwards UIKit touches into the C++ task and input
 * system. Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <UIKit/UIKit.h>

@class neGLView;

/**
 * Receives notice when the view's drawable, and thus the framebuffer size, has changed.
 */
@protocol neGLViewDelegate <NSObject>
/**
 * The view's drawable was resized by -layoutSubviews.
 * @param view The view whose drawable changed.
 * @ghidraAddress 0x28428
 */
- (void)LayoutedGLView:(neGLView *)view;
@end

/**
 * The CAEAGLLayer-backed OpenGL ES view that presents each rendered frame.
 */
@interface neGLView : UIView

/**
 * The live view instance: a raw global set on init and cleared on dealloc.
 * @return The view, or nil before init or after dealloc.
 * @ghidraAddress 0x280d4
 */
+ (neGLView *)GetInstance;

/**
 * The layout delegate.
 *
 * The binary's -delegate and -setDelegate: are atomic accessors: a DataMemoryBarrier around a
 * plain pointer store, so this is assign, not ARC weak. Addresses are annotated in the .mm.
 */
@property(atomic, assign) id<neGLViewDelegate> delegate;

/**
 * The GL drawable width, updated by -layoutSubviews from the renderbuffer.
 * @return The width, in pixels.
 * @ghidraAddress 0x28524
 */
- (int)GetFrontBufferWidth;
/**
 * The GL drawable height, updated by -layoutSubviews from the renderbuffer.
 * @return The height, in pixels.
 * @ghidraAddress 0x28534
 */
- (int)GetFrontBufferHeight;

/**
 * Make the GL context current. Called each frame by -[MainViewController draw].
 * @return YES when the context was made current.
 * @ghidraAddress 0x28544
 */
- (BOOL)BeginRender;
/**
 * Bind the default framebuffer.
 * @ghidraAddress 0x28570
 */
- (void)SetDefaultFrameBuffer;
/**
 * Bind the colour renderbuffer.
 * @ghidraAddress 0x28594
 */
- (void)SetDefaultColorBuffer;
/**
 * Present the renderbuffer (swap).
 * @return YES when the swap succeeded.
 * @ghidraAddress 0x285b8
 */
- (BOOL)Present;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
