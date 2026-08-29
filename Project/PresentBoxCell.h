/**
 * @file
 * @brief A present-box, or gift, row on a clear background.
 *
 * A full-width banner, a treasure or character icon, an amount label, a one-line info label, and
 * an "acquire" button. Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (initWithStyle:reuseIdentifier: @ 0x6e3ac, setPresentData: @ 0x6e494, getBtn @ 0x6ed34).
 */

#import <UIKit/UIKit.h>

/**
 * @brief One present-box row.
 */
@interface PresentBoxCell : UITableViewCell

/** The "acquire" button; the hosting controller wires its target and action. */
@property(readonly, strong) UIButton *getBtn;

/**
 * @brief Bind a present record and rebuild the row.
 * @param presentData An NSValue-wrapped PresentData; see the .m.
 */
- (void)setPresentData:(NSValue *)presentData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
