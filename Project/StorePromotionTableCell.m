//
//  StorePromotionTableCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePromotionTableCell.h"

#import "StorePromotionView.h"   // the embedded tag-0x2775 banner laid out below (setImageViewSize:)

@implementation StorePromotionTableCell

// @ 0x738c4 — a plain UITableViewCell (the promotion content is set by the store VC
// on the reused cell); the initializer just chains to super.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    return [super initWithStyle:style reuseIdentifier:reuseIdentifier];
}

// setSelected:animated: @ 0x738f4 — super-only override, omitted.

// @ 0x73924 — keep the embedded promotion banner (a StorePromotionView added under tag
// 0x2775 by the store VC) filling the content view as the cell resizes, and tell it to
// resize its cross-fading image views to the cell's bounds.
- (void)layoutSubviews {
    [super layoutSubviews];
    StorePromotionView *promoView =
        (StorePromotionView *)[self.contentView viewWithTag:0x2775];
    if (promoView != nil) {
        [promoView setFrame:self.contentView.bounds];
        [promoView setImageViewSize:self.bounds.size];
    }
}

@end
