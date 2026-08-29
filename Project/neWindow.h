/**
 * @file
 * A thin UIWindow subclass.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin. The __objc_classlist entry's
 * class_ro (@ 0x140744) declares flags 0x10, instanceStart 0x90, instanceSize 0x90 (144), and
 * ivars = NULL. Because instanceStart equals instanceSize and the ivar list pointer is null, the
 * class adds no ivars of its own; the 144-byte instance size is entirely the inherited UIWindow
 * layout. The superclass is UIWindow, confirmed by the sole method calling UIWindow's
 * -initWithFrame: via super.
 *
 * Only one method is present in the class method_list (@ 0x140730, count 1): -initWithFrame: @
 * 0x28a00.
 */

#import <UIKit/UIKit.h>

/**
 * The app's UIWindow subclass.
 */
@interface neWindow : UIWindow

/**
 * The designated initialiser; it forwards straight to UIWindow.
 * @param frame The window frame.
 * @return The initialised window.
 * @ghidraAddress 0x28a00
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
