//
//  HowToViewCtrlPad.h
//  pop'n rhythmin
//
//  The iPad how-to overlay: a dimmed full-screen cover view with a centred,
//  horizontally-paged strip of how-to images (a HowToView), a hidden
//  UIPageControl driving a custom dot strip
//  (_pageImgs, built from howto_page_on / howto_page_off), and open / close
//  fade animations. The sibling of the phone variant HowToViewCtrl. Pushed by
//  the setting / friend screens via -initWithFileNameArray: (e.g.
//  SettingHowtoTableViewController, SettingTableViewController). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (initWithFileNameArray: @
//  0x16718, viewDidAppear: @ 0x16b40).
//

#import <UIKit/UIKit.h>

/**
 * @brief The iPad how-to overlay: a paging scroll view over a dimmed cover, with a custom page-dot
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
 * @brief Retain the ordered list of image names to page through.
 * @param fileNameArray The page image names.
 * @return The initialised controller.
 * @ghidraAddress 0x16718
 */
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

/**
 * @brief Fade the overlay and its navigation controller view in.
 * @ghidraAddress 0x17378
 */
- (void)startOpenAnimation;
/**
 * @brief Fade the overlay and its navigation controller view out.
 * @ghidraAddress 0x174b8
 */
- (void)startCloseAnimation;

/**
 * @brief Rebuild the custom page-dot strip for the current page.
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
