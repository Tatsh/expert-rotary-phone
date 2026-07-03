//
//  DelayImageView.m
//  pop'n rhythmin
//
//  See DelayImageView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (threadFunc @ 0x88c8). The `image` getter/setter are the compiler-synthesized property
//  accessors (getter returns the ivar; setter is the retaining objc_setProperty setter), so they
//  are left to @synthesize rather than hand-written.
//

#import "DelayImageView.h"

@implementation DelayImageView

// ivar named `image` (offset 0x52 in the binary), not `_image`, matching the original.
// The synthesized accessors are real functions in the binary: image @ 0x8980, setImage: @ 0x8990.
@synthesize image;

// @ 0x88c8 — build a UIImageView from the stored image, size it to the image, add it to self.
- (void)threadFunc {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    [self addSubview:imageView];
    // NOTE: faithful to the binary — the alloc'd UIImageView is not released here. -addSubview:
    // retains it, so it survives, but the +1 from -alloc leaks (an original-code omission). The
    // class also ships no -dealloc, so the retained `image` property leaks on teardown too.
}

@end
