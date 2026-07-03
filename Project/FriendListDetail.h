//
//  FriendListDetail.h
//  pop'n rhythmin
//
//  The friend detail overlay pushed when a friend-list row is tapped: a translucent backdrop
//  behind a window that shows the friend's portrait (tap it for the FriendListDetailChara skill
//  card), name, player id, friendship value and a 3-difficulty x 6-row clear-count grid, plus an
//  unfriend button. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame:friendData: @ 0xb4280 and 14 more methods). Built in FriendListDetail.mm.
//

#import <UIKit/UIKit.h>

#import "Downloader.h"        // DownloaderDelegate (the unfriend POST)
#import "CommonAlertView.h"   // CommonAlertViewDelegate (confirm / result alerts)

@interface FriendListDetail : UIView <DownloaderDelegate, CommonAlertViewDelegate>

// `friendData` is an NSValue-wrapped FriendListData. `frame` covers the presenting view; the
// window itself is centred within it.
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData;

// Fade in (0.3s) / out (0.3s, then remove from superview).
- (void)startOpenAnimation;
- (void)startCloseAnimation;

// YES while presented (drives the list VC's tap/back guards). @ 0xb5c98.
- (BOOL)isEnabled;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
