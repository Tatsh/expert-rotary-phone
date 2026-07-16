//
//  RewardNetworkWebAPI.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See RewardNetworkWebAPI.h for the class overview.
//

#import "RewardNetworkWebAPI.h"
#import <UIKit/UIKit.h> // UIDevice (canUseNetworkRetry)

#import "RewardNetworkError.h"     // localized NSError by code
#import "RewardNetworkUtilities.h" // parameter dictionary / URL helpers

// Retry counter. The binary keeps this at `self+retryCount` where `self` is the
// RewardNetworkWebAPI class object (a single shared slot); modelled here as a
// static.
static int sRetryCount = 0;

@implementation RewardNetworkWebAPI

// @ 0xfa744
// @complete
- (instancetype)init {
    self = [super init];
    if (self) {
        retryCount = 0;
    }
    return self;
}

// @ 0xfa790
// @complete
+ (NSDictionary *)commonParameters {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"cr", @"json", @"format", nil];
}

// @ 0xfa7e8
// @complete
+ (NSMutableURLRequest *)requestWithURL:(NSString *)url
                                 method:(NSString *)method
                             parameters:(NSDictionary *)parameters
                            cachePolicy:(NSNumber *)cachePolicy {
    NSDictionary *merged = [RewardNetworkUtilities joinDictionary:parameters
                                                   withDictionary:[self commonParameters]];

    NSMutableURLRequest *request;
    if ([@"POST" isEqualToString:method]) {
        request = [self requestForPostWithURL:url parameters:merged];
    } else {
        request = [self requestForGetWithURL:url parameters:merged];
    }

    [request setHTTPMethod:method];
    [request setTimeoutInterval:10.0]; // Ghidra 0x40240000 == 10.0
    [request setCachePolicy:(cachePolicy != nil ? (NSURLRequestCachePolicy)[cachePolicy intValue] :
                                                  NSURLRequestReloadIgnoringLocalCacheData)];
    return request;
}

// @ 0xfa948
// @complete
+ (NSMutableURLRequest *)requestForGetWithURL:(NSString *)url
                                   parameters:(NSDictionary *)parameters {
    NSString *fullURL = [RewardNetworkUtilities appendParametersToURL:url parameters:parameters];
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
}

// @ 0xfa9f0
// @complete
+ (NSMutableURLRequest *)requestForPostWithURL:(NSString *)url
                                    parameters:(NSDictionary *)parameters {
    NSMutableArray *pairs = [NSMutableArray array];
    for (id key in [parameters allKeys]) {
        id value = [parameters objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger i = 0; i < [value count]; i++) {
                [pairs
                    addObject:[NSString stringWithFormat:@"%@[]=%@", key, [value objectAtIndex:i]]];
            }
        } else {
            [pairs
                addObject:[NSString stringWithFormat:@"%@=%@", key, [parameters objectForKey:key]]];
        }
    }

    NSString *body = [pairs componentsJoinedByString:@"&"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; // 1
    return request;
}

// @ 0xfad84  (with retry/watchdog block @ 0xfb0a9 and completion handler @
// 0xfb30c; class entry allocs+forwards @ 0xfbe04)
// DEVIATION (unverified as written): the watchdog block (@ 0xfb0a8) has NO
// `if (finished) return;` guard at its head; its first act is
// [self canUseNetworkRetry] (selref @ 0x125856, referenced @ 0xfb0c2). The
// binary suppresses a stale watchdog purely via the shared retry counter (the
// completion handler gates on `sRetryCount > 1` @ 0xfb344 and the private queue
// is suspended), not via the modelled __block bool. The counter increments,
// back-off (retryCount * 2 + 2), 0x403/0xfffffc17 timeout error, and the JSON
// dispatch are otherwise byte-faithful. Left unmarked because of the added
// finished-guard; the 0x3ee fallback selector fix (Applilink, not RewardNetwork)
// is applied above.
+ (void)requestAsynchronousWithURL:(NSString *)url
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                     finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                       failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock {
    NSMutableURLRequest *request = [self requestWithURL:url
                                                 method:method
                                             parameters:parameters
                                            cachePolicy:cachePolicy];

    __block BOOL finished = NO; // guard flag shared with the watchdog (Ghidra __block int)

    // 10-second watchdog on a private serial queue (Ghidra: retry block @
    // 0xfb0a9).
    dispatch_queue_t queue = dispatch_queue_create("requestAsynchronousWithURL", NULL);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10000000000LL), queue, ^{
      if (finished) {
          return;
      }
      // Network retry is only allowed on iOS >= 6.
      if (![self canUseNetworkRetry]) {
          sRetryCount = 2;
      }
      if (sRetryCount < 2) {
          [NSThread sleepForTimeInterval:(NSTimeInterval)(sRetryCount * 2 + 2)]; // back-off
          [self requestAsynchronousWithURL:url
                                    method:method
                                parameters:parameters
                                  userInfo:userInfo
                                       tag:tag
                               cachePolicy:cachePolicy
                             finishedBlock:finishedBlock
                               failedBlock:failedBlock];
          sRetryCount++;
      } else {
          sRetryCount++;
          NSError *base = [RewardNetworkError localizedApplilinkErrorWithCode:0x403];
          NSDictionary *info =
              [NSDictionary dictionaryWithObjectsAndKeys:url,
                                                         NSURLErrorFailingURLStringErrorKey,
                                                         url,
                                                         NSURLErrorFailingURLErrorKey,
                                                         [base localizedDescription],
                                                         NSLocalizedDescriptionKey,
                                                         nil];
          NSError *timeout =
              [NSError errorWithDomain:NSURLErrorDomain
                                  code:-1001 // Ghidra 0xfffffc17 == NSURLErrorTimedOut
                              userInfo:info];
          if (failedBlock) {
              failedBlock(request, timeout);
          }
      }
    });

    // Actual request; completion runs on the main queue.
    // @ 0xfb30c — completion handler: gate on the retry counter, treat HTTP
    // 4xx/5xx (and transport errors other than a timeout) as failures, otherwise
    // post-process the body and JSON-parse it before dispatching to the finished
    // / failed block.
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    // NSURLSession delivers its completion on a background queue, so the body is
    // re-dispatched onto the main queue to preserve the original threading (the
    // NSURLConnection form completed on [NSOperationQueue mainQueue]). Note the
    // block argument order differs from NSURLConnection (data, response, error).
    [[[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *connectionError) {
            dispatch_async(dispatch_get_main_queue(), ^{
              finished = YES; // stop the watchdog (the binary suspends the
                              // private queue here)
              if (sRetryCount > 1) {
                  return;
              }
              NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
              BOOL httpError = (statusCode >= 400 && statusCode <= 599);
              if (connectionError != nil || httpError) {
                  // Transport/HTTP failure. A genuine timeout is left for the
                  // watchdog to retry.
                  if ([connectionError code] != -1001 &&
                      failedBlock) { // 0xfffffc17 == NSURLErrorTimedOut
                      failedBlock(request, connectionError);
                  }
                  return;
              }
              NSData *processed = [self responseFromContentsServer:url
                                                           request:request
                                                              data:data
                                                     finishedBlock:finishedBlock
                                                       failedBlock:failedBlock];
              Class jsonClass = NSClassFromString(@"NSJSONSerialization");
              if (jsonClass == nil) {
                  if (failedBlock) {
                      failedBlock(request,
                                  [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
                  }
                  return;
              }
              NSError *jsonError = nil;
              id object = [jsonClass JSONObjectWithData:processed
                                                options:NSJSONReadingAllowFragments // 4
                                                  error:&jsonError];
              if (jsonError != nil) {
                  if (failedBlock) {
                      failedBlock(request, jsonError);
                  }
              } else if ([object isKindOfClass:[NSDictionary class]]) {
                  if (finishedBlock) {
                      finishedBlock(object, userInfo);
                  }
              } else {
                  if (failedBlock) {
                      // The binary's non-dictionary fallback sends the
                      // single-argument localizedApplilinkErrorWithCode: (selref
                      // @ 0x1247a5, referenced @ 0xfb4f2), not the
                      // RewardNetwork:userInfo: variant.
                      failedBlock(request,
                                  [RewardNetworkError localizedApplilinkErrorWithCode:0x3ee]);
                  }
              }
            });
          }] resume];
#else
    [NSURLConnection
        sendAsynchronousRequest:request
                          queue:[NSOperationQueue mainQueue]
              completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                finished = YES; // stop the watchdog (the binary suspends the
                                // private queue here)
                if (sRetryCount > 1) {
                    return;
                }
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                BOOL httpError = (statusCode >= 400 && statusCode <= 599);
                if (connectionError != nil || httpError) {
                    // Transport/HTTP failure. A genuine timeout is left for the
                    // watchdog to retry.
                    if ([connectionError code] != -1001 &&
                        failedBlock) { // 0xfffffc17 == NSURLErrorTimedOut
                        failedBlock(request, connectionError);
                    }
                    return;
                }
                NSData *processed = [self responseFromContentsServer:url
                                                             request:request
                                                                data:data
                                                       finishedBlock:finishedBlock
                                                         failedBlock:failedBlock];
                Class jsonClass = NSClassFromString(@"NSJSONSerialization");
                if (jsonClass == nil) {
                    if (failedBlock) {
                        failedBlock(request,
                                    [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
                    }
                    return;
                }
                NSError *jsonError = nil;
                id object = [jsonClass JSONObjectWithData:processed
                                                  options:NSJSONReadingAllowFragments // 4
                                                    error:&jsonError];
                if (jsonError != nil) {
                    if (failedBlock) {
                        failedBlock(request, jsonError);
                    }
                } else if ([object isKindOfClass:[NSDictionary class]]) {
                    if (finishedBlock) {
                        finishedBlock(object, userInfo);
                    }
                } else {
                    if (failedBlock) {
                        // The binary's non-dictionary fallback sends the
                        // single-argument localizedApplilinkErrorWithCode:
                        // (selref @ 0x1247a5, referenced @ 0xfb4f2), not the
                        // RewardNetwork:userInfo: variant.
                        failedBlock(request,
                                    [RewardNetworkError localizedApplilinkErrorWithCode:0x3ee]);
                    }
                }
              }];
#endif
}

// @ 0xfb58c  (line-enumeration accumulator block @ 0xfba3c; class entry
// allocs+forwards @ 0xfbf8c)
// DEVIATION (unverified as written): for the status "2" (@ 0xfb8c8) and status-
// "otherwise" (@ 0xfb91e) branches the binary does NOT discard the
// {@"response": text} dictionary. It builds it and passes it as the userInfo
// argument to the two-parameter selector
// localizedRewardNetworkErrorWithCode:userInfo: (selref @ 0x1249cb), i.e.
// [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ee/0x3ef
// userInfo:@{@"response": text}]. The reconstruction below models a discarded
// dictionary plus a single-argument call, which is behaviourally different (the
// error loses its userInfo). Left unmarked pending a header/signature fix.
+ (NSData *)responseFromContentsServer:(NSString *)contentsServer
                               request:(NSURLRequest *)request
                                  data:(NSData *)data
                         finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                           failedBlock:
                               (void (^)(NSURLRequest *request, NSError *error))failedBlock {
    NSData *result = data;

    NSString *appliURL =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.appliURL"];
    if (![contentsServer isEqualToString:appliURL]) {
        // Not the contents server — pass the body through untouched.
        return result;
    }

    if ([data length] == 0) {
        if (failedBlock) {
            failedBlock(request, [RewardNetworkError localizedApplilinkErrorWithCode:0x3eb]);
        }
        return result;
    }

    // First line is the status code; the remaining lines are the payload.
    __block NSString *status = nil;
    __block NSMutableString *bodyText = [[NSMutableString alloc] init];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // @ 0xfba3c — line-enumeration accumulator: first line is the status, the
    // rest is the body.
    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
      if (status == nil) {
          status = line;
      } else {
          [bodyText appendString:line];
      }
    }];

    if ([status isEqualToString:@"1"]) {
        result = [bodyText dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([status isEqualToString:@"2"]) {
        (void)[NSDictionary dictionaryWithObjectsAndKeys:text, @"response", nil];
        if (failedBlock) {
            failedBlock(request, [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ee]);
        }
    } else {
        (void)[NSDictionary dictionaryWithObjectsAndKeys:text, @"response", nil];
        if (failedBlock) {
            failedBlock(request, [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ef]);
        }
    }

    return result;
}

// @ 0xfbb34   (class entry allocs+forwards @ 0xfbee0)
// @complete
+ (id)requestSynchronousWithURL:(NSString *)url
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    NSMutableURLRequest *request = [self requestWithURL:url
                                                 method:method
                                             parameters:parameters
                                            cachePolicy:cachePolicy];

    int retry = 0; // binary uses the class-object retryCount slot; per-call counter here
    NSData *responseData = nil;

    while (1) {
        NSHTTPURLResponse *response = nil;
        NSError *connectionError = nil;
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        // Synchronous NSURLSession data task via a semaphore, preserving the
        // returned data and the out-parameters of the original synchronous call.
        NSData *__block _d = nil;
        NSURLResponse *__block _r = nil;
        NSError *__block _e = nil;
        dispatch_semaphore_t _sem = dispatch_semaphore_create(0);
        [[[NSURLSession sharedSession]
            dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *taskResponse, NSError *taskError) {
                _d = data;
                _r = taskResponse;
                _e = taskError;
                dispatch_semaphore_signal(_sem);
              }] resume];
        dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
        responseData = _d;
        response = (NSHTTPURLResponse *)_r;
        connectionError = _e;
#else
        responseData = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&connectionError];
#endif
        NSInteger status = [response statusCode];

        BOOL httpError = (status >= 400 && status < 500) || (status >= 500 && status < 600);
        if (connectionError == nil && !httpError) {
            if (responseData == nil) {
                if (error != NULL) {
                    *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3eb];
                }
                return nil;
            }
            break; // success
        }

        // Retry only up to twice, and only for the SDK's retryable connection
        // error.
        if (retry > 1 || [connectionError code] != (NSInteger)0xfffee6b9) {
            if (error != NULL) {
                *error = connectionError;
            }
            return nil;
        }
        [NSThread sleepForTimeInterval:(NSTimeInterval)(retry * 2 + 2)]; // back-off
        retry++;
        // Ghidra's `while (iVar7 < 2)` never exits (iVar7 is the pre-increment
        // count, always <= 1 here); the loop only leaves via the success break or
        // the `retry > 1` early return above. Do NOT break out to the JSON parse
        // here.
    }

    // Parse the body as JSON.
    Class jsonClass = NSClassFromString(@"NSJSONSerialization");
    if (jsonClass == nil) {
        if (error != NULL) {
            *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x401];
        }
        return nil;
    }

    NSError *jsonError = nil;
    id object = [jsonClass JSONObjectWithData:responseData
                                      options:NSJSONReadingAllowFragments // 4
                                        error:&jsonError];
    if (jsonError != nil) {
        if (error != NULL) {
            *error = jsonError;
        }
        return nil;
    }
    if (object != nil) {
        return object;
    }
    if (error != NULL) {
        *error = [RewardNetworkError localizedApplilinkErrorWithCode:1000];
    }
    return nil;
}

// @ 0xfc048
// @complete
+ (BOOL)canUseNetworkRetry {
    return [[[UIDevice currentDevice] systemVersion] doubleValue] >= 6.0;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
