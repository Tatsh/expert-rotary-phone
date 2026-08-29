/**
 * @file
 * A UIImageView that lazily fetches its image from a URL.
 *
 * It shows a spinner, kicks off an ImageDownloader after a one-second delay, and swaps in the
 * decoded image when the download finishes. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initWithURLString: @ 0x62be8, initWithURLString:withImage: @ 0x62c5c, dealloc @
 * 0x62cd0, SetupView @ 0x62d30, startDownload @ 0x62e24, imageDownloader:didLoad: @ 0x62ef0,
 * imageDownloaderDidFail:didLoad: @ 0x62f60).
 *
 * The binary's Objective-C metadata gives the superclass as UIImageView, adopting
 * `<ImageDownloaderDelegate>`.
 */

#import <UIKit/UIKit.h>

#import "ImageDownloader.h" // ImageDownloader + <ImageDownloaderDelegate>

/**
 * A UIImageView that lazily fetches its image from a URL, showing a spinner until the
 * decoded image swaps in.
 */
@interface DownloadImageView : UIImageView <ImageDownloaderDelegate>

/**
 * Build an empty image view bound to a URL; the fetch starts later, via -startDownload.
 * @param urlString The image URL.
 * @return The initialised view.
 * @ghidraAddress 0x62be8
 */
- (id)initWithURLString:(NSString *)urlString;
/**
 * Build an image view bound to a URL, showing a placeholder until the download completes.
 * @param urlString The image URL.
 * @param image The placeholder image.
 * @return The initialised view.
 * @ghidraAddress 0x62c5c
 */
- (id)initWithURLString:(NSString *)urlString withImage:(UIImage *)image;

/**
 * Create the ImageDownloader, once, and begin the deferred fetch.
 * @ghidraAddress 0x62e24
 */
- (void)startDownload;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
