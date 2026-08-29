/**
 * @file
 * The top-level "settings" menu: the four-button カスタム screen.
 *
 * The buttons are ゲーム (Game), 遊び方 (How-to), お問い合わせ (Customer inquiry), and その他
 * (Other). On the phone each button pushes the matching sub-screen onto its own navigation
 * controller; on the pad it forwards the tap to a delegate, since the iPad settings host owns the
 * detail pane. Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0x13fe8 and
 * 11 more methods). Built in SettingTopViewController.mm, which drives the C++ neSceneManager and
 * neEngine singletons.
 *
 * It follows the app-wide modal view-controller lifecycle (see SettingTableViewController.h):
 * initAtNavigationController wraps self in a UINavigationController; startOpenAnimation and
 * startCloseAnimation fade the view and nav view; endCloseAnimation notifies the host via
 * -[MainViewController SettingEndCallBack].
 */

#import <UIKit/UIKit.h>

@class SettingTopViewController;

// The pad-layout host (the settings split/detail owner) receives the button
// taps so it can swap its own detail pane. NB: the binary spells the protocol
// "Dalegate" (typo preserved).
/**
 * The iPad-layout host, the settings split or detail owner, which receives the section
 * button taps so it can swap its own detail pane.
 *
 * The binary spells the protocol "Dalegate"; the typo is preserved.
 */
@protocol SettingTopViewControllerDalegate <NSObject>
/**
 * The gameplay-settings button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14964
 */
- (void)onGameButtonTouched:(id)sender;
/**
 * The how-to button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14a90
 */
- (void)onHowtoButtonTouched:(id)sender;
/**
 * The customer-support button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14ae0
 */
- (void)onCustomerButtonTouched:(id)sender;
/**
 * The "Other" button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14b30
 */
- (void)onOtherButtonTouched:(id)sender;
@end

/**
 * The settings top screen: the four section buttons.
 */
@interface SettingTopViewController : UIViewController

/**
 * Lay out the four custom buttons over a "friman_bg" backdrop on phone, or a clear view on
 * iPad.
 * @return The initialised controller.
 * @ghidraAddress 0x13fe8
 */
- (instancetype)init;

/**
 * Build self and wrap it in a fresh navigation controller with a back button and nav-bar
 * art; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0x14464
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the screen in.
 * @ghidraAddress 0x14694
 */
- (void)startOpenAnimation;
/**
 * Fade the screen out; this is also the back-button action.
 * @ghidraAddress 0x147d8
 */
- (void)startCloseAnimation;

/** The iPad-layout tap target. Getter @ 0x14b80, setter @ 0x14b90. */
@property(nonatomic, assign) id<SettingTopViewControllerDalegate> settingTopDelegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
