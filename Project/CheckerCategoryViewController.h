//
//  CheckerCategoryViewController.h
//  pop'n rhythmin
//
//  The music-checker's genre-category list: a transparent, separator-less grouped
//  UITableView (one CheckerCategoryCell per non-empty category) with a "get data"
//  button in its header that syncs the player's arcade scores over HTTP. Selecting
//  a row pushes the CheckerMusicViewController song list for that category. A dimmed
//  "dummy" cover view + spinner is shown while a sync is in flight.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle: @ 0xcfb88, the score-sync download flow, the table data source /
//  delegate and the header actions).
//
//  .mm because it drives the C++ "ne" engine singletons via neEngineBridge (scene-
//  manager pad flag, the system-SE hooks and the e-AMUSEMENT login context).
//

#import <UIKit/UIKit.h>

@interface CheckerCategoryViewController : UITableViewController

// Build the transparent grouped table, the header "get data" button + spinner cover,
// and load the locally-cached arcade scores into 25 per-category buckets (24 genres +
// a "latest 10" bucket). Ghidra: initWithStyle: @ 0xcfb88.
- (instancetype)initWithStyle:(UITableViewStyle)style;

// Kick off the arcade-score HTTP sync, POSTing the konami-id / password / one-time
// password (`otp` may be nil). Called back by the OTP-input screen once the code is
// entered. Ghidra: startGetArcadeScoreHttpWithOtp: @ 0xd06b4.
- (void)startGetArcadeScoreHttpWithOtp:(NSString *)otp;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
