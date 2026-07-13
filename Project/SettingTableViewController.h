//
//  SettingTableViewController.h
//  pop'n rhythmin
//
//  The top-level Settings screen: a grouped table of six sections whose rows
//  open the various setting / how-to / support sub-screens. Presented modally
//  by MainViewController
//  -[GotoSetting]. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//
//  Sections (titleForHeaderInSection:) and their rows
//  (didSelectRowAtIndexPath:):
//    * 0  "お知らせ"        (News)          — 1 row  -> CustomWebView (official
//    app info).
//    * 1  "設定"            (Settings)      — 3 rows -> SoundSettingView /
//    PopkunSizeViewCtrl /
//                                                       GameEffectView.
//    * 2  "遊び方"          (How to play)   — 2 rows -> HowToViewCtrl(Pad)
//    (basic / treasure).
//    * 3  "トレジャーモード" (Treasure Mode) — 1 row  -> "リタイア" (Retire)
//    confirm alert
//                                                       -> [UserSettingData
//                                                       initTreasureTmp].
//    * 4  "機種変更"        (Device Change) — 1 row  -> ConversionView (data
//    transfer).
//    * 5  "お問い合わせ"    (Inquiry)       — 3 rows -> FAQ URL / 特定商取引法
//    URL / PolicyView.
//
//  On the phone the sub-screen rows carry a disclosure indicator
//  (accessoryType); on the iPad the how-to screens are shown as an overlay on
//  the root scene view instead of pushed.
//
//  Reconstructed method addresses (imp):
//    initWithStyle: @ 0x7eaf8, initAtNavigationController @ 0x7ed98, dealloc @
//    0x7ef98, startOpenAnimation @ 0x7efec, endOpenAnimation @ 0x7f118,
//    startCloseAnimation @ 0x7f130, endCloseAnimation @ 0x7f250, viewDidAppear:
//    @ 0x7f2f0, viewDidLoad @ 0x7f31c, didReceiveMemoryWarning @ 0x7f348,
//    numberOfSectionsInTableView: @ 0x7f374, tableView:numberOfRowsInSection: @
//    0x7f378, tableView:cellForRowAtIndexPath: @ 0x7f390,
//    tableView:titleForHeaderInSection: @ 0x7f708,
//    tableView:accessoryTypeForRowWithIndexPath: @ 0x7f764,
//    tableView:didSelectRowAtIndexPath: @ 0x7f818,
//    commonAlertView:clickedButtonAtIndex: @ 0x80128, settingClose @ 0x801dc,
//    onEffectOnChanged: @ 0x801ec, onSimpleModeChanged: @ 0x8029c.
//
//  Follows the app-wide modal-VC lifecycle: initAtNavigationController wraps
//  self in a UINavigationController; startOpen/startCloseAnimation fade the
//  view + nav view; endCloseAnimation removes the nav view and notifies the
//  host via -SettingEndCallBack.
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate (retire-confirm callback)

@interface SettingTableViewController : UITableViewController <CommonAlertViewDelegate>

// Wrap self in a fresh navigation controller (with the phone back button) and
// return it.
- (UINavigationController *)initAtNavigationController
    __attribute__((objc_method_family(none))); // @ 0x7ed98

- (void)startOpenAnimation;  // @ 0x7efec
- (void)startCloseAnimation; // @ 0x7f130

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
