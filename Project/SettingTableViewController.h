/**
 * @file
 * The top-level Settings screen.
 *
 * A grouped table of six sections whose rows open the various setting, how-to, and support
 * sub-screens. MainViewController -[GotoSetting] presents it modally. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin.
 *
 * The sections (titleForHeaderInSection:) and their rows (didSelectRowAtIndexPath:) are: section 0
 * (お知らせ, News), one row leading to a CustomWebView of the official app info; section 1 (設定,
 * Settings), three rows leading to SoundSettingView, PopkunSizeViewCtrl, and GameEffectView;
 * section 2 (遊び方, How to play), two rows leading to HowToViewCtrl or HowToViewCtrlPad for the
 * basic and treasure tutorials; section 3 (トレジャーモード, Treasure Mode), one row, リタイア
 * (Retire), raising a confirm alert that calls [UserSettingData initTreasureTmp]; section 4
 * (機種変更, Device Change), one row leading to ConversionView; and section 5 (お問い合わせ,
 * Inquiry), three rows leading to the FAQ URL, the 特定商取引法 URL, and PolicyView.
 *
 * On the phone the sub-screen rows carry a disclosure indicator (accessoryType); on the iPad the
 * how-to screens are shown as an overlay on the root scene view instead of pushed.
 *
 * Reconstructed method addresses (imp): initWithStyle: @ 0x7eaf8, initAtNavigationController @
 * 0x7ed98, dealloc @ 0x7ef98, startOpenAnimation @ 0x7efec, endOpenAnimation @ 0x7f118,
 * startCloseAnimation @ 0x7f130, endCloseAnimation @ 0x7f250, viewDidAppear: @ 0x7f2f0,
 * viewDidLoad @ 0x7f31c, didReceiveMemoryWarning @ 0x7f348, numberOfSectionsInTableView: @
 * 0x7f374, tableView:numberOfRowsInSection: @ 0x7f378, tableView:cellForRowAtIndexPath: @ 0x7f390,
 * tableView:titleForHeaderInSection: @ 0x7f708, tableView:accessoryTypeForRowWithIndexPath: @
 * 0x7f764, tableView:didSelectRowAtIndexPath: @ 0x7f818, commonAlertView:clickedButtonAtIndex: @
 * 0x80128, settingClose @ 0x801dc, onEffectOnChanged: @ 0x801ec, and onSimpleModeChanged: @
 * 0x8029c.
 *
 * It follows the app-wide modal view-controller lifecycle: initAtNavigationController wraps self
 * in a UINavigationController; startOpenAnimation and startCloseAnimation fade the view and nav
 * view; endCloseAnimation removes the nav view and notifies the host via -SettingEndCallBack.
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate (retire-confirm callback)

/**
 * The account settings list, including the retire flow.
 */
@interface SettingTableViewController : UITableViewController <CommonAlertViewDelegate>

/**
 * Wrap self in a fresh navigation controller with the phone back button.
 * @return The navigation controller.
 * @ghidraAddress 0x7ed98
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the screen in.
 * @ghidraAddress 0x7efec
 */
- (void)startOpenAnimation;
/**
 * Fade the screen out.
 * @ghidraAddress 0x7f130
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
