/**
 * @file
 * The modal "communicating…" network-activity overlay.
 *
 * A centred window backdrop (cmn_window) with a spinning UIActivityIndicatorView and a
 * "communicating" caption (mes_loading), plus a "communication failed" caption (mes_loadingerror)
 * that -failed reveals. It fades itself in (-startOpenAnimation) and out (-startCloseAnimation),
 * and while the failure caption is visible a tap dismisses it. On close it removes its view and
 * calls -CommunicatingEndCallBack on the scene manager's root view controller. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (-init @ 0xde740, -viewDidLoad @ 0xdec30).
 *
 * Despite the "View" name this is a UIViewController subclass: it overrides -viewDidLoad and
 * -didReceiveMemoryWarning and builds its hierarchy under self.view.
 */

#import <UIKit/UIKit.h>

/**
 * A modal "communicating…" network-activity overlay.
 */
@interface CommunicatingView : UIViewController {
    UIImageView *communicatingView;         /**< +0xa4 The "communicating" caption (mes_loading). */
    UIImageView *communicateFailedView;     /**< +0xa8 The "failed" caption (mes_loadingerror). */
    UIActivityIndicatorView *indicatorView; /**< +0xac The spinner. */
    BOOL _isAnimationing;                   /**< +0xb0 A fade animation is in flight. */
    BOOL _isCloseReserve;                   /**< +0xb1 A close was requested mid-animation. */
}

/**
 * Switch the overlay to its "communication failed" state: hide the spinner and the
 * "communicating" caption, and reveal the "failed" caption.
 * @ghidraAddress 0xdecb4
 */
- (void)failed;

/**
 * Fade the overlay in, alpha 0 to 1 over 0.3 s.
 * @ghidraAddress 0xded10
 */
- (void)startOpenAnimation;

/**
 * Fade the overlay out, alpha 1 to 0 over 0.3 s, then tear it down. If a fade is already
 * running the close is deferred; see _isCloseReserve.
 * @ghidraAddress 0xdee48
 */
- (void)startCloseAnimation;

/**
 * Whether a fade animation is running. The read is atomic.
 * @return YES while a fade is in flight.
 * @ghidraAddress 0xdefd8
 */
- (BOOL)isAnimationing;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
