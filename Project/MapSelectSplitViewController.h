//
//  MapSelectSplitViewController.h
//  pop'n rhythmin
//
//  The iPad sugoroku "map select" split hub: a full-screen UIViewController
//  that hosts the two halves of the map-select flow side by side — the left map
//  list (MapSelectViewController, a grouped table of main maps) and the right
//  area panel (SubMapSelectViewController) — joined by an animated arrow that
//  slides to the selected row. It also carries the top banner, the per-map
//  header label/icon, an "empty area" placeholder, and a bottom auto-scrolling
//  event banner carousel (a UIScrollView + UIPageControl) whose contents come
//  from DownloadMain's live event list. The custom back button and the
//  open/close cross-fades drive the parent navigation controller and hand
//  control back to the app root (MainViewController) via the C++ neSceneManager
//  singleton.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x754d8 and 24 more methods). Built in MapSelectSplitViewController.mm
//  (Objective-C++: drives the C++ neSceneManager / neEngine bridge). ARC.
//

#import <UIKit/UIKit.h>

@class MapSelectViewController;
@class SubMapSelectViewController;
@class UIImageView;
@class UILabel;
@class UIScrollView;
@class UIPageControl;
@class HowToViewCtrlPad;

@interface MapSelectSplitViewController : UIViewController <UIScrollViewDelegate>

// YES while an open/close/arrow-move cross-fade is running; taps and the back
// button are swallowed until it clears. Exposed read-only for the flow
// controller. Ghidra: @ 0x787d8.
- (BOOL)isAnimationing;

// The table row the arrow currently points at (the pending area selection).
// Ghidra: setter @ 0x766b8.
- (void)setSelectIndexPath:(NSIndexPath *)selectIndexPath;

// Slide the arrow to -selectIndexPath's row and cross-fade the right area panel
// to the freshly-built `treasureData` / `mapHeadArray` for `mainMapId`. Ghidra:
// @ 0x76b40.
- (void)touchWithTreasureData:(NSArray *)treasureData
                 mapHeadArray:(NSArray *)mapHeadArray
                    mainMapId:(int)mainMapId;

// Cross-fade the whole hub in / out (the parent navigation controller's view
// rides along). Ghidra: startOpenAnimation @ 0x766e0 / startCloseAnimation @
// 0x769c8.
- (void)startOpenAnimation;
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
