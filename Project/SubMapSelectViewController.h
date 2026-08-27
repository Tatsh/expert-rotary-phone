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

/**
 * @brief The sugoroku sub-map (area) list for one main map.
 */
@interface SubMapSelectViewController : UITableViewController

/**
 * @brief Build the area list for a main map; the initialiser cross-references the two arrays to
 * produce the visible sub-map rows.
 * @param treasureData An NSArray of TreasureData records: the sugoroku save table.
 * @param mapHeadArray An NSArray of NSValue-wrapped map-head entries.
 * @param mainMapId The main map to list.
 * @return The initialised controller.
 * @ghidraAddress 0xc1ea0
 */
- (instancetype)initWithTreasureData:(NSArray *)treasureData
                        mapHeadArray:(NSArray *)mapHeadArray
                           mainMapId:(short)mainMapId;

/** The optional iPad map-select overlay owner. While it is set and animating, row taps are
 * swallowed and -startCloseAnimation defers closing to it. Getter @ 0xc3334, setter @
 * 0xc3344. */
@property(nonatomic, assign) id delegate;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
