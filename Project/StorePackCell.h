/**
 * @file
 * A store song-pack row.
 *
 * Jacket artwork with a drop shadow, pack name, price, and "purchased" labels, and the new,
 * arcade-viewer, and chara-ticket marker icons. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x6ed4c, loadPackInfo: @ 0x6f604, setBgImage: @
 * 0x6f7b4, isPurchased @ 0x6f5a8 with setIsPurchased: @ 0x6f5d8).
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

/**
 * One pack row of the store catalogue table.
 */
@interface StorePackCell : UITableViewCell

/** The row background. */
@property(nonatomic, retain) UIImageView *bgView;
/** The pack jacket. Getter @ 0x6f8b0. */
@property(nonatomic, retain) UIImageView *artworkView;
/** The pack name. */
@property(nonatomic, retain) UILabel *labelName;
/** The localised price. */
@property(nonatomic, retain) UILabel *labelPrice;
/** The "purchased" label, whose visibility backs isPurchased. */
@property(nonatomic, retain) UILabel *labelPurchased;
/** The "new" badge. */
@property(nonatomic, retain) UIImageView *newMarker;
/**
 * The "new" badge.
 *
 * The name begins with the ARC `new` method family, which would imply a +1 owned getter, so the
 * getter opts out — matching the objc_method_family(none) convention in AVBus.h.
 * @return The badge image view.
 */
- (UIImageView *)newMarker __attribute__((objc_method_family(none)));
/** The arcade-availability badge. */
@property(nonatomic, retain) UIImageView *arcadeViewer;
/** The character-ticket badge. */
@property(nonatomic, retain) UIImageView *charaTicket;

/** Whether the pack is shown as purchased; backed by the "purchased" label's visibility. */
@property(nonatomic) BOOL isPurchased;

/**
 * Bind a pack model: the name, price, badges and the live purchased state.
 * @param packInfo The pack to show.
 */
- (void)loadPackInfo:(StorePackInfo *)packInfo;

/**
 * Replace the row's background image.
 * @param image The new image.
 */
- (void)setBgImage:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
