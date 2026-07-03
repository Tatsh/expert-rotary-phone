//
//  PolicyView.mm
//  pop'n rhythmin
//
//  See PolicyView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    init                                @ 0x52a04
//    viewDidLoad                         @ 0x52a8c
//    didReceiveMemoryWarning             @ 0x52eec
//    viewDidUnload                       @ 0x52f18
//    viewWillAppear:                     @ 0x52f44
//    viewDidAppear:                      @ 0x52fac
//    viewWillDisappear:                  @ 0x52fd8
//    viewDidDisappear:                   @ 0x53004
//    shouldAutorotateToInterfaceOrientation:                                @ 0x53030
//    backButtonFunc                                                         @ 0x5303c
//    layoutManager:lineSpacingAfterGlyphAtIndex:withProposedLineFragmentRect: @ 0x53134
//  Objective-C++ for the C++ neEngine / neSceneManager singletons. ARC.
//
//  Honesty notes:
//   - The agreement body is NOT an embedded CFString: -viewDidLoad loads it from
//     the app bundle via -[NSBundle pathForResource:@"policy" ofType:@"txt"] +
//     -[NSData dataWithContentsOfFile:] + -[NSString initWithData:encoding:] with
//     encoding 4 (NSUTF8StringEncoding). The ASCII CFStrings "policy", "txt",
//     "navi_btn_back" and "settings_navbar" are exact byte decodes.
//   - On iOS 7+, a single "\n" is appended to the loaded text (a workaround for
//     the trailing-line clipping in the taller UITextView); exact from the decomp.
//   - All colour/geometry constants are exact float-hex decodes:
//       bg grey 0.953 (0x3f73f3f4, ~243/255), text grey 0.3 (0x3e99999a),
//       bold font 12pt (0x41400000), top content inset 10pt (0x41200000),
//       line spacing 3.8pt (0x40733333, from movw/movt in the delegate method).
//   - The iPad frame is NEON-spilled: the text view is inset from self.view.frame
//     by +10 on x (0x41200000) and -20 on width (0xc1a00000) — reconstructed from
//     the FloatVectorAdd pair; y/height are the view's own.
//   - -backButtonFunc's final pop/remove is a tail-call (jumptable) so the
//     -popViewControllerAnimated: BOOL was not recoverable; YES is best-effort.
//   - The decompiled -viewDidLoad does not assign the text view's
//     layoutManager.delegate; the class still implements the delegate method
//     (declared conformance in the header), so it is kept faithfully as-is.
//

#import "PolicyView.h"

#import "neEngineBridge.h"     // neEngine::playSystemSe, neSceneManager::isPadDisplay

@implementation PolicyView

// @ 0x52a04 — light-grey (0.953) background.
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.view.backgroundColor =
            [UIColor colorWithRed:0.953f green:0.953f blue:0.953f alpha:1.0f];
    }
    return self;
}

// @ 0x52a8c — build the read-only agreement text view from bundled policy.txt,
// then add a nav-bar back button.
- (void)viewDidLoad {
    [super viewDidLoad];

    const BOOL isPad = neSceneManager::isPadDisplay();

    // Text view fills self.view; on pad it is inset (x +10, width -20).
    CGRect frame = self.view.frame;
    if (isPad) {
        frame.origin.x += 10.0f;
        frame.size.width += -20.0f;
    }
    UITextView *textView = [[UITextView alloc] initWithFrame:frame];

    // Load the agreement body (UTF-8) from the bundle.
    NSString *path = [[NSBundle mainBundle] pathForResource:@"policy" ofType:@"txt"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSString *text = [[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 7.0f) {
        text = [text stringByAppendingString:@"\n"];
    }

    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.text = text;
    textView.textColor = [UIColor colorWithRed:0.3f green:0.3f blue:0.3f alpha:1.0f];
    textView.font = [UIFont boldSystemFontOfSize:12.0f];
    textView.userInteractionEnabled = YES;
    textView.contentInset = UIEdgeInsetsMake(10.0f, 0, 0, 0);
    if (isPad) {
        textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self.view addSubview:textView];
    _textView = textView;

    // Nav-bar back button.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backButtonFunc)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];
}

// @ 0x52eec
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0x52f18
- (void)viewDidUnload {
    [super viewDidUnload];
}

// @ 0x52f44 — reset the scroll position to the top each time it appears.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_textView setContentOffset:CGPointZero];
}

// @ 0x52fac
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

// @ 0x52fd8
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

// @ 0x53004
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

// @ 0x53030 — portrait only.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

// @ 0x5303c — back-button action.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);   // cancel/back SE

    UINavigationController *nav = self.navigationController;
    if (!neSceneManager::isPadDisplay() && nav.viewControllers.count > 1) {
        // Phone, embedded in a nav stack: restore the settings nav-bar art and pop.
        [nav.navigationBar setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
                                forBarMetrics:UIBarMetricsDefault];
        [nav popViewControllerAnimated:YES];   // BOOL best-effort (tail-call)
    } else {
        // Pad / presented as the nav root: just drop the nav view.
        [nav.view removeFromSuperview];
    }
}

#pragma mark - NSLayoutManagerDelegate

// @ 0x53134 — constant 3.8pt spacing after every glyph (0x40733333).
- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager
    lineSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex
    withProposedLineFragmentRect:(CGRect)rect {
    return 3.8f;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
