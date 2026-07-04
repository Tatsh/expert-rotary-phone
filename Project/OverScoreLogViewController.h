//
//  OverScoreLogViewController.h
//  pop'n rhythmin
//
//  The "friend over-score" log screen: a grouped-style UITableViewController that downloads the
//  list of songs on which a friend has beaten your score (via DownloadMain) and shows one
//  OverScoreLogCell per entry over a dimmed spinner overlay. Picking a row closes the panel and,
//  in the close-animation completion, drives the owning C++ MusicSelTask straight into a play of
//  that song (or raises a "song not installed" alert). Wrapped in its own UINavigationController
//  (with a back button on phone) and driven by the shared fade/slide open/close lifecycle. Pushed
//  by MainViewController.GotoOverScoreLog:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0x29928,
//  initAtNavigationController: @ 0x29e24, the table data source / delegate, the DownloadMain
//  callback, the open/close animations and the musicSelTask accessors).
//

#import <UIKit/UIKit.h>

#import "DownloadMain.h"  // DownloadMainDelegate (the over-score-log download callback)

// The C++ music-select task (System/src/Task/MainTask.h) whose song list this screen plays
// from. "MusicSelTask" is the binary's name for MainTask, so it is an alias here. Held as a
// real forward-declared pointer (never void*); this header is ObjC++ (every includer is .mm).
class MainTask;
using MusicSelTask = MainTask;

@interface OverScoreLogViewController : UITableViewController <DownloadMainDelegate>

// The owning C++ music-select task. Atomic raw pointer: the binary brackets both the getter
// (@ 0x2af2c) and setter (@ 0x2af40) with a DataMemoryBarrier and stores the pointer without
// retaining it (assign).
@property (atomic, assign) MusicSelTask *musicSelTask;

// Build the transparent, separator-less table (a clear spacer header, the "friman" backdrop on
// phone, and a hidden dimmed spinner overlay). `style` is forwarded to UITableViewController.
// Ghidra: @ 0x29928.
- (instancetype)initWithStyle:(UITableViewStyle)style;

// Keep the C++ task pointer, (re)build the table, wrap self in a UINavigationController (with a
// back button on phone) and return that navigation controller. Ghidra: @ 0x29e24.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask __attribute__((objc_method_family(none)));

// Fade (phone) / slide (iPad) the panel in. Ghidra: startOpenAnimation @ 0x2a1b0.
- (void)startOpenAnimation;

// Fade (phone) / slide (iPad) the panel closed; the completion launches the selected play.
// Ghidra: startCloseAnimation @ 0x2a678.
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
