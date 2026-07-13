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
- (UIImage *)createImagefromRect:(CGRect)rect {
    CGImageRef cg = self.CGImage;

    UIGraphicsBeginImageContextWithOptions(rect.size, NO, self.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Identity scaled (1, -1): flip vertically so the sub-rect draws upright.
    CGAffineTransform flip = CGAffineTransformScale(CGAffineTransformIdentity, 1.0f, -1.0f);
    CGContextConcatCTM(ctx, flip);

    // Draw the whole image shifted by -rect.origin so `rect` lands at the context
    // origin. (The exact CTM translation is partially obscured in the decompile;
    // modeled by the -origin offset on the draw rect.)  best-effort
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
