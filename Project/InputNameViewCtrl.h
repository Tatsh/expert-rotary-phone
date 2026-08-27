//
//  InputNameViewCtrl.h
//  pop'n rhythmin
//
//  The "register a player name" entry screen. On phone it is a full-screen
//  "friman_bg" form (a <= 12-char ASCII name field, a decide button and the
//  "inputname_text_*" caption images); on pad (neSceneManager::isPadDisplay) it
//  is a floating rounded navigation-card panel over a dimmed backdrop, with the
//  caption drawn as DFSoGei labels instead of images. Submitting a non-empty,
//  valid name POSTs "uuid=<uuid>&name=<name>&client_ver=<n>" to StoreUtil
//  +playerNewURL; on success it saves the returned PlayerId + name via
//  UserSettingData and fades the panel out (notifying the scene root
//  -InPlayerNameEndCallBack).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @
//  0x8f438, startPlayerNewHttp: @ 0x90f14, checkUsableCharacter: @ 0x91108).
//
//  .mm because the decide / cancel flow drives the C++ neEngine /
//  neSceneManager singletons via neEngineBridge.
//

#import <UIKit/UIKit.h>

#import "Downloader.h" // DownloaderDelegate

/**
 * @brief The player-name entry screen.
 */
@interface InputNameViewCtrl : UIViewController <UITextFieldDelegate, DownloaderDelegate> {
    UITextField *_nameField;             /**< The player-name entry; at most 12 ASCII characters. */
    UIActivityIndicatorView *_indicator; /**< The in-flight spinner; it hides when stopped. */
    Downloader *_downloader;             /**< The in-flight "new player" POST; nil when idle. */
    BOOL m_IsAnimationing;               /**< The open and close fade guard. */
}

/**
 * @brief Wrap a freshly-built controller in a UINavigationController, with the back button hidden
 * and the "inputname_navbar" bar background.
 * @return The navigation host.
 * @ghidraAddress 0x90668
 */
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the panel and its navigation view in; guarded by m_IsAnimationing.
 * @ghidraAddress 0x90740
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the panel and its navigation view out; guarded by m_IsAnimationing.
 * @ghidraAddress 0x90890
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
