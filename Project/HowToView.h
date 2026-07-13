//
//  HowToView.h
//  pop'n rhythmin
//
//  The scrolling image strip inside a HowToViewCtrl tutorial: the how-to images
//  laid out side by side over an optional background. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (initWithImageList:frame:backGroundImg:
//  @ 0xe9230, drawRect: @ 0xe9368). The build lives in HowToView.mm.
//

#import <UIKit/UIKit.h>

@interface HowToView : UIView

// Lay `imageList` (UIImage*) side by side, `frame` wide per page, over
// `backGroundImg`.
- (instancetype)initWithImageList:(NSArray *)imageList
                            frame:(CGRect)frame
                    backGroundImg:(UIImage *)backGroundImg;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
