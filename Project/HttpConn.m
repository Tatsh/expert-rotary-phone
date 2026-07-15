//
//  HttpConn.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "HttpConn.h"

#import "SDKCompat.h"

RB_DEPRECATED_BEGIN
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
    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (conn == nil) {
        NSLog(@"http get connection error.");
    }
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
    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (conn == nil) {
        NSLog(@"http post connection error.");
    }
    status = HttpConnStatusRunning;
}

// @ 0x6a8c0
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"catch server response.");
    statusCode = (int)[(NSHTTPURLResponse *)response statusCode];
    NSString *name = [[response textEncodingName] lowercaseString];
    if ([name isEqualToString:@"shift_jis"] || [name isEqualToString:@"sjis"]) {
        encoding = NSShiftJISStringEncoding;
    } else {
        encoding = NSUTF8StringEncoding;
    }
}

// @ 0x6a978
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"data receive %lu byte.", (unsigned long)[data length]);
    [receivedData appendData:data];
}

// @ 0x6a9c8
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection error:%@", error);
    conn = nil;
    receivedData = nil;
    status = HttpConnStatusError;
}

// @ 0x6aa38
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
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

@end
RB_DEPRECATED_END

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
