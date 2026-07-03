//
//  MapSelectViewController.h
//  pop'n rhythmin
//
//  The sugoroku "main map" select screen: a grouped UITableViewController listing every main
//  map the player has a save record for, one MapListCell per map. On phone selecting a map
//  pushes the SubMapSelectViewController (area list); on pad the screen is embedded in a
//  MapSelectSplitViewController and forwards the selection to that overlay owner
//  (mapSelectDelegate) instead. A scrolling event banner is shown above the list when a
//  treasure event is running (kept refreshed off DownloadMain's event-info push).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0xbec60, initAtNavigationController @ 0xbf498 and 17 more methods).
//  Built in MapSelectViewController.mm (Objective-C++: drives the C++ neSceneManager singleton).
//

#import <UIKit/UIKit.h>

@class MapSelectViewController;

// Sent to the pad overlay owner (MapSelectSplitViewController) that embeds this list.
@protocol MapSelectViewControllerDelegate <NSObject>
// Remember which row is highlighted (pad: the map whose areas fill the right pane).
- (void)setSelectIndexPath:(NSIndexPath *)selectIndexPath;
// A main map was chosen: rebuild the right-pane area list for `mainMapId` from the freshly
// snapshotted `treasureData` / `mapHeadArray`.
- (void)touchWithTreasureData:(NSArray *)treasureData
                 mapHeadArray:(NSArray *)mapHeadArray
                    mainMapId:(short)mainMapId;
// Mirror the list's scroll offset into the overlay (keeps both panes aligned).
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
@end

@interface MapSelectViewController : UITableViewController

// Wrap self in a UINavigationController (with the custom back button); on first-ever entry
// also push a two-page how-to overlay. Returns that navigation controller (the phone nav host).
// Ghidra: @ 0xbf498.
- (UINavigationController *)initAtNavigationController;

// Cross-fade the nav host in. Called by the root MainViewController after it adds the host.
// Ghidra: @ 0xbfa38.
- (void)startOpenAnimation;

// The pad overlay owner the selection is forwarded to (nil on phone). Ghidra: getter
// @ 0xc0768 / setter @ 0xc0778.
@property (nonatomic, assign) id<MapSelectViewControllerDelegate> mapSelectDelegate;

// The sugoroku save table (NSArray of TreasureData) snapshotted at init. Barriered getter
// (Ghidra @ 0xc0788).
@property (atomic, strong, readonly) NSArray *treasureDataArray;
// All bundled map-head records (NSArray of NSValue-wrapped MapFileHead). Barriered getter
// (Ghidra @ 0xc079c).
@property (atomic, strong, readonly) NSArray *mapHeadArray;
// The visible main-map rows (NSArray of NSValue-wrapped MainMapData). Barriered getter
// (Ghidra @ 0xc07b0).
@property (atomic, strong, readonly) NSArray *mapDataArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
