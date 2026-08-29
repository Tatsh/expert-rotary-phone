/**
 * @file
 * @brief A UIView that holds an image and builds a UIImageView from it on demand.
 *
 * The subview is sized to the image. The build is done in -threadFunc, which callers invoke off
 * the main path (deferred, or on a background thread, hence "Delay") so a batch of image work does
 * not block. Reconstructed from Ghidra project rb420, program PopnRhythmin (threadFunc @ 0x88c8,
 * image @ 0x8980, setImage: @ 0x8990).
 */

#import <UIKit/UIKit.h>

/**
 * @brief A view that holds an image and builds its UIImageView off the main path, so a batch of
 * image work does not block.
 */
@interface DelayImageView : UIView

/** The image to display, backed by the `image` ivar @ +0x52. The getter returns the ivar directly
 * and the setter is the retaining property setter. */
@property(nonatomic, retain) UIImage *image;

/**
 * @brief Build a view for an image with a spinner overlay and start -threadFunc off-thread.
 * @param image The image to display.
 * @return The new view.
 * @ghidraAddress 0x8690
 */
+ (instancetype)allocWithImage:(UIImage *)image;

/**
 * @brief Build a UIImageView from the held image, size it to the image, and add it as a subview.
 */
- (void)threadFunc;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
