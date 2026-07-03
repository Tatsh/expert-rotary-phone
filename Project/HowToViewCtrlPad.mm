//
//  HowToViewCtrlPad.mm
//  pop'n rhythmin
//
//  See HowToViewCtrlPad.h. Reconstructed from Ghidra project rb420, program PopnRhythmin. The iPad
//  how-to overlay differs from the phone HowToViewCtrl: it installs a dimmed, tappable cover view
//  in -viewDidLoad, builds the centred paging strip and custom page-dot images lazily in
//  -viewDidAppear:, and opens / closes with a UIView fade animation instead of a navbar back
//  button. Several frame origins are NEON-spilled in the decompile and are flagged where
//  reconstructed. Uses the neEngine bridge (.mm) for the cancel / page system SE.
//

#import "HowToViewCtrlPad.h"
#import "HowToView.h"
#import "neEngineBridge.h"      // neEngine::playSystemSe (cancel / page SE)

@implementation HowToViewCtrlPad

@synthesize backGroundImage = _backGroundImage;
@synthesize pageCtrl = _pageCtrl;

// @ 0x16718 — retain the ordered image-name list.
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray {
    self = [super init];
    if (self != nil) {
        _fileNameArray = fileNameArray;
    }
    return self;
}

// @ 0x16808 — install the dimmed, tappable cover view and the (hidden) page control. The paging
// strip itself is built later, in -viewDidAppear:.
- (void)viewDidLoad {
    [super viewDidLoad];

    // Dimmed full-screen cover: 50% black, exclusive-touch, with a tap recogniser that closes.
    m_CoverView = [[UIView alloc] initWithFrame:self.view.frame];
    m_CoverView.opaque = NO;
    m_CoverView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
    m_CoverView.userInteractionEnabled = YES;
    m_CoverView.exclusiveTouch = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleTapCoverView:)];
    [m_CoverView addGestureRecognizer:tap];
    [self.view addSubview:m_CoverView];

    // Page tracker, kept hidden (the visible dots are the custom _pageImgs strip).
    const CGRect vf = self.view.frame;
    _pageCtrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, vf.size.width, 30.0f)];
    _pageCtrl.currentPage = 0;
    _pageCtrl.hidden = YES;
    _pageCtrl.center = CGPointMake(self.view.frame.size.width * 0.5f, 160.0f);
    [_pageCtrl addTarget:self action:@selector(pageControlDidChanged:)
        forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_pageCtrl];
}

// @ 0x16adc — reveal the cover fully opaque when the controller appears.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    m_CoverView.alpha = 1.0f;
    m_CoverView.hidden = NO;
}

// @ 0x16b40 — build the centred paging strip, the scroll view, the (hidden) multi-page page
// control and the custom page-dot strip once the view is on screen.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // One image per page.
    NSMutableArray *images = [NSMutableArray array];
    for (NSUInteger i = 0; i < _fileNameArray.count; i++) {
        [images addObject:[UIImage imageNamed:_fileNameArray[i]]];
    }

    // The pages are sized to the first how-to image; the strip is count images wide.
    const CGSize pageSize = [UIImage imageNamed:_fileNameArray[0]].size;   // NEON-spilled
    const CGRect vf = self.view.frame;
    const NSUInteger count = _fileNameArray.count;

    CGRect stripFrame = CGRectMake(0, 0, vf.size.width * count, vf.size.height);
    HowToView *strip = [[HowToView alloc] initWithImageList:images
                                                      frame:stripFrame
                                              backGroundImg:_backGroundImage];

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, pageSize.width, pageSize.height)];
    _scrollView.contentSize = CGSizeMake(pageSize.width * count, pageSize.height);
    _scrollView.pagingEnabled = YES;
    _scrollView.bounces = NO;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.center = CGPointMake(vf.size.width * 0.5f, vf.size.height * 0.5f);
    [self.view addSubview:_scrollView];
    [_scrollView addSubview:strip];

    // With more than one page, size the page tracker (kept hidden — the custom strip is visible).
    if (count > 1) {
        _pageCtrl.numberOfPages = count;
        _pageCtrl.hidden = YES;
    }

    // Custom page-dot strip, centred below the scroll view.
    UIImage *dotImg = [UIImage imageNamed:@"howto_page_off"];
    CGFloat dotsWidth = dotImg.size.width * count + (count * 10 - 10);
    CGFloat dotsCenterY = _scrollView.frame.origin.y + _scrollView.frame.size.height
                          + 20.0f + dotImg.size.height * 0.5f;   // NEON-spilled
    _pageImgs = [[UIView alloc] initWithFrame:CGRectMake(0, 0, dotsWidth, dotImg.size.height)];
    _pageImgs.backgroundColor = [UIColor clearColor];
    _pageImgs.center = CGPointMake(vf.size.width * 0.5f, dotsCenterY);
    [self setPageImages];
    [self.view addSubview:_pageImgs];
}

// didReceiveMemoryWarning @ 0x1718c — super-only override, omitted.
// viewWillDisappear: @ 0x171b8 — super-only override, omitted.

// @ 0x171e4 — page control changed: scroll the strip so the selected page is visible.
- (void)pageControlDidChanged:(UIPageControl *)sender {
    CGRect frame = _scrollView.frame;
    frame.origin.x = frame.size.width * sender.currentPage;
    frame.origin.y = 0;
    [_scrollView scrollRectToVisible:frame animated:YES];
}

// @ 0x1727c — track the current page while swiping, refresh the dot strip, and on a page change
// play the page SE.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger oldPage = _pageCtrl.currentPage;
    NSInteger page = (NSInteger)(scrollView.contentOffset.x / scrollView.frame.size.width + 0.5f);
    _pageCtrl.currentPage = page;
    [self setPageImages];
    if (oldPage != _pageCtrl.currentPage) {
        // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 4) — page SE.
        neEngine::playSystemSe(4);
    }
}

// @ 0x17378 — fade the overlay and its navigation controller view in.
- (void)startOpenAnimation {
    if (!_isAnimationing) {
        _isAnimationing = YES;
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.5];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        self.navigationController.view.alpha = 1.0f;
        [UIView commitAnimations];
    }
}

// @ 0x174a4 — open animation finished.
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x174b8 — play the cancel SE and fade the overlay (and its navigation controller view) out.
- (void)startCloseAnimation {
    // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 2) — cancel SE.
    neEngine::playSystemSe(2);
    if (!_isAnimationing) {
        _isAnimationing = NO;
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.3];   // Ghidra: DAT_000175d0 (double ~0.3).
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    }
}

// @ 0x175d8 — close animation finished: tear the overlay views out of the hierarchy.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [self.view removeFromSuperview];
    _isAnimationing = NO;
}

// @ 0x17634 — rebuild the custom page-dot strip: one image view per page, the current page's dot
// using howto_page_on and the rest howto_page_off, laid out left-to-right.
- (void)setPageImages {
    if (_pageImgs != nil) {
        for (UIView *v in _pageImgs.subviews) {
            [v removeFromSuperview];
        }
        NSInteger x = 0;
        for (NSUInteger i = 0; i < _fileNameArray.count; i++) {
            NSString *name = (i == (NSUInteger)_pageCtrl.currentPage) ? @"howto_page_on"
                                                                      : @"howto_page_off";
            UIImage *img = [UIImage imageNamed:name];
            UIImageView *dot = [[UIImageView alloc] initWithImage:img];
            CGRect f = dot.frame;
            f.origin.x = img.size.width * i + x;   // NEON-spilled: cumulative width + 10px gap
            [dot setFrame:f];
            [_pageImgs addSubview:dot];
            [_pageImgs reloadInputViews];
            x += 10;
        }
    }
}

// @ 0x178f8 — tap on the cover view closes the overlay (unless an animation is in flight).
- (void)handleTapCoverView:(UITapGestureRecognizer *)sender {
    if (_isAnimationing) {
        return;
    }
    [self startCloseAnimation];
}

// @ 0x1676c — detach the cover view before teardown. ARC: released object ivars (_fileNameArray,
// _scrollView, _pageCtrl) are collected automatically; only the removeFromSuperview logic remains.
- (void)dealloc {
    if (m_CoverView != nil) {
        [m_CoverView removeFromSuperview];
        m_CoverView = nil;
    }
}

@end
