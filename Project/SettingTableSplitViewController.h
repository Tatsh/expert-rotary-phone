/**
 * @file
 * @brief The iPad layout of the settings menu.
 *
 * A floating split panel over a dimmed, tappable backdrop: a left column that is a
 * SettingTopViewController, carrying the four custom buttons ゲーム, 遊び方, お問い合わせ, and
 * その他, and a right rounded, bordered UINavigationController pane hosting the matching settings
 * sub-table. A selection arrow slides between the four rows. Reconstructed from Ghidra project
 * rb420, program PopnRhythmin (init @ 0xb5cb0 and 12 more methods). Built in
 * SettingTableSplitViewController.mm, which drives the C++ neSceneManager and neEngine singletons
 * for SE playback and the root-VC close callback.
 *
 * This controller is the SettingTopViewController's pad split delegate: it adopts
 * SettingTopViewControllerDalegate (the typo is preserved from the binary) so the left column
 * forwards its four button taps here, and it swaps the right pane and moves the arrow in response
 * through startViewAnimation:.
 *
 * It follows the app-wide modal view-controller lifecycle (see SettingTableViewController.h):
 * startOpenAnimation fades the view and nav view 0 -> 1; startCloseAnimation fades 1 -> 0;
 * endCloseAnimation removes the view and notifies the host via -[MainViewController
 * SettingEndCallBack].
 */

#import <UIKit/UIKit.h>

#import "SettingTopViewController.h" // SettingTopViewControllerDalegate + the left column type

/**
 * @brief The iPad settings hub: a section column beside a detail pane.
 */
@interface SettingTableSplitViewController : UIViewController <SettingTopViewControllerDalegate>

/**
 * @brief Fade the hub in.
 * @ghidraAddress 0xb66dc
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the hub out.
 * @ghidraAddress 0xb6820
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
