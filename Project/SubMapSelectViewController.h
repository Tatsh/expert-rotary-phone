//
//  SubMapSelectViewController.h
//  pop'n rhythmin
//
//  The sugoroku "sub-map" (area) select screen: a grouped UITableViewController
//  listing the sub-maps of one main map, one SubMapListCell per area. Selecting
//  an area snapshots a pending "treasure" record (UserSettingData), asks
//  DownloadMain for the area's visiting friend, and — on completion — animates
//  the map-select flow closed and calls back into the root MainViewController.
//  A left-swipe or the custom back button pops the screen. Reconstructed from
//  Ghidra project rb420, program PopnRhythmin
//  (initWithTreasureData:mapHeadArray:mainMapId: @ 0xc1ea0 and 17 more
//  methods). Built in SubMapSelectViewController.mm (Objective-C++: drives the
//  C++ neSceneManager singleton).
//

#import <UIKit/UIKit.h>

@interface SubMapSelectViewController : UITableViewController

// Build the area list for `mainMapId`. `treasureData` is an NSArray of
// TreasureData records (the sugoroku save table) and `mapHeadArray` an NSArray
// of NSValue-wrapped map-head entries; the initializer cross-references them to
// produce the visible sub-map rows. Ghidra: @ 0xc1ea0.
- (instancetype)initWithTreasureData:(NSArray *)treasureData
                        mapHeadArray:(NSArray *)mapHeadArray
                           mainMapId:(short)mainMapId;

// Optional overlay owner (pad map-select overlay). When set and animating, row
// taps are swallowed and -startCloseAnimation defers closing to it. Ghidra:
// getter @ 0xc3334 / setter @ 0xc3344.
@property(nonatomic, assign) id delegate;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
