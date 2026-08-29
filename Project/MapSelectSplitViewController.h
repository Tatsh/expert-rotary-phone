/**
 * @file
 * The iPad sugoroku "map select" split hub.
 *
 * A full-screen UIViewController hosting the two halves of the map-select flow side by side: the
 * left map list (MapSelectViewController, a grouped table of main maps) and the right area panel
 * (SubMapSelectViewController), joined by an animated arrow that slides to the selected row. It
 * also carries the top banner, the per-map header label and icon, an "empty area" placeholder,
 * and a bottom auto-scrolling event banner carousel (a UIScrollView with a UIPageControl) whose
 * contents come from DownloadMain's live event list. The custom back button and the open and
 * close cross-fades drive the parent navigation controller and hand control back to the app root
 * (MainViewController) via the C++ neSceneManager singleton.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0x754d8 and 24 more
 * methods). Built in MapSelectSplitViewController.mm, which drives the C++ neSceneManager and
 * neEngine bridge, under ARC.
 */

#import <UIKit/UIKit.h>

@class MapSelectViewController;
@class SubMapSelectViewController;
@class UIImageView;
@class UILabel;
@class UIScrollView;
@class UIPageControl;
@class HowToViewCtrlPad;

/**
 * The iPad sugoroku map-select hub: a main-map list beside an area panel.
 */
@interface MapSelectSplitViewController : UIViewController <UIScrollViewDelegate>

/**
 * Whether an open, close or arrow-move cross-fade is running; taps and the back button are
 * swallowed until it clears. Exposed read-only for the flow controller.
 * @return YES while an animation is running.
 * @ghidraAddress 0x787d8
 */
- (BOOL)isAnimationing;

/**
 * Remember the table row the arrow points at: the pending area selection.
 * @param selectIndexPath The highlighted row.
 * @ghidraAddress 0x766b8
 */
- (void)setSelectIndexPath:(NSIndexPath *)selectIndexPath;

/**
 * Slide the arrow to -setSelectIndexPath:'s row and cross-fade the right area panel to the
 * freshly-built data for one main map.
 * @param treasureData The sugoroku save table snapshot.
 * @param mapHeadArray The bundled map-head records.
 * @param mainMapId The chosen main map.
 * @ghidraAddress 0x76b40
 */
- (void)touchWithTreasureData:(NSArray *)treasureData
                 mapHeadArray:(NSArray *)mapHeadArray
                    mainMapId:(int)mainMapId;

/**
 * Cross-fade the whole hub in; the parent navigation controller's view rides along.
 * @ghidraAddress 0x766e0
 */
- (void)startOpenAnimation;
/**
 * Cross-fade the whole hub out; the parent navigation controller's view rides along.
 * @ghidraAddress 0x769c8
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
