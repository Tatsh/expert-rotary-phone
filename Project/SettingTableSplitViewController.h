//
//  SettingTableSplitViewController.h
//  pop'n rhythmin
//
//  The iPad layout of the settings menu: a floating split panel over a dimmed,
//  tappable backdrop — a left column that is a SettingTopViewController (the
//  four custom buttons: ゲーム / 遊び方 / お問い合わせ / その他) and a right
//  rounded, bordered UINavigationController pane that hosts the matching
//  settings sub-table. A selection arrow slides between the four rows.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0xb5cb0 and 12 more methods). Built in SettingTableSplitViewController.mm
//  (Objective-C++: drives the C++ neSceneManager / neEngine singletons for SE
//  playback + the root-VC close callback).
//
//  This controller is the SettingTopViewController's pad split delegate: it
//  adopts SettingTopViewControllerDalegate (typo preserved from the binary) so
//  the left column forwards its four button taps here, and it swaps the right
//  pane / moves the arrow in response (startViewAnimation:).
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  startOpenAnimation fades the view + nav view 0 -> 1; startCloseAnimation
//  fades 1 -> 0; endCloseAnimation removes the view and notifies the host via
//  -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

#import "SettingTopViewController.h" // SettingTopViewControllerDalegate + the left column type

@interface SettingTableSplitViewController : UIViewController <SettingTopViewControllerDalegate>

- (void)startOpenAnimation;  // @ 0xb66dc
- (void)startCloseAnimation; // @ 0xb6820

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
