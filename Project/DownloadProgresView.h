//
//  DownloadProgresView.h
//  pop'n rhythmin
//
//  A small download-progress dialog view. It draws a "cmn_window" dialog frame
//  and lays out, inside it, a spinning activity indicator, a single-line message
//  label and a horizontal progress bar. -layout: recenters the message label and
//  shows/hides the progress bar depending on whether a determinate progress bar
//  is wanted.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame: @ 0xde1d0, dealloc @ 0xde630 [release-only, omitted under ARC],
//  layout: @ 0xde65c, indicatorView @ 0xde708, labelMessage @ 0xde718,
//  progressView @ 0xde728).
//

#import <UIKit/UIKit.h>

@interface DownloadProgresView : UIView

// The centered spinner shown while the download is in flight.
// Synthesized getter — Ghidra: @ 0xde708 (ivar _indicatorView @ 0x34).
@property (nonatomic, strong, readonly) UIActivityIndicatorView *indicatorView;

// The single-line status/message label. Synthesized getter — Ghidra: @ 0xde718
// (ivar _labelMessage @ 0x38).
@property (nonatomic, strong, readonly) UILabel *labelMessage;

// The determinate download progress bar. Synthesized getter — Ghidra: @ 0xde728
// (ivar _progressView @ 0x3c).
@property (nonatomic, strong, readonly) UIProgressView *progressView;

// Re-lay the message label for the current mode and toggle the progress bar.
// hidden == NO  -> show the progress bar, label sits at dialog center + 5pt.
// hidden == YES -> hide the progress bar, label sits at dialog center + 10pt.
// Ghidra: @ 0xde65c.
- (void)layout:(BOOL)hidden;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
