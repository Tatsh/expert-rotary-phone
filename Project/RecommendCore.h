/**
 * @file
 * @brief The Konami "Applilink" Recommend ad SDK's core facade.
 *
 * A shared singleton that remembers the caller's country code, category id, and environment; on
 * first start posts a one-shot, advertising-id backed "application install" record; presents the
 * recommend app list in a RecommendWebViewController; and intercepts applilink://ext-app:80/...
 * redirects to launch installed companion apps.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The superclass (NSObject) and the
 * ivars (navigationBarHidden as BOOL, _callbackForOpenAppliList as a block, _categoryId as
 * NSString *, _lastErrorForOpenAppliList as NSError *, _webViewController as
 * RecommendWebViewController *, _initializeFlg as int, and _countryCode as NSString *) come from
 * the Objective-C class_t metadata: +sharedInstance @ 0xfc47c, init @ 0xfc33c, +baseUrlSsl @
 * 0xfc50c, getCountryCode @ 0xfc628, getCategoryId @ 0xfc638, isInitialized @ 0xfc648,
 * isInstalledAppliWithScheme: @ 0xfc664, startWithCountryCode:categoryId:env:callback: @ 0xfc734,
 * openAppliListWithCallback: @ 0xfcc0c, appliListWithCallBack: @ 0xfd1c8, closeAppliList @
 * 0xfd630, postApplicationInstallWithAdIdFrom:... @ 0xfd688, setParentView:delegate: @ 0xfdb28,
 * setNavigationBarHidden: @ 0xfdc1c, redirectWithRequest: @ 0xfdc2c,
 * rotateAppliListWithInterfaceOrientation:duration: @ 0xfe4e4, appListDidAppear @ 0xfe56c,
 * appListDidDisappear @ 0xfe570, and appListFailLoadWithError: @ 0xfe610.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * @brief The completion for a modal open-app-list or install request.
 * @param error What went wrong, or nil on success.
 */
typedef void (^RecommendOpenAppliListCallback)(NSError *error);

/**
 * @brief The completion for the raw app-list fetch.
 * @param appliList The app-list payload, or nil on failure.
 * @param error What went wrong, or nil on success.
 */
typedef void (^RecommendAppliListCallback)(NSArray *appliList, NSError *error);

/**
 * @brief The Applilink recommend core: the app-list fetch, the modal list and the install record.
 */
@interface RecommendCore : NSObject

/**
 * @brief The process-wide shared core.
 * @return The singleton.
 * @ghidraAddress 0xfc47c
 */
+ (instancetype)sharedInstance;

/**
 * @brief The SSL base URL for the current "ApplilinkRecommend.env" environment.
 * @return The base URL.
 * @ghidraAddress 0xfc50c
 */
+ (NSString *)baseUrlSsl;

/**
 * @brief The stored country code.
 * @return The country code.
 * @ghidraAddress 0xfc628
 */
- (NSString *)getCountryCode;
/**
 * @brief The stored category id.
 * @return The category id.
 * @ghidraAddress 0xfc638
 */
- (NSString *)getCategoryId;

/**
 * @brief Whether -startWithCountryCode:categoryId:env:callback: has completed initialisation.
 * @return YES once initialised.
 * @ghidraAddress 0xfc648
 */
- (BOOL)isInitialized;

/**
 * @brief Whether an app answering a URL scheme is installed.
 * @param scheme The scheme to probe, without the "://".
 * @return YES when such an app is installed.
 * @ghidraAddress 0xfc664
 */
- (BOOL)isInstalledAppliWithScheme:(NSString *)scheme;

/**
 * @brief Record the country, category and environment and, on first launch, post the install
 * record.
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @param env The environment name.
 * @param callback Fired when initialisation finishes.
 * @ghidraAddress 0xfc734
 */
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback;

/**
 * @brief Present the modal recommend app list.
 * @param callback Fired when the list is dismissed.
 * @ghidraAddress 0xfcc0c
 */
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback;

/**
 * @brief Fetch the raw app list via GET /ad/external/adid/index.php and deliver it.
 * @param callback Fired with the payload or the error.
 * @ghidraAddress 0xfd1c8
 */
- (void)appliListWithCallBack:(RecommendAppliListCallback)callback;

/**
 * @brief Dismiss the modal recommend app list.
 * @ghidraAddress 0xfd630
 */
- (void)closeAppliList;

/**
 * @brief Lazily create the web-view controller and attach a parent view and delegate.
 * @param parentView The host view.
 * @param delegate The controller delegate.
 * @ghidraAddress 0xfdb28
 */
- (void)setParentView:(UIView *)parentView delegate:(id)delegate;

/**
 * @brief Hide or show the app-list navigation bar.
 * @param hidden YES to hide the bar.
 * @ghidraAddress 0xfdc1c
 */
- (void)setNavigationBarHidden:(BOOL)hidden;

/**
 * @brief Handle an `applilink://ext-app:80/...` redirect.
 * @param request The request the web view is about to load.
 * @return NO when the redirect was consumed by launching a companion app, YES to let the web view
 * proceed.
 * @ghidraAddress 0xfdc2c
 */
- (BOOL)redirectWithRequest:(NSURLRequest *)request;

/**
 * @brief Forward a rotation to the hosted app-list controller.
 * @param orientation The new interface orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0xfe4e4
 */
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
