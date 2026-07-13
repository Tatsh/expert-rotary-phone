//
//  SettingGameTableViewController.h
//  pop'n rhythmin
//
//  The "Game" sub-settings screen (opened from row 0 of
//  SettingTableViewController). A grouped table of three category header rows
//  -- サウンド (Sound), ゲーム演出 (Game effects) and ポップ君サイズ (Pop-kun
//  size) -- each of which expands an in-line detail row hosting a dedicated
//  sub-controller's view (SoundSettingView, GameEffectView,
//  PopkunSizeViewCtrl). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle: @ 0x88b08 and 16 more methods). Built in
//  SettingGameTableViewController.mm.
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController;
//  startOpen/ startCloseAnimation fade the view + nav view; endCloseAnimation
//  notifies the host via -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

@interface SettingGameTableViewController : UITableViewController

// Wrap self in a fresh navigation controller and return it (the phone layout).
- (UINavigationController *)initAtNavigationController
    __attribute__((objc_method_family(none))); // @ 0x88d7c

- (void)startOpenAnimation;  // @ 0x89074
- (void)startCloseAnimation; // @ 0x891b8

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
