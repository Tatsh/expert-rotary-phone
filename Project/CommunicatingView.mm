//
//  CommunicatingView.mm
//  pop'n rhythmin
//
//  See CommunicatingView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin. -init is
//  byte-reconstructed; the sub-view frames are computed from a heavily NEON-spilled vector
//  sequence, so the exact origins/centres are best-effort (flagged inline). -endCloseAnimation
//  reaches the app's root view controller through neSceneManager and posts -CommunicatingEndCallBack
//  to it.
//
//  .mm because -endCloseAnimation calls into the C++ neSceneManager bridge.
//

#import "CommunicatingView.h"

#import "neEngineBridge.h"       // neSceneManager::shared / rootViewController
#import "MainViewController.h"   // the scene manager's root VC; -CommunicatingEndCallBack

@implementation CommunicatingView

// @ 0xde740 — build the window backdrop, spinner, and the two captions.
- (instancetype)init {
    self = [super init];
    // Ghidra reads self.view.frame here (falling back to CGRectZero when the view is nil).
    CGRect vf = self.view.frame;
    if (self != nil) {
        // Transparent backdrop (colorWithWhite:1.0 alpha:0.0 — swallows touches without dimming).
        self.view.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.0f];

        // Window backdrop image: centred horizontally, raised ~100pt above the vertical centre.
        // (NEON-spilled frame — best-effort.)
        UIImage *windowImg = [UIImage imageNamed:@"cmn_window"];
        CGSize windowSize = windowImg ? windowImg.size : CGSizeZero;
        UIImageView *windowView = [[UIImageView alloc] initWithImage:windowImg];
        windowView.frame = CGRectMake((vf.size.width - windowSize.width) * 0.5f,
                                      vf.size.height * 0.5f - 100.0f,
                                      windowSize.width, windowSize.height);
        [self.view addSubview:windowView];

        // "communicating" caption, centred in the window near the top (y = 70).
        UIImage *loadingImg = [UIImage imageNamed:@"mes_loading"];
        CGSize loadingSize = loadingImg ? loadingImg.size : CGSizeZero;
        communicatingView = [[UIImageView alloc] initWithImage:loadingImg];
        communicatingView.frame = CGRectMake((windowSize.width - loadingSize.width) * 0.5f, 70.0f,
                                             loadingSize.width, loadingSize.height);
        [windowView addSubview:communicatingView];

        // "communication failed" caption, centred in the window; hidden until -failed.
        // (NEON-spilled frame — best-effort.)
        UIImage *failedImg = [UIImage imageNamed:@"mes_loadingerror"];
        CGSize failedSize = failedImg ? failedImg.size : CGSizeZero;
        communicateFailedView = [[UIImageView alloc] initWithImage:failedImg];
        communicateFailedView.frame = CGRectMake((windowSize.width - failedSize.width) * 0.5f,
                                                 (windowSize.height - failedSize.height) * 0.5f,
                                                 failedSize.width, failedSize.height);
        communicateFailedView.hidden = YES;
        [windowView addSubview:communicateFailedView];

        // Spinner near the top of the window (40x40, centred on the window's mid-X at y = 40).
        indicatorView = [[UIActivityIndicatorView alloc]
                            initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        indicatorView.center = CGPointMake(windowSize.width * 0.5f, 40.0f);
        indicatorView.color = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        [indicatorView startAnimating];
        [windowView addSubview:indicatorView];
    }
    return self;
}

// viewDidLoad @ 0xdec30 — super-only override, omitted (no added behavior)

// didReceiveMemoryWarning @ 0xdec5c — super-only override, omitted (no added behavior)

// dealloc @ 0xdec88 — ARC-omitted (chains to super only; releases object ivars only).

// @ 0xdecb4 — enter the "failed" state.
- (void)failed {
    [communicatingView setHidden:YES];
    [communicateFailedView setHidden:NO];
    [indicatorView setHidden:YES];
}

// @ 0xded10 — fade in over 0.3s; endOpenAnimation fires when the fade stops.
- (void)startOpenAnimation {
    if (!_isAnimationing) {
        _isAnimationing = YES;
        self.view.alpha = 0.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        [UIView commitAnimations];
    }
}

// @ 0xdee00 — open fade finished; run a deferred close if one was requested mid-fade.
- (void)endOpenAnimation {
    _isAnimationing = NO;
    if (_isCloseReserve) {
        [self startCloseAnimation];
        _isCloseReserve = YES;   // faithful to 0xdee00 (re-flagged after the deferred close)
    }
}

// @ 0xdee48 — fade out over 0.3s; if a fade is already running, defer the close.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        _isCloseReserve = YES;
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 1.0f;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0xdef48 — close fade finished: tear down and notify the root view controller.
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    neSceneManager::shared();
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root CommunicatingEndCallBack];
}

// @ 0xdef94 — a tap dismisses the overlay only once the failure caption is showing.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([communicateFailedView isHidden]) {
        return;
    }
    [self startCloseAnimation];
}

// @ 0xdefd8
- (BOOL)isAnimationing {
    return _isAnimationing;
}

@end
