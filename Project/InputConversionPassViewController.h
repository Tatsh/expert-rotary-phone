//
//  InputConversionPassViewController.h
//  pop'n rhythmin
//
//  The device-change "input pass-code" modal: the RECEIVING side of the machine
//  transfer. The player types the player-id and the 6-digit convert pass issued
//  on their old device into two UITextFields, taps the decide button, and the
//  screen POSTs {uuid, player_id, convert_code} to the convert endpoint. On
//  success the full server-side save (player name/id, chara, tickets, treasure
//  points, invite / login-bonus state, per-music scores, treasure map progress,
//  purchased chara tickets) is restored into UserSettingData + the Core Data
//  stores, the collabo / invite / login-bonus / treasure music is re-opened,
//  and a "done" alert is shown. (Contrast ConversionView, the ISSUING side that
//  uploads the local save and shows the freshly-minted pass.) It is raised over
//  the main menu inside its own UINavigationController (phone; see
//  -initAtNavigationController) or bare (pad, with a tap-to-dismiss cover
//  view), and fades itself in and out. Shown by MainViewController
//  -GotoInConversionPass; on close it calls back
//  -[MainViewController InConversionPassEndCallBack].
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    init                                                    @ 0x911d0
//    initAtNavigationController                              @ 0x91e84
//    dealloc                                                 @ 0x92064
//    (releases _downloader only -> ARC-omitted) onBackBtn @ 0x920b4
//    startOpenAnimation                                      @ 0x920e8
//    endOpenAnimation                                        @ 0x92220
//    startCloseAnimation                                     @ 0x92238
//    endCloseAnimation                                       @ 0x92368
//    didReceiveMemoryWarning                                 @ 0x9240c
//    (super-only) viewDidLoad                                             @
//    0x92438  (super-only) viewDidUnload @ 0x92464  (super-only)
//    viewWillAppear:                                         @ 0x92490
//    (super-only) viewDidAppear:                                          @
//    0x924bc  (super-only) viewWillDisappear: @ 0x924e8  (super-only)
//    viewDidDisappear:                                       @ 0x92514
//    (super-only) shouldAutorotateToInterfaceOrientation:                 @
//    0x92540 textFieldShouldBeginEditing:                            @ 0x9254c
//    textFieldShouldReturn:                                  @ 0x92550
//    touchedDecideButton:                                    @ 0x925a4
//    textField:shouldChangeCharactersInRange:replacementString: @ 0x92664
//    downloaderFinished:                                     @ 0x926e0
//    downloaderError:                                        @ 0x93938
//    startConversionHttpWithId:pass:                         @ 0x93a00
//    checkUsableCharacterForId:                              @ 0x93c38
//    checkUsableCharacterForPass:                            @ 0x93cf0
//    commonAlertView:clickedButtonAtIndex:                   @ 0x93d80
//    handleTapCoverView                                      @ 0x93d90
//  Built in InputConversionPassViewController.mm (Objective-C++: the SE /
//  scene-root bridge drives the C++ neEngine / neSceneManager singletons). ARC.
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate
#import "Downloader.h"      // DownloaderDelegate + Downloader ivar type

@interface InputConversionPassViewController
    : UIViewController <UITextFieldDelegate, DownloaderDelegate, CommonAlertViewDelegate> {
    UITextField *_idField;               // player-id entry (max 7 chars, alnum)
    UITextField *_passField;             // convert-pass entry (max 6 chars, digits)
    UIActivityIndicatorView *_indicator; // spinner shown while the POST is in flight
    Downloader *_downloader;             // in-flight convert POST (nil when idle)
    BOOL m_IsAnimationing;               // an open/close fade is running (guards re-entry)
    UIView *_coverView;                  // pad-only dimmed backdrop; tap dismisses
}

// Build the controller, wrap it in a fresh UINavigationController with a custom
// back button and return that host (the value the menu adds to the scene, phone
// only). Ghidra: @ 0x91e84.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

// Fade the panel (and, on phone, its embedded nav view) in over 0.3 s. Ghidra:
// @ 0x920e8.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
