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

// +[DelayImageView allocWithImage:]  @ 0x8690 — build a DelayImageView showing `image`, overlay
// a 2x-scaled white spinner centred in it plus a red placeholder subview, then kick off
// -threadFunc on a background thread to attach the image view. Ghidra-faithful (the spinner /
// marker are retained by their superview; the +1 from -init is intentionally not autoreleased,
// matching the "alloc"-named binary routine).
+ (instancetype)allocWithImage:(UIImage *)image {
    DelayImageView *view = [[DelayImageView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    view.image = image;

    UIActivityIndicatorView *indicator =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    indicator.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    indicator.center = CGPointMake(view.frame.size.width * 0.5f,
                                   view.frame.size.height * 0.5f);
    [indicator startAnimating];
    [view addSubview:indicator];

    UIView *marker = [[UIView alloc] init];
    marker.backgroundColor = [UIColor redColor];
    [view addSubview:marker];

    [NSThread detachNewThreadSelector:@selector(threadFunc) toTarget:view withObject:nil];
    return view;
}

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
