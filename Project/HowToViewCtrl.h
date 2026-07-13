//
//  HowToViewCtrl.h
//  pop'n rhythmin
//
//  A shared tutorial overlay: a horizontally-paged strip of how-to images (a
//  HowToView) with a UIPageControl and a nav-bar back / close button. Used on
//  first entry to several screens (e.g. the friend hub pushes it with
//  "firstplay_friend"). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithFileNameArray: @ 0x82e5c, viewDidLoad @ 0x82eb0).
//

#import <UIKit/UIKit.h>

@interface HowToViewCtrl : UIViewController <UIScrollViewDelegate> {
    NSArray *_fileNameArray;    // image names, one per page
    UIScrollView *_scrollView;  // the paging container
    UIPageControl *_pageCtrl;   // page dots
    UIButton *_closeBtn;        // right-bar close button (when enabled)
    BOOL _isCloseButtonEnable;  // show a close button instead of only "back"
    UIImage *_fromNaviBarImage; // saved navbar bg image to restore on close
    UIImage *_backGroundImage;  // optional strip background
}

// Retain the ordered list of image names to page through. Ghidra: @ 0x82e5c.
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

@property(nonatomic, assign) BOOL isCloseButtonEnable;  // isCloseButtonEnable @ 0x838a4 ;
                                                        // setIsCloseButtonEnable: @ 0x838bc
@property(nonatomic, retain) UIImage *fromNaviBarImage; // fromNaviBarImage @ 0x8385c ;
                                                        // setFromNaviBarImage: @ 0x83870
@property(nonatomic, retain)
    UIImage *backGroundImage; // backGroundImage @ 0x83880 ; setBackGroundImage:
                              // @ 0x83894

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
