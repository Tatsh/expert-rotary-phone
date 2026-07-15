//
//  RecommendCore.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendCore.h"

#import "NSString+URLDecode.h" // -URLDecodedString (SDK percent-decode category)
#import "RecommendAdId.h"
#import "RecommendWebAPI.h"
#import "RecommendWebViewController.h" // also supplies the RewardNetworkWebViewDelegate protocol
#import "RewardNetworkError.h"

// The single shared core and the serial "RewardCore" queue its designated
// initialiser runs on. Both are produced by the +allocWithZone: dispatch_once
// body (recommendCoreSharedAlloc @ 0xfc2c4).
static RecommendCore *g_pRecommendCoreInstance = nil; // @ g_pRecommendCoreInstance
static dispatch_queue_t g_pRewardCoreQueue = NULL;    // @ DAT_0018836c ("RewardCore")

@interface RecommendCore () <RewardNetworkWebViewDelegate> {
    BOOL navigationBarHidden; // hide the app-list navigation bar
}

@property(nonatomic, copy)
    RecommendOpenAppliListCallback callbackForOpenAppliList;                // @ 0xfe660 / 0xfe674
@property(nonatomic, strong) NSString *categoryId;                          // @ 0xfe698 / 0xfe6a8
@property(nonatomic, strong) NSError *lastErrorForOpenAppliList;            // @ 0xfe6d0 / 0xfe6e0
@property(nonatomic, strong) RecommendWebViewController *webViewController; // @ 0xfe708 / 0xfe718
@property(nonatomic, assign) int initializeFlg;                             // @ 0xfe740 / 0xfe750
@property(nonatomic, strong) NSString *countryCode;                         // @ 0xfe760 / 0xfe770

// @ 0xfd688 — POST the install record to /ad/external/app/install/regist.php.
- (void)postApplicationInstallWithAdIdFrom:(NSString *)adIdFrom
                               countryCode:(NSString *)countryCode
                                categoryId:(NSString *)categoryId
                                    adType:(NSString *)adType
                                  callback:(RecommendOpenAppliListCallback)callback;

// Map a server response's error_code/kind to a localized RewardNetworkError.
- (NSError *)appliListErrorFromResponse:(NSDictionary *)response;

@end

@implementation RecommendCore

// @ 0xfc258 (dispatch_once block recommendCoreSharedAlloc @ 0xfc2c4) — create
// the serial queue and the single instance once.
+ (instancetype)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      g_pRewardCoreQueue = dispatch_queue_create("RewardCore", NULL);
      g_pRecommendCoreInstance = [super allocWithZone:zone];
      [g_pRecommendCoreInstance setInitializeFlg:0];
    });
    return g_pRecommendCoreInstance;
}

// @ 0xfc47c
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      g_pRecommendCoreInstance = [[RecommendCore alloc] init];
    });
    return g_pRecommendCoreInstance;
}

// @ 0xfc33c — perform [super init] on the shared "RewardCore" serial queue
// (recommendCoreInitBlock
// @ 0xfc404 stores the result into the __block variable returned here).
- (instancetype)init {
    __block RecommendCore *result = nil;
    dispatch_sync(g_pRewardCoreQueue, ^{
      result = [super init];
    });
    return result;
}

// @ 0xfc50c — pick the SSL base URL for the stored environment index (0..4).
+ (NSString *)baseUrlSsl {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:@"ApplilinkRecommend.env"];
    if ([env isEqualToString:@"0"]) {
        return @"https://www.applilink.jp";
    }
    if ([env isEqualToString:@"1"]) {
        return @"https://st.es.i-revoinf.jp";
    }
    if ([env isEqualToString:@"2"]) {
        return @"https://dev.es.i-revoinf.jp";
    }
    if ([env isEqualToString:@"3"]) {
        return @"https://sandbox.applilink.jp";
    }
    if ([env isEqualToString:@"4"]) {
        return @"https://dev.es.i-revoinf.jp";
    }
    return nil;
}

// @ 0xfc628
- (NSString *)getCountryCode {
    return [self countryCode];
}

// @ 0xfc638
- (NSString *)getCategoryId {
    return [self categoryId];
}

// @ 0xfc648
- (BOOL)isInitialized {
    return [self initializeFlg] == 1;
}

// @ 0xfc664
- (BOOL)isInstalledAppliWithScheme:(NSString *)scheme {
    UIApplication *app = [UIApplication sharedApplication];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", scheme]];
    return [app canOpenURL:url] ? YES : NO;
}

// @ 0xfc734
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback {
    [[NSUserDefaults standardUserDefaults] setValue:env forKey:@"ApplilinkRecommend.env"];
    [self setCountryCode:countryCode];
    [self setCategoryId:categoryId];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ApplilinkRecommend.postInstalled"]) {
        // recommendCorePostInstallWithAdId @ 0xfc8d0
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
          RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                                categoryId:categoryId];
          NSError *loadError = nil;
          NSDictionary *record = [adId getWithCountryCode:countryCode
                                               categoryId:categoryId
                                                    error:&loadError];
          NSString *adIdFrom = nil;
          NSString *adType = nil;
          if (loadError == nil && record != nil) {
              id from = [record objectForKey:@"AdIdFrom"];
              if ([from isKindOfClass:[NSString class]]) {
                  adIdFrom = from;
              }
              id type = [record objectForKey:@"AdType"];
              if ([type isKindOfClass:[NSString class]]) {
                  adType = type;
              }
          }
          // recommendCorePostInstallCallback @ 0xfcadc
          [self postApplicationInstallWithAdIdFrom:adIdFrom
                                       countryCode:countryCode
                                        categoryId:categoryId
                                            adType:adType
                                          callback:^(NSError *error) {
                                            if (error == nil) {
                                                [adId deleteWithCountryCode:countryCode
                                                                 categoryId:categoryId
                                                                      error:nil];
                                                [[NSUserDefaults standardUserDefaults]
                                                    setBool:YES
                                                     forKey:@"ApplilinkRecommend."
                                                            @"postInstalled"];
                                            }
                                            if (callback) {
                                                callback(error);
                                            }
                                          }];
        });
    } else if (callback != nil) {
        callback(nil);
    }
}

// @ 0xfcc0c — wrap the raw fetch (recommendCoreLoadOpenAppliList @ 0xfcc78)
// that filters the installed apps, lazily builds the web-view controller and
// loads /ad/external/index.php.
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback {
    [self appliListWithCallBack:^(NSArray *appliList, NSError *error) {
      if (error != nil) {
          if (callback) {
              callback(error);
          }
          return;
      }
      NSMutableArray *installedAdIds = [[NSMutableArray alloc] init];
      for (id item in appliList) {
          if ([item isKindOfClass:[NSDictionary class]]) {
              NSString *scheme = [item objectForKey:@"default_scheme"];
              NSString *adId = [item objectForKey:@"ad_id"];
              if ([scheme isKindOfClass:[NSString class]] &&
                  [self isInstalledAppliWithScheme:scheme] && adId) {
                  [installedAdIds addObject:adId];
              }
          }
      }
      NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
      [params setValue:self.countryCode forKey:@"country_code"];
      [params setValue:self.categoryId forKey:@"category_id"];
      [params setValue:@"1" forKey:@"is_sdk"];
      if ([installedAdIds count] != 0) {
          [params setObject:installedAdIds forKey:@"install_ad_id_list"];
      }
      [self setCallbackForOpenAppliList:callback];
      [self setLastErrorForOpenAppliList:nil];
      if (self.webViewController == nil) {
          self.webViewController = [[RecommendWebViewController alloc] init];
      }
      [self.webViewController setNavigationBarHidden:navigationBarHidden];
      if (callback != nil) {
          [self.webViewController setDelegate:nil];
      }
      id existingDelegate = [self.webViewController delegate];
      NSURL *url = [NSURL URLWithString:[[RecommendCore baseUrlSsl]
                                            stringByAppendingString:@"/ad/external/index.php"]];
      if (existingDelegate == nil) {
          [self.webViewController loadRequestWithURL:url parameters:params delegate:self];
      } else {
          [self.webViewController loadRequestWithURL:url
                                          parameters:params
                                            delegate:[self.webViewController delegate]];
      }
    }];
}

// @ 0xfd1c8
- (void)appliListWithCallBack:(RecommendAppliListCallback)callback {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:2];
    [params setValue:self.countryCode forKey:@"country_code"];
    [params setValue:@"ip" forKey:@"carrier"]; // per binary
    NSString *url =
        [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/adid/index.php"];
    [RecommendWebAPI requestAsynchronousWithURL:url
        method:@"GET"
        parameters:params
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // recommendCoreAppliListResponseHandler @ 0xfd36c
          NSDictionary *dict = (NSDictionary *)response;
          if ([[dict objectForKey:@"status"] boolValue] &&
              [[dict objectForKey:@"error_code"] intValue] == 100000000) {
              if (callback) {
                  callback([dict objectForKey:@"list"], nil);
              }
              return;
          }
          if (callback) {
              callback(nil, [self appliListErrorFromResponse:dict]);
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          // @ 0xfd614
          if (callback) {
              callback(nil, error);
          }
        }];
}

// @ 0xfd630
- (void)closeAppliList {
    if (self.webViewController != nil) {
        [self.webViewController appliListClosed];
    }
}

// @ 0xfd688
- (void)postApplicationInstallWithAdIdFrom:(NSString *)adIdFrom
                               countryCode:(NSString *)countryCode
                                categoryId:(NSString *)categoryId
                                    adType:(NSString *)adType
                                  callback:(RecommendOpenAppliListCallback)callback {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
    [params setValue:adIdFrom forKey:@"ad_id_from"];
    [params setValue:countryCode forKey:@"country_code"];
    [params setValue:categoryId forKey:@"category_id"];
    if (adType != nil) {
        [params setValue:adType forKey:@"ad_type"];
    }
    NSString *url =
        [[RecommendCore baseUrlSsl] stringByAppendingString:@"/ad/external/app/install/regist.php"];
    [RecommendWebAPI requestAsynchronousWithURL:url
        method:@"POST"
        parameters:params
        userInfo:nil
        tag:0
        cachePolicy:nil
        finishedBlock:^(id response, id userInfo) {
          // recommendCorePostResponseHandler @ 0xfd884
          NSDictionary *dict = (NSDictionary *)response;
          if ([[dict objectForKey:@"status"] boolValue] &&
              [[dict objectForKey:@"error_code"] intValue] == 100000000) {
              if (callback) {
                  callback(nil);
              }
              return;
          }
          if (callback) {
              callback([self appliListErrorFromResponse:dict]);
          }
        }
        failedBlock:^(NSURLRequest *request, NSError *error) {
          if (callback) {
              callback(error);
          }
        }];
}

// Shared error mapping used by both response handlers
// (recommendCoreAppliListResponseHandler / recommendCorePostResponseHandler):
// translate the server error_code/kind into a localized RewardNetworkError.
- (NSError *)appliListErrorFromResponse:(NSDictionary *)response {
    int code = [[response objectForKey:@"error_code"] intValue];
    if (code == 0xc106101) {
        return [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3f1 userInfo:response];
    }
    if (code == 999999999) {
        return [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3f0 userInfo:response];
    }
    NSString *kind = [response objectForKey:@"kind"];
    if ([kind isEqualToString:@"authorization"]) {
        return [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3ea userInfo:response];
    }
    if ([kind isEqualToString:@"parameter_error"]) {
        return [RewardNetworkError localizedRewardNetworkErrorWithCode:0x3e9 userInfo:response];
    }
    return [RewardNetworkError localizedRewardNetworkErrorWithCode:1000 userInfo:response];
}

// @ 0xfdb28
- (void)setParentView:(UIView *)parentView delegate:(id)delegate {
    if (self.webViewController == nil) {
        self.webViewController = [[RecommendWebViewController alloc] init];
    }
    if (parentView != nil) {
        [self.webViewController setParentView:parentView];
    }
    [self.webViewController setDelegate:delegate];
}

// @ 0xfdc1c
- (void)setNavigationBarHidden:(BOOL)hidden {
    navigationBarHidden = hidden;
}

// @ 0xfdc2c
- (BOOL)redirectWithRequest:(NSURLRequest *)request {
    NSURL *url = [request URL];
    NSString *scheme = [url scheme];
    NSString *host = [url host];
    NSInteger port = [[url port] intValue];
    NSString *query = [url query];
    if (scheme == nil) {
        return YES;
    }
    if (![scheme hasPrefix:@"applilink"] || host == nil) {
        return YES;
    }
    if (![host isEqualToString:@"ext-app"] || port != 80) {
        return YES;
    }
    // applilink://ext-app:80 — parse the query for a "default_scheme=" launch
    // and/or an {ad_id_from, country_code, category_id, ad_type} record to
    // persist.
    if (query != nil) {
        NSString *adIdFrom = nil;
        NSString *country = nil;
        NSString *category = nil;
        NSString *adType = nil;
        for (NSString *token in [query componentsSeparatedByString:@"&"]) {
            if (token == nil) {
                continue;
            }
            if ([token rangeOfString:@"default_scheme="].location != NSNotFound) {
                NSString *value =
                    [[token substringFromIndex:[@"default_scheme=" length]] URLDecodedString];
                NSURL *appURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", value]];
                if (appURL != nil && [[UIApplication sharedApplication] canOpenURL:appURL]) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                    [[UIApplication sharedApplication] openURL:appURL
                                                       options:@{}
                                             completionHandler:nil];
#else
                    [[UIApplication sharedApplication] openURL:appURL];
#endif
                    return NO;
                }
                break;
            } else if ([token rangeOfString:@"ad_id_from="].location != NSNotFound) {
                adIdFrom = [[token substringFromIndex:[@"ad_id_from=" length]] URLDecodedString];
            } else if ([token rangeOfString:@"country_code="].location != NSNotFound) {
                country = [[token substringFromIndex:[@"country_code=" length]] URLDecodedString];
            } else if ([token rangeOfString:@"category_id="].location != NSNotFound) {
                category = [[token substringFromIndex:[@"category_id=" length]] URLDecodedString];
            } else if ([token rangeOfString:@"ad_type="].location != NSNotFound) {
                adType = [[token substringFromIndex:[@"ad_type=" length]] URLDecodedString];
            }
        }
        if (adIdFrom != nil && country != nil && category != nil) {
            RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:country
                                                                  categoryId:category];
            NSError *error = nil;
            [adId setWithAdIdFrom:adIdFrom
                      countryCode:country
                       categoryId:category
                           adType:adType
                            error:&error];
        }
    }
    // Otherwise launch a scheme URL embedded directly in the
    // "applilink://ext-app:80/<url>" path.
    NSString *prefix = @"applilink://ext-app:80";
    NSString *absolute = [url absoluteString];
    NSString *remainder = nil;
    if ([absolute hasPrefix:prefix]) {
        remainder = [absolute substringFromIndex:[prefix length]];
        if ([query length] != 0) {
            NSString *querySuffix = [NSString stringWithFormat:@"?%@", query];
            if ([remainder hasSuffix:querySuffix]) {
                remainder =
                    [remainder substringToIndex:([remainder length] - [querySuffix length])];
            }
        }
    }
    if ([remainder length] != 0) {
        NSArray *parts = [[remainder substringFromIndex:1] componentsSeparatedByString:@"&"];
        if ([parts count] != 0) {
            NSString *value = [[parts objectAtIndex:0] URLDecodedString];
            NSURL *appURL = [NSURL URLWithString:value];
            if (appURL != nil && [[UIApplication sharedApplication] canOpenURL:appURL]) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                [[UIApplication sharedApplication] openURL:appURL
                                                   options:@{}
                                         completionHandler:nil];
#else
                [[UIApplication sharedApplication] openURL:appURL];
#endif
                return NO;
            }
        }
    }
    return YES;
}

// @ 0xfe4e4
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration {
    if (self.webViewController != nil) {
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        // -willAnimateRotationToInterfaceOrientation:duration: was deprecated in
        // iOS 8; it only forwarded to the controller's shared layout method using
        // the current status-bar orientation, so drive that method directly here.
        UIInterfaceOrientation currentOrientation =
            [[UIApplication sharedApplication] statusBarOrientation];
        [self.webViewController rotateWebViewWithInterfaceOrientation:currentOrientation
                                                             duration:duration];
#else
        [self.webViewController willAnimateRotationToInterfaceOrientation:orientation
                                                                 duration:duration];
#endif
    }
}

#pragma mark - RewardNetworkWebViewDelegate

// @ 0xfe56c
- (void)appListDidAppear {
}

// @ 0xfe570
- (void)appListDidDisappear {
    RecommendOpenAppliListCallback callback = [self callbackForOpenAppliList];
    if (callback != nil) {
        callback([self lastErrorForOpenAppliList]);
    }
    [self.webViewController setDelegate:nil];
}

// @ 0xfe610
- (void)appListFailLoadWithError:(NSError *)error {
    [self setLastErrorForOpenAppliList:error];
    [self.webViewController setDelegate:nil];
}

// callbackForOpenAppliList / categoryId / lastErrorForOpenAppliList /
// webViewController /
//   initializeFlg / countryCode accessors @ 0xfe660..0xfe770 — synthesized
//   (copy for the block, strong for the objects, assign for the int);
//   getCountryCode/getCategoryId/isInitialized above are thin public wrappers
//   over them.
// .cxx_destruct @ 0xfe798 — compiler-emitted ARC teardown for the object ivars;
// not hand-written.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
