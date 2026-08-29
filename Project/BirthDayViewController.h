/**
 * @file
 * The age-gate modal shown before a purchase when no birthday is on record.
 *
 * This is Japan's youth spending-limit compliance: a rounded, gradient-bordered panel that slides
 * in over a dimmed backdrop, showing an instruction text view, a YearAndMonthPicker, and OK,
 * Cancel, and Decide buttons. Entering a birthday saves it and notifies the delegate so the
 * purchase flow can re-evaluate the limit. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (init @ 0x8396c, onOkBtn: @ 0x848d4, onDecideBtn: @ 0x84af0, onCancelBtn: @
 * 0x84c30, startOpenAnimation @ 0x84c80, endOpenAnimation @ 0x84e70, startCloseAnimation @
 * 0x84e84, endCloseAnimation @ 0x84fec).
 */

#import <UIKit/UIKit.h>

@class BirthDayViewController;
@class YearAndMonthPicker;

/**
 * Receives notice that the age gate closed.
 */
@protocol BirthDayViewControllerDelegate <NSObject>
@optional
/**
 * The gate closed: a birthday was entered, or the user cancelled.
 *
 * StorePackDetailViewPad implements this.
 */
- (void)birthDayViewClose;
@end

/**
 * The age-gate modal shown before a purchase when no birthday is on record.
 */
@interface BirthDayViewController : UIViewController {
    /** An open or close animation is running; it guards against re-entry. */
    BOOL m_IsAnimationing;
    UIView *_dummyView;              /**< The full-screen touch blocker under the panel. */
    UIView *_borderView;             /**< The outer gradient-bordered panel. */
    UIView *_infoView;               /**< The instruction text container inside the border. */
    UIView *_subBorderView;          /**< The sliding inner panel holding the picker and buttons. */
    UIView *_subView;                /**< The content host inside the sub-border. */
    YearAndMonthPicker *_selectDate; /**< The year and month wheel the birthday is read from. */
    /** The close delegate; not retained. */
    id<BirthDayViewControllerDelegate> __unsafe_unretained _delegate;
}

/** The delegate notified when the gate closes. */
@property(nonatomic, assign) id<BirthDayViewControllerDelegate> delegate;

/**
 * Slide the panel in from off-screen above and fade the dim backdrop up to 50%.
 * @ghidraAddress 0x84c80
 */
- (void)startOpenAnimation;

/**
 * Slide the panel off-screen and fade the dim backdrop out; the didStop callback notifies
 * the delegate.
 * @ghidraAddress 0x84e84
 */
- (void)startCloseAnimation;

/**
 * The OK button: reveal the picker panel by sliding the info panel out and the picker
 * sub-panel in.
 * @param sender The tapped button.
 * @ghidraAddress 0x848d4
 */
- (void)onOkBtn:(id)sender;

/**
 * The Cancel button: record the cancellation, then close.
 * @param sender The tapped button.
 * @ghidraAddress 0x84c30
 */
- (void)onCancelBtn:(id)sender;

/**
 * The Decide button: read the year and month off the picker, save them as the birthday (the
 * 15th of that month, at noon), clear the cancel flag, then close.
 * @param sender The tapped button.
 * @ghidraAddress 0x84af0
 */
- (void)onDecideBtn:(id)sender;

// -init (@0x8396c, ~3.7 KB geometry) builds the bordered panels, gradient
// layers, instruction text view and buttons, and wires the picker +
// OK/Cancel/Decide buttons. Reconstructed from the NEON-spilled CGRect geometry
// (see the .mm); it overrides NSObject's -init so it is not declared here.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
