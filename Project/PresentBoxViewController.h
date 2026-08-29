/**
 * @file
 * The "present box", or gift inbox, modal.
 *
 * A UITableViewController listing the player's pending server presents, one PresentBoxCell per
 * row, plus an "acquire all" button and an empty-state banner. It is raised over the main menu
 * inside its own UINavigationController (see -initAtNavigationController) and slides itself in and
 * out with a fade on phone or a frame-slide on pad. Presents are fetched and claimed through the
 * DownloadMain singleton, with this controller registered as its present-list and present-claim
 * delegate, and each claim is confirmed through a CustomAlertView.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: initWithStyle: @ 0x24098,
 * initAtNavigationController @ 0x24938, dealloc @ 0x24988, viewDidLoad @ 0x24abc, viewWillAppear:
 * @ 0x24ba4, didReceiveMemoryWarning @ 0x24c6c, startOpenAnimation @ 0x24c98, endOpenAnimation @
 * 0x2514c, startCloseAnimation @ 0x25160, endCloseAnimation @ 0x255bc,
 * numberOfSectionsInTableView: @ 0x25628, tableView:numberOfRowsInSection: @ 0x2562c,
 * tableView:cellForRowAtIndexPath: @ 0x25668, downloadMainFinished: @ 0x257a8, backButtonFunc @
 * 0x25cdc, allGetFunc @ 0x25d48, indexPathForControlEvent: @ 0x25db4, touchedGetButton:event: @
 * 0x25e34, customAlertView:clickedButtonAtIndex: @ 0x260a4, and isAnimationing @ 0x26144.
 */

#import <UIKit/UIKit.h>

#import "CustomAlertView.h" // CustomAlertViewDelegate

/**
 * The present box: the list of unclaimed gifts.
 */
@interface PresentBoxViewController : UITableViewController <CustomAlertViewDelegate>

/**
 * Build the controller and wrap it in a fresh portrait-style UINavigationController.
 * @return The navigation host the menu pushes into the scene.
 * @ghidraAddress 0x24938
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Slide or fade the box in. MainViewController drives it when showing the present box.
 * @ghidraAddress 0x24c98
 */
- (void)startOpenAnimation;
/**
 * Slide or fade the box out. MainViewController drives it when dismissing the present box.
 * @ghidraAddress 0x25160
 */
- (void)startCloseAnimation;

/**
 * Whether an open or close animation is in flight; the host polls it to gate input. The
 * read is atomic.
 * @return YES while a transition is running.
 * @ghidraAddress 0x26144
 */
- (BOOL)isAnimationing;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
