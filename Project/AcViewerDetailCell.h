/** @file
 * An arcade-viewer detail row, whose content the view controller sets on bind. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x5b620).
 */

#import <UIKit/UIKit.h>

/**
 * @brief One value row of an arcade-viewer option list.
 */
@interface AcViewerDetailCell : UITableViewCell

/** The label shown for this particular value; the view controller sets it before -setData:.
 * Getter @ 0x5bbb8, setter @ 0x5bbc8. */
@property(nonatomic, copy) NSString *optionName;
/** The option this row belongs to: 0 HI-SPEED, 1 POP-KUN, 2 HID-SUD, 3 RAN-MIR. The accessors are
 * atomic, using a DataMemoryBarrier in the binary. Getter @ 0x5bbd8, setter @ 0x5bbec. */
@property(atomic) int optionKind;

/**
 * @brief Bind the row to a value index within its option kind.
 *
 * It draws the grouped-list background slice (top, bar or under), the option name on the left, and
 * a check mark on the right of the row that matches the player's current UserSettingData value.
 * @param index The value index within the option kind.
 * @ghidraAddress 0x5b694
 */
- (void)setData:(int)index;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
