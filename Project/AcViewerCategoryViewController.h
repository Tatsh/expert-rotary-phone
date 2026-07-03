//
//  AcViewerCategoryViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's genre-category list: a transparent, separator-less
//  UITableView. Row 0 is the "all songs" banner; the remaining rows are the
//  non-empty genre categories (each an AcViewerCategoryCell). Selecting a row
//  pushes the AcViewerMusicViewController song list for that category. On phone
//  the whole screen fades in / out via the open / close animations; the iPad
//  flow forwards this screen's delegate to the pushed music list.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0x68804, initAtNavigationController @ 0x68d40, the table
//  data source / delegate, the open/close animations and the back action).
//
//  .mm because init / viewDidLoad / the animations and the row actions reach the
//  C++ "ne" engine singletons via neEngineBridge (scene-manager pad flag, the
//  AC-viewer event-center selection, the system-SE hooks and the root view
//  controller's AcViewerEndCallBack).
//

#import <UIKit/UIKit.h>

// The AcViewerViewControllerDelegate protocol (the host that hides the split
// panel) is declared here; the iPad flow forwards this screen's delegate to the
// pushed music list.
#import "AcViewerOptionViewController.h"

@interface AcViewerCategoryViewController : UITableViewController

// Synthesized accessors: delegate getter @ 0x69740, setDelegate: @ 0x69750
// (assign — the binary stores the pointer raw, with no retain).
// @ 0x69740
// @ 0x69750
@property (nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

// Build the transparent grouped table, bucketing every MusicManager AC song into
// one of 24 genre categories. Ghidra: initWithStyle: @ 0x68804.
- (instancetype)initWithStyle:(UITableViewStyle)style;

// Initialize the receiver (grouped style) and return it wrapped in a fresh
// UINavigationController with a custom back button in the left nav slot (the phone
// nav host). Ghidra: initAtNavigationController @ 0x68d40.
- (UINavigationController *)initAtNavigationController;

// Fade the screen + its nav view in (phone entry animation). Ghidra: @ 0x69068.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
