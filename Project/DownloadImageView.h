//
//  DownloadImageView.h
//  pop'n rhythmin
//
//  A UIImageView that lazily fetches its image from a URL: it shows a spinner, kicks off an
//  ImageDownloader (after a 1s delay) and swaps in the decoded image when the download finishes.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithURLString: @ 0x62be8,
//  initWithURLString:withImage: @ 0x62c5c, dealloc @ 0x62cd0, SetupView @ 0x62d30,
//  startDownload @ 0x62e24, imageDownloader:didLoad: @ 0x62ef0,
//  imageDownloaderDidFail:didLoad: @ 0x62f60).
//
//  Binary Objective-C metadata: superclass UIImageView, adopts <ImageDownloaderDelegate>.
//

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"   // ImageDownloader + <ImageDownloaderDelegate>

@interface DownloadImageView : UIImageView <ImageDownloaderDelegate>

// Empty image view bound to `urlString`; the fetch is started later via -startDownload.
- (id)initWithURLString:(NSString *)urlString;
// As above, but showing `image` as a placeholder until the download completes.
- (id)initWithURLString:(NSString *)urlString withImage:(UIImage *)image;

// Create the ImageDownloader (once) and begin the deferred fetch.
- (void)startDownload;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
