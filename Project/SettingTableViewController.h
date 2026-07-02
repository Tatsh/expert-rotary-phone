//
//  SettingTableViewController.h
//  pop'n rhythmin
//
//  The top-level Settings screen: a grouped table whose rows open the sub-setting
//  screens (game / how-to / customer support / other). Presented modally by
//  MainViewController -[GotoSetting]. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (initWithStyle: @ 0x7eaf8, the shared modal-VC open/close
//  animations @ 0x7efec.., cell config @ 0x7e3c4).
//
//  Follows the app-wide modal-VC lifecycle (see AcViewerSplitViewController.h):
//  initAtNavigationController wraps self in a UINavigationController; startOpen/
//  startCloseAnimation fade the view + nav view; endCloseAnimation notifies the
//  host via -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

@interface SettingTableViewController : UITableViewController

// Wrap self in a fresh navigation controller and return it (the phone layout).
- (UINavigationController *)initAtNavigationController;   // Ghidra: initAtNavigationController

- (void)startOpenAnimation;    // @ 0x7efec
- (void)startCloseAnimation;   // @ 0x7f130

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
