/**
 * @file
 * The store's modal host.
 *
 * A UITabBarController with three tabs — the pack store, the purchased-music manager, and the
 * arcade-viewer manager — each wrapped in a navigation controller with a custom back button and
 * navbar image. It is presented with a cross-fade over the running GL scene; on close it pushes
 * and pops the menu BGM and calls back to the root view controller, unless it was opened for a
 * specific recommended pack.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin: initWithRecommendPackId: @
 * 0x53140, loadView @ 0x537d8, showAnimation @ 0x53e88, showAnimationEnd @ 0x54030, hideAnimation
 * @ 0x540b0, hideAnimationEnd @ 0x54178, pushBarBtnBack: @ 0x541e0, recommendPackId @ 0x54424,
 * setRecommendPackId: @ 0x54438, showModalDialog: @ 0x53b10, hideModalDialog @ 0x53cd8,
 * modalDialog @ 0x54414, shouldAutorotateToInterfaceOrientation: @ 0x53e58, and dealloc @ 0x53708.
 */

#import <UIKit/UIKit.h>

#import "StoreDialogView.h"

/**
 * The store's tab host: the pack catalogue, the purchased-music manager and the
 * arcade-viewer manager, plus the shared modal progress dialog.
 */
@interface StoreViewController : UITabBarController {
    UINavigationController *m_MainNavCtrl;      /**< The pack store tab. */
    UINavigationController *m_ManageNavCtrl;    /**< The purchased-music manager tab. */
    UINavigationController *m_AcvManageNavCtrl; /**< The arcade-viewer manager tab. */
    BOOL m_Animation;                           /**< A fade is in progress. */
    UIView *m_CoverView;            /**< The dimming backdrop behind the modal dialog. */
    StoreDialogView *m_ModalDialog; /**< The shared "please wait / abort" dialog. */
    BOOL m_IsModalDialogAnimation;  /**< A modal-dialog fade is in progress. */
}

/** The recommended pack to open on; 0 or negative opens the plain store. */
@property(nonatomic, assign) int recommendPackId;

/** The shared "please wait / abort" dialog, built in -loadView. Getter @ 0x54414. */
@property(nonatomic, readonly) StoreDialogView *modalDialog;

/**
 * Build the store, optionally opening on a recommended pack.
 * @param recommendPackId The pack to open on; 0 or negative for the plain store.
 * @return The initialised controller.
 */
- (instancetype)initWithRecommendPackId:(int)recommendPackId;

/**
 * Cross-fade the store in.
 */
- (void)showAnimation;
/**
 * Cross-fade the store out.
 */
- (void)hideAnimation;

/**
 * Fade the modal dialog and its dimming cover in.
 * @param delegate The abort delegate for the dialog.
 * @return YES when the transition started; it is a no-op while a fade is already running.
 */
- (BOOL)showModalDialog:(id)delegate;
/**
 * Fade the modal dialog and its dimming cover out.
 * @return YES when the transition started.
 */
- (BOOL)hideModalDialog;

/**
 * The nav-bar back button's target.
 * @param sender The tapped button.
 */
- (void)pushBarBtnBack:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
