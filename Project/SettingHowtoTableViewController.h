//
//  SettingHowtoTableViewController.h
//  pop'n rhythmin
//
//  The "how to play" settings sub-screen: a two-row grouped table reached from the
//  top Settings list (SettingTableViewController row 1). Each row is a rounded,
//  patterned tile with a coloured border and a centred label; tapping a row spawns a
//  HowToViewCtrlPad tutorial (a horizontally-paged strip of how-to images) and drops
//  its view onto the scene manager's root view controller:
//    row 0  "ゲームプレー"     -> howto_01 … howto_05        (adds a "howto_navbar" nav bar)
//    row 1  "トレジャーモード"  -> howto_tre01 … howto_tre06
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController; startOpen/
//  startCloseAnimation fade the view + nav view; endCloseAnimation notifies the host
//  via -[MainViewController SettingEndCallBack]. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (class @ 0x0014b500; initWithStyle: @ 0x802e0,
//  initAtNavigationController @ 0x80488, the modal open/close animations @ 0x806ec..,
//  cellForRow @ 0x809c4, didSelectRow @ 0x80f1c).
//

#import <UIKit/UIKit.h>

@interface SettingHowtoTableViewController : UITableViewController

// Wrap self in a fresh navigation controller and return it (the phone layout).
// Also builds the nav-bar back button (targets -settingClose). Ghidra: @ 0x80488.
- (UINavigationController *)initAtNavigationController;

- (void)startOpenAnimation;    // @ 0x806ec
- (void)startCloseAnimation;   // @ 0x80830 — plays the cancel SE, fades out
- (void)settingClose;          // @ 0x811b8 — back-button action, calls -startCloseAnimation

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
