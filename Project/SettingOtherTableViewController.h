//
//  SettingOtherTableViewController.h
//  pop'n rhythmin
//
//  The "Other" (その他) settings sub-screen, pushed by
//  -[SettingTableViewController tableView:didSelectRowAtIndexPath:] (row 3). A grouped
//  table with three sections:
//    * Section 0  "お知らせ"      (News)          — 1 row: opens the official-app-info web view.
//    * Section 1  "トレジャーモード" (Treasure Mode) — 1 row: "リタイア" (Retire) -> confirm alert
//                                                    -> [UserSettingData initTreasureTmp].
//    * Section 2  "機種変更"      (Device Change) — 2 rows: row 0 is a toggle that expands
//                                                    row 1, an embedded ConversionView
//                                                    (data-transfer panel).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Objective-C++ because it
//  drives the C++ neEngine / neSceneManager singletons (SE playback, root VC, pad flag).
//
//  Method addresses (imp & ~1):
//    initWithStyle: @ 0xd4180, initAtNavigationController @ 0xd4398, dealloc @ 0xd4578,
//    startOpenAnimation @ 0xd45ec, endOpenAnimation @ 0xd4718, startCloseAnimation @ 0xd4730,
//    endCloseAnimation @ 0xd4850, viewDidAppear: @ 0xd48bc, viewDidLoad @ 0xd48e8,
//    didReceiveMemoryWarning @ 0xd4914, numberOfSectionsInTableView: @ 0xd4940,
//    tableView:numberOfRowsInSection: @ 0xd4944, tableView:heightForRowAtIndexPath: @ 0xd495c,
//    tableView:cellForRowAtIndexPath: @ 0xd4a08, tableView:titleForHeaderInSection: @ 0xd5330,
//    tableView:viewForHeaderInSection: @ 0xd5334, tableView:heightForHeaderInSection: @ 0xd54d4,
//    tableView:accessoryTypeForRowWithIndexPath: @ 0xd54dc,
//    tableView:didSelectRowAtIndexPath: @ 0xd54f8, commonAlertView:clickedButtonAtIndex: @ 0xd579c,
//    settingClose @ 0xd5850, viewCmnDelegate @ 0xd5860, setViewCmnDelegate: @ 0xd5870.
//
//  Follows the shared modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController; startOpen/startClose
//  fade the view + nav view; endCloseAnimation notifies the host via -SettingEndCallBack.
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h"   // CommonAlertViewDelegate (protocol_list @ 0x1552ac)

// TODO(dep): ViewCmnProtocol is not present in Project/. The class holds a weak
// (assign) id<ViewCmnProtocol> delegate that it forwards to the embedded ConversionView.
// Forward-declared here so the property type resolves; recover the real protocol later.
@protocol ViewCmnProtocol;

@interface SettingOtherTableViewController : UITableViewController <CommonAlertViewDelegate>

// The common "view delegate" handed down to the embedded ConversionView. Ivar @ +0xac.
@property (nonatomic, assign) id<ViewCmnProtocol> viewCmnDelegate;

// Wrap self in a fresh navigation controller (with the back button) and return it.
- (UINavigationController *)initAtNavigationController;   // @ 0xd4398

- (void)startOpenAnimation;    // @ 0xd45ec
- (void)startCloseAnimation;   // @ 0xd4730 (also plays the cancel SE)

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
