//
//  CheckerMusicCell.h
//  pop'n rhythmin
//
//  A music-checker song row: banner background plus update-date, title and
//  genre labels. Layout x-offsets vary by iPad + iOS version (computed in
//  init). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xd1d28).
//

#import <UIKit/UIKit.h>

@class ArcadeScoreData;

@interface CheckerMusicCell : UITableViewCell

// Bind the row to one arcade song record: its update date (formatted
// yyyy/MM/dd), title and genre are drawn into three labels over the list
// banner.
- (void)setData:(ArcadeScoreData *)scoreData;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
