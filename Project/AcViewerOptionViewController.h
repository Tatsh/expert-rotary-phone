//
//  AcViewerOptionViewController.h
//  pop'n rhythmin
//
//  The arcade (AC) viewer's per-song options screen: a small UITableView-backed list of
//  four gameplay-option rows (HI-SPEED / POP-KUN / HID-SUD / RAN-MIR), a custom header
//  showing the chosen song's banner, difficulty banner and BPM, and — off the AC-main
//  flow — PLAY / CONTINUE buttons plus a back button. It is pushed into the AC-viewer
//  split panel's right navigation pane by AcViewerSplitViewController.endHiddenAnimation
//  (which sets itself as the delegate), and drives the shared fade open/close lifecycle.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xdeff0,
//  initForAcMain: @ 0xdfc0c, the table data source / delegate, the play/resume/back
//  actions, the sendLog analytics POST, and the open/close fade animations).
//

#import <UIKit/UIKit.h>

// Host that owns the split panel behind this options screen. When the player picks a
// song to play (or resumes an in-progress AC play), the options screen asks its delegate
// to hide the panel so the GL play scene shows through. Ghidra: the _delegate ivar is
// typed id<AcViewerViewControllerDelegate> and is sent -startHiddenAnimation:.
@protocol AcViewerViewControllerDelegate <NSObject>
- (void)startHiddenAnimation:(BOOL)animated;
@end

@interface AcViewerOptionViewController : UITableViewController

// Synthesized accessors: delegate getter @ 0xe0b20, setDelegate: @ 0xe0b30 (assign — the
// binary stores the pointer raw, with no retain).
// @ 0xe0b20
// @ 0xe0b30
@property (nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

// Build the options screen for the AC-main (in-game) flow: sets _forAcMain, keeps the
// C++ AcViewerTask pointer, wraps itself in its own UINavigationController and installs a
// back button. `acMain` is the C++ AcViewerTask* (opaque here). Ghidra: initForAcMain: @ 0xdfc0c.
class AcViewerTask;   // C++ task (System/src/Task/AcViewerTask.h); this header is ObjC++
- (instancetype)initForAcMain:(AcViewerTask *)acMain;

// Fade the AC-main nav controller's view in over 0.3 s. Ghidra: startOpenAnimationForAcMain @ 0xe0820.
- (void)startOpenAnimationForAcMain;

// Fade the panel out over 0.3 s; on didStop tears down (endCloseAnimation, or, on the
// AC-main flow, endCloseAnimationForAcMain). Ghidra: startCloseAnimation @ 0xe0960.
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
