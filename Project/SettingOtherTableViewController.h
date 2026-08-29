/**
 * @file
 * The "Other" (その他) settings sub-screen.
 *
 * -[SettingTableViewController tableView:didSelectRowAtIndexPath:] pushes it from row 3. It is a
 * grouped table with three sections. Section 0 (お知らせ, News) has one row that opens the
 * official-app-info web view. Section 1 (トレジャーモード, Treasure Mode) has one row, リタイア
 * (Retire), which raises a confirm alert and then calls [UserSettingData initTreasureTmp]. Section
 * 2 (機種変更, Device Change) has two rows: row 0 is a toggle that expands row 1, an embedded
 * ConversionView data-transfer panel.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. It is Objective-C++ because it
 * drives the C++ neEngine and neSceneManager singletons for SE playback, the root view controller,
 * and the pad flag.
 *
 * Method addresses (imp & ~1): initWithStyle: @ 0xd4180, initAtNavigationController @ 0xd4398,
 * dealloc @ 0xd4578, startOpenAnimation @ 0xd45ec, endOpenAnimation @ 0xd4718,
 * startCloseAnimation @ 0xd4730, endCloseAnimation @ 0xd4850, viewDidAppear: @ 0xd48bc,
 * viewDidLoad @ 0xd48e8, didReceiveMemoryWarning @ 0xd4914, numberOfSectionsInTableView: @
 * 0xd4940, tableView:numberOfRowsInSection: @ 0xd4944, tableView:heightForRowAtIndexPath: @
 * 0xd495c, tableView:cellForRowAtIndexPath: @ 0xd4a08, tableView:titleForHeaderInSection: @
 * 0xd5330, tableView:viewForHeaderInSection: @ 0xd5334, tableView:heightForHeaderInSection: @
 * 0xd54d4, tableView:accessoryTypeForRowWithIndexPath: @ 0xd54dc,
 * tableView:didSelectRowAtIndexPath: @ 0xd54f8, commonAlertView:clickedButtonAtIndex: @ 0xd579c,
 * settingClose @ 0xd5850, viewCmnDelegate @ 0xd5860, and setViewCmnDelegate: @ 0xd5870.
 *
 * It follows the shared modal view-controller lifecycle (see SettingTableViewController.h):
 * initAtNavigationController wraps self in a UINavigationController; startOpenAnimation and
 * startCloseAnimation fade the view and nav view; endCloseAnimation notifies the host via
 * -SettingEndCallBack.
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate (protocol_list @ 0x1552ac)

// ViewCmnProtocol is defined in ConversionView.h (declares
// -startCloseAnimation). This VC holds a weak (assign) id<ViewCmnProtocol>
// delegate and forwards it to the embedded ConversionView. Forward-declared
// here so the property type resolves without pulling ConversionView.h (and its
// Downloader/CommonAlertView deps) into this header; the .mm imports the real
// definition.
@protocol ViewCmnProtocol;

/**
 * The "Other" settings list, which embeds the device-change panel.
 */
@interface SettingOtherTableViewController : UITableViewController <CommonAlertViewDelegate>

/** The common "view delegate" handed down to the embedded ConversionView; the ivar is at
 * +0xac. */
@property(nonatomic, assign) id<ViewCmnProtocol> viewCmnDelegate;

/**
 * Wrap self in a fresh navigation controller with the back button.
 * @return The navigation controller.
 * @ghidraAddress 0xd4398
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the screen in.
 * @ghidraAddress 0xd45ec
 */
- (void)startOpenAnimation;
/**
 * Play the cancel SE and fade the screen out.
 * @ghidraAddress 0xd4730
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
