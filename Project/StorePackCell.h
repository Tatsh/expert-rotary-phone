//
//  StorePackCell.h
//  pop'n rhythmin
//
//  A store song-pack row: jacket artwork (with a drop shadow), pack name + price +
//  "purchased" labels, and new / arcade-viewer / chara-ticket marker icons.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x6ed4c).
//

#import <UIKit/UIKit.h>

@interface StorePackCell : UITableViewCell

@property (nonatomic, retain) UIImageView *bgView;
@property (nonatomic, retain) UIImageView *artworkView;
@property (nonatomic, retain) UILabel *labelName;
@property (nonatomic, retain) UILabel *labelPrice;
@property (nonatomic, retain) UILabel *labelPurchased;
@property (nonatomic, retain) UIImageView *newMarker;
@property (nonatomic, retain) UIImageView *arcadeViewer;
@property (nonatomic, retain) UIImageView *charaTicket;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
