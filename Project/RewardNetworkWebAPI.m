//
//  RewardNetworkWebAPI.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  See RewardNetworkWebAPI.h for the class overview.
//

#import "RewardNetworkWebAPI.h"
#import <UIKit/UIKit.h>   // UIDevice (canUseNetworkRetry)

#import "RewardNetworkUtilities.h"   // parameter dictionary / URL helpers
#import "RewardNetworkError.h"       // localized NSError by code

// Retry counter. The binary keeps this at `self+retryCount` where `self` is the
// RewardNetworkWebAPI class object (a single shared slot); modelled here as a static.
static int sRetryCount = 0;

@implementation RewardNetworkWebAPI

// @ 0xfa744
- (instancetype)init {
    self = [super init];
    if (self) {
        retryCount = 0;
    }
    return self;
}

// @ 0xfa790
+ (NSDictionary *)commonParameters {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"0", @"cr",
            @"json", @"format",
            nil];
}

// @ 0xfa7e8
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
    [request setTimeoutInterval:10.0];  // Ghidra 0x40240000 == 10.0
    [request setCachePolicy:(cachePolicy != nil ? (NSURLRequestCachePolicy)[cachePolicy intValue]
                                                : NSURLRequestReloadIgnoringLocalCacheData)];
    return request;
}

// @ 0xfa948
+ (NSMutableURLRequest *)requestForGetWithURL:(NSString *)url parameters:(NSDictionary *)parameters {
    NSString *fullURL = [RewardNetworkUtilities appendParametersToURL:url parameters:parameters];
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
}

// @ 0xfa9f0
+ (NSMutableURLRequest *)requestForPostWithURL:(NSString *)url parameters:(NSDictionary *)parameters {
    NSMutableArray *pairs = [NSMutableArray array];
    for (id key in [parameters allKeys]) {
        id value = [parameters objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger i = 0; i < [value count]; i++) {
                [pairs addObject:[NSString stringWithFormat:@"%@[]=%@", key, [value objectAtIndex:i]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [parameters objectForKey:key]]];
        }
    }

    NSString *body = [pairs componentsJoinedByString:@"&"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];  // 1
    return request;
}

// @ 0xfad84  (with retry/watchdog block @ 0xfb0a9 and completion handler @ 0xfb30c; class entry allocs+forwards @ 0xfbe04)
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

    __block BOOL finished = NO;   // guard flag shared with the watchdog (Ghidra __block int)

    // 10-second watchdog on a private serial queue (Ghidra: retry block @ 0xfb0a9).
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
            [NSThread sleepForTimeInterval:(NSTimeInterval)(sRetryCount * 2 + 2)];  // back-off
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
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                  url, NSURLErrorFailingURLStringErrorKey,
                                  url, NSURLErrorFailingURLErrorKey,
                                  [base localizedDescription], NSLocalizedDescriptionKey,
                                  nil];
            NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain
                                                   code:-1001   // Ghidra 0xfffffc17 == NSURLErrorTimedOut
                                               userInfo:info];
            if (failedBlock) {
                failedBlock(request, timeout);
            }
        }
    });

    // Actual request; completion runs on the main queue.
    // @ 0xfb30c — completion handler: gate on the retry counter, treat HTTP 4xx/5xx (and
    // transport errors other than a timeout) as failures, otherwise post-process the body
    // and JSON-parse it before dispatching to the finished / failed block.
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        finished = YES;   // stop the watchdog (the binary suspends the private queue here)
        if (sRetryCount > 1) {
            return;
        }
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL httpError = (statusCode >= 400 && statusCode <= 599);
        if (connectionError != nil || httpError) {
            // Transport/HTTP failure. A genuine timeout is left for the watchdog to retry.
            if ([connectionError code] != -1001 && failedBlock) {  // 0xfffffc17 == NSURLErrorTimedOut
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
                failedBlock(request, [RewardNetworkError localizedApplilinkErrorWithCode:0x401]);
            }
            return;
        }
        NSError *jsonError = nil;
        id object = [jsonClass JSONObjectWithData:processed
                                          options:NSJSONReadingAllowFragments  // 4
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
                failedBlock(request, [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ee]);
            }
        }
    }];
}

// @ 0xfb58c  (line-enumeration accumulator block @ 0xfba3c; class entry allocs+forwards @ 0xfbf8c)
+ (NSData *)responseFromContentsServer:(NSString *)contentsServer
                               request:(NSURLRequest *)request
                                  data:(NSData *)data
                         finishedBlock:(void (^)(id response, id userInfo))finishedBlock
                           failedBlock:(void (^)(NSURLRequest *request, NSError *error))failedBlock {
    NSData *result = data;

    NSString *appliURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkReward.appliURL"];
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
    // @ 0xfba3c — line-enumeration accumulator: first line is the status, the rest is the body.
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
+ (id)requestSynchronousWithURL:(NSString *)url
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    NSMutableURLRequest *request = [self requestWithURL:url
                                                 method:method
                                             parameters:parameters
                                            cachePolicy:cachePolicy];

    int retry = 0;   // binary uses the class-object retryCount slot; per-call counter here
    NSData *responseData = nil;

    while (1) {
        NSHTTPURLResponse *response = nil;
        NSError *connectionError = nil;
        responseData = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&connectionError];
        NSInteger status = [response statusCode];

        BOOL httpError = (status >= 400 && status < 500) || (status >= 500 && status < 600);
        if (connectionError == nil && !httpError) {
            if (responseData == nil) {
                if (error != NULL) {
                    *error = [RewardNetworkError localizedApplilinkErrorWithCode:0x3eb];
                }
                return nil;
            }
            break;  // success
        }

        // Retry only up to twice, and only for the SDK's retryable connection error.
        if (retry > 1 || [connectionError code] != (NSInteger)0xfffee6b9) {
            if (error != NULL) {
                *error = connectionError;
            }
            return nil;
        }
        [NSThread sleepForTimeInterval:(NSTimeInterval)(retry * 2 + 2)];  // back-off
        retry++;
        // Ghidra's `while (iVar7 < 2)` never exits (iVar7 is the pre-increment count,
        // always <= 1 here); the loop only leaves via the success break or the
        // `retry > 1` early return above. Do NOT break out to the JSON parse here.
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
                                      options:NSJSONReadingAllowFragments  // 4
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
+ (BOOL)canUseNetworkRetry {
    return [[[UIDevice currentDevice] systemVersion] doubleValue] >= 6.0;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
