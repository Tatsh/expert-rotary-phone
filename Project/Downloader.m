//
//  Downloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Manual
//  retain/release is kept where the original manages the connection/data
//  lifetime.
//

#import "Downloader.h"

#import "AppDelegate.h"
#import "NSDictionary_JSONExtensions.h" // TouchJSON +dictionaryWithJSONData:error: fallback
#import "StoreUtil.h"

// Request timeout (Ghidra: 0x402e0000 = 15.0s); reload-ignoring-cache policy
// (4).
static const NSTimeInterval kTimeout = 15.0;

@implementation Downloader {
    NSMutableURLRequest *m_Request;
    __weak id<DownloaderDelegate> m_Delegate; // not retained (ARC weak; matches original assign)
    NSURLConnection *m_Connection;
    NSURLSessionDataTask *m_Task; // modern-SDK replacement for m_Connection
    NSMutableData *m_DownloadedData;
    id m_AdditionalData;
    NSDate *m_StartTime;
    long long m_DownloadSize; // expected content length from the response (0
                              // until known)
}

// addData / setAddData: are synthesized from the @addData property — the binary
// emits objc_getProperty @ 0x62afc / objc_setProperty @ 0x62b10 (atomic
// retain), so they are annotated on the @property in Downloader.h rather than
// hand-written here.

// Apply the request headers every request carries (Ghidra: shared by both
// inits).
- (void)applyCommonHeadersTo:(NSMutableURLRequest *)request {
    [request setValue:AppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
}

// @ 0x620f4 — a GET request.
// @complete
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate {
    if ((self = [super init])) {
        m_Request = [[NSMutableURLRequest alloc]
                initWithURL:url
                cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
            timeoutInterval:kTimeout];
        [self applyCommonHeadersTo:m_Request];
        m_Delegate = delegate;
        m_Connection = nil;
        m_DownloadedData = nil;
        m_AdditionalData = nil;
    }
    return self;
}

// @ 0x6224c — a POST request with a body + Content-Type.
// @complete
- (instancetype)initWithURL:(NSURL *)url
                   delegate:(id<DownloaderDelegate>)delegate
                       Post:(NSData *)body
                ContextType:(NSString *)contentType {
    if ((self = [super init])) {
        m_Request = [[NSMutableURLRequest alloc]
                initWithURL:url
                cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
            timeoutInterval:kTimeout];
        m_Request.HTTPMethod = @"POST";
        m_Request.HTTPBody = body;
        if (contentType != nil) {
            [m_Request setValue:contentType forHTTPHeaderField:@"Context-Type"];
        }
        [self applyCommonHeadersTo:m_Request];
        m_Delegate = delegate;
        m_Connection = nil;
        m_DownloadedData = nil;
        m_AdditionalData = nil;
    }
    return self;
}

// @ 0x623f0 — start the connection (once) and stamp the start time.
// @complete
- (void)startDownloading {
    if (m_Connection != nil || m_Task != nil) {
        return;
    }
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    // NSURLSession buffers the whole body itself and delivers a single
    // completion, so the response, accumulated data, and finish/fail are
    // funnelled into the same handlers the delegate used. A per-chunk progress
    // callback (downloaderProceed:) is no longer possible with the completion-
    // handler form, so progress is reported once when the body arrives. The
    // completion is delivered on a background queue and re-dispatched onto the
    // main queue to preserve the original delegate threading.
    m_Task = [[NSURLSession sharedSession]
        dataTaskWithRequest:m_Request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              m_Task = nil;
              if (error != nil) {
                  [self handleFailWithError:error];
                  return;
              }
              if ([self handleResponse:response]) {
                  // Treated as a hard error (for example a 404); the handler has
                  // already notified the delegate.
                  return;
              }
              if (data != nil) {
                  [self handleData:data];
              }
              [self handleFinish];
            });
          }];
    m_StartTime = [NSDate date];
    [m_Task resume];
#else
    m_Connection = [[NSURLConnection alloc] initWithRequest:m_Request delegate:self];
    m_StartTime = [NSDate date];
#endif
}

// @ 0x6249c — abort in flight. Clears the (unretained) delegate first so a
// callback already queued on the run loop is ignored, then tears down the
// connection + buffer.
// @complete
- (void)cancel {
    m_Delegate = nil;
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (m_Task != nil) {
        [m_Task cancel];
        m_Task = nil;
    }
#else
    if (m_Connection != nil) {
        [m_Connection cancel];
        m_Connection = nil;
    }
#endif
    if (m_DownloadedData != nil) {
        m_DownloadedData = nil;
    }
}

// @ 0x62938 — the raw buffered response bytes.
// @complete
- (NSData *)getData {
    return m_DownloadedData;
}

// @ 0x62948 — decode the buffered body as JSON (system serializer, TouchJSON
// fallback).
// @complete
- (NSDictionary *)getDataInJSON {
    if (m_DownloadedData == nil) {
        return nil;
    }
    if (NSClassFromString(@"NSJSONSerialization") != nil) {
        return [NSJSONSerialization JSONObjectWithData:m_DownloadedData
                                               options:NSJSONReadingMutableContainers
                                                 error:NULL];
    }
    return [NSDictionary dictionaryWithJSONData:m_DownloadedData error:NULL]; // TouchJSON
}

// @ 0x62888 — bytes buffered so far (the live length of the response buffer).
// @complete
- (NSUInteger)currentSize {
    return m_DownloadedData.length;
}

// @ 0x628a8 — fractional progress: buffered bytes over the expected content
// length, or 0 when the length is not (yet) known / non-positive.
// @complete
- (float)currentProgress {
    if (m_DownloadSize > 0) {
        // Ghidra @ 0x62912: the ratio is saturated to 1.0 (vcmpe.f32 s0,#1.0 +
        // conditional vmov.f32 s0,#0x3f800000) -- the decompiler dropped the clamp.
        const float ratio = (float)m_DownloadedData.length / (float)m_DownloadSize;
        return ratio > 1.0f ? 1.0f : ratio;
    }
    return 0.0f;
}

// @ 0x629bc — elapsed seconds since the download started; 0 before
// startDownloading.
// @complete
- (NSTimeInterval)getProgressSec {
    if (m_StartTime != nil) {
        // Ghidra @ 0x629e6: the result of -timeIntervalSinceNow (negative for a
        // past date) is negated (vneg.f64 d16,d16), yielding the positive elapsed
        // interval.
        return -[m_StartTime timeIntervalSinceNow];
    }
    return 0.0;
}

#pragma mark - Response handling

// @ 0x62514 — capture the expected length and pre-size the buffer. A 404 is
// treated as a hard error: notify the delegate instead of buffering. Returns YES
// when the response was treated as a hard error and buffering should be skipped.
// Funnelled into by both the NSURLConnection delegate (old SDK) and the
// NSURLSession completion handler (modern SDK).
// @complete
- (BOOL)handleResponse:(NSURLResponse *)response {
    if ([response respondsToSelector:@selector(statusCode)] &&
        [(NSHTTPURLResponse *)response statusCode] == 404) {
        if ([m_Delegate respondsToSelector:@selector(downloaderError:)]) {
            [m_Delegate performSelector:@selector(downloaderError:) withObject:self];
        }
        return YES;
    }

    m_DownloadSize = response.expectedContentLength;
    if (m_DownloadSize > 0) {
        m_DownloadedData = [[NSMutableData alloc] initWithCapacity:(NSUInteger)m_DownloadSize];
    }
    return NO;
}

// @ 0x6267c — buffer the body (lazily creating a 64 KB-seeded NSMutableData) and
// notify the delegate of progress.
// @complete
- (void)handleData:(NSData *)data {
    if (m_DownloadedData == nil) {
        m_DownloadedData = [[NSMutableData alloc] initWithCapacity:0x10000];
    }
    [m_DownloadedData appendData:data];
    if ([m_Delegate respondsToSelector:@selector(downloaderProceed:)]) {
        [m_Delegate performSelector:@selector(downloaderProceed:) withObject:self];
    }
}

// @ 0x627f4 — notify success.
// @complete
- (void)handleFinish {
    if ([m_Delegate respondsToSelector:@selector(downloaderFinished:)]) {
        [m_Delegate performSelector:@selector(downloaderFinished:) withObject:self];
    }
}

// @ 0x6273c — release the buffered data and notify failure.
// @complete
- (void)handleFailWithError:(NSError *)error {
    if (m_DownloadedData != nil) {
        m_DownloadedData = nil;
    }
    if ([m_Delegate respondsToSelector:@selector(downloaderError:)]) {
        [m_Delegate performSelector:@selector(downloaderError:) withObject:self];
    }
}

#if !(defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)

#pragma mark - NSURLConnection delegate

// @ 0x62514 — capture the expected length and pre-size the buffer. A 404 is
// treated as a hard error: cancel the connection and notify the delegate
// instead of buffering.
// @complete
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response respondsToSelector:@selector(statusCode)] &&
        [(NSHTTPURLResponse *)response statusCode] == 404) {
        [connection cancel];
        if (m_Connection == connection) {
            m_Connection = nil;
        }
        if ([m_Delegate respondsToSelector:@selector(downloaderError:)]) {
            [m_Delegate performSelector:@selector(downloaderError:) withObject:self];
        }
        return;
    }

    m_DownloadSize = response.expectedContentLength;
    if (m_DownloadSize > 0) {
        m_DownloadedData = [[NSMutableData alloc] initWithCapacity:(NSUInteger)m_DownloadSize];
    }
}

// @ 0x6267c — buffer each chunk (lazily creating a 64 KB-seeded NSMutableData)
// and notify the delegate of progress.
// @complete
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (m_DownloadedData == nil) {
        m_DownloadedData = [[NSMutableData alloc] initWithCapacity:0x10000];
    }
    [m_DownloadedData appendData:data];
    if ([m_Delegate respondsToSelector:@selector(downloaderProceed:)]) {
        [m_Delegate performSelector:@selector(downloaderProceed:) withObject:self];
    }
}

// @ 0x627f4 — release the connection and notify success.
// @complete
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (m_Connection == connection) {
        m_Connection = nil;
    }
    if ([m_Delegate respondsToSelector:@selector(downloaderFinished:)]) {
        [m_Delegate performSelector:@selector(downloaderFinished:) withObject:self];
    }
}

// @ 0x6273c — release the connection + buffered data and notify failure.
// @complete
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (m_Connection == connection) {
        m_Connection = nil;
    }
    if (m_DownloadedData != nil) {
        m_DownloadedData = nil;
    }
    if ([m_Delegate respondsToSelector:@selector(downloaderError:)]) {
        [m_Delegate performSelector:@selector(downloaderError:) withObject:self];
    }
}

#endif

// @ 0x629f8 — KEEP under ARC: the object-ivar releases are ARC-omitted, but
// dealloc still does real work — drop the (unretained) delegate and cancel the
// connection so a callback already queued on the run loop can't fire after the
// object is gone.
// @complete
- (void)dealloc {
    m_Delegate = nil;
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    [m_Task cancel];
    m_Task = nil;
#else
    [m_Connection cancel];
    m_Connection = nil;
#endif
}

@end
