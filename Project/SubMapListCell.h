//
//  SubMapListCell.h
//  pop'n rhythmin
//
//  A sub-map list row (sugoroku map select). Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0xc0f8c).
//

#import <UIKit/UIKit.h>

@interface SubMapListCell : UITableViewCell

// Bind the row to a sugoroku sub-map (area) entry. `mapValue` is an NSValue
// wrapping the struct { short mainMapId; short subMapId; int; NSString *name;
// }. Draws the area banner, name, collected-piece counts (kakera / ticket), the
// difficulty/item headers, the earned-star row, an optional goal "daon" icon,
// and a "cleared" badge.
- (void)setMapData:(NSValue *)mapValue;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
