/**
 * @file
 * The "Game" sub-settings screen, opened from row 0 of SettingTableViewController.
 *
 * A grouped table of three category header rows — サウンド (Sound), ゲーム演出 (Game effects), and
 * ポップ君サイズ (Pop-kun size) — each of which expands an in-line detail row hosting a dedicated
 * sub-controller's view: SoundSettingView, GameEffectView, and PopkunSizeViewCtrl. Reconstructed
 * from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0x88b08 and 16 more methods).
 * Built in SettingGameTableViewController.mm.
 *
 * It follows the app-wide modal view-controller lifecycle (see SettingTableViewController.h):
 * initAtNavigationController wraps self in a UINavigationController; startOpenAnimation and
 * startCloseAnimation fade the view and nav view; endCloseAnimation notifies the host via
 * -[MainViewController SettingEndCallBack].
 */

#import <UIKit/UIKit.h>

/**
 * The gameplay settings list.
 */
@interface SettingGameTableViewController : UITableViewController

/**
 * Wrap self in a fresh navigation controller; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0x88d7c
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the screen in.
 * @ghidraAddress 0x89074
 */
- (void)startOpenAnimation;
/**
 * Fade the screen out.
 * @ghidraAddress 0x891b8
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
