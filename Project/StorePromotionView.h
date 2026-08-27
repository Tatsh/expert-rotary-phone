//
//  StorePromotionView.h
//  pop'n rhythmin
//
//  The store's promotion banner: a cross-fading image carousel. It downloads a
//  set of promo images (one ImageDownloader each), then rotates through them on
//  a timer with a fade transition. Tapping it reports the current promo's pack
//  id to the delegate so the store can jump to that pack.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithFrame: @ 0x79900   SetupView @ 0x79c2c   setImageViewSize: @
//    0x79f28 setImageURLs: @ 0x7a008    setImage:Index: @ 0x7a4b4
//    imageDownloader:didLoad: @ 0x7a230 setNext @ 0x7a2e4  nextShowEnd @
//    0x7a454  startAnimation @ 0x7a628 stopAnimation @ 0x7a6ac  getImageCount @
//    0x7a2c4  getPackID @ 0x79f84 handleTapPromotionView: @ 0x7a6dc  cancel @
//    0x79af8  dealloc @ 0x79994
//

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

@class StorePromotionView;

/**
 * @brief Receives the promotion banner's tap.
 */
@protocol StorePromotionViewDelegate <NSObject>
/**
 * @brief The banner was tapped.
 * @param view The banner.
 * @param packID The pack the visible promo advertises.
 */
- (void)storePromotionViewTaped:(StorePromotionView *)view PackID:(int)packID;
@end

/**
 * @brief The store's promotion banner: a cross-fading rotation of promo images.
 */
@interface StorePromotionView : UIView <ImageDownloaderDelegate> {
    UIActivityIndicatorView *m_Indicator; /**< Shown until the first image loads. */
    UIImageView *m_FrontImageView;        /**< The currently visible promo. */
    UIImageView *m_NextImageView;         /**< Fades in on top during a transition. */
    /** The promo records: dictionaries of ID, ImageURL and image. */
    NSMutableArray *m_PromotionDataArray;
    int m_Index;                       /**< The current promo index; -1 before the first. */
    NSMutableArray *m_ImageDownloader; /**< The in-flight ImageDownloaders. */
    NSTimer *m_Timer;                  /**< The 2.5-second rotation timer. */
    __weak id<StorePromotionViewDelegate> m_Delegate; /**< The tap delegate. */
}

/** The tap delegate. */
@property(nonatomic, weak) id<StorePromotionViewDelegate> delegate;

// Recovered accessors and controls, implemented in the .mm and read by StoreMainViewController.

/**
 * @brief How many promo images are loaded.
 * @return The image count.
 * @ghidraAddress 0x7a2c4
 */
- (int)getImageCount;
/**
 * @brief Stop the rotation timer.
 * @ghidraAddress 0x7a6ac
 */
- (void)stopAnimation;
/**
 * @brief The currently-shown promo's pack id.
 * @return The pack id.
 * @ghidraAddress 0x79f84
 */
- (int)getPackID;

/**
 * @brief Resize both banner image views.
 * @param size The new size.
 */
- (void)setImageViewSize:(CGSize)size;
/**
 * @brief Begin loading the promo images.
 * @param promotionData An array of dictionaries carrying ID and ImageURL.
 */
- (void)setImageURLs:(NSArray *)promotionData;
/**
 * @brief Stop the timers and cancel every in-flight download.
 */
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
