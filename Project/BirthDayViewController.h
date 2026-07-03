//
//  BirthDayViewController.h
//  pop'n rhythmin
//
//  The age-gate modal shown before a purchase when no birthday is on record (Japan's
//  youth spending-limit compliance): a rounded, gradient-bordered panel that slides in
//  over a dimmed backdrop, showing an instruction text view, a YearAndMonthPicker, and
//  OK / Cancel / Decide buttons. Entering a birthday saves it and notifies the delegate
//  so the purchase flow can re-evaluate the limit. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (init @ 0x8396c, onOkBtn: @ 0x848d4, onDecideBtn: @ 0x84af0,
//  onCancelBtn: @ 0x84c30, startOpenAnimation @ 0x84c80, endOpenAnimation @ 0x84e70,
//  startCloseAnimation @ 0x84e84, endCloseAnimation @ 0x84fec).
//

#import <UIKit/UIKit.h>

@class BirthDayViewController;
@class YearAndMonthPicker;

@protocol BirthDayViewControllerDelegate <NSObject>
@optional
// The gate closed (a birthday was entered or the user cancelled). Ghidra selector
// birthDayViewClose (StorePackDetailViewPad implements it).
- (void)birthDayViewClose;
@end

@interface BirthDayViewController : UIViewController {
    BOOL m_IsAnimationing;          // an open/close animation is running (guards re-entry)
    UIView *_dummyView;            // full-screen touch blocker under the panel
    UIView *_borderView;           // outer gradient-bordered panel
    UIView *_infoView;             // instruction text container inside the border
    UIView *_subBorderView;        // the sliding inner panel (picker + buttons)
    UIView *_subView;              // content host inside the sub-border
    YearAndMonthPicker *_selectDate;  // the year/month wheel the birthday is read from
    id<BirthDayViewControllerDelegate> _delegate;   // not retained
}

@property (nonatomic, assign) id<BirthDayViewControllerDelegate> delegate;

// Slide the panel in from off-screen (above) and fade the dim backdrop up to 50%. Ghidra:
// startOpenAnimation @ 0x84c80.
- (void)startOpenAnimation;

// Slide the panel off-screen and fade the dim backdrop out; the didStop callback
// notifies the delegate. Ghidra: startCloseAnimation @ 0x84e84.
- (void)startCloseAnimation;

// OK button: reveal the picker panel (slide the info panel out and the picker sub-panel
// in). Ghidra: onOkBtn: @ 0x848d4.
- (void)onOkBtn:(id)sender;

// Cancel button: record the cancellation, then close. Ghidra: onCancelBtn: @ 0x84c30.
- (void)onCancelBtn:(id)sender;

// Decide button: read the year/month off the picker, save it as the birthday (the 15th of
// that month, noon), clear the cancel flag, then close. Ghidra: onDecideBtn: @ 0x84af0.
- (void)onDecideBtn:(id)sender;

// -init (@0x8396c, ~3.7 KB geometry) builds the bordered panels, gradient layers, instruction
// text view and buttons, and wires the picker + OK/Cancel/Decide buttons. Reconstructed from the
// NEON-spilled CGRect geometry (see the .mm); it overrides NSObject's -init so it is not declared
// here.

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
