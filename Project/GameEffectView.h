//
//  GameEffectView.h
//  pop'n rhythmin
//
//  The "game effect" (ゲーム演出) settings sub-screen: a two-row grouped table that
//  toggles two boolean play-effect options persisted through UserSettingData —
//    row 0  ->  isEffectOn          (general note effects on/off)
//    row 1  ->  isLongNotesEffectOn (long-note effects on/off)
//  Each row shows an on/off checkmark (m_sort_check_00 / m_sort_check_01); tapping a
//  row plays the decide SE, flips the stored flag and reloads the row so the checkmark
//  updates. On iPad the rows also carry a "custom_bt02_top/under" background image.
//
//  Pushed as the row-3 detail controller of SettingGameTableViewController (which
//  currently carries a `// TODO(dep): GameEffectView` marker). A UITableViewController
//  subclass despite the "View" name. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle: @ 0x72d4c, dealloc @ 0x72eb0, viewDidLoad @ 0x72edc,
//  didReceiveMemoryWarning @ 0x730f4, numberOfSectionsInTableView: @ 0x73120,
//  tableView:numberOfRowsInSection: @ 0x73124, tableView:cellForRowAtIndexPath: @
//  0x73128, tableView:didSelectRowAtIndexPath: @ 0x73518, tableView:viewForHeaderInSection:
//  @ 0x735dc, tableView:heightForHeaderInSection: @ 0x737b0, backButtonFunc @ 0x737d8).
//  Built as Objective-C++ (.mm) because it drives the C++ engine singletons through
//  neEngineBridge.h (neSceneManager::isPadDisplay, neEngine::playSystemSe). The class
//  metadata reports 0 ivars.
//

#import <UIKit/UIKit.h>

@interface GameEffectView : UITableViewController

// Custom nav-bar back button action (@ 0x737d8): plays the cancel SE, restores the
// "settings_navbar" bar background, pops self, then re-applies the stored SE volume.
- (void)backButtonFunc;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
