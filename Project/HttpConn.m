//
//  HttpConn.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "HttpConn.h"

@implementation HttpConn

// receivedString @ 0x6ab60, status / setStatus: @ 0x6ab74 / 0x6ab88 (atomic).
@synthesize receivedString = receivedString;
@synthesize status = status;

// @ 0x6a550
- (instancetype)init {
    if ((self = [super init])) {
        status = HttpConnStatusReady;
    }
    return self;
}

// @ 0x6a58c
- (void)get:(NSString *)urlString {
    if (status != HttpConnStatusReady) {
        NSLog(@"Http Util is not READY.");
        return;
    }
    receivedData = [[NSMutableData alloc] initWithLength:0];
    if (receivedData != nil) {
        receivedString = nil;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    [self startSessionTaskWithRequest:request errorLog:@"http get connection error."];
#else
    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (conn == nil) {
        NSLog(@"http get connection error.");
    }
#endif
    status = HttpConnStatusRunning;
}

// @ 0x6a6c4
- (void)post:(NSString *)urlString paramString:(NSString *)paramString {
    if (status != HttpConnStatusReady) {
        NSLog(@"Http Util is not READY.");
        return;
    }
    receivedData = [[NSMutableData alloc] initWithLength:0];
    if (receivedData != nil) {
        receivedString = nil;
    }
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                            timeoutInterval:240.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[paramString length]]
        forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:[paramString dataUsingEncoding:NSUTF8StringEncoding]];
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    [self startSessionTaskWithRequest:request errorLog:@"http post connection error."];
#else
    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (conn == nil) {
        NSLog(@"http post connection error.");
    }
#endif
    status = HttpConnStatusRunning;
}

// Shared response-handling logic, funnelled into by both the NSURLConnection
// delegate methods (old SDK) and the NSURLSession completion handler (modern
// SDK).
- (void)handleResponse:(NSURLResponse *)response {
    NSLog(@"catch server response.");
    statusCode = (int)[(NSHTTPURLResponse *)response statusCode];
    NSString *name = [[response textEncodingName] lowercaseString];
    if ([name isEqualToString:@"shift_jis"] || [name isEqualToString:@"sjis"]) {
        encoding = NSShiftJISStringEncoding;
    } else {
        encoding = NSUTF8StringEncoding;
    }
}

- (void)handleData:(NSData *)data {
    NSLog(@"data receive %lu byte.", (unsigned long)[data length]);
    [receivedData appendData:data];
}

- (void)handleFailWithError:(NSError *)error {
    NSLog(@"connection error:%@", error);
    conn = nil;
    receivedData = nil;
    status = HttpConnStatusError;
}

- (void)handleFinish {
    NSLog(@"data receive finished. total %lu byte.", (unsigned long)[receivedData length]);
    receivedString = [[NSString alloc] initWithData:receivedData encoding:encoding];
    if (statusCode < 400) {
        if (receivedString == nil) {
            NSLog(@"data encoding failed.");
            status = HttpConnStatusEncoding;
        } else {
            status = HttpConnStatusSuccess;
        }
    } else {
        NSLog(@"http error:%d", statusCode);
        status = HttpConnStatusError;
    }
    conn = nil;
    receivedData = nil;
}

#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0

// Issue the request as an NSURLSession data task, funnelling the single response,
// body, and completion (or failure) into the same internal handlers the
// NSURLConnection delegate used. The completion handler is delivered on a
// background queue, so it is re-dispatched onto the main queue to preserve the
// original delegate threading.
- (void)startSessionTaskWithRequest:(NSURLRequest *)request errorLog:(NSString *)errorLog {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (error != nil) {
                  [self handleFailWithError:error];
                  return;
              }
              [self handleResponse:response];
              if (data != nil) {
                  [self handleData:data];
              }
              [self handleFinish];
            });
          }];
    if (task == nil) {
        NSLog(@"%@", errorLog);
    }
    [task resume];
}

#else

// @ 0x6a8c0
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self handleResponse:response];
}

// @ 0x6a978
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self handleData:data];
}

// @ 0x6a9c8
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self handleFailWithError:error];
}

// @ 0x6aa38
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self handleFinish];
}

#endif

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
