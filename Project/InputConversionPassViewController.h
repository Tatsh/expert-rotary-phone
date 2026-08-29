/**
 * @file
 * The device-change "input pass-code" modal: the receiving side of the machine transfer.
 *
 * The player types the player id and the 6-digit convert pass issued on their old device into two
 * UITextFields, taps the decide button, and the screen POSTs uuid, player_id, and convert_code to
 * the convert endpoint. On success the full server-side save (player name and id, chara, tickets,
 * treasure points, invite and login-bonus state, per-music scores, treasure map progress, and
 * purchased chara tickets) is restored into UserSettingData and the Core Data stores, the collabo,
 * invite, login-bonus, and treasure music is re-opened, and a "done" alert is shown. Contrast
 * ConversionView, the issuing side that uploads the local save and shows the freshly-minted pass.
 * It is raised over the main menu inside its own UINavigationController on phone (see
 * -initAtNavigationController) or bare on pad, with a tap-to-dismiss cover view, and fades itself
 * in and out. MainViewController -GotoInConversionPass shows it; on close it calls back
 * -[MainViewController InConversionPassEndCallBack].
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: init @ 0x911d0,
 * initAtNavigationController @ 0x91e84, dealloc @ 0x92064 (releases _downloader only, so it is
 * ARC-omitted), onBackBtn @ 0x920b4, startOpenAnimation @ 0x920e8, endOpenAnimation @ 0x92220,
 * startCloseAnimation @ 0x92238, endCloseAnimation @ 0x92368, didReceiveMemoryWarning @ 0x9240c,
 * viewDidLoad @ 0x92438, viewDidUnload @ 0x92464, viewWillAppear: @ 0x92490, viewDidAppear: @
 * 0x924bc, viewWillDisappear: @ 0x924e8, viewDidDisappear: @ 0x92514, and
 * shouldAutorotateToInterfaceOrientation: @ 0x92540 (all super-only),
 * textFieldShouldBeginEditing: @ 0x9254c, textFieldShouldReturn: @ 0x92550,
 * touchedDecideButton: @ 0x925a4, textField:shouldChangeCharactersInRange:replacementString: @
 * 0x92664, downloaderFinished: @ 0x926e0, downloaderError: @ 0x93938,
 * startConversionHttpWithId:pass: @ 0x93a00, checkUsableCharacterForId: @ 0x93c38,
 * checkUsableCharacterForPass: @ 0x93cf0, commonAlertView:clickedButtonAtIndex: @ 0x93d80, and
 * handleTapCoverView @ 0x93d90.
 *
 * Built in InputConversionPassViewController.mm under ARC, where the SE and scene-root bridge
 * drives the C++ neEngine and neSceneManager singletons.
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate
#import "Downloader.h"      // DownloaderDelegate + Downloader ivar type

/**
 * The device-change pass-entry screen: player id plus convert pass.
 */
// Doxygen mis-parses an @interface whose line is wrapped before the ':' when an ivar block
// follows: it reports every protocol after the first as an undocumented ivar. Breaking inside the
// protocol list instead parses correctly, so the formatter is held off here.
// clang-format off
@interface InputConversionPassViewController : UIViewController <UITextFieldDelegate,
                                                                 DownloaderDelegate,
                                                                 CommonAlertViewDelegate> {
    UITextField *_idField;   /**< The player-id entry; at most 7 alphanumeric characters. */
    UITextField *_passField; /**< The convert-pass entry; at most 6 digits. */
    UIActivityIndicatorView *_indicator; /**< The spinner shown while the POST is in flight. */
    Downloader *_downloader; /**< The in-flight convert POST; nil when idle. */
    BOOL m_IsAnimationing;   /**< An open or close fade is running; it guards re-entry. */
    UIView *_coverView;      /**< The pad-only dimmed backdrop; a tap dismisses it. */
}
// clang-format on

/**
 * Build the controller and wrap it in a fresh UINavigationController with a custom back
 * button.
 * @return The navigation host the menu adds to the scene; phone only.
 * @ghidraAddress 0x91e84
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * Fade the panel in over 0.3 s, along with its embedded navigation view on phone.
 * @ghidraAddress 0x920e8
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
