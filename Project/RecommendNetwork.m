//
//  RecommendNetwork.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RecommendNetwork.h"

// Module globals owned by RecommendNetwork's shared-instance machinery. The
// serial "RewardNetwork" queue is created in +allocWithZone:'s dispatch_once
// body (Ghidra recommendNetworkSharedAlloc @ 0xebcac), which also allocates the
// singleton via [super allocWithZone:] and zeroes its initializeFlg. -init
// below dispatches onto the queue that path produces.
static dispatch_queue_t g_pRewardNetworkQueue = NULL;       // @ g_pRewardNetworkQueue
static RecommendNetwork *g_pRecommendNetworkInstance = nil; // @ g_pRecommendNetworkInstance

@implementation RecommendNetwork {
    int _initializeFlg;
}

// @ 0xebbb4 — return the process-wide shared instance, creating it once via
// [[self alloc] init] (the dispatch_once body @ 0xebbe8 stores the result into
// g_pRecommendNetworkInstance).
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken; // @ g_dwRecommendNetworkOnceToken
    dispatch_once(&onceToken, ^{
      g_pRecommendNetworkInstance = [[self alloc] init];
    });
    return g_pRecommendNetworkInstance;
}

// @ 0xebc44 — singleton allocator. Its dispatch_once body
// (recommendNetworkSharedAlloc @ 0xebcac) creates the shared "RewardNetwork"
// serial queue and, if the instance has not yet been made, allocates it through
// [super allocWithZone:] and clears its initializeFlg. Always returns the one
// shared instance.
+ (id)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken; // @ DAT_0018832c
    dispatch_once(&onceToken, ^{
      g_pRewardNetworkQueue = dispatch_queue_create("RewardNetwork", NULL);
      if (g_pRecommendNetworkInstance == nil) {
          g_pRecommendNetworkInstance = [super allocWithZone:zone];
          [g_pRecommendNetworkInstance setInitializeFlg:0];
      }
    });
    return g_pRecommendNetworkInstance;
}

// @ 0xeba74 — perform [super init] on the shared RewardNetwork serial queue and
// return the resulting instance. The captured self is retained for the block
// and released afterwards (handled automatically under ARC); the block stores
// its [super init] result into the
// __block variable that is then handed back.
- (instancetype)init {
    __block RecommendNetwork *result = nil;
    dispatch_sync(g_pRewardNetworkQueue, ^{
      // @ 0xebb3c — the block body just performs [super init].
      result = [super init];
    });
    return result;
}

// @ 0xec4b4
- (int)initializeFlg {
    return _initializeFlg;
}

// @ 0xec4c4
- (void)setInitializeFlg:(int)initializeFlg {
    _initializeFlg = initializeFlg;
}

// @ 0xebd24
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback {
    [[RecommendCore sharedInstance] startWithCountryCode:countryCode
                                              categoryId:categoryId
                                                     env:env
                                                callback:callback];
}

// @ 0xebdbc — show the navigation bar, then present the modal app list.
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback {
    [[RecommendCore sharedInstance] setNavigationBarHidden:NO];
    [[RecommendCore sharedInstance] openAppliListWithCallback:callback];
}

// @ 0xebe4c — embed the app list in parentView (hiding the nav bar when a
// parent is supplied).
- (void)openAppliListWithParentView:(UIView *)parentView delegate:(id)delegate {
    [[RecommendCore sharedInstance] setNavigationBarHidden:(parentView != nil)];
    [[RecommendCore sharedInstance] setParentView:parentView delegate:delegate];
    [[RecommendCore sharedInstance] openAppliListWithCallback:nil];
}

// @ 0xebf24 — embed the app list in parentView (hiding the nav bar when a
// parent is supplied), firing callback on completion.
- (void)openAppliListWithParentView:(UIView *)parentView
                           callback:(RecommendOpenAppliListCallback)callback {
    if (parentView == nil) {
        [[RecommendCore sharedInstance] setNavigationBarHidden:NO];
    } else {
        [[RecommendCore sharedInstance] setNavigationBarHidden:YES];
        [[RecommendCore sharedInstance] setParentView:parentView delegate:nil];
    }
    [[RecommendCore sharedInstance] openAppliListWithCallback:callback];
}

// @ 0xec000
- (void)closeAppliList {
    [[RecommendCore sharedInstance] closeAppliList];
}

// @ 0xec044
- (void)openRecommendPageWithCreateWebViewRect:(CGRect)rect
                                        parent:(UIView *)parent
                                      viewType:(int)viewType
                                      callback:(RecommendWebViewOpenAppliListCallback)callback {
    RecommendWebView *webView = [[RecommendWebView alloc] init];
    [webView setFrame:rect];
    [webView setScrollEnabled:NO];
    [webView setViewType:viewType];
    if (parent == nil) {
        parent = [[UIApplication sharedApplication] keyWindow];
    }
    [parent addSubview:webView];
    [webView loadRequestWithCallback:callback];
}

// @ 0xec170 — remove every RecommendWebView hosted under parentView (or the key
// window).
- (void)closeRecommendPageWithParentView:(UIView *)parentView {
    UIView *host = parentView;
    if (host == nil) {
        host = [[UIApplication sharedApplication] keyWindow];
    }
    for (UIView *subview in host.subviews) {
        if ([subview isKindOfClass:[RecommendWebView class]]) {
            [subview removeFromSuperview];
        }
    }
}

// @ 0xec2dc — hide/show every RecommendWebView hosted under parentView (or the
// key window).
- (void)setRecommendPageVisibleWithParentView:(UIView *)parentView flag:(BOOL)flag {
    UIView *host = parentView;
    if (host == nil) {
        host = [[UIApplication sharedApplication] keyWindow];
    }
    for (UIView *subview in host.subviews) {
        if ([subview isKindOfClass:[RecommendWebView class]]) {
            [subview setHidden:!flag];
        }
    }
}

// @ 0xec460
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration {
    [[RecommendCore sharedInstance] rotateAppliListWithInterfaceOrientation:orientation
                                                                   duration:duration];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
