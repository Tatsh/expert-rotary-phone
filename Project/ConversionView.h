//
//  ConversionView.h
//  pop'n rhythmin
//
//  The "device change" (kishu henkou / data-transfer) panel embedded into the
//  "Other" settings screen (SettingOtherTableViewController, section 2 row 1).
//  It shows a caution notice and a how-to, and — when the user confirms — POSTs
//  the player's full local save (purchases, got characters, per-music scores,
//  treasure progress, chara tickets) to the convert-code endpoint via
//  Downloader. On success it shows the issued "device change pass", offers to
//  mail it or wipe-and-return to the title. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (ConversionView @ 0x1be48..0x1de8c).
//
//  .mm because it drives the C++ neEngine / neSceneManager singletons (system
//  SE, root view controller) and goes through the Downloader bridge.
//

#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate
#import "Downloader.h"      // DownloaderDelegate

// ViewCmnProtocol — the embedded panel forwards a "close the whole settings
// overlay" message up to its container through this weak delegate. Only
// -startCloseAnimation is invoked on it (see -commonAlertView:...). This is the
// protocol's canonical declaration; SettingOtherTableViewController.h
// forward-declares it (@protocol ViewCmnProtocol;) and pulls in this header
// from its .mm.
@protocol ViewCmnProtocol <NSObject>
- (void)startCloseAnimation;
@end

@interface ConversionView : UIViewController <CommonAlertViewDelegate, DownloaderDelegate>

// The container ("view common") delegate. The accessors are a plain pointer
// load/store in the binary (no objc_storeWeak / retain), i.e.
// unsafe-unretained, matching CommonAlertView's delegate. Ghidra: -delegate @
// 0x1de7c, -setDelegate: @ 0x1de8c.
@property(nonatomic, assign) id<ViewCmnProtocol> delegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
