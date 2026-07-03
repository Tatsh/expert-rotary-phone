//
//  HowToViewCtrl.m
//  pop'n rhythmin
//
//  See HowToViewCtrl.h. Reconstructed from Ghidra project rb420, program PopnRhythmin. -init,
//  -viewDidLoad and the page-control / scroll interactions (backButtonFunc, pageControlDidChanged:,
//  scrollViewDidScroll:) are decompiled. Some frame origins are NEON-spilled and flagged.
//

#import "HowToViewCtrl.h"
#import "HowToView.h"
#import "neEngineBridge.h"      // neEngine::playSystemSe (page / cancel SE)

@implementation HowToViewCtrl

@synthesize isCloseButtonEnable = _isCloseButtonEnable;
@synthesize fromNaviBarImage = _fromNaviBarImage;
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

// @ 0x837bc — back / close button: play the cancel SE, restore the previous navbar background
// image (if this overlay had overridden it) and pop.
- (void)backButtonFunc {
    // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 2) — cancel SE.
    neEngine::playSystemSe(2);
    if (_fromNaviBarImage) {
        [self.navigationController.navigationBar setBackgroundImage:_fromNaviBarImage
                                                     forBarMetrics:UIBarMetricsDefault];
        _fromNaviBarImage = nil;   // ARC: was release + nil.
    }
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x835d8 — page control tapped: scroll the strip so the selected page is visible.
- (void)pageControlDidChanged:(UIPageControl *)sender {
    CGRect frame = _scrollView.frame;
    frame.origin.x = frame.size.width * sender.currentPage;
    frame.origin.y = 0;
    [_scrollView scrollRectToVisible:frame animated:YES];
}

// @ 0x83670 — track the current page as the user swipes; on a page change play the page SE and,
// in close-button mode, reveal the close button only once the last page is reached.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger oldPage = _pageCtrl.currentPage;
    NSInteger page = (NSInteger)(scrollView.contentOffset.x / scrollView.frame.size.width + 0.5f);
    _pageCtrl.currentPage = page;
    if (oldPage != _pageCtrl.currentPage) {
        // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 4) — page SE.
        neEngine::playSystemSe(4);
        if (_isCloseButtonEnable) {
            _closeBtn.hidden = (_pageCtrl.currentPage != (NSInteger)_fileNameArray.count - 1);
        }
    }
}

// didReceiveMemoryWarning @ 0x834e0 — super-only override, omitted.
// viewWillDisappear: @ 0x8350c — super-only override, omitted.

// dealloc @ 0x83538 — ARC-omitted (released object ivars only: _fileNameArray, _scrollView,
// _pageCtrl, _fromNaviBarImage, _backGroundImage).

@end
