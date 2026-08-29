/**
 * @file
 * A sub-map list row in the sugoroku map select.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @
 * 0xc0f8c).
 */

#import <UIKit/UIKit.h>

/**
 * One sugoroku sub-map (area) row.
 */
@interface SubMapListCell : UITableViewCell

/**
 * Bind the row to a sub-map entry.
 *
 * It draws the area banner, the name, the collected-piece counts (kakera and ticket), the
 * difficulty and item headers, the earned-star row, an optional goal "daon" icon, and a "cleared"
 * badge.
 * @param mapValue An NSValue wrapping `{ short mainMapId; short subMapId; int; NSString *name; }`.
 */
- (void)setMapData:(NSValue *)mapValue;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
