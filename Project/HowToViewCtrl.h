//
//  HowToViewCtrl.h
//  pop'n rhythmin
//
//  A shared tutorial overlay: a horizontally-paged strip of how-to images (a HowToView) with a
//  UIPageControl and a nav-bar back / close button. Used on first entry to several screens (e.g.
//  the friend hub pushes it with "firstplay_friend"). Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (initWithFileNameArray: @ 0x82e5c, viewDidLoad @ 0x82eb0).
//

#import <UIKit/UIKit.h>

@interface HowToViewCtrl : UIViewController <UIScrollViewDelegate> {
    NSArray *_fileNameArray;        // image names, one per page
    UIScrollView *_scrollView;      // the paging container
    UIPageControl *_pageCtrl;       // page dots
    UIButton *_closeBtn;            // right-bar close button (when enabled)
    BOOL _isCloseButtonEnable;      // show a close button instead of only "back"
    UIImage *_backGroundImage;      // optional strip background
}

// Retain the ordered list of image names to page through. Ghidra: @ 0x82e5c.
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

@property (nonatomic, assign) BOOL isCloseButtonEnable;   // setIsCloseButtonEnable:
@property (nonatomic, retain) UIImage *backGroundImage;   // setBackGroundImage:

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
