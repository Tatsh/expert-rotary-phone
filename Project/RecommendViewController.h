//
//  RecommendViewController.h
//  pop'n rhythmin
//
//  The "friend recommend" list: a grouped-style, separator-less UITableViewController of
//  RecommendListCells, one per recommended music pack (from DownloadMain.recommendDataArray,
//  sorted by update date, newest first). Tapping a row opens the in-app StoreViewController on
//  that recommended pack; the back button re-sorts the owning C++ MusicSelTask's song list (when
//  a store was opened) and fades the panel closed. Wrapped in its own UINavigationController (with
//  a back button on phone) and driven by the shared fade/slide open/close lifecycle. Pushed by
//  MainViewController.GotoRecommend:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0xbbd68,
//  initAtNavigationController: @ 0xbc30c, the table data source / delegate, the open/close
//  animations and the musicSelTask / isAnimationing accessors).
//

#import <UIKit/UIKit.h>

@class StoreViewController;

// TODO(dep): MusicSelTask — the C++ music-select task (System/src/Task, not yet reconstructed)
// whose song list this screen re-sorts. Held as a real forward-declared pointer (never void*);
// this header is ObjC++ and every including unit is compiled as .mm.
class MusicSelTask;

@interface RecommendViewController : UITableViewController

// The owning C++ music-select task. Atomic raw pointer: the binary brackets both the getter
// (@ 0xbd3d4) and setter (@ 0xbd3e8) with a DataMemoryBarrier and stores the pointer without
// retaining it (assign).
@property (atomic, assign) MusicSelTask *musicSelTask;

// YES while an open/close animation is in flight. Atomic (DataMemoryBarrier-bracketed) getter.
// Ghidra: isAnimationing @ 0xbd400.
@property (atomic, assign, readonly, getter=isAnimationing) BOOL animationing;

// Build the transparent, separator-less recommend table (a clear spacer header, the "friman"
// backdrop on phone, a hidden dimmed spinner overlay) and load + date-sort the recommend list.
// `style` is forwarded to UITableViewController. Ghidra: @ 0xbbd68.
- (instancetype)initWithStyle:(UITableViewStyle)style;

// Keep the C++ task pointer, (re)build the table, wrap self in a UINavigationController (with a
// back button on phone) and return that navigation controller. Ghidra: @ 0xbc30c.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask;

// Fade (phone) / slide (iPad) the panel in. Ghidra: startOpenAnimation @ 0xbc5e0.
- (void)startOpenAnimation;

// If a store was opened, re-sort the task's list, then fade (phone) / slide (iPad) the panel
// closed. Ghidra: startCloseAnimation @ 0xbcaa8.
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
