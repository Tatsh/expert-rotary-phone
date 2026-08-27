//
//  SettingCustomerTableViewController.h
//  pop'n rhythmin
//
//  The "customer support" sub-settings screen (pushed by
//  SettingTableViewController's row 2). A three-row grouped table of rounded,
//  colour-bordered buttons:
//    row 0  お問い合わせ                 -> opens the FAQ page in Safari
//    row 1  特定商取引法に基づく表示     -> opens the KONAMI TOKUSHO (SCTA)
//    page in Safari row 2  利用規約                     -> shows the in-app
//    Terms-of-Use (PolicyView) overlay
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:
//  @ 0xd32b8 and 13 more methods). Built in
//  SettingCustomerTableViewController.mm (Objective-C++: drives the C++
//  neSceneManager / neEngine singletons).
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController;
//  startOpen/ startCloseAnimation fade the view + nav view; endCloseAnimation
//  notifies the host via -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

/**
 * @brief The customer-support settings list.
 */
@interface SettingCustomerTableViewController : UITableViewController

/**
 * @brief Wrap self in a fresh navigation controller with a back button; the phone layout.
 * @return The navigation controller.
 * @ghidraAddress 0xd3460
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen in.
 * @ghidraAddress 0xd36ec
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the screen out.
 * @ghidraAddress 0xd3830
 */
- (void)startCloseAnimation;

/**
 * @brief The back-button action wired up by -initAtNavigationController; it calls
 * -startCloseAnimation.
 * @ghidraAddress 0xd4170
 */
- (void)settingClose;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
