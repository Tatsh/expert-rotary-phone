//
//  RewardNetworkWebAPI.h
//  pop'n rhythmin
//
//  HTTP request builder / transport for the bundled Konami **RewardNetwork**
//  ("applilink") ad/reward SDK. Builds GET (query-string) and POST
//  (x-www-form-urlencoded) NSURLRequests, merges in the SDK "common"
//  parameters, and issues them synchronously (with a small retry/back-off) or
//  asynchronously (via NSURLConnection with a 10s watchdog + retry).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (RewardNetworkWebAPI methods @ 0xfa744..0xfc048). Superclass is NSObject
//  (Ghidra: -init chains to [NSObject init]).
//
//  Dispatch note: every request helper below is invoked on the CLASS object in
//  the binary (Ghidra: sent to the RewardNetworkWebAPI classref), so they are
//  class (+) methods. The retry counter the binary stores at `self+retryCount`
//  is likewise on the class object; it is modelled here as a file-static in the
//  .m. -init is a genuine instance initializer (Ghidra @ 0xfa744) that zeroes
//  the declared `retryCount` ivar.
//

#import <Foundation/Foundation.h>

@interface RewardNetworkWebAPI : NSObject {
    int retryCount; // zeroed by -init (@ 0xfa744); see dispatch note above
}

// @{ @"cr": @"0", @"format": @"json" } — parameters attached to every request.
// @ 0xfa790
+ (NSDictionary *)commonParameters;

// Build a request for `url`, merging `parameters` with +commonParameters and
// choosing GET or POST from `method`; sets HTTP method, 10s timeout and cache
// policy. @ 0xfa7e8
+ (NSMutableURLRequest *)requestWithURL:(NSString *)url
                                 method:(NSString *)method
                             parameters:(NSDictionary *)parameters
                            cachePolicy:(NSNumber *)cachePolicy;

// GET request: append `parameters` as a query string onto `url`. @ 0xfa948
+ (NSMutableURLRequest *)requestForGetWithURL:(NSString *)url parameters:(NSDictionary *)parameters;

// POST request: x-www-form-urlencoded body (arrays expand to `key[]=v`). @
// 0xfa9f0
+ (NSMutableURLRequest *)requestForPostWithURL:(NSString *)url
                                    parameters:(NSDictionary *)parameters;

// Fire `url` asynchronously; the 10s watchdog retries with back-off, then
// reports a timeout error through failedBlock. On completion the response is
// post-processed by +responseFromContentsServer:... and delivered to
// finishedBlock. @ 0xfad84
+ (void)requestAsynchronousWithURL:(NSString *)url
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

// Post-process a contents-server body: when `contentsServer` is the stored
// appli URL the first response line is a status code ("1" ok, "2"/other →
// error) and the rest is the payload; failures are reported through
// failedBlock. Returns the (possibly rewritten) data. @ 0xfb58c
+ (NSData *)responseFromContentsServer:(NSString *)contentsServer
                               request:(NSURLRequest *)request
                                  data:(NSData *)data
                         finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                           failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock;

// Synchronous request with a small retry/back-off; parses the response as JSON
// and returns the parsed object (or nil with `*error` set). @ 0xfbb34
+ (id)requestSynchronousWithURL:(NSString *)url
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error;

// YES on iOS >= 6.0 (network retry is only enabled there). @ 0xfc048
+ (BOOL)canUseNetworkRetry;

// Genuine instance initializer (zeroes `retryCount`). @ 0xfa744
- (instancetype)init;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
