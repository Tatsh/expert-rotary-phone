//
//  TouchRangeViewCtrl.mm
//  pop'n rhythmin
//
//  See TouchRangeViewCtrl.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ (ARC) for the neEngine C++ bridge used by
//  -backButtonFunc.
//
//  viewDidLoad builds the single-layout (iPhone) screen entirely in code: a
//  "ta_bg.png" pattern background, a "ta_text" caption image, a 40-148pt radius
//  UISlider with mini/max icons, the embedded TouchRangeView pop-kun preview, a
//  "ta_btn_default.png" reset button, and a custom "navi_btn_back" bar button.
//
//  Touch handling: while a finger is down, -touchesBegan/Moved/Ended track a
//  single touch point (_touchedPoint, seeded to (-1,-1) = "no touch") and
//  toggle the preview's -isTouched flag via -isEnablePoint:, which tests
//  whether the point lies within _radius of the pop-kun centre.
//
//  Honesty / recovery notes:
//   * All CGRect / CGPoint reads in the binary are NEON-spilled with
//   compiler-emitted
//     "receiver == nil -> zero the struct" guards; those are elided here and
//     modelled as ordinary Cocoa -frame / -locationInView: calls (behaviourally
//     identical for the non-nil case that always holds at runtime).
//     _touchedPoint (CGPoint @0xb4) is one such spilled frame.
//   * Float constants are the exact IEEE-754 values decoded from the binary
//   (annotated
//     inline with their hex): 0.95 (0x3f733333), 40.0 (0x42200000), 10.0
//     (0x41200000), 110.0 (0x42dc0000), 148.0 (0x43140000), 160.0 (0x43200000),
//     268.0 (0x43860000), 68.0 (0x42880000), -1.0 (0xbf800000).
//   * -isEnablePoint: calls a free helper pointInCircle(px,py,cx,cy,radius) in
//   the
//     binary; it is inlined here as the equivalent squared-distance test.
//   * The two pop-kun image names ("ta_popkun_before"/"ta_popkun_after") are
//   the ASCII
//     CFStrings @ 0x1389d8 / 0x1389e8 passed to -[TouchRangeView
//     initWithFilename:touched:].
//   * _radius persists via UserSettingData: read with +touchRadius and written
//   with
//     +saveTouchRadius: (both selectors are present in the binary but NOT yet
//     declared in UserSettingData.h -- only +popkunSize is; see the notes at
//     the call sites).
//

#import "TouchRangeViewCtrl.h"

#import "TouchRangeView.h"  // embedded pop-kun preview (_toucheRangeView)
#import "UserSettingData.h" // touchRadius getter (+ saveTouchRadius: setter)
#import "neEngineBridge.h"  // neEngine::playSystemSe (system "cancel" SE)

@implementation TouchRangeViewCtrl {
    UIImageView *_infoView;           // @0xa4  "ta_text" caption art
    UISlider *_radiusSlider;          // @0xa8  40-148pt radius slider
    UIButton *_resetButton;           // @0xac  "ta_btn_default.png" (restore 68pt)
    TouchRangeView *_toucheRangeView; // @0xb0  the pop-kun touch-range preview
    CGPoint _touchedPoint;            // @0xb4  active touch point, or (-1,-1) when none
    float _radius;                    // @0xbc  current touch radius (40..148)
}

// @ 0x8a360
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];

    // NOTE: +touchRadius is present in the binary but not yet declared in
    // UserSettingData.h (only the +popkunSize getter is).
    _radius = [UserSettingData touchRadius];

    // Horizontal layout reference width: the live view width.
    const CGFloat W = self.view.frame.size.width;

    // Background: the "ta_bg.png" pattern.
    UIImage *bgImg = [UIImage imageNamed:@"ta_bg.png"];
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:bgImg]];
    // (binary -release on bgImg here; ARC no-op, omitted)

    // Caption image, centred at (W/2, 40).
    UIImage *textImg = [UIImage imageNamed:@"ta_text"];
    _infoView = [[UIImageView alloc] initWithImage:textImg];
    [_infoView setFrame:CGRectMake(0, 0, textImg.size.width, textImg.size.height)];
    [_infoView setCenter:CGPointMake(W * 0.5f, 40.0f)]; // 0x3f000000 / 0x42200000

    // --- Radius slider ---
    _radiusSlider = [[UISlider alloc] initWithFrame:CGRectMake(0,
                                                               0,
                                                               W * 0.95f,
                                                               10.0f)]; // 0x3f733333 / 0x41200000
    [_radiusSlider setCenter:CGPointMake(W * 0.5f, 110.0f)];            // 0x42dc0000
    [_radiusSlider setMinimumValue:40.0f];                              // 0x42200000
    [_radiusSlider setMaximumValue:148.0f];                             // 0x43140000
    [_radiusSlider setValue:_radius];
    [_radiusSlider setMinimumValueImage:[UIImage imageNamed:@"ta_icon_mini"]];
    [_radiusSlider setMaximumValueImage:[UIImage imageNamed:@"ta_icon_max"]];
    [_radiusSlider setContinuous:NO];
    [_radiusSlider addTarget:self
                      action:@selector(sliderValChanged:)
            forControlEvents:UIControlEventValueChanged]; // 0x1000

    // --- Pop-kun touch-range preview ---
    _toucheRangeView = [[TouchRangeView alloc] initWithFilename:@"ta_popkun_before"
                                                        touched:@"ta_popkun_after"];
    const CGFloat imgW = [_toucheRangeView getImageWidth];
    const CGFloat imgH = [_toucheRangeView getImageHeight];
    // Centred horizontally, top edge at y = 268.
    [_toucheRangeView setFrame:CGRectMake(W * 0.5f - imgW * 0.5f,
                                          268.0f,
                                          imgW,
                                          imgH)]; // 0x43860000

    // --- Reset button ---
    UIImage *resetImg = [UIImage imageNamed:@"ta_btn_default.png"];
    _resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_resetButton setFrame:CGRectMake(0, 0, resetImg.size.width, resetImg.size.height)];
    [_resetButton setCenter:CGPointMake(W * 0.5f, 160.0f)]; // 0x43200000
    [_resetButton setBackgroundImage:resetImg forState:UIControlStateNormal];
    [_resetButton addTarget:self
                     action:@selector(touchedResetButton:)
           forControlEvents:UIControlEventTouchUpInside]; // 0x40

    [self.view addSubview:_infoView];
    [self.view addSubview:_radiusSlider];
    [self.view addSubview:_toucheRangeView];
    [self.view addSubview:_resetButton];

    // No active touch yet.
    _touchedPoint = CGPointMake(-1.0f, -1.0f); // 0xbf800000

    // Custom back bar button.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self
                  action:@selector(backButtonFunc)
        forControlEvents:UIControlEventTouchUpInside]; // 0x40
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
}

// didReceiveMemoryWarning @ 0x8a9d0 — super-only override, omitted (no added
// behavior)

// @ 0x8a9fc — persist the chosen radius on the way out.
// @complete
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // NOTE: +saveTouchRadius: is present in the binary but not yet declared in
    // UserSettingData.h (only the +popkunSize side is).
    [UserSettingData saveTouchRadius:_radius];
    // (binary -release on _infoView / _radiusSlider / _toucheRangeView here; ARC
    //  no-ops, omitted -- the view hierarchy owns them.)
}

// @ 0x8aa9c — live slider drag: track the value (the radius circle is re-tested
// on the next touch via -isEnablePoint:).
// @complete
- (void)sliderValChanged:(id)sender {
    _radius = [_radiusSlider value];
}

// @ 0x8aad0 — reset to the default radius and reflect it on the slider.
// @complete
- (void)touchedResetButton:(id)sender {
    _radius = 68.0f; // 0x42880000
    [_radiusSlider setValue:_radius];
}

// @ 0x8ab04 — YES if `point` lies within _radius of the pop-kun centre. The
// centre is the live view width's midpoint horizontally, and the pop-kun's
// vertical midpoint (top 268 + height/2). Modelled from the binary's
// pointInCircle() helper.
// @complete
- (BOOL)isEnablePoint:(CGPoint)point {
    const CGFloat cx = self.view.frame.size.width * 0.5f;
    const CGFloat cy = [_toucheRangeView getImageHeight] * 0.5f + 268.0f; // 0x43860000
    const CGFloat dx = point.x - cx;
    const CGFloat dy = point.y - cy;
    return (dx * dx + dy * dy) <= (CGFloat)_radius * (CGFloat)_radius;
}

// @ 0x8abd0 — first touch down: if no touch is active, record its point and
// light up the preview when it falls inside the radius.
// @complete
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_touchedPoint.x == -1.0f && _touchedPoint.y == -1.0f) {
        for (UITouch *touch in touches) {
            _touchedPoint = [touch locationInView:self.view];
            if ([self isEnablePoint:_touchedPoint]) {
                [_toucheRangeView setIsTouched:YES];
                [_toucheRangeView setNeedsDisplay];
            }
            break; // binary only inspects the first enumerated touch
        }
    }
}

// @ 0x8ad0c — drag: find the touch whose previous location matches the tracked
// point, update it, and toggle the preview only when the enabled-state actually
// changes.
// @complete
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_touchedPoint.x != -1.0f || _touchedPoint.y != -1.0f) {
        for (UITouch *touch in touches) {
            CGPoint prev = [touch previousLocationInView:self.view];
            if (_touchedPoint.x == prev.x && _touchedPoint.y == prev.y) {
                _touchedPoint = [touch locationInView:self.view];
                BOOL enable = [self isEnablePoint:_touchedPoint];
                if (_toucheRangeView.isTouched != enable) {
                    [_toucheRangeView setIsTouched:enable];
                    [_toucheRangeView setNeedsDisplay];
                }
                break;
            }
        }
    }
}

// @ 0x8af28 — lift: when every touch has ended (or the tracked touch's is the
// one that lifted), clear the preview and reset the tracked point to "none".
// @complete
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_touchedPoint.x != -1.0f || _touchedPoint.y != -1.0f) {
        if ([touches count] == [[event touchesForView:self.view] count]) {
            [_toucheRangeView setIsTouched:NO];
            [_toucheRangeView setNeedsDisplay];
            _touchedPoint = CGPointMake(-1.0f, -1.0f);
        } else {
            for (UITouch *touch in touches) {
                CGPoint prev = [touch previousLocationInView:self.view];
                if (_touchedPoint.x == prev.x && _touchedPoint.y == prev.y) {
                    [_toucheRangeView setIsTouched:NO];
                    [_toucheRangeView setNeedsDisplay];
                    _touchedPoint = CGPointMake(-1.0f, -1.0f);
                    break;
                }
            }
        }
    }
}

// @ 0x8b15c — cancel is handled identically to a normal touch end.
// @complete
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

// @ 0x8b16c — back button: play the cancel SE, restore the settings nav bar
// background and pop.
// @complete
- (void)backButtonFunc {
    neEngine::playSystemSe(2); // Ghidra: NESceneManager_shared();
                               // SysSePlayIntoSlot(&g_pNeSceneManager, 2)
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
