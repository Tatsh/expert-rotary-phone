//
//  RecommendCore.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the SDK core / facade. A shared singleton that:
//    * remembers the caller's country code, category id and environment,
//    * on first start posts a one-shot "application install" record (advertising-id backed),
//    * presents the recommend app list in a RecommendWebViewController, and
//    * intercepts applilink://ext-app:80/... redirects to launch installed companion apps.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass (NSObject) and the
//  ivars (navigationBarHidden:BOOL, _callbackForOpenAppliList:block, _categoryId:NSString*,
//  _lastErrorForOpenAppliList:NSError*, _webViewController:RecommendWebViewController*,
//  _initializeFlg:int, _countryCode:NSString*) come from the Objective-C class_t metadata.
//    +sharedInstance @ 0xfc47c   init @ 0xfc33c   +baseUrlSsl @ 0xfc50c
//    getCountryCode @ 0xfc628   getCategoryId @ 0xfc638   isInitialized @ 0xfc648
//    isInstalledAppliWithScheme: @ 0xfc664   startWithCountryCode:categoryId:env:callback: @ 0xfc734
//    openAppliListWithCallback: @ 0xfcc0c   appliListWithCallBack: @ 0xfd1c8
//    closeAppliList @ 0xfd630   postApplicationInstallWithAdIdFrom:... @ 0xfd688
//    setParentView:delegate: @ 0xfdb28   setNavigationBarHidden: @ 0xfdc1c
//    redirectWithRequest: @ 0xfdc2c   rotateAppliListWithInterfaceOrientation:duration: @ 0xfe4e4
//    appListDidAppear @ 0xfe56c   appListDidDisappear @ 0xfe570   appListFailLoadWithError: @ 0xfe610
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Completion for a modal open-app-list / install request: fired with the error (or nil).
typedef void (^RecommendOpenAppliListCallback)(NSError *error);

// Completion for the raw app-list fetch: the app-list payload plus an error (either may be nil).
typedef void (^RecommendAppliListCallback)(NSArray *appliList, NSError *error);

@interface RecommendCore : NSObject

// @ 0xfc47c — the process-wide shared core.
+ (instancetype)sharedInstance;

// @ 0xfc50c — the SSL base URL for the current "ApplilinkRecommend.env" environment.
+ (NSString *)baseUrlSsl;

// @ 0xfc628 / 0xfc638 — the stored country code / category id.
- (NSString *)getCountryCode;
- (NSString *)getCategoryId;

// @ 0xfc648 — YES once -startWithCountryCode:... has completed initialisation.
- (BOOL)isInitialized;

// @ 0xfc664 — YES if an app that answers `scheme://` is installed.
- (BOOL)isInstalledAppliWithScheme:(NSString *)scheme;

// @ 0xfc734 — record the country/category/env and, on first launch, post the install record.
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback;

// @ 0xfcc0c — present the modal recommend app list.
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback;

// @ 0xfd1c8 — fetch the raw app list (GET /ad/external/adid/index.php) and deliver it.
- (void)appliListWithCallBack:(RecommendAppliListCallback)callback;

// @ 0xfd630 — dismiss the modal recommend app list.
- (void)closeAppliList;

// @ 0xfdb28 — lazily create the web-view controller and attach a parent view / delegate.
- (void)setParentView:(UIView *)parentView delegate:(id)delegate;

// @ 0xfdc1c — hide/show the app-list navigation bar.
- (void)setNavigationBarHidden:(BOOL)hidden;

// @ 0xfdc2c — handle an applilink://ext-app:80/... redirect. Returns NO if it consumed the
// request (launched a companion app), YES to let the web view proceed.
- (BOOL)redirectWithRequest:(NSURLRequest *)request;

// @ 0xfe4e4 — forward a rotation to the hosted app-list controller.
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
