//
//  CheckerMusicViewController.h
//  pop'n rhythmin
//
//  Music-checker song list: a grouped table of one arcade category's songs,
//  each row a CheckerMusicCell; selecting a row pushes a CheckerDetail score
//  graph. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithScoreData:category: @ 0xd27b8).
//

#import <UIKit/UIKit.h>

@interface CheckerMusicViewController : UITableViewController

// Build the list for one music-checker category: `scoreDataArray` is the array
// of ArcadeScoreData records to show; `category` (0 = etc, 1 = TV, 2..23 =
// p01..p22,
// >=24 = "near") picks the list-header banner image.
- (instancetype)initWithScoreData:(NSArray *)scoreDataArray category:(short)category;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
