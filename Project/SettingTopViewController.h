//
//  SettingTopViewController.h
//  pop'n rhythmin
//
//  The top-level "settings" menu (the four-button カスタム screen): ゲーム
//  (Game), 遊び方 (How-to), お問い合わせ (Customer/inquiry) and その他 (Other).
//  On the phone each button pushes the matching sub-screen onto its own
//  navigation controller; on the pad it forwards the tap to a delegate (the
//  iPad settings host owns the detail pane). Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (init @ 0x13fe8 and 11 more methods). Built in
//  SettingTopViewController.mm (Objective-C++: drives the C++ neSceneManager /
//  neEngine singletons).
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController;
//  startOpen/ startCloseAnimation fade the view + nav view; endCloseAnimation
//  notifies the host via -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

@class SettingTopViewController;

// The pad-layout host (the settings split/detail owner) receives the button
// taps so it can swap its own detail pane. NB: the binary spells the protocol
// "Dalegate" (typo preserved).
/**
 * @brief The iPad-layout host, the settings split or detail owner, which receives the section
 * button taps so it can swap its own detail pane.
 *
 * The binary spells the protocol "Dalegate"; the typo is preserved.
 */
@protocol SettingTopViewControllerDalegate <NSObject>
/**
 * @brief The gameplay-settings button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14964
 */
- (void)onGameButtonTouched:(id)sender;
/**
 * @brief The how-to button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14a90
 */
- (void)onHowtoButtonTouched:(id)sender;
/**
 * @brief The customer-support button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14ae0
 */
- (void)onCustomerButtonTouched:(id)sender;
/**
 * @brief The "Other" button was tapped.
 * @param sender The tapped button.
 * @ghidraAddress 0x14b30
 */
- (void)onOtherButtonTouched:(id)sender;
@end

/**
 * @brief The settings top screen: the four section buttons.
 */
@interface SettingTopViewController : UIViewController

/**
 * @brief Lay out the four custom buttons over a "friman_bg" backdrop on phone, or a clear view on
 * iPad.
 * @return The initialised controller.
 * @ghidraAddress 0x13fe8
 */
- (instancetype)init;

/**
 * @brief Build self and wrap it in a fresh navigation controller with a back button and nav-bar
 * art; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0x14464
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen in.
 * @ghidraAddress 0x14694
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the screen out; this is also the back-button action.
 * @ghidraAddress 0x147d8
 */
- (void)startCloseAnimation;

/** The iPad-layout tap target. Getter @ 0x14b80, setter @ 0x14b90. */
@property(nonatomic, assign) id<SettingTopViewControllerDalegate> settingTopDelegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
