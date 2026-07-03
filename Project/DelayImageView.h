//
//  DelayImageView.h
//  pop'n rhythmin
//
//  A UIView that holds an image and, when told to, builds a UIImageView from it sized to the
//  image and adds it as a subview. The build is done in -threadFunc, which callers invoke off the
//  main path (deferred / on a background thread — hence "Delay") so a batch of image work does not
//  block. Reconstructed from Ghidra project rb420, program PopnRhythmin (threadFunc @ 0x88c8,
//  image @ 0x8980, setImage: @ 0x8990).
//

#import <UIKit/UIKit.h>

@interface DelayImageView : UIView

// The image to display. Backed by the `image` ivar @ +0x52; accessors are synthesized (the getter
// returns the ivar directly, the setter is the retaining property setter).
@property (nonatomic, retain) UIImage *image;

// Build a UIImageView from `image`, size it to the image, and add it as a subview.
- (void)threadFunc;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
