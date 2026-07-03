//
//  StoreDialogView.h
//  pop'n rhythmin
//
//  A modal progress dialog shown over the store view (StoreViewController /
//  StoreMainViewController): a rounded, shadowed, translucent-black card that owns a spinner,
//  a centered message label, a horizontal progress bar and — when constructed abortable — a
//  "中止" (abort) button. -layout: toggles the progress bar / abort button and recenters the
//  message label; the abort button routes to the delegate's -storeDialogCancel:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame: @ 0x416dc, initWithFrame:abortable: @ 0x41708, dealloc @ 0x41dc0,
//  layout: @ 0x41e4c, btnAbort: @ 0x41f38).
//
//  Superclass is UIView (the card itself is the styled background; the spinner/label/progress/
//  button are direct subviews). Written for ARC: no manual retain/release/autorelease; the
//  binary's -dealloc only release-chains the object ivars and is omitted.
//
//  Delegate note: the binary carries NO StoreDialogViewDelegate protocol metadata — the abort
//  callback is an informal, respondsToSelector:-gated delegate (see -btnAbort: @ 0x41f38, which
//  does -performSelector:@selector(storeDialogCancel:) withObject:self). The protocol below is a
//  reconstruction convenience so the callback is typed and discoverable; the selector matches the
//  -storeDialogCancel: implemented by StoreMainViewController.
//

#import <UIKit/UIKit.h>

@protocol StoreDialogViewDelegate <NSObject>
@optional
// Sent when the abort button is tapped. The passed object is the dialog itself.
// Invoked from -btnAbort: @ 0x41f38 via -performSelector:withObject:.
- (void)storeDialogCancel:(id)sender;
@end

@interface StoreDialogView : UIView {
    UIActivityIndicatorView *m_IndicatorView;   // spinner
    UILabel *m_LabelMessage;                    // centered status message
    UIProgressView *m_ProgressView;             // horizontal progress bar
    UIButton *m_ButtonAbort;                    // "中止" button (only when abortable)
    id delegate;                                // informal delegate (assign)
}

// Convenience initializer: forwards to -initWithFrame:abortable: with abortable = YES
// (mov lr,#1 pushed to the abortable arg slot). Ghidra: @ 0x416dc.
- (instancetype)initWithFrame:(CGRect)frame;

// Designated initializer. Builds the rounded/shadowed card, the spinner, the message label and
// the progress bar; when abortable is YES also builds the "中止" button wired to -btnAbort:.
// Ghidra: @ 0x41708.
- (instancetype)initWithFrame:(CGRect)frame abortable:(BOOL)abortable;

// Toggle the progress bar + abort button and recenter the message label. When hideControls is NO
// the progress bar and abort button are shown and the label sits 10pt above the card center; when
// YES they are hidden and the label sits 10pt below center. Ghidra: @ 0x41e4c.
- (void)layout:(BOOL)hideControls;

// Abort button action: forwards -storeDialogCancel: to the delegate if it responds. Ghidra: @ 0x41f38.
- (void)btnAbort:(id)sender;

// Informal delegate; raw assign (unsafe_unretained under ARC). getter @ 0x41f8c, setter @ 0x41f9c.
@property (nonatomic, assign) id<StoreDialogViewDelegate> delegate;

// Read-only accessors for the subviews (synthesized). Callers drive these via -performSelector:.
@property (nonatomic, readonly) UIActivityIndicatorView *indicatorView;  // @ 0x41fac
@property (nonatomic, readonly) UILabel *labelMessage;                   // @ 0x41fbc
@property (nonatomic, readonly) UIProgressView *progressView;            // @ 0x41fcc
@property (nonatomic, readonly) UIButton *buttonAbort;                   // @ 0x41fdc

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
