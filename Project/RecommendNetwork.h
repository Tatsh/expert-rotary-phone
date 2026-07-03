//
//  RecommendNetwork.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the public facade the game talks to. A singleton whose
//  designated initialiser runs [super init] on the shared "RewardNetwork" serial dispatch queue
//  (so instance creation is serialised against the rest of the SDK's networking) and whose
//  methods thinly forward to the RecommendCore singleton or drive a RecommendWebView directly.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass (NSObject) and the
//  int `_initializeFlg` ivar come from the Objective-C class_t metadata.
//    +sharedInstance @ 0xebbb4   +allocWithZone: @ 0xebc44   init @ 0xeba74
//    startWithCountryCode:categoryId:env:callback: @ 0xebd24
//    openAppliListWithCallback: @ 0xebdbc   openAppliListWithParentView:delegate: @ 0xebe4c
//    openAppliListWithParentView:callback: @ 0xebf24   closeAppliList @ 0xec000
//    openRecommendPageWithCreateWebViewRect:parent:viewType:callback: @ 0xec044
//    closeRecommendPageWithParentView: @ 0xec170
//    setRecommendPageVisibleWithParentView:flag: @ 0xec2dc
//    rotateAppliListWithInterfaceOrientation:duration: @ 0xec460
//    initializeFlg @ 0xec4b4   setInitializeFlg: @ 0xec4c4
//

#import <Foundation/Foundation.h>

#import "RecommendCore.h"       // RecommendCore singleton + RecommendOpenAppliListCallback
#import "RecommendWebView.h"    // RecommendWebView + RecommendWebViewOpenAppliListCallback

@interface RecommendNetwork : NSObject

// Backed by the int `_initializeFlg` ivar; cleared to 0 when the shared instance is allocated.
@property (nonatomic, assign) int initializeFlg;

// @ 0xebbb4 — the process-wide shared RecommendNetwork facade.
+ (instancetype)sharedInstance;

// @ 0xebc44 — allocate the singleton: create the "RewardNetwork" serial queue and, on the first
// call, allocate the shared instance via [super allocWithZone:] and clear its initializeFlg.
+ (id)allocWithZone:(NSZone *)zone;

// @ 0xebd24 — forward to [RecommendCore sharedInstance]: record country/category/env and start.
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback;

// @ 0xebdbc — show the modal app list with the navigation bar visible.
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback;

// @ 0xebe4c — host the app list inside parentView (nav bar hidden when embedded), no callback.
- (void)openAppliListWithParentView:(UIView *)parentView delegate:(id)delegate;

// @ 0xebf24 — host the app list inside parentView (nav bar hidden when embedded) with callback.
- (void)openAppliListWithParentView:(UIView *)parentView
                           callback:(RecommendOpenAppliListCallback)callback;

// @ 0xec000 — dismiss the modal app list.
- (void)closeAppliList;

// @ 0xec044 — create a RecommendWebView with the given frame/viewType, add it to parent (or the
// key window when parent is nil) and load the recommend page.
- (void)openRecommendPageWithCreateWebViewRect:(CGRect)rect
                                        parent:(UIView *)parent
                                      viewType:(int)viewType
                                      callback:(RecommendWebViewOpenAppliListCallback)callback;

// @ 0xec170 — remove every RecommendWebView from parentView (or the key window when nil).
- (void)closeRecommendPageWithParentView:(UIView *)parentView;

// @ 0xec2dc — hide/show every RecommendWebView under parentView (or the key window when nil).
- (void)setRecommendPageVisibleWithParentView:(UIView *)parentView flag:(BOOL)flag;

// @ 0xec460 — forward a rotation to the hosted app-list controller.
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
