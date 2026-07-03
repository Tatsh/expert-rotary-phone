//
//  HowToViewCtrl.m
//  pop'n rhythmin
//
//  See HowToViewCtrl.h. Reconstructed from Ghidra project rb420, program PopnRhythmin. -init and
//  -viewDidLoad are byte-reconstructed; the page-control / scroll interactions (backButtonFunc,
//  pageControlDidChanged:, scrollViewDidScroll:) are best-effort standard behaviour (their bodies
//  are not yet decompiled). Some frame origins are NEON-spilled and flagged.
//

#import "HowToViewCtrl.h"
#import "HowToView.h"

@implementation HowToViewCtrl

@synthesize isCloseButtonEnable = _isCloseButtonEnable;
@synthesize backGroundImage = _backGroundImage;

// @ 0x82e5c — retain the ordered image-name list.
- (instancetype)initWithFileNameArray:(NSArray *)fileNameArray {
    self = [super init];
    if (self != nil) {
        _fileNameArray = fileNameArray;
    }
    return self;
}

// @ 0x82eb0 — build the paging strip, page control and nav-bar buttons.
- (void)viewDidLoad {
    [super viewDidLoad];

    // One image per page.
    NSMutableArray *images = [NSMutableArray array];
    for (NSUInteger i = 0; i < _fileNameArray.count; i++) {
        [images addObject:[UIImage imageNamed:_fileNameArray[i]]];
    }

    // The horizontally-paged strip (count pages wide) over the optional background.
    const CGRect vf = self.view.frame;
    CGRect stripFrame = CGRectMake(0, 0, vf.size.width * _fileNameArray.count, vf.size.height);
    HowToView *strip = [[HowToView alloc] initWithImageList:images
                                                      frame:stripFrame
                                              backGroundImg:_backGroundImage];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
    _scrollView.contentSize = strip.bounds.size;
    _scrollView.pagingEnabled = YES;
    _scrollView.bounces = NO;
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];
    [_scrollView addSubview:strip];

    // Page dots (revealed as the user swipes).
    _pageCtrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, vf.size.width, 30.0f)];
    _pageCtrl.numberOfPages = _fileNameArray.count;
    _pageCtrl.currentPage = 0;
    _pageCtrl.hidden = YES;
    [_pageCtrl addTarget:self action:@selector(pageControlDidChanged:)
        forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_pageCtrl];

    // Nav-bar back button.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backButtonFunc)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    // In "close-button" mode, hide the back button and add a right-bar close button; with more
    // than one page it stays hidden until the last page (revealed in scrollViewDidScroll:).
    if (_isCloseButtonEnable) {
        backBtn.hidden = YES;
        UIImage *closeImg = [UIImage imageNamed:@"howto_btn_close"];
        _closeBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, closeImg.size.width, closeImg.size.height)];
        [_closeBtn setBackgroundImage:closeImg forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:_closeBtn];
        if (_fileNameArray.count > 1) {
            _closeBtn.hidden = YES;
        }
    }
}

// Close the tutorial (back / close button). Ghidra selector backButtonFunc — best-effort pop.
- (void)backButtonFunc {
    [self.navigationController popViewControllerAnimated:YES];
}

// Page control tapped: scroll to that page. Ghidra selector pageControlDidChanged: — best-effort.
- (void)pageControlDidChanged:(id)sender {
    CGFloat w = _scrollView.frame.size.width;
    [_scrollView setContentOffset:CGPointMake(w * _pageCtrl.currentPage, 0) animated:YES];
}

// Track the current page as the user swipes; reveal the close button on the last page. Best-effort.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger page = (NSInteger)(scrollView.contentOffset.x / scrollView.frame.size.width + 0.5f);
    _pageCtrl.currentPage = page;
    _pageCtrl.hidden = NO;
    if (_isCloseButtonEnable && page == (NSInteger)_fileNameArray.count - 1) {
        _closeBtn.hidden = NO;
    }
}

// dealloc — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
