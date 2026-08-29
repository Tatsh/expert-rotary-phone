/**
 * @file
 * @brief The friend detail overlay pushed when a friend-list row is tapped.
 *
 * A translucent backdrop behind a window that shows the friend's portrait (tap it for the
 * FriendListDetailChara skill card), name, player id, friendship value, and a 3-difficulty by
 * 6-row clear-count grid, plus an unfriend button. Reconstructed from Ghidra project rb420,
 * program PopnRhythmin (initWithFrame:friendData: @ 0xb4280 and 14 more methods). Built in
 * FriendListDetail.mm.
 */

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate (confirm / result alerts)
#import "Downloader.h"      // DownloaderDelegate (the unfriend POST)

/**
 * @brief The friend detail overlay pushed when a friend-list row is tapped.
 */
@interface FriendListDetail : UIView <DownloaderDelegate, CommonAlertViewDelegate>

/**
 * @brief Build the overlay for one friend.
 * @param frame The frame covering the presenting view; the window itself is centred within it.
 * @param friendData An NSValue-wrapped FriendListData.
 * @return The initialised overlay.
 * @ghidraAddress 0xb4280
 */
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData;

/**
 * @brief Fade the overlay in over 0.3 s.
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the overlay out over 0.3 s, then remove it from its superview.
 */
- (void)startCloseAnimation;

/**
 * @brief Whether the overlay is presented; it drives the list controller's tap and back guards.
 * @return YES while presented.
 * @ghidraAddress 0xb5c98
 */
- (BOOL)isEnabled;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
