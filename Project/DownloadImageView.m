//
//  DownloadImageView.m
//  pop'n rhythmin
//
//  See DownloadImageView.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "DownloadImageView.h"

@interface DownloadImageView ()
// Build the spinner (called from the initializers). Named to match the binary
// selector.
- (void)SetupView;
@end

@implementation DownloadImageView {
    NSString *m_ImageURL;                     // @+0x38  source URL
    ImageDownloader *m_ImageDownLoader;       // @+0x3c  in-flight downloader (nil when idle)
    UIActivityIndicatorView *m_IndicatorView; // @+0x40  progress spinner
}

// @ 0x62be8 — empty image view for `urlString`.
- (id)initWithURLString:(NSString *)urlString {
    self = [super init];
    if (self != nil) {
        // Faithful: the binary stores the (autoreleased) string without retaining
        // it; the strong ivar under ARC keeps it alive.
        m_ImageURL = [NSString stringWithString:urlString];
        [self SetupView];
    }
    return self;
}

// @ 0x62c5c — image view for `urlString` showing `image` until the download
// completes.
- (id)initWithURLString:(NSString *)urlString withImage:(UIImage *)image {
    self = [super initWithImage:image];
    if (self != nil) {
        m_ImageURL = [NSString stringWithString:urlString];
        [self SetupView];
    }
    return self;
}

// @ 0x62d30 — build the centered progress spinner and add it as a subview.
- (void)SetupView {
    CGRect bounds = self.bounds;
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator setBounds:CGRectMake(0, 0, 30.0f, 30.0f)];
    [indicator setCenter:CGPointMake(bounds.size.width * 0.5f, bounds.size.height * 0.5f)];
    [indicator setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleBottomMargin]; // 0x2d
    [self addSubview:indicator];
    m_IndicatorView = indicator;
}

// @ 0x62e24 — start the fetch once: spin, create the downloader, hand it the
// URL and self as delegate, and kick it off after a 1s delay.
- (void)startDownload {
    if (m_ImageDownLoader == nil) {
        [m_IndicatorView startAnimating];
        m_ImageDownLoader = [[ImageDownloader alloc] init];
        m_ImageDownLoader.imageURL = m_ImageURL;
        [m_ImageDownLoader setDelegate:self];
        [m_ImageDownLoader performSelector:@selector(startDownload) withObject:nil afterDelay:1.0];
    }
}

// @ 0x62ef0 — ImageDownloaderDelegate: swap in the decoded image, stop the
// spinner, drop the downloader.
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    if (image != nil) {
        [self setImage:image];
    }
    [m_IndicatorView stopAnimating];
    m_ImageDownLoader = nil;
}

// @ 0x62f60 — ImageDownloaderDelegate: on failure just stop the spinner and
// drop the downloader.
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    [m_IndicatorView stopAnimating];
    m_ImageDownLoader = nil;
}

// @ 0x62cd0 — dealloc: cancel any in-flight download (kept, not a plain
// object-only teardown). ARC supplies the ivar release and the [super dealloc]
// chain.
- (void)dealloc {
    if (m_ImageDownLoader != nil) {
        [m_ImageDownLoader cancelDownload];
    }
}

@end
