//
//  StoreTableCell.h
//  pop'n rhythmin
//
//  A store list row that shows two song packs side by side. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x527b4).
//

#import <UIKit/UIKit.h>

@class StorePackView;

@interface StoreTableCell : UITableViewCell

@property (nonatomic, retain) StorePackView *leftPackView;   // synthesized getter @ 0x529e4
@property (nonatomic, retain) StorePackView *rightPackView;  // synthesized getter @ 0x529f4

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
