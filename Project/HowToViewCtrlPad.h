//
//  HowToViewCtrlPad.h
//  pop'n rhythmin
//
//  The iPad how-to overlay: a dimmed full-screen cover view with a centred, horizontally-paged
//  strip of how-to images (a HowToView), a hidden UIPageControl driving a custom dot strip
//  (_pageImgs, built from howto_page_on / howto_page_off), and open / close fade animations. The
//  sibling of the phone variant HowToViewCtrl. Pushed by the setting / friend screens via
//  -initWithFileNameArray: (e.g. SettingHowtoTableViewController, SettingTableViewController).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFileNameArray: @ 0x16718, viewDidAppear: @ 0x16b40).
//

#import <UIKit/UIKit.h>

@interface HowToViewCtrlPad : UIViewController <UIScrollViewDelegate> {
    NSArray *_fileNameArray;        // image names, one per page
    UIScrollView *_scrollView;      // the paging container (built lazily in viewDidAppear:)
    UIPageControl *_pageCtrl;       // page tracker (kept hidden; drives the custom dot strip)
    UIImage *_backGroundImage;      // optional strip background
    BOOL _isAnimationing;           // guards the open / close fade animations
    UIView *m_CoverView;            // dimmed, tappable full-screen cover
    UIView *_pageImgs;              // container for the custom page-dot image views
}

// Retain the ordered list of image names to page through. Ghidra: @ 0x16718.
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray;

// Fade the overlay (and its navigation controller view) in / out. Ghidra: startOpenAnimation
// @ 0x17378 ; startCloseAnimation @ 0x174b8.
- (void)startOpenAnimation;
- (void)startCloseAnimation;

// Rebuild the custom page-dot strip for the current page. Ghidra: @ 0x17634.
- (void)setPageImages;

// atomic accessors in the binary (objc_getProperty/objc_setProperty and DMB-guarded ivar loads).
@property (retain) UIImage *backGroundImage;   // backGroundImage @ 0x1791c ; setBackGroundImage: @ 0x17930
@property (retain) UIPageControl *pageCtrl;    // pageCtrl @ 0x17940 ; setPageCtrl: @ 0x17954

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
