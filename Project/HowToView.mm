//
//  HowToView.mm
//  pop'n rhythmin
//
//  See HowToView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithImageList:frame:backGroundImg: @ 0xe9230, drawRect: @ 0xe9368, dealloc @ 0xe9304).
//  Objective-C++ for the neSceneManager device check. On iPhone the images are drawn directly
//  (with an optional per-page background); on iPad each image is added as a UIImageView. The
//  iPhone per-page centring uses page-dimension constants (DAT_000e96e4/e8) that are flagged
//  best-effort.
//

#import "HowToView.h"
#import "System/src/neEngineBridge.h"   // neSceneManager::isPadDisplay

@implementation HowToView {
    NSArray *_imageList;   // the how-to page images
    UIImage *_bgImage;     // optional per-page background
}

// @ 0xe9230 — retain the image list (+ background); clear the backdrop on iPad.
- (instancetype)initWithImageList:(NSArray *)imageList
                            frame:(CGRect)frame
                    backGroundImg:(UIImage *)backGroundImg {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _imageList = imageList;
        if (neSceneManager::isPadDisplay()) {
            self.backgroundColor = [UIColor clearColor];
        }
        if (backGroundImg != nil) {
            _bgImage = backGroundImg;
        }
    }
    return self;
}

// @ 0xe9368 — lay the pages out horizontally: iPhone draws them (+ background) into the context;
// iPad adds an image view per page.
- (void)drawRect:(CGRect)rect {
    CGFloat x = 0;
    if (!neSceneManager::isPadDisplay()) {
        // iPhone: draw each image (centred over its page background if there is one).
        for (UIImage *img in _imageList) {
            CGPoint pt = CGPointMake(x, 0);
            if (_bgImage != nil) {
                [_bgImage drawAtPoint:CGPointMake(x, 0)];
                // Centre the image within the page. Page dimensions are DAT_000e96e4/e8 in the
                // binary; approximated here by the background image's size.
                CGFloat pageW = _bgImage.size.width;
                pt.x = x + (pageW - img.size.width) * 0.5f;
                pt.y = (self.bounds.size.height - img.size.height) * 0.5f;
            }
            [img drawAtPoint:pt];
            x += img.size.width;
        }
    } else {
        // iPad: an image view per page.
        for (UIImage *img in _imageList) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            iv.frame = CGRectMake(x, 0, img.size.width, img.size.height);
            [self addSubview:iv];
            x += img.size.width;
        }
    }
}

// dealloc @ 0xe9304 — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
