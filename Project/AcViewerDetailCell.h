//
//  AcViewerDetailCell.h
//  pop'n rhythmin
//
//  An arcade-viewer detail row (content set by the VC on bind). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x5b620).
//

#import <UIKit/UIKit.h>

@interface AcViewerDetailCell : UITableViewCell

// The option this row belongs to (0 = HI-SPEED, 1 = POP-KUN, 2 = HID-SUD, 3 =
// RAN-MIR) and the label shown for this particular value; the VC sets both
// before -setData:. Ghidra: optionName getter @ 0x5bbb8 / setter @ 0x5bbc8;
// optionKind getter @ 0x5bbd8 / setter @ 0x5bbec.
@property(nonatomic, copy) NSString *optionName;
@property(atomic) int optionKind; // accessors are atomic (DataMemoryBarrier in the binary)

// Bind the row to value index within its option kind: draws the grouped-list
// background slice (top / bar / under), the option name on the left, and a
// check mark on the right of the row that matches the player's current
// UserSettingData value. Ghidra: setData: @ 0x5b694.
- (void)setData:(int)index;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
