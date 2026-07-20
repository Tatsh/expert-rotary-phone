//
//  ImageDownloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "ImageDownloader.h"

@implementation ImageDownloader

// @ 0x5a63c — open a connection for the stored imageURL; incoming bytes
// accumulate in activeDownload. The binary is the legacy NSURLConnection build
// (verified against the #else branch); the NSURLSession path is a modernisation.
- (void)startDownload {
    self.activeDownload = [NSMutableData data];
    NSURL *url = [NSURL URLWithString:self.imageURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    // NSURLSession buffers the whole body itself, so the accumulated data is
    // funnelled into the same finish/fail handling the delegate used. A 404 is
    // treated as a failure just as the response delegate did. The completion is
    // delivered on a background queue and re-dispatched onto the main queue to
    // preserve the original delegate threading.
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (error != nil) {
                  [self handleFailWithError:error];
                  return;
              }
              if ([response respondsToSelector:@selector(statusCode)] &&
                  [(NSHTTPURLResponse *)response statusCode] == 404) {
                  self.activeDownload = nil;
                  self.imageConnection = nil;
                  [self.delegate imageDownloaderDidFail:self didLoad:self.indexPathInTableView];
                  return;
              }
              if (data != nil) {
                  [self.activeDownload appendData:data];
              }
              [self handleFinish];
            });
          }];
    [task resume];
#else
    self.imageConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
#endif
}

// @ 0x5a78c
- (UIImage *)getImage {
    return self.downloadedImage;
}

// @ 0x5a724 — stop: drop the delegate, cancel the connection, clear state.
- (void)cancelDownload {
    self.delegate = nil;
#if !(defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)
    [self.imageConnection cancel];
    self.imageConnection = nil;
#endif
    self.activeDownload = nil;
}

#pragma mark - Response handling

// @ 0x5a8e0 — decode the image (matching the main screen's scale for Retina),
// then notify the delegate with the row's index path. Funnelled into by both the
// NSURLConnection finish delegate (old SDK) and the NSURLSession completion
// handler (modern SDK).
- (void)handleFinish {
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
    // The binary calls the delegate unconditionally once downloadedImage is set;
    // -handleFailWithError: likewise calls its delegate method unconditionally.
    if (self.downloadedImage != nil) {
        [self.delegate imageDownloader:self didLoad:self.indexPathInTableView];
    }
}

// @ 0x5a880 — clear the buffer/connection, then tell the delegate the row's
// image failed. The binary (0x5a880 loads the delegate and index-path ivars and
// tail-calls imageDownloaderDidFail:didLoad: at 0x5a84a) does so
// unconditionally, with no respondsToSelector: guard.
- (void)handleFailWithError:(NSError *)error {
    self.activeDownload = nil;
    self.imageConnection = nil;
    [self.delegate imageDownloaderDidFail:self didLoad:self.indexPathInTableView];
}

#if !(defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)

#pragma mark - NSURLConnection delegate

// @ 0x5a79c — treat a 404 response as a failure: cancel the connection, drop
// the buffer, and tell the delegate the row's image could not be loaded.
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

// @ 0x5a8e0 — decode the image and notify the delegate (this delegate method is
// -handleFinish in the binary).
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self handleFinish];
}

// @ 0x5a880 (this delegate method is -handleFailWithError: in the binary).
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self handleFailWithError:error];
}

#endif

#pragma mark -

// @ 0x5aaa4 — cancel any in-flight connection before going away (ARC frees the
// remaining object ivars).
- (void)dealloc {
#if !(defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)
    [_imageConnection cancel];
#endif
}

@end
