/**
 * @file
 * @brief The "Sound" sub-settings screen.
 *
 * It is embedded as the row-1 detail sub-controller of SettingGameTableViewController, which
 * imports SoundSettingView.h and instantiates it. A grouped table of volume sliders plus an
 * optional touch-sound ("hit sound") picker: section 0 (BGM ボリューム) is the BGM master volume
 * slider, linear over 0..1; section 1 (SE ボリューム) is the SE master volume slider over 0..127;
 * section 2 (タッチサウンド ボリューム) is the touch-sound volume slider over 0..127; and section
 * 3 (タッチサウンド) is the touch-sound kind picker, present only when the player owns two or more
 * unlocked touch sounds.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0x811c8 and 22
 * more methods). Built in SoundSettingView.mm, in Objective-C++ for the neSceneManager and
 * neEngine C++ bridge: isPadDisplay, the hit and normal sound-name tables, and the back-button
 * system SE. Volumes persist through UserSettingData; SE preview and playback go through
 * AudioManager (lib_rsnd).
 *
 * All values are committed on -dealloc: the BGM, SE, and touch volumes and the selected
 * touch-sound kind. The iPad build additionally persists each volume live as its slider moves.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The "Sound" sub-settings screen: the volume sliders and touch-sound picker.
 */
@interface SoundSettingView : UITableViewController

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
