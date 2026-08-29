/**
 * @file
 * @brief An arcade-viewer option row, whose content the view controller binds.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @
 * 0x65480).
 */

#import <UIKit/UIKit.h>

/**
 * @brief One row of the arcade-viewer option list.
 */
@interface AcViewerOptionCell : UITableViewCell

/**
 * @brief Bind the row to one of the arcade-viewer option kinds and rebuild its labels.
 *
 * The detail label shows the player's current UserSettingData value for that kind.
 * @param optionKind 0 HI-SPEED, 1 POP-KUN, 2 HID-SUD, 3 RAN-MIR.
 */
- (void)setData:(int)optionKind;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
