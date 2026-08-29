/**
 * @file
 * A display-only UITextView: no text selection, no edit menu, and never first responder.
 *
 * It is used for message bodies, for example in CommonAlertView. Reconstructed from Ghidra
 * project rb420, program PopnRhythmin.
 */

#import <UIKit/UIKit.h>

/**
 * A display-only UITextView used for message bodies.
 */
@interface CustomTextView : UITextView
@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
