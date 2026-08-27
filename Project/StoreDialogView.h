//
//  StoreDialogView.h
//  pop'n rhythmin
//
//  A modal progress dialog shown over the store view (StoreViewController /
//  StoreMainViewController): a rounded, shadowed, translucent-black card that
//  owns a spinner, a centered message label, a horizontal progress bar and —
//  when constructed abortable — a "中止" (abort) button. -layout: toggles the
//  progress bar / abort button and recenters the message label; the abort
//  button routes to the delegate's -storeDialogCancel:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame: @ 0x416dc, initWithFrame:abortable: @ 0x41708, dealloc @
//  0x41dc0, layout: @ 0x41e4c, btnAbort: @ 0x41f38).
//
//  Superclass is UIView (the card itself is the styled background; the
//  spinner/label/progress/ button are direct subviews). Written for ARC: no
//  manual retain/release/autorelease; the binary's -dealloc only release-chains
//  the object ivars and is omitted.
//
//  Delegate note: the binary carries NO StoreDialogViewDelegate protocol
//  metadata — the abort callback is an informal, respondsToSelector:-gated
//  delegate (see -btnAbort: @ 0x41f38, which does
//  -performSelector:@selector(storeDialogCancel:) withObject:self). The
//  protocol below is a reconstruction convenience so the callback is typed and
//  discoverable; the selector matches the -storeDialogCancel: implemented by
//  StoreMainViewController.
//

#import <UIKit/UIKit.h>

/**
 * @brief Receives the store dialog's abort tap.
 */
@protocol StoreDialogViewDelegate <NSObject>
@optional
/**
 * @brief The abort button was tapped. -btnAbort: sends it via -performSelector:withObject:.
 * @param sender The dialog itself.
 */
- (void)storeDialogCancel:(id)sender;
@end

/**
 * @brief The store's progress dialog: a spinner, a status message, a progress bar and an optional
 * abort button.
 */
@interface StoreDialogView : UIView {
    UIActivityIndicatorView *m_IndicatorView; /**< The spinner. */
    UILabel *m_LabelMessage;                  /**< The centred status message. */
    UIProgressView *m_ProgressView;           /**< The horizontal progress bar. */
    UIButton *m_ButtonAbort;                  /**< The "中止" button, only when abortable. */
    id __unsafe_unretained delegate;          /**< The informal delegate; a plain assign. */
}

/**
 * @brief The convenience initialiser, forwarding to -initWithFrame:abortable: with abortable set.
 * @param frame The dialog frame.
 * @return The initialised dialog.
 * @ghidraAddress 0x416dc
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The designated initialiser: build the rounded, shadowed card, the spinner, the message
 * label and the progress bar.
 * @param frame The dialog frame.
 * @param abortable YES to also build the "中止" button, wired to -btnAbort:.
 * @return The initialised dialog.
 * @ghidraAddress 0x41708
 */
- (instancetype)initWithFrame:(CGRect)frame abortable:(BOOL)abortable;

/**
 * @brief Toggle the progress bar and abort button, and recentre the message label.
 * @param hideControls NO shows the progress bar and abort button and puts the label 10 pt above
 * the card centre; YES hides them and puts the label 10 pt below centre.
 * @ghidraAddress 0x41e4c
 */
- (void)layout:(BOOL)hideControls;

/**
 * @brief The abort button's action: forward -storeDialogCancel: to the delegate when it responds.
 * @param sender The tapped button.
 * @ghidraAddress 0x41f38
 */
- (void)btnAbort:(id)sender;

/** The abort delegate; a raw assign, unsafe-unretained under ARC. Getter @ 0x41f8c, setter @
 * 0x41f9c. */
@property(nonatomic, assign) id<StoreDialogViewDelegate> delegate;

// Read-only subview accessors; callers drive these via -performSelector:.

/** The spinner. Getter @ 0x41fac. */
@property(nonatomic, readonly) UIActivityIndicatorView *indicatorView;
/** The status message label. Getter @ 0x41fbc. */
@property(nonatomic, readonly) UILabel *labelMessage;
/** The progress bar. Getter @ 0x41fcc. */
@property(nonatomic, readonly) UIProgressView *progressView;
/** The abort button. Getter @ 0x41fdc. */
@property(nonatomic, readonly) UIButton *buttonAbort;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
