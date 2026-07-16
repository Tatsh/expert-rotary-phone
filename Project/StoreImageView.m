//
//  StoreImageView.m
//  pop'n rhythmin
//
//  See StoreImageView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "StoreImageView.h"

@implementation StoreImageView

// -imageURL is a plain retaining property (Ghidra: synthesized getter @
// 0x42b20, objc_setProperty setter @ 0x42b30).
@synthesize imageURL = m_ImageURL;

// @ 0x42884 — begin a fetch for the current URL, but only if there is a URL and
// one is not already in flight (so re-triggering while loading is a no-op).
// @complete
- (void)startDownloadImage {
    if (m_ImageURL != nil && m_ImageDownloader == nil) {
        m_ImageDownloader = [[ImageDownloader alloc] init];
        m_ImageDownloader.imageURL = m_ImageURL;
        m_ImageDownloader.delegate = self;
        [m_ImageDownloader startDownload];
    }
}

// @ 0x42980 — fetch succeeded. Adopt the decoded image; on a Retina screen, if
// the image itself is @2x+, match its scale so it draws at the right size. Then
// drop the downloader.
// @complete
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *img = [downloader getImage];
    if (img != nil) {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
            [UIScreen mainScreen].scale > 1.0f && img.scale > 1.0f) {
            self.contentScaleFactor = img.scale;
        }
        self.image = img;
    }
    m_ImageDownloader = nil;
}

// @ 0x42a7c — fetch failed. Keep whatever placeholder is showing and just drop
// the downloader.
// @complete
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    m_ImageDownloader = nil;
}

// @ 0x42928 — cancel any in-flight fetch (so its callback can't reach this
// view) and drop the downloader, then swap in the supplied image (nil to clear
// the current one).
// @complete
- (void)unloadImage:(UIImage *)image {
    if (m_ImageDownloader != nil) {
        [m_ImageDownloader cancelDownload];
        m_ImageDownloader = nil;
    }
    [self setImage:image];
}

// @ 0x42aa8 — release the URL, then stop + release any in-flight fetch so it
// cannot call back into a freed view.
// @complete
- (void)dealloc {
    if (m_ImageDownloader != nil) {
        [m_ImageDownloader cancelDownload];
    }
}

@end
