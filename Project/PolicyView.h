//
//  PolicyView.h
//  pop'n rhythmin
//
//  The in-app Terms-of-Use / agreement overlay: a full-screen, non-editable
//  UITextView that renders the bundled "policy.txt" (UTF-8) on a light-grey
//  background, with a nav-bar back button. Pushed by
//  SettingCustomerTableViewController's row 2 (利用規約), which imports this header
//  and instantiates PolicyView directly.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (init @ 0x52a04, viewDidLoad @ 0x52a8c and 9 more methods). Built in
//  PolicyView.mm (Objective-C++: -backButtonFunc drives the C++ neEngine /
//  neSceneManager singletons).
//
//  The class is declared as the text view's NSLayoutManagerDelegate: it
//  implements -layoutManager:lineSpacingAfterGlyphAtIndex:withProposedLine-
//  FragmentRect: to force a constant 3.8pt spacing after every glyph. (Note:
//  the decompiled -viewDidLoad does not itself assign
//  self.textView.layoutManager.delegate = self — see PolicyView.mm.)
//

#import <UIKit/UIKit.h>

@interface PolicyView : UIViewController <NSLayoutManagerDelegate> {
    UITextView *_textView;   // @0xa4  the scrollable, read-only agreement text
}

// Back-button action: plays the cancel SE, then pops (phone, when embedded in a
// nav stack) or removes the nav view from its superview (pad / root). @ 0x5303c.
- (void)backButtonFunc;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
