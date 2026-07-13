//
//  RewardNetworkURLConnection.h
//  pop'n rhythmin
//
//  A single asynchronous HTTP request for the bundled Konami "RewardNetwork"
//  (applilink) SDK, wrapping NSURLConnection with a 10-second watchdog timer
//  and a two-attempt retry/back-off. On finish the body is post-processed by
//  +[RewardNetworkWebAPI responseFromContentsServer:...] and, when it parses to
//  a JSON dictionary, delivered through the finished block; parse failures,
//  HTTP 4xx/5xx responses, transport errors and timeouts are reported through
//  the failed block as an ApplilinkErrorDomain / NSURLErrorDomain NSError.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (init @ 0xff9d0 .. setApplilinkFinishedBlock: @ 0x100640). Superclass is
//  NSObject (Ghidra: -init chains to [NSObject init]).
//

#import <Foundation/Foundation.h>

@interface RewardNetworkURLConnection : NSObject <NSURLConnectionDataDelegate> {
    int retryCount; // attempt counter (zeroed by -init @ 0xff9d0); accessed
                    // directly
}

// @ 0x1004bc / setRequest: @ 0x1004cc — the in-flight request.
@property(nonatomic, retain) NSURLRequest *request;

// @ 0x1004f4 / setConnection: @ 0x100504 — the backing NSURLConnection.
@property(nonatomic, retain) NSURLConnection *connection;

// @ 0x10052c / setApplilinkFailedBlock: @ 0x100540 — failure callback.
@property(nonatomic, copy) void (^ApplilinkFailedBlock)(NSURLRequest *request, NSError *error);

// @ 0x100564 / setReceiveData: @ 0x100574 — accumulated response body.
@property(nonatomic, retain) NSMutableData *receiveData;

// @ 0x10059c / setIsConnection: @ 0x1005ac — YES while a request is in flight.
@property(nonatomic, assign) BOOL isConnection;

// @ 0x1005bc / setTimer: @ 0x1005cc — the 10s watchdog timer.
@property(nonatomic, retain) NSTimer *timer;

// @ 0x1005f4 / setUrl: @ 0x100604 — the target URL string.
@property(nonatomic, retain) NSString *url;

// @ 0x10062c / setApplilinkFinishedBlock: @ 0x100640 — success callback. Typed
// to match +[RewardNetworkWebAPI responseFromContentsServer:...finishedBlock:]
// (both args id); -connectionDidFinishLoading: invokes it as block(request,
// jsonObject).
@property(nonatomic, copy) void (^ApplilinkFinishedBlock)(id response, id userInfo);

// @ 0xff9d0 — designated initializer (zeroes retryCount, nils the blocks / url
// / request).
- (instancetype)init;

// @ 0xffa6c — start `request` against `url`; installs the callbacks (kept if a
// passed block is nil), the 10s watchdog and a fresh receive buffer, then
// starts the connection on the main queue.
- (void)requestAsynchronousWithURL:(NSString *)url
                           request:(NSURLRequest *)request
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
