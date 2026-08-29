/**
 * @file
 * @brief The scrolling image strip inside a HowToViewCtrl tutorial.
 *
 * The how-to images are laid out side by side over an optional background. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithImageList:frame:backGroundImg: @ 0xe9230,
 * drawRect: @ 0xe9368). The build lives in HowToView.mm.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The paged how-to strip: a row of page images over a shared background.
 */
@interface HowToView : UIView

/**
 * @brief Lay the images side by side, one page wide each, over a background image.
 * @param imageList The page images, as UIImage.
 * @param frame The per-page frame; its width is the page stride.
 * @param backGroundImg The background drawn behind every page.
 * @return The initialised view.
 */
- (instancetype)initWithImageList:(NSArray *)imageList
                            frame:(CGRect)frame
                    backGroundImg:(UIImage *)backGroundImg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
