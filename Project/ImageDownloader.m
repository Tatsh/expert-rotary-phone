//
//  ImageDownloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "ImageDownloader.h"

@implementation ImageDownloader

// @ 0x5a63c — open a connection for the stored imageURL; incoming bytes accumulate
// in activeDownload.
- (void)startDownload {
    self.activeDownload = [NSMutableData data];
    NSURL *url = [NSURL URLWithString:self.imageURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.imageConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

// @ 0x5a78c
- (UIImage *)getImage {
    return self.downloadedImage;
}

// @ 0x5a724 — stop: drop the delegate, cancel the connection, clear state.
- (void)cancelDownload {
    self.delegate = nil;
    [self.imageConnection cancel];
    self.imageConnection = nil;
    self.activeDownload = nil;
}

#pragma mark - NSURLConnection delegate

// @ 0x5a79c — treat a 404 response as a failure: cancel the connection, drop the
// buffer, and tell the delegate the row's image could not be loaded.
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response respondsToSelector:@selector(statusCode)] &&
        [(NSHTTPURLResponse *)response statusCode] == 404) {
        [connection cancel];
        self.activeDownload = nil;
        self.imageConnection = nil;
        [self.delegate imageDownloaderDidFail:self didLoad:self.indexPathInTableView];
    }
}

// @ 0x5a854
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.activeDownload appendData:data];
}

// @ 0x5a8e0 — decode the image (matching the main screen's scale for Retina), then
// notify the delegate with the row's index path.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.downloadedImage = nil;
    UIImage *image = [[UIImage alloc] initWithData:self.activeDownload];
    if (image != nil) {
        UIImage *result = image;
        if ([UIScreen.mainScreen respondsToSelector:@selector(scale)]) {
            CGFloat scale = UIScreen.mainScreen.scale;
            if (scale != 1.0f) {
                result = [UIImage imageWithCGImage:image.CGImage
                                            scale:scale
                                      orientation:UIImageOrientationUp];
            }
        }
        self.downloadedImage = result;
    }
    self.activeDownload = nil;
    self.imageConnection = nil;
    // The binary calls the delegate unconditionally once downloadedImage is set
    // (no respondsToSelector: guard here, unlike -didFailWithError:).
    if (self.downloadedImage != nil) {
        [self.delegate imageDownloader:self didLoad:self.indexPathInTableView];
    }
}

// @ 0x5a880
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.activeDownload = nil;
    self.imageConnection = nil;
    if ([self.delegate respondsToSelector:@selector(imageDownloaderDidFail:didLoad:)]) {
        [self.delegate imageDownloaderDidFail:self didLoad:self.indexPathInTableView];
    }
}

#pragma mark -

// @ 0x5aaa4 — cancel any in-flight connection before going away (ARC frees the
// remaining object ivars).
- (void)dealloc {
    [_imageConnection cancel];
}

@end
