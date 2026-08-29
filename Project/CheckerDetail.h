/**
 * @file
 * @brief The music-checker score detail screen.
 *
 * A per-song graph plotting the venue top, venue mean, and personal-best scores across the four
 * arcade sheets (EX, Hyper, Normal, Easy). Buttons switch the active sheet; tapping the top-score
 * plate toggles between showing the top score and the top holder's name. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithScoreData: @ 0xd752c).
 */

#import <UIKit/UIKit.h>

@class ArcadeScoreData;

/**
 * @brief The music-checker score detail screen: a per-song graph of the venue top, venue mean and
 * personal-best scores.
 */
@interface CheckerDetail : UIViewController

/**
 * @brief Build the detail graph for one arcade song record.
 * @param scoreData The record to graph.
 * @return The initialised controller.
 */
- (instancetype)initWithScoreData:(ArcadeScoreData *)scoreData;

/**
 * @brief Redraw an image into a device-gray bitmap context.
 * @param image The image to convert.
 * @return A greyscale copy.
 */
- (UIImage *)convertGrayScaleImage:(UIImage *)image;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
