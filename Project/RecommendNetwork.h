//
//  RecommendNetwork.h
//  pop'n rhythmin
//
//  Konami "Applilink" Recommend ad SDK — the public facade the game talks to. A
//  singleton whose designated initialiser runs [super init] on the shared
//  "RewardNetwork" serial dispatch queue (so instance creation is serialised
//  against the rest of the SDK's networking) and whose methods thinly forward
//  to the RecommendCore singleton or drive a RecommendWebView directly.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Superclass
//  (NSObject) and the int `_initializeFlg` ivar come from the Objective-C
//  class_t metadata.
//    +sharedInstance @ 0xebbb4   +allocWithZone: @ 0xebc44   init @ 0xeba74
//    startWithCountryCode:categoryId:env:callback: @ 0xebd24
//    openAppliListWithCallback: @ 0xebdbc openAppliListWithParentView:delegate:
//    @ 0xebe4c openAppliListWithParentView:callback: @ 0xebf24   closeAppliList
//    @ 0xec000 openRecommendPageWithCreateWebViewRect:parent:viewType:callback:
//    @ 0xec044 closeRecommendPageWithParentView: @ 0xec170
//    setRecommendPageVisibleWithParentView:flag: @ 0xec2dc
//    rotateAppliListWithInterfaceOrientation:duration: @ 0xec460
//    initializeFlg @ 0xec4b4   setInitializeFlg: @ 0xec4c4
//

#import <Foundation/Foundation.h>

#import "RecommendCore.h"    // RecommendCore singleton + RecommendOpenAppliListCallback
#import "RecommendWebView.h" // RecommendWebView + RecommendWebViewOpenAppliListCallback

/**
 * @brief The public facade over RecommendCore and RecommendWebView.
 */
@interface RecommendNetwork : NSObject

/** Backed by the int `_initializeFlg` ivar; cleared to 0 when the shared instance is allocated. */
@property(nonatomic, assign) int initializeFlg;

/**
 * @brief The process-wide shared facade.
 * @return The singleton.
 * @ghidraAddress 0xebbb4
 */
+ (instancetype)sharedInstance;

/**
 * @brief Allocate the singleton: create the "RewardNetwork" serial queue and, on the first call,
 * allocate the shared instance via [super allocWithZone:] and clear its initializeFlg.
 * @param zone The zone to allocate in.
 * @return The shared instance.
 * @ghidraAddress 0xebc44
 */
+ (id)allocWithZone:(NSZone *)zone;

/**
 * @brief Record the country, category and environment and start, by forwarding to
 * [RecommendCore sharedInstance].
 * @param countryCode The country code.
 * @param categoryId The category id.
 * @param env The environment name.
 * @param callback Fired when initialisation finishes.
 * @ghidraAddress 0xebd24
 */
- (void)startWithCountryCode:(NSString *)countryCode
                  categoryId:(NSString *)categoryId
                         env:(NSString *)env
                    callback:(RecommendOpenAppliListCallback)callback;

/**
 * @brief Show the modal app list with the navigation bar visible.
 * @param callback Fired when the list is dismissed.
 * @ghidraAddress 0xebdbc
 */
- (void)openAppliListWithCallback:(RecommendOpenAppliListCallback)callback;

/**
 * @brief Host the app list inside a parent view, with the navigation bar hidden while embedded.
 * @param parentView The host view.
 * @param delegate The controller delegate.
 * @ghidraAddress 0xebe4c
 */
- (void)openAppliListWithParentView:(UIView *)parentView delegate:(id)delegate;

/**
 * @brief Host the app list inside a parent view, with the navigation bar hidden while embedded,
 * and report completion.
 * @param parentView The host view.
 * @param callback Fired when the list is dismissed.
 * @ghidraAddress 0xebf24
 */
- (void)openAppliListWithParentView:(UIView *)parentView
                           callback:(RecommendOpenAppliListCallback)callback;

/**
 * @brief Dismiss the modal app list.
 * @ghidraAddress 0xec000
 */
- (void)closeAppliList;

/**
 * @brief Create a RecommendWebView, add it to a parent, and load the recommend page.
 * @param rect The web view's frame.
 * @param parent The host view, or nil to use the key window.
 * @param viewType The ad layout: 0..3.
 * @param callback Fired with the load error, or nil.
 * @ghidraAddress 0xec044
 */
- (void)openRecommendPageWithCreateWebViewRect:(CGRect)rect
                                        parent:(UIView *)parent
                                      viewType:(int)viewType
                                      callback:(RecommendWebViewOpenAppliListCallback)callback;

/**
 * @brief Remove every RecommendWebView from a parent view.
 * @param parentView The host view, or nil to use the key window.
 * @ghidraAddress 0xec170
 */
- (void)closeRecommendPageWithParentView:(UIView *)parentView;

/**
 * @brief Hide or show every RecommendWebView under a parent view.
 * @param parentView The host view, or nil to use the key window.
 * @param flag YES to show the views, NO to hide them.
 * @ghidraAddress 0xec2dc
 */
- (void)setRecommendPageVisibleWithParentView:(UIView *)parentView flag:(BOOL)flag;

/**
 * @brief Forward a rotation to the hosted app-list controller.
 * @param orientation The new interface orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0xec460
 */
- (void)rotateAppliListWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                       duration:(NSTimeInterval)duration;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
