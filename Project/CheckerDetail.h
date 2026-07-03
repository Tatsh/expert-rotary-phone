//
//  CheckerDetail.h
//  pop'n rhythmin
//
//  Music-checker score "detail" screen: a per-song graph plotting the venue top,
//  venue mean and personal-best scores across the four arcade sheets (EX / Hyper /
//  Normal / Easy). Buttons switch the active sheet; tapping the top-score plate
//  toggles between showing the top score and the top holder's name.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithScoreData: @ 0xd752c).
//

#import <UIKit/UIKit.h>

@class ArcadeScoreData;

@interface CheckerDetail : UIViewController

// Build the detail graph for one arcade song record.
- (instancetype)initWithScoreData:(ArcadeScoreData *)scoreData;

// Return a grayscale copy of `image` (device-gray bitmap context redraw).
- (UIImage *)convertGrayScaleImage:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
