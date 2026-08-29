/**
 * @file
 * @brief A custom iPad-style split container.
 *
 * A fixed-width left view controller docked against a right view controller that fills the
 * remaining width. This is the base class the app's concrete split hubs (for example
 * AcViewerSplitViewController) build on. Given a frame (or, when passed CGRectZero, the container
 * view's own frame) and a left-column width, it lays the two children side by side and adds their
 * views as subviews of its own view.
 *
 * Reconstructed from Ghidra program PopnRhythmin (32-bit armv7 iOS). The layout is
 * `m_leftViewCtrl` (UIViewController *) @ 0xa4, `m_rightViewCtrl` (UIViewController *) @ 0xa8,
 * and `m_leftViewWidth` (int) @ 0xac.
 */

#import <UIKit/UIKit.h>

/**
 * @brief A custom iPad-style split container: a fixed-width left view controller docked against a
 * right view controller that fills the remaining width.
 */
@interface CustomSplitViewController : UIViewController

/** The fixed-width left child (m_leftViewCtrl @ +0xa4). Getter @ 0x5def8, setter @ 0x5df0c. */
@property(nonatomic, strong) UIViewController *leftViewCtrl;
/** The right child that fills the remaining width (m_rightViewCtrl @ +0xa8). Getter @ 0x5df24,
 * setter @ 0x5df38. */
@property(nonatomic, strong) UIViewController *rightViewCtrl;

/**
 * @brief Lay the two children side by side inside an explicit frame.
 * @param frame The container frame; CGRectZero uses the container view's own frame.
 * @param leftViewWidth The left column's width, in points.
 * @param leftViewController The left child.
 * @param rightView The right child.
 * @return The initialised container.
 * @ghidraAddress 0x5dbc0
 */
- (id)initWithFrame:(CGRect)frame
         leftViewWidth:(int)leftViewWidth
    leftViewController:(UIViewController *)leftViewController
             rightView:(UIViewController *)rightView;

/**
 * @brief Lay the two children side by side inside the container view's own frame.
 * @param leftViewWidth The left column's width, in points.
 * @param leftViewController The left child.
 * @param rightView The right child.
 * @return The initialised container.
 * @ghidraAddress 0x5dde0
 */
- (id)initWithLeftViewWidth:(int)leftViewWidth
         leftViewController:(UIViewController *)leftViewController
                  rightView:(UIViewController *)rightView;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
