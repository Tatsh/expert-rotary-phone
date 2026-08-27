//
//  InputOTPViewCtrl.h
//  pop'n rhythmin
//
//  The e-AMUSEMENT "one-time password" entry screen, pushed by
//  CheckerCategoryViewController when the arcade-score sync requires an OTP. A
//  scrollable form (secure text field limited to 16 characters, a decide button
//  and a custom back button) over the "friman_bg" backdrop, with a dimmed dummy
//  cover + activity spinner used while the parent runs the score sync. Entering
//  a non-empty code calls back -startGetArcadeScoreHttpWithOtp: on the owning
//  CheckerCategoryViewController and pops.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithCategoryView: @ 0x78d18 and the button / text-field / keyboard
//  flow).
//
//  .mm because it drives the C++ "ne" engine singletons via neEngineBridge (the
//  decide / cancel system SE and the scene-manager root view controller
//  callback).
//

#import <UIKit/UIKit.h>

@class CheckerCategoryViewController;
@class TouchableScrollView;

/**
 * @brief The one-time-password entry screen for the arcade-score sync.
 */
@interface InputOTPViewCtrl : UIViewController <UITextFieldDelegate> {
    /** The owner, which receives -startGetArcadeScoreHttpWithOtp:. */
    CheckerCategoryViewController *_categoryView;
    /** The form host; taps pass through to the content. */
    TouchableScrollView *_scrollView;
    UITextField *_otpField; /**< The secure OTP entry; at most 16 characters. */
    /** The dimmed cover and spinner; owned, and released in -dealloc. */
    UIViewController *_dummyView;
    float _scrollOffset; /**< The keyboard scroll offset: 90 on 3.5-inch, 0 on 4-inch. */
}

/**
 * @brief Build the OTP form for an owner and register the keyboard-notification observers.
 * @param categoryView The owner to call back with the entered code.
 * @return The initialised controller.
 * @ghidraAddress 0x78d18
 */
- (instancetype)initWithCategoryView:(CheckerCategoryViewController *)categoryView;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
