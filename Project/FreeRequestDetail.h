//
//  FreeRequestDetail.h
//  pop'n rhythmin
//
//  The "free request" friend-request confirm overlay raised by
//  FreeRequestListViewController when a recommended-friend row is tapped. A
//  full-screen dimmed UIView carrying a "frilis_window" card: the friend's
//  character art, name and player-id, a per-difficulty clear-medal / perfect /
//  full-combo count sheet, and (when the row carries a player id) "request" +
//  "cancel" buttons. Confirming POSTs the friend request through Downloader;
//  the result is reported via a CommonAlertView. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (initWithFrame:friendData: @ 0xe3170 and
//  14 more methods). Built in FreeRequestDetail.mm (Objective-C++: drives the
//  C++ neSceneManager / neEngine singletons).
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate (result / error alerts)
#import "Downloader.h"      // Downloader + DownloaderDelegate

@interface FreeRequestDetail : UIView <DownloaderDelegate, CommonAlertViewDelegate>

// Build the overlay for one recommended-friend row. `frame` is the host
// superview's frame (full screen); `friendData` is the NSValue-wrapped
// FriendListData (see DownloadMain.h) whose playerId / name / charaId / rank
// tallies drive the card. Ghidra: @ 0xe3170.
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData;

// Fade the card in (alpha 0 -> 1 over 0.3s); marks the overlay enabled +
// animating. Ghidra: @ 0xe42f8.
- (void)startOpenAnimation;

// YES while an open/close animation is running. Ghidra: @ 0xe4994.
@property(nonatomic, readonly, getter=isAnimationing) BOOL animationing;
// YES while the overlay is on screen and interactive (the owning list blocks
// its own back button while this is set). Ghidra: @ 0xe49ac.
@property(nonatomic, readonly, getter=isEnabled) BOOL enabled;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
