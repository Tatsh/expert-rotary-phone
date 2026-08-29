/**
 * @file
 * @brief The table header of the iPhone StoreDetailViewController.
 *
 * It carries the pack jacket, name, copyright, and the buy or "INSTALLED" button. Reconstructed
 * from Ghidra project rb420, program PopnRhythmin (initWithFrame: @ 0x73a0c, loadPackInfo: @
 * 0x740d4, setArtwork: @ 0x74400, buttonPurchase @ 0x74564). The view build lives in
 * StoreDetailHeaderView.m.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

/**
 * @brief The pack-detail table header: the jacket, name, description and buy button.
 */
@interface StoreDetailHeaderView : UIView

/**
 * @brief The buy or "INSTALLED" button; the detail controller titles it and wires it to
 * -onPurchaseButton:.
 * @return The button.
 */
- (UIButton *)buttonPurchase;

/**
 * @brief The pack-name label.
 * @return The label.
 * @ghidraAddress 0x74544
 */
- (UILabel *)labelName;
/**
 * @brief The pack-description label.
 * @return The label.
 * @ghidraAddress 0x74554
 */
- (UILabel *)labelComment;

/**
 * @brief Fill the header — the jacket, name and copyright — from a pack.
 * @param packInfo The pack to show.
 * @ghidraAddress 0x718b8
 */
- (void)loadPackInfo:(StorePackInfo *)packInfo;

/**
 * @brief Set the pack jacket once its asynchronous download completes.
 * @param image The downloaded jacket.
 */
- (void)setArtwork:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
