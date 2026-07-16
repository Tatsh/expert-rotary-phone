//
//  UIImage+Effects.m
//  pop'n rhythmin
//
//  See UIImage+Effects.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Float words decoded from the decompile: 0xbf800000 = -1.0,
//  0x3f800000 = 1.0. ARC: the CGImage/CGContext handles are C objects and are
//  released with the CG*Release C calls (not ARC-managed); the returned UIImage
//  is ARC-owned.
//

#import "UIImage+Effects.h"

@implementation UIImage (Effects)

// @ 0x7bba0
// @complete
- (UIImage *)createReverseImage:(BOOL)flip {
    CGImageRef cg = self.CGImage;
    CGSize size = self.size;

    UIGraphicsBeginImageContextWithOptions(size, NO, self.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // The binary applies the flip when the argument is *false* (param_3 == 0).
    if (!flip) {
        CGContextTranslateCTM(ctx, size.width, size.height);
        CGContextScaleCTM(ctx, -1.0f, -1.0f); // 0xbf800000, 0xbf800000
    }

    CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), cg);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

// @ 0x7bcc4
// @complete
- (UIImage *)createImageHarfBlightness {
    CGImageRef cg = self.CGImage;
    if (cg == NULL) {
        return nil;
    }

    size_t width = CGImageGetWidth(cg);
    size_t height = CGImageGetHeight(cg);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(cg);
    size_t bytesPerRow = CGImageGetBytesPerRow(cg);
    CGColorSpaceRef space = CGImageGetColorSpace(cg);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(cg);

    CGContextRef ctx = CGBitmapContextCreate(
        NULL, width, height, bitsPerComponent, bytesPerRow, space, bitmapInfo);
    if (ctx == NULL) {
        return nil;
    }

    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cg);

    unsigned char *data = (unsigned char *)CGBitmapContextGetData(ctx);
    if (data == NULL) {
        CGContextRelease(ctx);
        return nil;
    }

    // Halve each RGB channel (>> 1); the fourth byte (alpha) is left untouched.
    for (size_t y = 0; y < height; y++) {
        unsigned char *row = data + y * bytesPerRow;
        for (size_t x = 0; x < width; x++) {
            unsigned char *px = row + x * 4;
            px[0] = px[0] >> 1; // R
            px[1] = px[1] >> 1; // G
            px[2] = px[2] >> 1; // B
        }
    }

    CGImageRef out = CGBitmapContextCreateImage(ctx);
    if (out == NULL) {
        CGContextRelease(ctx);
        return nil;
    }

    UIImage *result = [[UIImage alloc] initWithCGImage:out];
    CGImageRelease(out);
    CGContextRelease(ctx);
    return result;
}

// @ 0x7be1c
// @complete
- (UIImage *)createImagefromRect:(CGRect)rect {
    CGImageRef cg = self.CGImage;

    UIGraphicsBeginImageContextWithOptions(rect.size, NO, self.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Vertical flip about the sub-rect: start from scale(1, -1) and fold a vertical
    // translation into the transform's ty so the flip pivots about `rect` rather than
    // the context origin. Verified: 0x7bed0 vadd d16 = 2 * rect.origin.y, 0x7bed4 adds
    // self.size.height ([self size].height), 0x7bed8 stores the sum into the
    // transform's ty (sp+0x4c) before CGContextConcatCTM at 0x7bef2.
    CGAffineTransform flip = CGAffineTransformScale(CGAffineTransformIdentity, 1.0f, -1.0f);
    flip.ty = 2.0f * rect.origin.y + self.size.height;
    CGContextConcatCTM(ctx, flip);

    // Draw the whole image shifted by -rect.origin so `rect` lands at the context
    // origin (draw rect at 0x7bf3a..0x7bf4c is
    // (-rect.origin.x, -rect.origin.y, self.size.width, self.size.height)).
    CGContextDrawImage(
        ctx, CGRectMake(-rect.origin.x, -rect.origin.y, self.size.width, self.size.height), cg);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
