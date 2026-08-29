/**
 * @file
 * The arcade (AC) viewer's per-song options screen.
 *
 * A small UITableView-backed list of four gameplay-option rows (HI-SPEED, POP-KUN, HID-SUD,
 * RAN-MIR), a custom header showing the chosen song's banner, difficulty banner and BPM, and, off
 * the AC-main flow, PLAY and CONTINUE buttons plus a back button. It is pushed into the AC-viewer
 * split panel's right navigation pane by AcViewerSplitViewController.endHiddenAnimation (which
 * sets itself as the delegate), and drives the shared fade open and close lifecycle.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0xdeff0, initForAcMain: @
 * 0xdfc0c, the table data source and delegate, the play, resume, and back actions, the sendLog
 * analytics POST, and the open and close fade animations).
 */

#import <UIKit/UIKit.h>

/**
 * The host that owns the split panel behind the options screen.
 *
 * When the player picks a song to play, or resumes an in-progress arcade play, the options screen
 * asks its delegate to hide the panel so the GL play scene shows through. In the binary the
 * _delegate ivar is typed id<AcViewerViewControllerDelegate> and is sent -startHiddenAnimation:.
 */
@protocol AcViewerViewControllerDelegate <NSObject>
/**
 * Hide the split panel so the play scene shows through.
 * @param animated YES to fade the panel out, NO to hide it after a short delay.
 */
- (void)startHiddenAnimation:(BOOL)animated;
@end

/**
 * The arcade viewer's per-song options screen.
 */
@interface AcViewerOptionViewController : UITableViewController

/** The host that hides the split panel. The binary stores the pointer raw, with no retain. Getter
 * @ 0xe0b20, setter @ 0xe0b30. */
@property(nonatomic, assign) id<AcViewerViewControllerDelegate> delegate;

class AcViewerTask; // C++ task (System/src/Task/AcViewerTask.h); this header is ObjC++
/**
 * Build the options screen for the arcade-main (in-game) flow.
 *
 * It sets _forAcMain, keeps the C++ task pointer, wraps itself in its own UINavigationController
 * and installs a back button.
 * @param acMain The C++ AcViewerTask, opaque here.
 * @return The initialised controller.
 * @ghidraAddress 0xdfc0c
 */
- (instancetype)initForAcMain:(AcViewerTask *)acMain;

/**
 * Fade the arcade-main navigation controller's view in over 0.3 s.
 * @ghidraAddress 0xe0820
 */
- (void)startOpenAnimationForAcMain;

/**
 * Fade the panel out over 0.3 s; on didStop it tears down via endCloseAnimation, or
 * endCloseAnimationForAcMain on the arcade-main flow.
 * @ghidraAddress 0xe0960
 */
- (void)startCloseAnimation;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
