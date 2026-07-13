//
//  SortSelectViewController.h
//  pop'n rhythmin
//
//  The music-list sort-select screen: a transparent, separator-less UITableView
//  of six SortCells (Title / Artist / Lv N / Lv H / Lv EX / best-score), the
//  current sort marked with a check. Picking a new sort saves it, shows a
//  dimmed "loading" overlay, re-sorts the owning C++ MusicSelTask's song list
//  and fades the panel closed. Wrapped in its own UINavigationController (with
//  a back button on phone) and driven by the shared fade/slide open/close
//  lifecycle. Pushed by MainViewController.GotoSortSelect:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0xc5988, initAtNavigationController: @ 0xc6018, the table
//  data source / delegate, the open/close animations and the musicSelTask
//  accessors).
//

#import <UIKit/UIKit.h>

// The C++ music-select task (System/src/Task/MainTask.h) whose song list this
// screen re-sorts. "MusicSelTask" is the binary's name for MainTask, so it is
// an alias here. Held as a real forward-declared pointer (never void*); this
// header is ObjC++ (every includer is .mm).
class MainTask;
using MusicSelTask = MainTask;

@interface SortSelectViewController : UITableViewController

// The owning C++ music-select task. Atomic raw pointer: the binary brackets
// both the getter
// (@ 0xc7028) and setter (@ 0xc703c) with a DataMemoryBarrier and stores the
// pointer without retaining it (assign).
@property(atomic, assign) MusicSelTask *musicSelTask;

// Build the sort list (six SortData rows, the current sort checked) as a
// transparent table with a "loading" overlay. `style` is forwarded to
// UITableViewController. Ghidra: @ 0xc5988.
- (instancetype)initWithStyle:(UITableViewStyle)style;

// Keep the C++ task pointer, (re)build the table, wrap self in a
// UINavigationController (with a back button on phone) and return that
// navigation controller. Ghidra: @ 0xc6018. Factory named with an 'init' prefix
// but returns a *nav controller*, not self; opt out of the ARC init method
// family (AVBus.h convention) so the unrelated return type is allowed.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask
    __attribute__((objc_method_family(none)));

// Fade (phone) / slide (iPad) the panel in. Ghidra: startOpenAnimation @
// 0xc6288.
- (void)startOpenAnimation;

// Re-sort the task's list if the sort changed, then fade (phone) / slide (iPad)
// the panel closed. Ghidra: startCloseAnimation @ 0xc6750.
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
