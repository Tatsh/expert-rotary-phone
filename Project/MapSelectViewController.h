//
//  MapSelectViewController.h
//  pop'n rhythmin
//
//  The sugoroku "main map" select screen: a grouped UITableViewController
//  listing every main map the player has a save record for, one MapListCell per
//  map. On phone selecting a map pushes the SubMapSelectViewController (area
//  list); on pad the screen is embedded in a MapSelectSplitViewController and
//  forwards the selection to that overlay owner (mapSelectDelegate) instead. A
//  scrolling event banner is shown above the list when a treasure event is
//  running (kept refreshed off DownloadMain's event-info push). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0xbec60,
//  initAtNavigationController @ 0xbf498 and 17 more methods). Built in
//  MapSelectViewController.mm (Objective-C++: drives the C++ neSceneManager
//  singleton).
//

#import <UIKit/UIKit.h>

@class MapSelectViewController;

/**
 * @brief One bundled sugoroku map header.
 *
 * 0x50 bytes; the Ghidra Objective-C encoding is "{MapFileHead=ss[24c][40c]s[10c]}".
 */
typedef struct MapFileHead {
    int16_t mapId;       /**< +0x00 The map id. */
    int16_t squareCount; /**< +0x02 The number of board squares. */
    char name[24];       /**< +0x04 The map display name. */
    char detail[40];     /**< +0x1c The map detail or theme text. */
    int16_t eventId;     /**< +0x44 The associated event id. */
    char reserved[10];   /**< +0x46 Reserved bytes. */
} MapFileHead;

/**
 * @brief Load every bundled "map_%02d_%d.map" header, in the fixed display order.
 * @return An NSArray of NSValue-wrapped MapFileHead.
 * @ghidraAddress 0xcdee0
 */
NSArray *loadAllTreasureMapHeaders(void);

/**
 * @brief Whether an index is a valid event id.
 * @param index The index to test.
 * @return true when @p index is below 12.
 * @ghidraAddress 0xe2c3c
 */
bool isIndexInRange12(unsigned int index);

/**
 * @brief Sent to the iPad overlay owner (MapSelectSplitViewController) that embeds this list.
 */
@protocol MapSelectViewControllerDelegate <NSObject>
/**
 * @brief Remember which row is highlighted: on iPad, the map whose areas fill the right pane.
 * @param selectIndexPath The highlighted row.
 */
- (void)setSelectIndexPath:(NSIndexPath *)selectIndexPath;
/**
 * @brief A main map was chosen: rebuild the right-pane area list from the freshly snapshotted
 * data.
 * @param treasureData The sugoroku save table snapshot.
 * @param mapHeadArray The bundled map-head records.
 * @param mainMapId The chosen main map.
 */
- (void)touchWithTreasureData:(NSArray *)treasureData
                 mapHeadArray:(NSArray *)mapHeadArray
                    mainMapId:(short)mainMapId;
/**
 * @brief Mirror the list's scroll offset into the overlay, keeping both panes aligned.
 * @param scrollView The list that scrolled.
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
@end

/**
 * @brief The NSValue payload for one visible main-map row: the elements of -mapDataArray.
 *
 * The Objective-C type-encoding is "{MainMapData=s@}". It is owned by this controller; the iPad
 * split-view host reads it back to label its header banner.
 */
typedef struct MainMapData {
    short mainMapId;                    /**< The main map id. */
    NSString *__unsafe_unretained name; /**< The map name, Shift-JIS decoded. */
} MainMapData;

/**
 * @brief The sugoroku main-map list.
 */
@interface MapSelectViewController : UITableViewController

/**
 * @brief Wrap self in a UINavigationController with the custom back button; on the first-ever
 * entry it also pushes a two-page how-to overlay.
 * @return The navigation controller: the phone navigation host.
 * @ghidraAddress 0xbf498
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Cross-fade the navigation host in. The root MainViewController calls it after adding the
 * host.
 * @ghidraAddress 0xbfa38
 */
- (void)startOpenAnimation;

/** The iPad overlay owner the selection is forwarded to; nil on phone. Getter @ 0xc0768, setter @
 * 0xc0778. */
@property(nonatomic, assign) id<MapSelectViewControllerDelegate> mapSelectDelegate;

/** The sugoroku save table, an NSArray of TreasureData, snapshotted at init. The getter is
 * barriered. Getter @ 0xc0788. */
@property(atomic, strong, readonly) NSArray *treasureDataArray;
/** All bundled map-head records, as NSValue-wrapped MapFileHead. The getter is barriered. Getter @
 * 0xc079c. */
@property(atomic, strong, readonly) NSArray *mapHeadArray;
/** The visible main-map rows, as NSValue-wrapped MainMapData. The getter is barriered. Getter @
 * 0xc07b0. */
@property(atomic, strong, readonly) NSArray *mapDataArray;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
