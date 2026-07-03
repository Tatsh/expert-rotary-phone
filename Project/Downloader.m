//
//  Downloader.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Manual
//  retain/release is kept where the original manages the connection/data lifetime.
//

#import "Downloader.h"

#import "AppDelegate.h"
#import "StoreUtil.h"

// Request timeout (Ghidra: 0x402e0000 = 15.0s); reload-ignoring-cache policy (4).
static const NSTimeInterval kTimeout = 15.0;

@implementation Downloader {
    NSMutableURLRequest *m_Request;
    __weak id<DownloaderDelegate> m_Delegate;   // not retained (ARC weak; matches original assign)
    NSURLConnection *m_Connection;
    NSMutableData *m_DownloadedData;
    id m_AdditionalData;
    NSDate *m_StartTime;
}

// Caller context accessors (backing ivar m_AdditionalData).
- (id)addData {
    return m_AdditionalData;
}

- (void)setAddData:(id)addData {
    if (m_AdditionalData != addData) {
        m_AdditionalData = addData;
    }
}

// Apply the request headers every request carries (Ghidra: shared by both inits).
- (void)applyCommonHeadersTo:(NSMutableURLRequest *)request {
    [request setValue:AppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
}

// @ 0x620f4 — a GET request.
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate {
    if ((self = [super init])) {
        m_Request = [[NSMutableURLRequest alloc]
            initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
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
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)delegate
                       Post:(NSData *)body ContextType:(NSString *)contentType {
    if ((self = [super init])) {
        m_Request = [[NSMutableURLRequest alloc]
            initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
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
- (void)startDownloading {
    if (m_Connection != nil) {
        return;
    }
    m_Connection = [[NSURLConnection alloc] initWithRequest:m_Request delegate:self];
    m_StartTime = [NSDate date];
}

// @ 0x6249c — abort in flight. Clears the (unretained) delegate first so a callback
// already queued on the run loop is ignored, then tears down the connection + buffer.
- (void)cancel {
    m_Delegate = nil;
    if (m_Connection != nil) {
        [m_Connection cancel];
        m_Connection = nil;
    }
    if (m_DownloadedData != nil) {
        m_DownloadedData = nil;
    }
}

// @ 0x62938 — the raw buffered response bytes.
- (NSData *)getData {
    return m_DownloadedData;
}

// @ 0x62948 — decode the buffered body as JSON (system serializer, TouchJSON fallback).
- (NSDictionary *)getDataInJSON {
    if (m_DownloadedData == nil) {
        return nil;
    }
    if (NSClassFromString(@"NSJSONSerialization") != nil) {
        return [NSJSONSerialization JSONObjectWithData:m_DownloadedData
                                               options:NSJSONReadingMutableContainers error:NULL];
    }
    return [NSDictionary dictionaryWithJSONData:m_DownloadedData error:NULL];   // TouchJSON
}

#pragma mark - NSURLConnection delegate

// @ 0x6267c — buffer each chunk (lazily creating a 64 KB-seeded NSMutableData) and
// notify the delegate of progress.
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
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (m_Connection == connection) {
        m_Connection = nil;
    }
    if ([m_Delegate respondsToSelector:@selector(downloaderFinished:)]) {
        [m_Delegate performSelector:@selector(downloaderFinished:) withObject:self];
    }
}

// @ 0x6273c — release the connection + buffered data and notify failure.
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

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
