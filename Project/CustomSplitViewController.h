//
//  CustomSplitViewController.h
//  pop'n rhythmin
//
//  A custom iPad-style split container: a fixed-width left view controller
//  docked against a right view controller that fills the remaining width. This
//  is the BASE class that the app's concrete split hubs (e.g.
//  AcViewerSplitViewController) build on. Given a frame (or, when passed
//  CGRectZero, the container view's own frame) and a left-column width, it lays
//  the two children side by side and adds their views as subviews of its own
//  view.
//
//  Reconstructed from Ghidra program PopnRhythmin (32-bit armv7 iOS). Layout:
//    m_leftViewCtrl  UIViewController* @ 0xa4
//    m_rightViewCtrl UIViewController* @ 0xa8
//    m_leftViewWidth int              @ 0xac
//

#import <UIKit/UIKit.h>

@interface CustomSplitViewController : UIViewController

@property(nonatomic, strong)
    UIViewController *leftViewCtrl; // getter @ 0x5def8 / setter @ 0x5df0c (m_leftViewCtrl @ 0xa4)
@property(nonatomic, strong) UIViewController *rightViewCtrl; // getter @ 0x5df24 / setter @ 0x5df38
                                                              // (m_rightViewCtrl @ 0xa8)

- (id)initWithFrame:(CGRect)frame
         leftViewWidth:(int)leftViewWidth
    leftViewController:(UIViewController *)leftViewController
             rightView:(UIViewController *)rightView; // @ 0x5dbc0

- (id)initWithLeftViewWidth:(int)leftViewWidth
         leftViewController:(UIViewController *)leftViewController
                  rightView:(UIViewController *)rightView; // @ 0x5dde0

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
