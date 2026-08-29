/**
 * @file
 * @brief A shared tutorial overlay.
 *
 * A horizontally-paged strip of how-to images (a HowToView) with a UIPageControl and a nav-bar
 * back or close button. It is used on first entry to several screens; the friend hub, for
 * example, pushes it with "firstplay_friend". Reconstructed from Ghidra project rb420, program
 * PopnRhythmin (initWithFileNameArray: @ 0x82e5c, viewDidLoad @ 0x82eb0).
 */

#import <UIKit/UIKit.h>

/**
 * @brief The phone how-to overlay: a paging scroll view of full-page images with page dots.
 */
@interface HowToViewCtrl : UIViewController <UIScrollViewDelegate> {
    NSArray *_fileNameArray;    /**< The image names, one per page. */
    UIScrollView *_scrollView;  /**< The paging container. */
    UIPageControl *_pageCtrl;   /**< The page dots. */
    UIButton *_closeBtn;        /**< The right-bar close button, when enabled. */
    BOOL _isCloseButtonEnable;  /**< Show a close button instead of only "back". */
    UIImage *_fromNaviBarImage; /**< The saved nav-bar background to restore on close. */
    UIImage *_backGroundImage;  /**< The optional strip background. */
}

/**
 * @brief Retain the ordered list of image names to page through.
 * @param fileNameArray The page image names.
 * @return The initialised controller.
 * @ghidraAddress 0x82e5c
 */
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

/** Whether to show a close button instead of only "back". Getter @ 0x838a4, setter @ 0x838bc. */
@property(nonatomic, assign) BOOL isCloseButtonEnable;
/** The saved nav-bar background image, restored on close. Getter @ 0x8385c, setter @ 0x83870. */
@property(nonatomic, retain) UIImage *fromNaviBarImage;
/** The optional strip background. Getter @ 0x83880, setter @ 0x83894. */
@property(nonatomic, retain) UIImage *backGroundImage;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
