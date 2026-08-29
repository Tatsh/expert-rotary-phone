/**
 * @file
 * The iPad how-to overlay.
 *
 * A dimmed full-screen cover view with a centred, horizontally-paged strip of how-to images (a
 * HowToView), a hidden UIPageControl driving a custom dot strip (_pageImgs, built from
 * howto_page_on and howto_page_off), and open and close fade animations. It is the sibling of the
 * phone variant HowToViewCtrl, pushed by the setting and friend screens via
 * -initWithFileNameArray: (for example SettingHowtoTableViewController and
 * SettingTableViewController). Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (initWithFileNameArray: @ 0x16718, viewDidAppear: @ 0x16b40).
 */

#import <UIKit/UIKit.h>

/**
 * The iPad how-to overlay: a paging scroll view over a dimmed cover, with a custom page-dot
 * strip.
 */
@interface HowToViewCtrlPad : UIViewController <UIScrollViewDelegate> {
    NSArray *_fileNameArray;   /**< The image names, one per page. */
    UIScrollView *_scrollView; /**< The paging container, built lazily in -viewDidAppear:. */
    /** The page tracker; kept hidden, it drives the custom dot strip. */
    UIPageControl *_pageCtrl;
    UIImage *_backGroundImage; /**< The optional strip background. */
    BOOL _isAnimationing;      /**< Guards the open and close fade animations. */
    UIView *m_CoverView;       /**< The dimmed, tappable full-screen cover. */
    UIView *_pageImgs;         /**< The container for the custom page-dot image views. */
}

/**
 * Retain the ordered list of image names to page through.
 * @param fileNameArray The page image names.
 * @return The initialised controller.
 * @ghidraAddress 0x16718
 */
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

/**
 * Fade the overlay and its navigation controller view in.
 * @ghidraAddress 0x17378
 */
- (void)startOpenAnimation;
/**
 * Fade the overlay and its navigation controller view out.
 * @ghidraAddress 0x174b8
 */
- (void)startCloseAnimation;

/**
 * Rebuild the custom page-dot strip for the current page.
 * @ghidraAddress 0x17634
 */
- (void)setPageImages;

// The accessors are atomic in the binary, using objc_getProperty and objc_setProperty with
// DMB-guarded ivar loads.

/** The optional strip background. Getter @ 0x1791c, setter @ 0x17930. */
@property(retain) UIImage *backGroundImage;
/** The hidden page tracker driving the custom dot strip. Getter @ 0x17940, setter @ 0x17954. */
@property(retain) UIPageControl *pageCtrl;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
