//
//  SoundSettingView.h
//  pop'n rhythmin
//
//  The "Sound" sub-settings screen, embedded as the row-1 detail sub-controller
//  of SettingGameTableViewController (which imports SoundSettingView.h and
//  instantiates it). A grouped table of volume sliders plus an optional
//  touch-sound ("hit sound") picker:
//
//    * Section 0  "BGM ボリューム"          -- BGM master volume slider (linear
//    0..1)
//    * Section 1  "SE ボリューム"           -- SE master volume slider (0..127)
//    * Section 2  "タッチサウンド ボリューム" -- touch-sound volume slider
//    (0..127)
//    * Section 3  "タッチサウンド"           -- touch-sound kind picker (only
//    present when
//                                            the player owns >= 2 unlocked
//                                            touch sounds)
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0x811c8 and 22 more methods). Built in
//  SoundSettingView.mm. Objective-C++ for the neSceneManager / neEngine C++
//  bridge (isPadDisplay, hit/normal sound-name tables, the back-button system
//  SE). Volumes persist through UserSettingData; SE preview and playback go
//  through AudioManager (lib_rsnd).
//
//  All values are committed on -dealloc (BGM/SE/touch volume + selected
//  touch-sound kind); the iPad build additionally persists each volume live as
//  its slider moves.
//

#import <UIKit/UIKit.h>

@interface SoundSettingView : UITableViewController

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
