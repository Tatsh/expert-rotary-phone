/**
 * @file
 * A single asynchronous HTTP request for the bundled Konami "RewardNetwork" (applilink)
 * SDK.
 *
 * It wraps NSURLConnection with a 10-second watchdog timer and a two-attempt retry and back-off.
 * On finish the body is post-processed by +[RewardNetworkWebAPI responseFromContentsServer:...]
 * and, when it parses to a JSON dictionary, delivered through the finished block; parse failures,
 * HTTP 4xx and 5xx responses, transport errors, and timeouts are reported through the failed block
 * as an ApplilinkErrorDomain or NSURLErrorDomain NSError.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xff9d0 through
 * setApplilinkFinishedBlock: @ 0x100640). The superclass is NSObject; in Ghidra, -init chains to
 * [NSObject init].
 */

#import <Foundation/Foundation.h>

/**
 * One reward-SDK HTTP request, with a watchdog timer and retry counter.
 */
@interface RewardNetworkURLConnection : NSObject <NSURLConnectionDataDelegate> {
    /** The attempt counter, zeroed by -init and accessed directly. */
    int retryCount;
}

/** The in-flight request. Getter @ 0x1004bc, setter @ 0x1004cc. */
@property(nonatomic, retain) NSURLRequest *request;

/** The backing NSURLConnection. Getter @ 0x1004f4, setter @ 0x100504. */
@property(nonatomic, retain) NSURLConnection *connection;

/** The failure callback. Getter @ 0x10052c, setter @ 0x100540. */
@property(nonatomic, copy) void (^ApplilinkFailedBlock)(NSURLRequest *request, NSError *error);

/** The accumulated response body. Getter @ 0x100564, setter @ 0x100574. */
@property(nonatomic, retain) NSMutableData *receiveData;

/** Whether a request is in flight. Getter @ 0x10059c, setter @ 0x1005ac. */
@property(nonatomic, assign) BOOL isConnection;

/** The 10-second watchdog timer. Getter @ 0x1005bc, setter @ 0x1005cc. */
@property(nonatomic, retain) NSTimer *timer;

/** The target URL string. Getter @ 0x1005f4, setter @ 0x100604. */
@property(nonatomic, retain) NSString *url;

/** The success callback, typed to match
 * +[RewardNetworkWebAPI responseFromContentsServer:request:data:finishedBlock:failedBlock:], whose
 * two arguments are both `id`. -connectionDidFinishLoading: invokes it as
 * `block(request, jsonObject)`. Getter @ 0x10062c, setter @ 0x100640. */
@property(nonatomic, copy) void (^ApplilinkFinishedBlock)(id response, id userInfo);

/**
 * The designated initialiser: it zeroes retryCount and nils the blocks, URL and request.
 * @return The initialised connection.
 * @ghidraAddress 0xff9d0
 */
- (instancetype)init;

/**
 * Start a request.
 *
 * It installs the callbacks — keeping the existing one when a passed block is nil — the
 * 10-second watchdog and a fresh receive buffer, then starts the connection on the main queue.
 * @param url The target URL string.
 * @param request The request to send.
 * @param finishedBlock Fired with the response payload.
 * @param failedBlock Fired with the request and error.
 * @ghidraAddress 0xffa6c
 */
- (void)requestAsynchronousWithURL:(NSString *)url
                           request:(NSURLRequest *)request
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
