/**
 * @file
 * @brief A small download-progress dialog view.
 *
 * It draws a "cmn_window" dialog frame and lays out, inside it, a spinning activity indicator, a
 * single-line message label, and a horizontal progress bar. -layout: recentres the message label
 * and shows or hides the progress bar depending on whether a determinate progress bar is wanted.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithFrame: @ 0xde1d0,
 * dealloc @ 0xde630 (release-only, omitted under ARC), layout: @ 0xde65c, indicatorView @
 * 0xde708, labelMessage @ 0xde718, progressView @ 0xde728).
 */

#import <UIKit/UIKit.h>

/**
 * @brief A small download-progress dialog: a "cmn_window" frame around a spinner, a message label
 * and a progress bar.
 */
@interface DownloadProgresView : UIView

/** The centred spinner shown while the download is in flight; the ivar is _indicatorView @ +0x34.
 * Getter @ 0xde708. */
@property(nonatomic, strong, readonly) UIActivityIndicatorView *indicatorView;

/** The single-line status message label; the ivar is _labelMessage @ +0x38. Getter @ 0xde718. */
@property(nonatomic, strong, readonly) UILabel *labelMessage;

/** The determinate download progress bar; the ivar is _progressView @ +0x3c. Getter @
 * 0xde728. */
@property(nonatomic, strong, readonly) UIProgressView *progressView;

/**
 * @brief Re-lay the message label for the current mode and toggle the progress bar.
 * @param hidden NO shows the progress bar and puts the label 5 pt below the dialog centre; YES
 * hides the bar and puts the label 10 pt below the centre.
 * @ghidraAddress 0xde65c
 */
- (void)layout:(BOOL)hidden;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
