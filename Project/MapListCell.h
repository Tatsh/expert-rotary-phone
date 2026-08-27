//
//  MapListCell.h
//  pop'n rhythmin
//
//  A sugoroku map-list row. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xbe270).
//

#import <UIKit/UIKit.h>

/**
 * @brief One sugoroku main-map row.
 */
@interface MapListCell : UITableViewCell

/**
 * @brief Bind the row to a sugoroku main-map entry.
 *
 * It draws the banner, the map icon, the name label, and — once all three sub-maps are cleared —
 * a "cleared" badge.
 * @param mapValue An NSValue wrapping the row struct `{ short mapId; short; NSString *name; }`.
 * @param isSelect YES to draw the highlighted banner.
 */
- (void)setMapData:(NSValue *)mapValue isSelect:(BOOL)isSelect;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
