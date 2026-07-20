//
//  StoreViewController.h
//  pop'n rhythmin
//
//  The store's modal host: a UITabBarController with three tabs — the pack
//  store, the purchased-music manager, and the arcade-viewer manager — each
//  wrapped in a navigation controller with a custom back button and navbar
//  image. Presented with a cross-fade over the running GL scene; on close it
//  pushes/pops the menu BGM and calls back to the root view controller (unless
//  it was opened for a specific recommended pack).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithRecommendPackId: @ 0x53140   loadView @ 0x537d8   showAnimation @
//    0x53e88 showAnimationEnd @ 0x54030   hideAnimation @ 0x540b0
//    hideAnimationEnd @ 0x54178 pushBarBtnBack: @ 0x541e0   recommendPackId @
//    0x54424   setRecommendPackId: @ 0x54438 showModalDialog: @ 0x53b10
//    hideModalDialog @ 0x53cd8   modalDialog @ 0x54414
//    shouldAutorotateToInterfaceOrientation: @ 0x53e58   dealloc @ 0x53708
//

#import <UIKit/UIKit.h>

#import "StoreDialogView.h"

@interface StoreViewController : UITabBarController {
    UINavigationController *m_MainNavCtrl;      // pack store tab
    UINavigationController *m_ManageNavCtrl;    // purchased-music manager tab
    UINavigationController *m_AcvManageNavCtrl; // arcade-viewer manager tab
    BOOL m_Animation;                           // a fade is in progress
    UIView *m_CoverView;                        // dimming backdrop behind the modal dialog
    StoreDialogView *m_ModalDialog;             // the shared "please wait / abort" dialog
    BOOL m_IsModalDialogAnimation;              // a modal-dialog fade is in progress
}

// Present opened for a specific recommended pack id (0/negative = the plain
// store).
@property(nonatomic, assign) int recommendPackId;

// The shared modal "please wait / abort" dialog built in -loadView. Ghidra:
// modalDialog @ 0x54414.
@property(nonatomic, readonly) StoreDialogView *modalDialog;

- (instancetype)initWithRecommendPackId:(int)recommendPackId;

// Cross-fade the store in / out.
- (void)showAnimation;
- (void)hideAnimation;

// Fade the modal dialog / dimming cover in (with delegate) and out. Both return
// whether the requested transition started (showModalDialog: is a no-op while a
// fade is already running).
- (BOOL)showModalDialog:(id)delegate;
- (BOOL)hideModalDialog;

// Nav-bar back button target.
- (void)pushBarBtnBack:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
