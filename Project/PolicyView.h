/**
 * @file
 * @brief The in-app terms-of-use agreement overlay.
 *
 * A full-screen, non-editable UITextView that renders the bundled "policy.txt" (UTF-8) on a
 * light-grey background, with a nav-bar back button. SettingCustomerTableViewController's row 2
 * (利用規約) pushes it, importing this header and instantiating PolicyView directly.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (init @ 0x52a04, viewDidLoad @
 * 0x52a8c, and 9 more methods). Built in PolicyView.mm, where -backButtonFunc drives the C++
 * neEngine and neSceneManager singletons.
 *
 * The class is declared as the text view's NSLayoutManagerDelegate: it implements
 * -layoutManager:lineSpacingAfterGlyphAtIndex:withProposedLineFragmentRect: to force a constant
 * 3.8pt spacing after every glyph. The decompiled -viewDidLoad does not itself assign
 * self.textView.layoutManager.delegate = self; see PolicyView.mm.
 */

#import <UIKit/UIKit.h>

/**
 * @brief The full terms-of-use screen.
 */
@interface PolicyView : UIViewController <NSLayoutManagerDelegate> {
    UITextView *_textView; /**< +0xa4 The scrollable, read-only agreement text. */
}

/**
 * @brief The back-button action: play the cancel SE, then pop on phone when embedded in a
 * navigation stack, or remove the navigation view from its superview on iPad and at the root.
 * @ghidraAddress 0x5303c
 */
- (void)backButtonFunc;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
