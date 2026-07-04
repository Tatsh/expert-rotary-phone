//
//  StorePackCell.h
//  pop'n rhythmin
//
//  A store song-pack row: jacket artwork (with a drop shadow), pack name + price +
//  "purchased" labels, and new / arcade-viewer / chara-ticket marker icons.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:reuseIdentifier: @ 0x6ed4c   loadPackInfo: @ 0x6f604
//    setBgImage: @ 0x6f7b4   isPurchased @ 0x6f5a8 / setIsPurchased: @ 0x6f5d8
//

#import <UIKit/UIKit.h>

@class StorePackInfo;

@interface StorePackCell : UITableViewCell

@property (nonatomic, retain) UIImageView *bgView;
@property (nonatomic, retain) UIImageView *artworkView;   // getter @ 0x6f8b0
@property (nonatomic, retain) UILabel *labelName;
@property (nonatomic, retain) UILabel *labelPrice;
@property (nonatomic, retain) UILabel *labelPurchased;
@property (nonatomic, retain) UIImageView *newMarker;
// 'newMarker' begins with the ARC 'new' method family (would imply a +1 owned getter);
// opt the getter out, matching the objc_method_family(none) convention in AVBus.h.
- (UIImageView *)newMarker __attribute__((objc_method_family(none)));
@property (nonatomic, retain) UIImageView *arcadeViewer;
@property (nonatomic, retain) UIImageView *charaTicket;

// Purchased state, backed by the "purchased" label's visibility.
@property (nonatomic) BOOL isPurchased;

// Bind a pack model: name / price / markers and the live purchased state.
- (void)loadPackInfo:(StorePackInfo *)packInfo;

// Replace the row's background image.
- (void)setBgImage:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
