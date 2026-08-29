/**
 * @file
 * The music-checker song list.
 *
 * A grouped table of one arcade category's songs, each row a CheckerMusicCell; selecting a row
 * pushes a CheckerDetail score graph. Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initWithScoreData:category: @ 0xd27b8).
 */

#import <UIKit/UIKit.h>

/**
 * The music-checker song list for one arcade category.
 */
@interface CheckerMusicViewController : UITableViewController

/**
 * Build the list for one music-checker category.
 * @param scoreDataArray The ArcadeScoreData records to show.
 * @param category 0 for etc, 1 for TV, 2..23 for p01..p22, and 24 or above for "near". It picks
 * the list-header banner image.
 * @return The initialised controller.
 */
- (instancetype)initWithScoreData:(NSArray *)scoreDataArray category:(short)category;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
