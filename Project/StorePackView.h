/**
 * @file
 * A single tappable song-pack tile shown in the store list.
 *
 * A framed jacket with a drop shadow, name, one-line comment, and price labels, a disabled
 * "purchased" button, and the new, arcade-viewer, and chara-ticket marker icons. A whole-tile tap
 * gesture plays a decide SE and notifies the delegate.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: initWithFrame: @ 0x51a44,
 * loadPackInfo:index: @ 0x5258c, isPurchased @ 0x52530, handleTap: @ 0x524c8, setArtwork: @
 * 0x524a8, setBgImage: @ 0x52488, setIsPurchased: @ 0x52560, and index @ 0x527a4.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackView;

// Implemented by the hosting controller (StoreMainViewController
// packViewSelected:
// @ 0x45318). Invoked via -respondsToSelector:/-performSelector:withObject:.
/**
 * Receives a pack tile's tap; the hosting controller implements it.
 */
@protocol StorePackViewDelegate <NSObject>
@optional
/**
 * The tile was tapped.
 * @param packView The tapped tile.
 */
- (void)packViewSelected:(StorePackView *)packView;
@end

/**
 * One pack tile in the store catalogue: the jacket, name, blurb, price and badges.
 */
@interface StorePackView : UIView {
    UIImageView *m_BackGroundImageView;   /**< The full-bounds background, carrying the tap
                                             gesture. */
    UIImageView *m_ArtworkImageView;      /**< The framed, shadowed jacket at (15, 15, 110, 110). */
    UILabel *m_NameLabel;                 /**< The pack name. */
    UILabel *m_CommentLabel;              /**< The one-line blurb, from StorePackInfo.s_comment. */
    UILabel *m_PriceLabel;                /**< The localised price. */
    UIButton *m_PurchasedButton;          /**< The disabled "purchased" pill. */
    UIImageView *m_NewMarker;             /**< The "store_new" badge. */
    UIImageView *m_ArcadeViewerImageView; /**< The "store_arcade_view_ic" badge. */
    UIImageView *m_TicketImageView;       /**< The "store_chara_ic" badge. */
    unsigned int m_Index;                 /**< The row index passed back on selection. */
    /** The tap delegate, the list controller; a plain assign. */
    id<StorePackViewDelegate> __unsafe_unretained m_Delegate;
}

/** The tap delegate. */
@property(nonatomic, assign) id<StorePackViewDelegate> delegate;
/** The row index passed back on selection. */
@property(nonatomic, readonly) unsigned int index;

/**
 * Bind a pack model to the tile and record its list index.
 * @param packInfo The pack to show.
 * @param index The row index to pass back on selection.
 */
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(unsigned int)index;

/**
 * Replace the jacket artwork.
 * @param artwork The new image.
 */
- (void)setArtwork:(UIImage *)artwork;

/**
 * Replace the tile's background image.
 * @param image The new image.
 */
- (void)setBgImage:(UIImage *)image;

/**
 * Whether the "purchased" button is visible.
 * @return YES when the pack is shown as purchased.
 */
- (BOOL)isPurchased;

/**
 * Show or hide the "purchased" button, which is the source of truth for -isPurchased.
 * @param purchased YES to show the button.
 */
- (void)setIsPurchased:(BOOL)purchased;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
