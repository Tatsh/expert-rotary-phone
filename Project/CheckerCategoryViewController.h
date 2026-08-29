/**
 * @file
 * The music-checker's genre-category list.
 *
 * A transparent, separator-less grouped UITableView (one CheckerCategoryCell per non-empty
 * category) with a "get data" button in its header that syncs the player's arcade scores over
 * HTTP. Selecting a row pushes the CheckerMusicViewController song list for that category. A
 * dimmed "dummy" cover view and spinner are shown while a sync is in flight.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithStyle: @ 0xcfb88, the
 * score-sync download flow, the table data source and delegate, and the header actions).
 *
 * The implementation is .mm because it drives the C++ "ne" engine singletons via neEngineBridge:
 * the scene-manager pad flag, the system-SE hooks, and the e-AMUSEMENT login context.
 */

#import <UIKit/UIKit.h>

/**
 * The music-checker's genre-category list.
 */
@interface CheckerCategoryViewController : UITableViewController

/**
 * Build the transparent grouped table and the header "get data" button and spinner cover,
 * then load the locally-cached arcade scores into 25 per-category buckets: 24 genres plus a
 * "latest 10" bucket.
 * @param style The table style.
 * @return The initialised controller.
 * @ghidraAddress 0xcfb88
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * Kick off the arcade-score HTTP sync, posting the KONAMI ID, password and one-time
 * password. The OTP-input screen calls it back once the code is entered.
 * @param otp The one-time password, or nil when none is required.
 * @ghidraAddress 0xd06b4
 */
- (void)startGetArcadeScoreHttpWithOtp:(NSString *)otp;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
