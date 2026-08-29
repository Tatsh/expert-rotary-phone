/**
 * @file
 * @brief A custom modal alert: the styled replacement for UIAlertView, used in around 99 places.
 *
 * A gradient-backed rounded card with a message text view, an optional title, and up to two
 * buttons (cancel and other), shown over the root scene view with an open animation.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <UIKit/UIKit.h>

@class CommonAlertView;

/**
 * @brief Receives the alert's button taps.
 */
@protocol CommonAlertViewDelegate <NSObject>
/**
 * @brief A button was tapped.
 * @param alertView The alert that was dismissed.
 * @param index 0 for the cancel button, 1 for the other button.
 */
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index;
@end

/**
 * @brief A custom modal alert: a styled replacement for UIAlertView, used in roughly 99 places.
 */
@interface CommonAlertView : UIView

/**
 * @brief The UIAlertView-shaped initialiser.
 * @param title The alert title, or nil for none.
 * @param message The alert body.
 * @param delegate The delegate notified of button taps.
 * @param cancelButtonTitle The cancel button's title.
 * @param otherButtonTitles The other button's title, or nil for a one-button alert.
 * @return The initialised alert.
 * @ghidraAddress 0x4a350
 */
- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                     delegate:(id<CommonAlertViewDelegate>)delegate
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles;

/**
 * @brief Add the alert over the root view and run its open animation.
 * @ghidraAddress 0x4b4cc
 */
- (void)show;
/**
 * @brief Whether the alert is currently on screen.
 * @return YES when the alert is not hidden.
 * @ghidraAddress 0x4bb9c
 */
- (BOOL)isVisible;

// Atomic copy properties, using objc_getProperty and objc_setProperty with the atomic flag set.

/** The alert title. Getter @ 0x4bbc0, setter @ 0x4bbd4. */
@property(copy) NSString *title;
/** The alert body. Getter @ 0x4bbe4, setter @ 0x4bbf8. */
@property(copy) NSString *message;

/** The button-tap delegate. The store is a plain barrier'd pointer, not weak. Getter @ 0x4bc08,
 * setter @ 0x4bc1c. */
@property(assign) id<CommonAlertViewDelegate> delegate;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
