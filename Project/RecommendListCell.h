//
//  RecommendListCell.h
//  pop'n rhythmin
//
//  A recommend-list row: a pack thumbnail (loaded asynchronously via
//  ImageDownloader), the pack name, the recommend date, the recommending
//  player's name, and a "NEW" badge when the row is newer than the last time
//  the recommend list was viewed. Subview x-offsets shift on iOS 7.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:reuseIdentifier: @ 0xbd418   dealloc @ 0xbd518
//    setRecommendData: @ 0xbd578   imageDownloader:didLoad: @ 0xbe1d0
//    imageDownloaderDidFail:didLoad: @ 0xbe244
//

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

@interface RecommendListCell : UITableViewCell <ImageDownloaderDelegate>

// Rebuild the row from an NSValue-wrapped recommend record and kick off the
// pack thumbnail download.
- (void)setRecommendData:(NSValue *)recommendValue;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
