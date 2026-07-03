//
//  StoreDetailHeaderView.h
//  pop'n rhythmin
//
//  The table header of the iPhone StoreDetailViewController: the pack jacket, name, copyright
//  and the buy / "INSTALLED" button. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithFrame: @ 0x73a0c, loadPackInfo: @ 0x740d4, setArtwork: @ 0x74400,
//  buttonPurchase @ 0x74564). The view build lives in StoreDetailHeaderView.m.
//

#import <UIKit/UIKit.h>

@class StorePackInfo;

@interface StoreDetailHeaderView : UIView

// The buy / "INSTALLED" button the detail controller titles + wires to -onPurchaseButton:.
- (UIButton *)buttonPurchase;

// The pack name / description labels (the controller reads them back). Ghidra:
// labelName @ 0x74544, labelComment @ 0x74554.
- (UILabel *)labelName;
- (UILabel *)labelComment;

// Fill the header (jacket / name / copyright) from the pack. Ghidra: loadPackInfo: @ 0x718b8.
- (void)loadPackInfo:(StorePackInfo *)packInfo;

// Set the pack jacket once its async download completes. Ghidra: setArtwork:.
- (void)setArtwork:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
