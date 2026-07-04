//
//  SettingTopViewController.h
//  pop'n rhythmin
//
//  The top-level "settings" menu (the four-button カスタム screen): ゲーム (Game),
//  遊び方 (How-to), お問い合わせ (Customer/inquiry) and その他 (Other). On the phone
//  each button pushes the matching sub-screen onto its own navigation controller;
//  on the pad it forwards the tap to a delegate (the iPad settings host owns the
//  detail pane). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (init @ 0x13fe8 and 11 more methods). Built in SettingTopViewController.mm
//  (Objective-C++: drives the C++ neSceneManager / neEngine singletons).
//
//  Follows the app-wide modal-VC lifecycle (see SettingTableViewController.h):
//  initAtNavigationController wraps self in a UINavigationController; startOpen/
//  startCloseAnimation fade the view + nav view; endCloseAnimation notifies the
//  host via -[MainViewController SettingEndCallBack].
//

#import <UIKit/UIKit.h>

@class SettingTopViewController;

// The pad-layout host (the settings split/detail owner) receives the button taps so it can
// swap its own detail pane. NB: the binary spells the protocol "Dalegate" (typo preserved).
@protocol SettingTopViewControllerDalegate <NSObject>
- (void)onGameButtonTouched:(id)sender;      // @ 0x14964 (pad) forwards here
- (void)onHowtoButtonTouched:(id)sender;     // @ 0x14a90 (pad) forwards here
- (void)onCustomerButtonTouched:(id)sender;  // @ 0x14ae0 (pad) forwards here
- (void)onOtherButtonTouched:(id)sender;     // @ 0x14b30 (pad) forwards here
@end

@interface SettingTopViewController : UIViewController

// Lay out the four custom buttons over a "friman_bg" backdrop (phone) or a clear view (pad).
// Ghidra: init @ 0x13fe8.
- (instancetype)init;

// Build self, wrap it in a fresh navigation controller (with a back button + nav-bar art) and
// return that controller (the phone layout). Ghidra: initAtNavigationController @ 0x14464.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none)));

- (void)startOpenAnimation;    // @ 0x14694
- (void)startCloseAnimation;   // @ 0x147d8 (also the back-button action)

// The pad-layout tap target. Synthesized assign accessors: getter @ 0x14b80, setter @ 0x14b90.
@property (nonatomic, assign) id<SettingTopViewControllerDalegate> settingTopDelegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
