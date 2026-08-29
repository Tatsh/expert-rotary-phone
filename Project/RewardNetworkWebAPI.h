/**
 * @file
 * @brief The HTTP request builder and transport for the bundled Konami RewardNetwork
 * ("applilink") ad and reward SDK.
 *
 * It builds GET (query-string) and POST (x-www-form-urlencoded) NSURLRequests, merges in the SDK
 * "common" parameters, and issues them synchronously, with a small retry and back-off, or
 * asynchronously via NSURLConnection with a 10-second watchdog and retry.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (RewardNetworkWebAPI methods @
 * 0xfa744..0xfc048). The superclass is NSObject; in Ghidra, -init chains to [NSObject init].
 *
 * On dispatch: every request helper below is invoked on the class object in the binary (Ghidra
 * shows them sent to the RewardNetworkWebAPI classref), so they are class methods. The retry
 * counter the binary stores at `self+retryCount` is likewise on the class object; it is modelled
 * here as a file-static in the .m. -init is a genuine instance initialiser (Ghidra @ 0xfa744) that
 * zeroes the declared `retryCount` ivar.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The reward SDK's HTTP layer: request building, async and sync dispatch, and response
 * post-processing.
 */
@interface RewardNetworkWebAPI : NSObject {
    int retryCount; /**< The attempt counter, zeroed by -init. */
}

/**
 * @brief The parameters attached to every request: `{"cr": "0", "format": "json"}`.
 * @return The common parameters.
 * @ghidraAddress 0xfa790
 */
+ (NSDictionary *)commonParameters;

/**
 * @brief Build a request, merging the parameters with +commonParameters and choosing GET or POST
 * from the method. It sets the HTTP method, a 10-second timeout and the cache policy.
 * @param url The target URL.
 * @param method The HTTP method.
 * @param parameters The request parameters.
 * @param cachePolicy The NSURLRequestCachePolicy, boxed.
 * @return The built request.
 * @ghidraAddress 0xfa7e8
 */
+ (NSMutableURLRequest *)requestWithURL:(NSString *)url
                                 method:(NSString *)method
                             parameters:(NSDictionary *)parameters
                            cachePolicy:(NSNumber *)cachePolicy;

/**
 * @brief Build a GET request, appending the parameters to the URL as a query string.
 * @param url The target URL.
 * @param parameters The query parameters.
 * @return The built request.
 * @ghidraAddress 0xfa948
 */
+ (NSMutableURLRequest *)requestForGetWithURL:(NSString *)url parameters:(NSDictionary *)parameters;

/**
 * @brief Build a POST request with an x-www-form-urlencoded body; arrays expand to `key[]=v`.
 * @param url The target URL.
 * @param parameters The body parameters.
 * @return The built request.
 * @ghidraAddress 0xfa9f0
 */
+ (NSMutableURLRequest *)requestForPostWithURL:(NSString *)url
                                    parameters:(NSDictionary *)parameters;

/**
 * @brief Fire a request asynchronously.
 *
 * The 10-second watchdog retries with back-off, then reports a timeout error through
 * @p failedBlock. On completion the response is post-processed by
 * +responseFromContentsServer:request:data:finishedBlock:failedBlock: and delivered to
 * @p finishedBlock.
 * @param url The target URL.
 * @param method The HTTP method.
 * @param parameters The request parameters.
 * @param userInfo Echoed back to @p finishedBlock.
 * @param tag A caller tag.
 * @param cachePolicy The NSURLRequestCachePolicy, boxed.
 * @param finishedBlock Fired with the response payload.
 * @param failedBlock Fired with the request and error.
 * @ghidraAddress 0xfad84
 */
+ (void)requestAsynchronousWithURL:(NSString *)url
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

/**
 * @brief Post-process a contents-server body.
 *
 * When @p contentsServer is the stored appli URL, the first response line is a status code — "1"
 * for success, "2" or anything else for an error — and the rest is the payload. Failures are
 * reported through @p failedBlock.
 * @param contentsServer The server the body came from.
 * @param request The request that produced it.
 * @param data The raw response body.
 * @param finishedBlock Fired with the response payload.
 * @param failedBlock Fired with the request and error.
 * @return The possibly-rewritten data.
 * @ghidraAddress 0xfb58c
 */
+ (NSData *)responseFromContentsServer:(NSString *)contentsServer
                               request:(NSURLRequest *)request
                                  data:(NSData *)data
                         finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                           failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

/**
 * @brief Fire a request synchronously, with a small retry and back-off, and parse the response as
 * JSON.
 * @param url The target URL.
 * @param method The HTTP method.
 * @param parameters The request parameters.
 * @param cachePolicy The NSURLRequestCachePolicy, boxed.
 * @param error Receives the failure reason; may be NULL.
 * @return The parsed object, or nil on failure.
 * @ghidraAddress 0xfbb34
 */
+ (id)requestSynchronousWithURL:(NSString *)url
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error;

/**
 * @brief Whether network retry is available; it is only enabled on iOS 6.0 or later.
 * @return YES when retry is enabled.
 * @ghidraAddress 0xfc048
 */
+ (BOOL)canUseNetworkRetry;

/**
 * @brief The instance initialiser; it zeroes retryCount.
 * @return The initialised instance.
 * @ghidraAddress 0xfa744
 */
- (instancetype)init;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
