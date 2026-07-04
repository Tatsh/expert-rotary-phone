//
//  CustomSplitViewController.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra program PopnRhythmin (32-bit armv7 iOS). Base custom
//  split container: a fixed-width left view controller alongside a right view
//  controller. Pure UIKit/Objective-C (no C++), written for ARC.
//
//  Addresses:
//    initWithFrame:leftViewWidth:leftViewController:rightView: @ 0x5dbc0
//    initWithLeftViewWidth:leftViewController:rightView:       @ 0x5dde0
//    dealloc                                                   @ 0x5de28 (release-only, omitted under ARC)
//    viewDidLoad                                               @ 0x5dea0 (super-only override, omitted)
//    didReceiveMemoryWarning                                   @ 0x5decc (super-only override, omitted)
//    leftViewCtrl / setLeftViewCtrl:   @ 0x5def8 / 0x5df0c (synthesized)
//    rightViewCtrl / setRightViewCtrl: @ 0x5df24 / 0x5df38 (synthesized)
//

#import "CustomSplitViewController.h"

@implementation CustomSplitViewController {
    UIViewController *m_leftViewCtrl;   // @ 0xa4  (exposed as leftViewCtrl)
    UIViewController *m_rightViewCtrl;  // @ 0xa8  (exposed as rightViewCtrl)
    int m_leftViewWidth;                // @ 0xac
}

@synthesize leftViewCtrl = m_leftViewCtrl;
@synthesize rightViewCtrl = m_rightViewCtrl;

// @ 0x5dbc0
- (id)initWithFrame:(CGRect)frame
      leftViewWidth:(int)leftViewWidth
 leftViewController:(UIViewController *)leftViewController
          rightView:(UIViewController *)rightView
{
    // When called with an empty frame, fall back to the container view's own frame.
    if (frame.size.width == 0.0f && frame.size.height == 0.0f) {
        UIView *hostView = [self view];
        frame = hostView ? hostView.frame : CGRectZero;
    }

    // Require a positive left width that still leaves room for the right side.
    if (leftViewWidth <= 0 || (float)leftViewWidth >= frame.size.width) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    m_leftViewWidth = leftViewWidth;

    // Left child: docked at the frame origin, fixed width, full height.
    // All setFrame: args confirmed exact by disassembly trace.
    m_leftViewCtrl = leftViewController;
    [[m_leftViewCtrl view] setFrame:CGRectMake(0.0f,
                                               0.0f,
                                               (float)m_leftViewWidth,
                                               frame.size.height)];
    [m_leftViewCtrl reloadInputViews];

    // Right child: offset past the left column, filling the remaining width.
    m_rightViewCtrl = rightView;
    [[m_rightViewCtrl view] setFrame:CGRectMake(frame.origin.x + (float)m_leftViewWidth,
                                                frame.origin.y,
                                                frame.size.width - (float)m_leftViewWidth,
                                                frame.size.height)];
    [m_rightViewCtrl reloadInputViews];

    [[self view] addSubview:[m_leftViewCtrl view]];
    [[self view] addSubview:[m_rightViewCtrl view]];

    return self;
}

// @ 0x5dde0
- (id)initWithLeftViewWidth:(int)leftViewWidth
         leftViewController:(UIViewController *)leftViewController
                  rightView:(UIViewController *)rightView
{
    return [self initWithFrame:CGRectZero
                 leftViewWidth:leftViewWidth
            leftViewController:leftViewController
                     rightView:rightView];
}

// dealloc @ 0x5de28 — release-only (releases m_leftViewCtrl/m_rightViewCtrl), omitted under ARC.
// viewDidLoad @ 0x5dea0 — super-only override, omitted.
// didReceiveMemoryWarning @ 0x5decc — super-only override, omitted.
// leftViewCtrl @ 0x5def8 / setLeftViewCtrl: @ 0x5df0c — synthesized property accessors.
// rightViewCtrl @ 0x5df24 / setRightViewCtrl: @ 0x5df38 — synthesized property accessors.

@end
