//
//  RewardNetworkURLConnection.m
//  pop'n rhythmin
//
//  See RewardNetworkURLConnection.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. A single async NSURLConnection request for the
//  applilink SDK, with a 10s watchdog timer and a two-attempt retry/back-off.
//

#import "RewardNetworkURLConnection.h"

#import "RewardNetworkError.h" // +localizedApplilinkErrorWithCode:
#import "RewardNetworkWebAPI.h" // +responseFromContentsServer:request:data:finishedBlock:failedBlock:

// Own privates (the watchdog callback and the retry driver).
@interface RewardNetworkURLConnection ()
- (void)connectionTimeout:(NSTimer *)timer;
- (void)retryConnection;
@end

@implementation RewardNetworkURLConnection

// @ 0xff9d0
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        retryCount = 0;
        self.ApplilinkFinishedBlock = nil;
        self.ApplilinkFailedBlock = nil;
        self.url = nil;
        self.request = nil;
    }
    return self;
}

// @ 0xffa6c
- (void)requestAsynchronousWithURL:(NSString *)url
                           request:(NSURLRequest *)request
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock {
    if (self.timer != nil) {
        [self.timer invalidate];
    }
    // A nil block on a retry keeps the previously installed callback.
    if (finishedBlock != nil) {
        self.ApplilinkFinishedBlock = finishedBlock;
    }
    if (failedBlock != nil) {
        self.ApplilinkFailedBlock = failedBlock;
    }
    self.url = url;
    self.request = request;

    self.connection = [[NSURLConnection alloc] initWithRequest:request
                                                      delegate:self
                                              startImmediately:NO];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                  target:self
                                                selector:@selector(connectionTimeout:)
                                                userInfo:nil
                                                 repeats:NO];
    self.receiveData = [NSMutableData data];

    // @ 0xffcbc — the block body just starts the connection.
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.connection start];
    });
    self.isConnection = YES;
}

// @ 0xffd08 — watchdog fired: cancel and retry.
- (void)connectionTimeout:(NSTimer *)timer {
    [self.connection cancel];
    [self retryConnection];
}

#pragma mark - NSURLConnectionDataDelegate

// @ 0xffd58 — HTTP 4xx/5xx are treated as failures (cancel + retry); any other
// status resets the receive buffer and continues.
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    if (statusCode >= 400 && statusCode <= 599) {
        [self.connection cancel];
        [self retryConnection];
    } else {
        [self.receiveData setLength:0];
    }
}

// @ 0xffe00
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receiveData appendData:data];
}

// @ 0xffe50 — post-process the body, then parse it as JSON and dispatch to the
// finished / failed block.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.timer != nil) {
        [self.timer invalidate];
        self.timer = nil;
    }

    NSData *data = [RewardNetworkWebAPI responseFromContentsServer:self.url
                                                           request:self.request
                                                              data:self.receiveData
                                                     finishedBlock:self.ApplilinkFinishedBlock
                                                       failedBlock:self.ApplilinkFailedBlock];
    self.isConnection = NO;

    if (NSClassFromString(@"NSJSONSerialization") == nil) {
        // iOS < 5: no JSON parser available.
        if (self.ApplilinkFailedBlock != nil) {
            self.ApplilinkFailedBlock(self.request,
                                      [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
        }
        return;
    }

    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data
                                                options:NSJSONReadingAllowFragments
                                                  error:&error];
    if (error != nil) {
        if (self.ApplilinkFailedBlock != nil) {
            self.ApplilinkFailedBlock(self.request, error);
        }
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        if (self.ApplilinkFinishedBlock != nil) {
            self.ApplilinkFinishedBlock(self.request, object);
        }
    } else {
        if (self.ApplilinkFailedBlock != nil) {
            self.ApplilinkFailedBlock(self.request,
                                      [RewardNetworkError localizedApplilinkErrorWithCode:0x3ee]);
        }
    }
}

// @ 0x1001cc — transport error: retry.
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self retryConnection];
}

#pragma mark - Retry

// @ 0x1001dc — up to two retries with a back-off, then fail with a timeout
// error.
- (void)retryConnection {
    if (self.timer != nil) {
        [self.timer invalidate];
        self.timer = nil;
    }

    if (retryCount < 2) {
        [NSThread sleepForTimeInterval:(NSTimeInterval)(retryCount * 2 + 2)]; // back-off
        [self requestAsynchronousWithURL:self.url
                                 request:self.request
                           finishedBlock:nil
                             failedBlock:nil];
        retryCount++;
        return;
    }

    NSError *base = [RewardNetworkError localizedApplilinkErrorWithCode:0x403];
    NSString *description = [base localizedDescription];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:3];
    if (self.url != nil) {
        [userInfo setValue:self.url forKey:NSURLErrorFailingURLStringErrorKey];
        [userInfo setValue:self.url forKey:NSURLErrorFailingURLErrorKey];
    }
    if (description != nil) {
        [userInfo setValue:description forKey:NSLocalizedDescriptionKey];
    }
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain
                                                code:-1001 // NSURLErrorTimedOut (Ghidra 0xfffffc17)
                                            userInfo:userInfo];
    if (self.ApplilinkFailedBlock != nil) {
        self.ApplilinkFailedBlock(self.request, timeoutError);
    }
    self.isConnection = NO;
}

// .cxx_destruct @ 0x100664 — compiler-emitted ARC teardown; not hand-written.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
