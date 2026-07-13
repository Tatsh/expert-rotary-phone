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

#import "ImageDownloader.h"
#import <UIKit/UIKit.h>

@class StorePromotionView;

@protocol StorePromotionViewDelegate <NSObject>
- (void)storePromotionViewTaped:(StorePromotionView *)view PackID:(int)packID;
@end

@interface StorePromotionView : UIView <ImageDownloaderDelegate> {
    UIActivityIndicatorView *m_Indicator; // shown until the first image loads
    UIImageView *m_FrontImageView;        // currently visible promo
    UIImageView *m_NextImageView;         // fades in on top during a transition
    NSMutableArray *m_PromotionDataArray; // dicts { ID, ImageURL, image }
    int m_Index;                          // current promo index (-1 = none yet)
    NSMutableArray *m_ImageDownloader;    // in-flight ImageDownloaders
    NSTimer *m_Timer;                     // 2.5s rotation timer
    __weak id<StorePromotionViewDelegate> m_Delegate;
}

@property(nonatomic, weak) id<StorePromotionViewDelegate> delegate;

// Recovered accessors/controls (impls in .mm; read by StoreMainViewController).
- (int)getImageCount;  // @ 0x7a2c4
- (void)stopAnimation; // @ 0x7a6ac — stop the rotation timer
- (int)getPackID;      // @ 0x79f84 — the currently-shown promo's pack id

// Resize both banner image views.
- (void)setImageViewSize:(CGSize)size;
// Begin loading the promo images described by an array of { ID, ImageURL }
// dicts.
- (void)setImageURLs:(NSArray *)promotionData;
// Stop timers and cancel in-flight downloads.
- (void)cancel;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
